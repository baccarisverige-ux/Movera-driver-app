import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

/// A real ride against a running movera-server, through the app's own
/// live services (sign-in, availability, location, offers, trip commands
/// and trip events). Skipped unless `MOVERA_E2E_BASE` names the server
/// (e.g. `http://127.0.0.1:8080`) and `MOVERA_E2E_STATE` a folder the rider
/// side (`tool/live_e2e_rider.py`) watches: the test writes `online`, then
/// `accepted-<n>` with the trip id and `done-<n>` after each ride.
///
/// Ride 1 runs pickup to drop-off; on ride 2 the rider cancels and the
/// trip events must say so; on ride 3 the driver cancels before pickup.
void main() {
  final base = Platform.environment['MOVERA_E2E_BASE'];
  final state = Platform.environment['MOVERA_E2E_STATE'];
  final phone = Platform.environment['MOVERA_E2E_DRIVER'] ?? '+46701740605';
  final skip = base == null || state == null
      ? 'Set MOVERA_E2E_BASE and MOVERA_E2E_STATE to run against a server'
      : null;

  test('a driver takes real rides through the server', () async {
    final client = http.Client();
    final tokens = MemoryTokenStore();
    final api = ApiClient(client: client, baseUri: Uri.parse(base!), tokens: tokens);
    final auth = AuthRepository(api: api, tokens: tokens);
    final challenge = await auth.requestCode(phone);
    await auth.verify(challenge.phone, challenge.sessionId, '1234');

    // Norrmalm (zone Z001), near where the rider script books.
    final gps = _MovableLocation(const GeoPoint(59.3326, 18.0649));
    final live = LiveDriverServices(
      client: client,
      origin: Uri.parse(base),
      tokens: tokens,
      api: api,
      location: gps,
      locationEvery: const Duration(seconds: 5),
    );
    void mark(String name, [String text = '']) =>
        File('$state/$name').writeAsStringSync(text);

    expect(await live.presence.goOnline(), isNull, reason: 'online');
    expect(live.presence.serverOnline, isTrue);
    await _until(() => live.dispatch.feedLive, 'offer feed open');
    mark('online');

    Future<RideOffer> nextOffer() async {
      final offers = live.dispatch.watchNearbyOffers();
      final found = await offers
          .firstWhere((list) => list.isNotEmpty)
          .timeout(const Duration(seconds: 120));
      return found.first;
    }

    // ---- Ride 1: pickup to drop-off.
    var offer = await nextOffer();
    var tripId = offer.tripId!;
    expect((await live.dispatch.claimOffer(offer.id)).isSuccess, isTrue);
    expect(live.trips.statusOf(tripId), 'accepted');
    mark('accepted-1', tripId);
    var realtime = live.realtime();
    var events = <DriverRealtimeEvent>[];
    var sub = realtime.subscribe(tripId).listen(events.add);

    expect((await live.trips.begin(tripId)).ok, isTrue);
    expect(live.trips.statusOf(tripId), 'driver_to_pickup');
    // Far from the pickup: the server says so.
    gps.point = const GeoPoint(59.2000, 17.9000);
    await live.reporter.sendNow();
    final early = await live.trips.arrive(tripId);
    expect(early.ok, isFalse);
    expect((early.error! as ApiError).detail, 'not_at_pickup');
    // At the pickup.
    gps.point = offer.pickupPosition;
    expect(await live.reporter.sendNow(), isTrue);
    expect((await live.trips.arrive(tripId)).ok, isTrue);
    expect((await live.trips.start(tripId)).ok, isTrue);
    expect(live.trips.statusOf(tripId), 'in_trip');
    gps.point = offer.dropoffPosition;
    await live.reporter.sendNow();
    expect((await live.trips.complete(tripId)).ok, isTrue);
    expect(live.trips.statusOf(tripId), 'completed');
    await Future<void>.delayed(const Duration(seconds: 2));
    // The stream replayed the trip and its own steps were not echoed.
    expect(events.where((e) => e.status == TripStatus.completed), isEmpty);
    expect(events.any((e) => e.status == TripStatus.accepted), isTrue);
    await sub.cancel();
    realtime.dispose();
    mark('done-1', tripId);

    // ---- Ride 2: the rider cancels; the trip events say so.
    gps.point = const GeoPoint(59.3326, 18.0649);
    await live.reporter.sendNow();
    offer = await nextOffer();
    tripId = offer.tripId!;
    expect((await live.dispatch.claimOffer(offer.id)).isSuccess, isTrue);
    realtime = live.realtime();
    events = <DriverRealtimeEvent>[];
    sub = realtime.subscribe(tripId).listen(events.add);
    expect((await live.trips.begin(tripId)).ok, isTrue);
    mark('accepted-2', tripId);
    await _until(
      () => events.any((e) => e.status == TripStatus.cancelledByRider),
      'rider cancel on the trip events',
      timeout: const Duration(seconds: 60),
    );
    await sub.cancel();
    realtime.dispose();
    mark('done-2', tripId);

    // ---- Ride 3: the driver cancels before pickup (back to dispatch).
    offer = await nextOffer();
    tripId = offer.tripId!;
    expect((await live.dispatch.claimOffer(offer.id)).isSuccess, isTrue);
    mark('accepted-3', tripId);
    final cancelled = await live.trips.cancel(tripId, reasonCode: 'unsafe_pickup');
    expect(cancelled.ok, isTrue, reason: cancelled.message);
    expect(live.trips.statusOf(tripId), 'searching');
    mark('done-3', tripId);

    // Offline again.
    expect(await live.presence.goOffline(), isNull, reason: 'offline');
    expect(live.presence.serverOnline, isFalse);
    await live.dispose();
    client.close();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _until(
  bool Function() done,
  String what, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

class _MovableLocation implements DriverLocationRepository {
  _MovableLocation(this.point);

  GeoPoint point;

  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: point,
    accuracyMeters: 5,
    measuredAt: DateTime.now().toUtc(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
