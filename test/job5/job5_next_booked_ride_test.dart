import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/ride/next_trip.dart';
import 'package:movera/core/scheduled/next_booked_ride.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_card.dart';

/// Fix job 5 (contract v0.18.33, owner Q7 + 2026-11-05): while on a trip the
/// driver sees his next trip on the sheet (a live trip he accepted, or a
/// booked ride whose time to drive is near); after Complete the next trip
/// opens with an information popup and one OK button.
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

const queuedTrip = {
  'tripId': 'trp_next',
  'version': 4,
  'status': 'accepted',
  'nextAfterTripId': 'driving',
  'rider': {'firstName': 'Anna'},
  'pickup': {'address': 'Odenplan', 'lat': 59.34, 'lng': 18.04},
};

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
  });

  test('next trip: the queued live trip first; a booked one only when its '
      'time to drive is near', () {
    expect(
      nextTripAfter('driving', queued: queuedTrip, now: now)?.tripId,
      'trp_next',
    );
    expect(
      nextTripAfter(
        'driving',
        accepted: [ride('far', '2026-11-05T15:00:00Z')],
        now: now,
      ),
      isNull,
    );
    expect(
      nextTripAfter(
        'driving',
        accepted: [ride('near', '2026-11-05T12:40:00Z')],
        now: now,
      )?.booked,
      isTrue,
    );
  });

  test('after the trip ends: the queued trip, or a booked ride the server '
      'started; a live trip nobody queued is not a next trip', () {
    final queued = NextTrip.fromQueued(queuedTrip);
    expect(
      nextTripOfProjection(const {
        'tripId': 'trp_next',
      }, queued: queued)?.riderName,
      'Anna',
    );
    final booked = nextTripOfProjection(const {
      'tripId': 'trp_b',
      'kind': 'scheduled',
      'scheduledAt': '2026-11-05T12:40:00Z',
      'pickup': {'address': 'Sergels torg'},
    });
    expect(booked?.booked, isTrue);
    expect(nextTripOfProjection(const {'tripId': 'x', 'kind': 'live'}), isNull);
  });

  test('the words in sv / fr / en', () {
    expect(
      DriverL10n.strings.nextTripAfterThis('Anna'),
      'Next: Anna · after this trip',
    );
    DriverAppTexts.language = 'sv';
    expect(
      DriverL10n.strings.nextBookedRideAt('14:05'),
      'Nästa: bokad resa kl. 14:05',
    );
    DriverAppTexts.language = 'fr';
    expect(DriverL10n.strings.nextTripPopupTitle, 'Votre prochaine course');
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    Map<String, dynamic>? queued,
    List<ServerReservation> accepted = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextTripCard(
            currentTripId: 'driving',
            now: () => now,
            queued: (_) => queued,
            load: () async =>
                ServerReservations(open: const [], accepted: accepted),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('card: a second trip he accepted during this one', (
    tester,
  ) async {
    await pumpCard(tester, queued: queuedTrip);
    expect(find.text('Next: Anna · after this trip'), findsOneWidget);
    expect(find.text('Odenplan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('card: a booked ride whose time to drive is near', (
    tester,
  ) async {
    final next = ride('soon', '2026-11-05T12:40:00Z');
    await pumpCard(tester, accepted: [next]);
    final time = ServerReservation.clockOf(next.scheduledAt);
    expect(find.text('Next: booked ride at $time'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('card: nothing without a next trip', (tester) async {
    await pumpCard(tester, accepted: [ride('far', '2026-11-05T15:00:00Z')]);
    expect(find.byKey(const ValueKey('next-trip-card')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('after Complete: the next trip with its popup; OK closes it '
      'and the trip stays', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NextTripPopupHost(
          next: NextTrip.fromQueued(queuedTrip)!,
          child: const Scaffold(body: Text('next trip screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-trip-popup')), findsOneWidget);
    expect(find.text('Your next trip'), findsOneWidget);
    expect(
      find.text('Anna is waiting at Odenplan. Drive there now.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('next-trip-popup-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-trip-popup')), findsNothing);
    expect(find.text('next trip screen'), findsOneWidget);
  });
}
