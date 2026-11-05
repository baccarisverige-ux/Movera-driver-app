import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/scheduled/next_booked_ride.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_card.dart';

/// Fix job 5 (contract v0.18.33, owner Q7): a driver on a trip who holds a
/// booked ride as his next one sees "Next: booked ride at HH:MM" on the trip
/// sheet. Before, the trip sheet never showed a booked ride.
ServerReservation ride(String id, String at, {String status = 'accepted'}) =>
    ServerReservation.fromJson({
      'tripId': id,
      'version': 3,
      'scheduledAt': at,
      'categoryId': 'economy',
      'rideType': 'normal',
      'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
      'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
      'stops': 0,
      'distanceMeters': 8000,
      'durationSeconds': 1080,
      'earnings': {'amountMinor': 17360, 'currency': 'SEK'},
      'status': status,
      'mustBeOnlineAt': '2026-11-05T06:00:00Z',
    });

void main() {
  final now = DateTime.utc(2026, 11, 5, 12);
  tearDown(() => DriverAppTexts.language = 'en');

  test('the soonest booked ride he holds, never the trip he drives', () {
    final rides = [
      ride('later', '2026-11-05T14:00:00Z'),
      ride('soon', '2026-11-05T12:40:00Z'),
      ride('driving', '2026-11-05T12:10:00Z'),
      ride('open', '2026-11-05T12:20:00Z', status: 'requested'),
      ride('long-gone', '2026-11-05T10:00:00Z'),
    ];
    expect(
      nextBookedRide(rides, now, currentTripId: 'driving')?.tripId,
      'soon',
    );
    expect(nextBookedRide(const [], now), isNull);
  });

  test('the words in sv / fr / en', () {
    expect(NextBookedRideTexts.title('14:05'), 'Next: booked ride at 14:05');
    DriverAppTexts.language = 'sv';
    expect(NextBookedRideTexts.title('14:05'), 'Nästa: bokad resa kl. 14:05');
    DriverAppTexts.language = 'fr';
    expect(
      NextBookedRideTexts.title('14:05'),
      'Suivante : course réservée à 14:05',
    );
  });

  testWidgets('the trip sheet card shows the next booked ride and its pickup', (
    tester,
  ) async {
    final next = ride('soon', '2026-11-05T12:40:00Z');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextBookedRideCard(
            currentTripId: 'driving',
            now: () => now,
            load: () async =>
                ServerReservations(open: const [], accepted: [next]),
          ),
        ),
      ),
    );
    await tester.pump();
    final time = ServerReservation.clockOf(next.scheduledAt);
    expect(find.text('Next: booked ride at $time'), findsOneWidget);
    expect(find.text('Sergels torg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nothing without a booked ride (and nothing in the demo)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NextBookedRideCard())),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('next-booked-ride-card')), findsNothing);
  });
}
