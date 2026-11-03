import '../../integration_test/headless_map_platform.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// Live test 2026-11-03 (Rules audits/live-book-later-2026-11-03.md) and
/// the owner's leave-on-time and badge rules, contract v0.18.19. Each test
/// fails on the build before this job.
Map<String, dynamic> _row({Map<String, Object?>? reservation}) => {
  'tripId': 'trp_1',
  'version': 4,
  'scheduledAt': '2026-11-05T09:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
  'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
  'stops': 0,
  'distanceMeters': 8000,
  'durationSeconds': 1080,
  'earnings': {'amountMinor': 19950, 'currency': 'SEK'},
  'status': 'accepted',
  'mustBeOnlineAt': '2026-11-05T08:00:00Z',
  'canStartAt': '2026-11-05T08:00:00Z',
  'reservation': ?reservation,
};

Map<String, dynamic> _offer({bool reservation = true}) => {
  'offerId': 'o1',
  'tripId': 'trp_1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': DateTime.now()
      .add(const Duration(seconds: 15))
      .toUtc()
      .toIso8601String(),
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
  if (reservation) 'reservation': true,
  if (reservation)
    'scheduledAt': DateTime(2026, 11, 5, 7, 40).toUtc().toIso8601String(),
};

RadarOfferView _view({String? reservationTime}) => RadarOfferView(
  id: 'r1',
  category: 'Comfort',
  payment: 'Card',
  rating: '',
  fare: '120,70 kr',
  pickupMinutes: 4,
  pickupKm: 1.2,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Odengatan 63, Stockholm',
  dropoff: 'Solna centrum, Solna',
  reservationTime: reservationTime,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  test('HIGH 2 / leave on time: a list row reads changeAsk, leaveAt and '
      'driveSeconds from its reservation', () {
    final ride = ServerReservation.fromJson(
      _row(
        reservation: {
          'changeAsk': {
            'until': '2026-11-05T07:15:00Z',
            'previousAt': '2026-11-05T08:30:00Z',
          },
          'leaveAt': '2026-11-05T08:32:00Z',
          'driveSeconds': 1080,
        },
      ),
    );
    expect(ride.asksToKeep, isTrue);
    expect(ride.previousAt, DateTime.utc(2026, 11, 5, 8, 30));
    expect(ride.leaveAt, DateTime.utc(2026, 11, 5, 8, 32));
    expect(ride.driveSeconds, 1080);
  });

  test('badge: Offer.reservation gives the booked time and changes no '
      'flow', () {
    final offer = OfferWire.parse(_offer());
    expect(offer.bookedTime, '07:40');
    expect(offer.badgeTime, '07:40');
    expect(offer.isReservation, isFalse);
    expect(OfferWire.parse(_offer(reservation: false)).bookedTime, isNull);
  });

  test('MED 5: home area uses the live fix, else the saved position', () async {
    const live = GeoPoint(59.33, 18.06);
    const saved = GeoPoint(59.31, 18.07);
    expect(
      await ScheduledRideStore.homeAreaPoint(live, fallback: () async => saved),
      live,
    );
    expect(
      await ScheduledRideStore.homeAreaPoint(null, fallback: () async => saved),
      saved,
    );
  });

  testWidgets('badge: the Exclusive offer always shows "Booked ride · 07:40", '
      'even with badges off', (tester) async {
    DriverOfferRules.current = DriverOfferRules.current.withOffers({
      'offerCard': {'badges': false},
    });
    await _pump(
      tester,
      ExclusiveRequestSheet(
        offer: _view(),
        secondsLeft: 12,
        reservation: true,
        reservationTime: '07:40',
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('exclusive-offer-reservation-r1')),
      findsOneWidget,
    );
    expect(find.text('Booked ride · 07:40'), findsOneWidget);
  });

  testWidgets('badge: the Radar card always shows "Booked ride · 07:40", '
      'even with badges off', (tester) async {
    DriverOfferRules.current = DriverOfferRules.current.withOffers({
      'offerCard': {'badges': false},
    });
    await _pump(
      tester,
      RadarOfferCard(
        offer: _view(reservationTime: '07:40'),
        onMatch: () {},
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('radar-offer-reservation-r1')),
      findsOneWidget,
    );
    expect(find.text('Booked ride · 07:40'), findsOneWidget);
  });

  testWidgets('badge: the accepted trip shows "Booked ride · 07:40"', (
    tester,
  ) async {
    await _pump(
      tester,
      TripBottomBar(
        instruction: 'Pick up Maya',
        address: 'Sergels torg',
        onPreferences: () {},
        onTap: () {},
        bookedTime: '07:40',
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('trip-bar-booked')),
      findsOneWidget,
    );
    expect(find.text('Booked ride · 07:40'), findsOneWidget);
  });

  testWidgets('HIGH 2 + MED 6: Keep it at the new time? shows the new time, '
      'the NEW price and Yes / No', (tester) async {
    final ride = ServerReservation.fromJson(
      _row(
        reservation: {
          'changeAsk': {
            'until': '2026-11-05T07:15:00Z',
            'previousAt': '2026-11-05T08:30:00Z',
          },
        },
      ),
    );
    bool? answer;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await askKeepAtNewTime(context, ride),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Keep it at the new time?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('scheduled-keep-price')),
      findsOneWidget,
    );
    expect(find.textContaining(ride.earnings.formatted), findsOneWidget);
    expect(
      find.textContaining(ServerReservation.clockOf(ride.scheduledAt)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('scheduled-keep-yes')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('leave on time: "Start in 12 min", then "Start now towards the '
      'pickup"', (tester) async {
    final pickup = DateTime(2026, 11, 5, 10);
    final leave = DateTime(2026, 11, 5, 9, 32);
    await _pump(
      tester,
      LeaveCountdown(
        leaveAt: leave,
        pickupAt: pickup,
        earlyMin: 10,
        now: () => DateTime(2026, 11, 5, 9, 20),
      ),
    );
    expect(find.text('Start in 12 min'), findsOneWidget);
    expect(find.text('Arrive 10 min before 10:00.'), findsOneWidget);
    await _pump(
      tester,
      LeaveCountdown(
        key: const ValueKey('later'),
        leaveAt: leave,
        pickupAt: pickup,
        earlyMin: 10,
        now: () => DateTime(2026, 11, 5, 9, 33),
      ),
    );
    expect(find.text('Start now towards the pickup'), findsOneWidget);
  });

  testWidgets('badge: the Home popup shows "Booked ride · <time>"', (
    tester,
  ) async {
    await _pump(
      tester,
      ReservationRequestSheet(
        request: DemoReservations.main,
        clock: () => DateTime(2026, 10, 26, 6, 7),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('reservation-booked')),
      findsOneWidget,
    );
    expect(find.textContaining('Booked ride · '), findsOneWidget);
  });

  testWidgets(
    'badge: every card in Booked rides shows "Booked ride · <time>"',
    (tester) async {
      DemoReservations.reset();
      ScheduledRideStore.reset();
      await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      final cards = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('scheduled-booked-'),
      );
      expect(cards, findsWidgets);
      expect(find.textContaining('Booked ride · '), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('HIGH 3: a live booking shows the real map and no demo texts', (
    tester,
  ) async {
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    DemoReservations.reset();
    ScheduledRideStore.reset();
    final live = LiveReservations(
      api: ApiClient(
        client: MockClient((request) async {
          final accepted = request.url.query.contains('accepted');
          return http.Response(
            jsonEncode({
              'items': [if (accepted) _row()],
              'nextCursor': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      ),
    );
    await tester.runAsync(() => ScheduledRideStore.syncFromServer(live));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Accepted').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.textContaining('Sergels torg').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey<String>('scheduled-details-real-map')),
      findsOneWidget,
    );
    expect(find.text('Illustrative route — sample data'), findsNothing);
    expect(find.text('Demo accepted'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
