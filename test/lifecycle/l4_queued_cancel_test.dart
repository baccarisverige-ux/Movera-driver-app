import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/accept%20ride/next_booked_ride_card.dart';

/// Lifecycle L4 (contract v0.18.50 §72 `lifecycle0_18_50.l4`, owner button
/// 2026-11-07 "Allow cancel (Recommended)"): the Next-trip card of a live
/// trip queued after the current one gets Cancel with the driverNextTrip
/// reasons; the driver's choice is sent as POST /trips/{tripId}/cancel with
/// that reasonCode and the card goes away; his current trip goes on.
void main() {
  final now = DateTime.utc(2026, 11, 7, 12);
  const queuedTrip = {
    'tripId': 'queued-1',
    'status': 'accepted',
    'nextAfterTripId': 'driving',
    'rider': {'firstName': 'Anna'},
    'pickup': {'address': 'Odenplan'},
  };

  setUp(() => CancelReasons.current = const CancelReasons());

  Future<List<(String, String)>> pumpCard(
    WidgetTester tester, {
    Map<String, dynamic>? queued = queuedTrip,
    List<ServerReservation> accepted = const [],
    LiveTripOutcome outcome = const LiveTripOutcome.ok(),
    bool withCancel = true,
  }) async {
    final sent = <(String, String)>[];
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextTripCard(
            currentTripId: 'driving',
            now: () => now,
            queued: (_) => queued,
            load: () async =>
                ServerReservations(open: const [], accepted: accepted),
            cancel: withCancel
                ? (tripId, code) async {
                    sent.add((tripId, code));
                    return outcome;
                  }
                : null,
          ),
        ),
      ),
    );
    await tester.pump();
    return sent;
  }

  testWidgets('the queued trip card has Cancel with the driverNextTrip '
      'reasons; a reason sends the cancel', (tester) async {
    final sent = await pumpCard(tester);
    final cancel = find.byKey(const ValueKey('next-trip-card-cancel'));
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    final codes = [
      for (final r in CancelReasons.current.of(
        CancelReasonGroup.driverNextTrip,
      ))
        r.code,
    ];
    // contract.json#cancelReasons.driverNextTrip
    expect(codes, [
      'next_trip_current_running_late',
      'next_trip_pickup_too_far',
      'next_trip_rider_requested',
      'next_trip_vehicle_issue',
      'next_trip_driver_emergency',
      'next_trip_other',
    ]);
    for (final code in codes) {
      expect(
        find.byKey(ValueKey('next-trip-card-reason-$code')),
        findsOneWidget,
      );
    }
    expect(find.text('Cancel the next trip?'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('next-trip-card-reason-next_trip_pickup_too_far'),
      ),
    );
    await tester.pumpAndSettle();
    expect(sent, [('queued-1', 'next_trip_pickup_too_far')]);
    expect(find.byKey(const ValueKey('next-trip-card')), findsNothing);
    expect(find.textContaining('Next trip cancelled'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Keep trip sends nothing', (tester) async {
    final sent = await pumpCard(tester);
    await tester.tap(find.byKey(const ValueKey('next-trip-card-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-trip-card-keep')));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(find.byKey(const ValueKey('next-trip-card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a refused cancel keeps the card and says the server error', (
    tester,
  ) async {
    await pumpCard(
      tester,
      outcome: const LiveTripOutcome.failed('Could not cancel'),
    );
    await tester.tap(find.byKey(const ValueKey('next-trip-card-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('next-trip-card-reason-next_trip_other')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-trip-card')), findsOneWidget);
    expect(find.text('Could not cancel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a booked ride on the card has no Cancel here', (tester) async {
    await pumpCard(
      tester,
      queued: null,
      accepted: [
        ServerReservation.fromJson({
          'tripId': 'booked-1',
          'version': 3,
          'scheduledAt': '2026-11-07T12:40:00Z',
          'categoryId': 'economy',
          'rideType': 'normal',
          'pickup': {'address': 'Odenplan', 'lat': 59.34, 'lng': 18.05},
          'dropoff': {'address': 'T-Centralen', 'lat': 59.33, 'lng': 18.06},
          'stops': 0,
          'distanceMeters': 8000,
          'durationSeconds': 1080,
          'earnings': {'amountMinor': 17360, 'currency': 'SEK'},
          'status': 'accepted',
          'mustBeOnlineAt': '2026-11-07T11:40:00Z',
        }),
      ],
    );
    expect(find.byKey(const ValueKey('next-trip-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('next-trip-card-cancel')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
