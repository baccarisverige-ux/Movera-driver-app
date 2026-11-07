// Real-screen run 2026-11-07 (Rules audits/screens-2026-11-07/
// full-lifecycle, 2-booked 034, W1 HIGH): on the live app « Acceptera »
// on a booked ride's details sent NO request; the screen went back to the
// list with no message and the ride stayed `requested`. The same details
// showed the demo text « Det här är en lokal förhandsvisning… ».
//
// Cause: the server's list is read again while the details are open (the
// screen's own initState read, every driver_reservations_changed hint):
// ScheduledRideStore.syncFromServer replaces every row object, and
// _openRideDetails checked `_requests.contains(ride)` (identity), so the
// Accept was dropped without a word.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

import '../../integration_test/headless_map_platform.dart';

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

Map<String, Object?> _row(String status) {
  final at = DateTime.now().toUtc().add(const Duration(days: 1));
  return {
    'tripId': 'trp_booked',
    'version': 4,
    'scheduledAt': at.toIso8601String(),
    'categoryId': 'economy',
    'rideType': 'normal',
    'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
    'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
    'stops': 0,
    'distanceMeters': 8000,
    'durationSeconds': 1080,
    'earnings': {'amountMinor': 14943, 'currency': 'SEK'},
    'status': status,
    'mustBeOnlineAt': at.subtract(const Duration(hours: 1)).toIso8601String(),
    'canStartAt': at.subtract(const Duration(hours: 1)).toIso8601String(),
  };
}

void main() {
  testWidgets('W1 Acceptera on the details sends the accept, also after the '
      'list was read again while the details were open', (tester) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    ScheduledRideStore.reset();
    var accepted = false;
    final posts = <String>[];
    final client = MockClient((request) async {
      http.Response json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
      final path = request.url.path;
      if (request.method == 'POST') posts.add(path);
      if (path == '/api/v1/driver/reservations') {
        final scope = request.url.queryParameters['scope'];
        final items = [
          if (scope == 'open' && !accepted) _row('requested'),
          if (scope == 'accepted' && accepted) _row('accepted'),
        ];
        return json({'items': items, 'nextCursor': null});
      }
      if (path == '/api/v1/driver/reservations/trp_booked/accept') {
        accepted = true;
        return json({
          'tripId': 'trp_booked',
          'status': 'accepted',
          'version': 5,
        });
      }
      return json({'code': 'unavailable'}, 503);
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
    addTearDown(() async {
      LiveDriverServices.instance = null;
      await live.dispose();
      ScheduledRideStore.reset();
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(
      () => ScheduledRideStore.syncFromServer(live.reservations),
    );
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.textContaining('Sergels torg').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Live: no demo text on a real booking.
    expect(find.textContaining('local preview'), findsNothing);
    // The list is read again while the details are open.
    await tester.runAsync(
      () => ScheduledRideStore.syncFromServer(live.reservations),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.textContaining('Accept').last);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10 && posts.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(posts, [
      '/api/v1/driver/reservations/trp_booked/accept',
    ], reason: 'no accept request reached the server');
    await tester.pumpWidget(const SizedBox());
  });
}
