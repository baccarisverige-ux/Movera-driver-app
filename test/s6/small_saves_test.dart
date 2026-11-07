// S6 I-4 / I-5 (2026-11-07), fail before on main 00762a7a:
// - I-4: a cold start on a trip whose stop the server says was left put
//   the stop behind the driver but did not save it (stopIndex 0 saved);
// - I-5: a booked ride restored from the server (new phone, nothing saved)
//   lost its pickup time and booking id (no booked badge, no late-ETA
//   watch).
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';

import 's6_harness.dart';

const _onTrip = [
  'accepted',
  'driver_to_pickup',
  'arrived',
  'rider_onboard',
  'in_trip',
];

void main() {
  testWidgets('I-4 cold start on trip with a stop the server says was left: '
      'the left stop is saved', (tester) async {
    final h = Harness(tester);
    final at = DateTime.now().toUtc().subtract(const Duration(seconds: 60));
    final stops = [
      {
        'lat': 59.336,
        'lng': 18.07,
        'address': 'Drottninggatan 50, Stockholm',
        'arrivedAt': at.toIso8601String(),
        'leftAt': at.add(const Duration(seconds: 30)).toIso8601String(),
      },
    ];
    for (final s in _onTrip) {
      h.server.change(s, send: false, extra: {'stops': stops});
    }
    final base = savedTrip(ActiveRideStage.onTrip);
    await h.rides.save(
      PersistedActiveRide(
        tripId: base.tripId,
        stage: base.stage,
        savedAt: DateTime.now(),
        riderName: 'Alva',
        pickupLat: base.pickupLat,
        pickupLng: base.pickupLng,
        dropoffLat: base.dropoffLat,
        dropoffLng: base.dropoffLng,
        pickupAddress: base.pickupAddress,
        dropoffAddress: base.dropoffAddress,
        stopAddresses: const ['Drottninggatan 50, Stockholm'],
        stopPoints: const [GeoPoint(59.336, 18.07)],
      ),
    );
    await h.openHome();
    await h.frames(const Duration(seconds: 4));
    expect(find.byType(AcceptRide), findsOneWidget);
    expect((await h.rides.read())?.stopIndex, 1);
    await h.leave();
  });

  for (final status in ['accepted', 'driver_to_pickup', 'arrived', 'in_trip']) {
    testWidgets('I-5 new phone, nothing saved, server booked ride $status: '
        'the pickup time and booking are kept', (tester) async {
      final h = Harness(tester);
      final pickupAt = DateTime.now().toUtc().add(const Duration(minutes: 20));
      h.server.change(
        status,
        send: false,
        tripKind: 'scheduled',
        extra: {'scheduledAt': pickupAt.toIso8601String()},
      );
      h.server.activeTripId = tripId;
      await h.openHome();
      await h.frames(const Duration(seconds: 4));
      expect(find.byType(AcceptRide), findsOneWidget);
      final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
      expect(
        trip.scheduledPickupAt?.isAtSameMomentAs(pickupAt),
        isTrue,
        reason: 'booked badge / late-ETA watch lost',
      );
      final saved = await h.rides.read();
      expect(saved?.scheduledRideId, tripId);
      expect(saved?.scheduledPickupAt?.isAtSameMomentAs(pickupAt), isTrue);
      await h.leave();
    });
  }

  test('I-5 snapshotOf: a now-ride has no booked fields', () {
    final ride = LiveActiveTrip.snapshotOf(
      Map<String, dynamic>.from(projection('accepted', version: 1)),
    )!;
    expect(ride.scheduledPickupAt, isNull);
    expect(ride.scheduledRideId, isNull);
  });
}
