import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/analytics/acceptance%20rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/widgets/exclusive_offer_card.dart';
import 'package:movera/widgets/radar_offer_card.dart';

import '../../integration_test/headless_map_platform.dart';

// Round 3 (D2): offer cards follow the admin's detail switches (Q14), the
// waiting sheet shows the waiting rules (Q19/Q20), the rate screens show
// their rules (Q16/Q22) and trip details show the cash lines (Q23).

const _offer = RadarOfferView(
  id: 'o1',
  category: 'Comfort',
  payment: 'Cash',
  rating: '4.94',
  fare: '100,00 kr',
  pickupMinutes: 4,
  pickupKm: 1.6,
  tripMinutes: 19,
  tripKm: 9.4,
  pickup: 'Gamla vägen, Stockholm',
  dropoff: 'Solna centrum, Solna',
  bags: 1,
  reservationTime: '07:40',
  fareBoost: '+20 kr',
  stops: 1,
  riderTrips: 128,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(375, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    ),
  );
}

ExclusiveOfferCard _exclusive(OfferCardDetails details) => ExclusiveOfferCard(
  offer: _offer,
  reservation: true,
  reservationTime: '07:40',
  details: details,
);

void main() {
  group('offer card details (Q14)', () {
    testWidgets('everything on: the full Exclusive card', (tester) async {
      await _pump(tester, _exclusive(const OfferCardDetails()));
      expect(find.text('100,00 kr', findRichText: true), findsOneWidget);
      expect(find.text('YOUR SHARE'), findsNothing);
      expect(find.text('Gamla vägen'), findsOneWidget);
      expect(find.text('Solna centrum'), findsOneWidget);
      expect(find.text('1.6 km'), findsOneWidget);
      expect(find.text('9.4 km · 1 stop'), findsOneWidget);
      expect(find.text('4.94 · 128 trips'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Reservation · 07:40'), findsOneWidget);
      expect(find.text('+20 kr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each switch takes its detail off', (tester) async {
      await _pump(
        tester,
        _exclusive(
          const OfferCardDetails(
            netFare: true,
            pickupAddress: false,
            dropoffAreaOnly: true,
            stops: false,
            riderRating: false,
            tripMinutesKm: false,
            pickupDistance: false,
            badges: false,
          ),
        ),
      );
      // The driver's share after Movera's 25 %.
      expect(find.text('YOUR SHARE'), findsOneWidget);
      expect(find.text('75,00 kr', findRichText: true), findsOneWidget);
      expect(find.text('Pickup nearby'), findsOneWidget);
      expect(find.text('Gamla vägen'), findsNothing);
      // Only the area of the drop-off.
      expect(find.text('Solna'), findsOneWidget);
      expect(find.text('Solna centrum'), findsNothing);
      expect(find.textContaining(RegExp(r'\d km')), findsNothing);
      expect(find.textContaining('stop'), findsNothing);
      expect(find.textContaining('4.94'), findsNothing);
      expect(find.text('Cash'), findsNothing);
      expect(find.textContaining('Reservation'), findsNothing);
      expect(find.text('+20 kr'), findsNothing);
      // The Exclusive mark and the pickup minutes stay.
      expect(find.text('Exclusive'), findsOneWidget);
      expect(find.text('4 min'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Radar card follows the same switches', (tester) async {
      await _pump(
        tester,
        RadarOfferCard(offer: _offer, onMatch: () {}),
      );
      expect(find.text('128 trips'), findsOneWidget);
      expect(find.text('19 min trip · 9.4 km · 1 stop'), findsOneWidget);
      expect(find.text('1.6 km away'), findsOneWidget);
      await _pump(
        tester,
        RadarOfferCard(
          offer: _offer,
          details: const OfferCardDetails(
            netFare: true,
            riderRating: false,
            badges: false,
            tripMinutesKm: false,
            pickupDistance: false,
          ),
          onMatch: () {},
        ),
      );
      expect(find.text('YOUR SHARE'), findsOneWidget);
      expect(find.text('75,00 kr', findRichText: true), findsOneWidget);
      expect(find.text('4.94'), findsNothing);
      expect(find.text('128 trips'), findsNothing);
      expect(find.text('Cash'), findsNothing);
      expect(find.text('1 stop'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and so does the reservation popup', (tester) async {
      const request = ReservationRequestPreview(
        category: 'Comfort',
        fare: '126.75 kr',
        paidByCash: true,
        pickupLabel: '',
        pickupAddress: 'Gamla vägen, Stockholm',
        dropoffAddress: 'Solna centrum, Solna',
        pickupTime: '07:40',
        pickupDay: 'Today',
        tripMinutes: 19,
        tripKm: 9.4,
        pickup: GeoPoint(59.3362, 18.0714),
        dropoff: GeoPoint(59.3603, 18.0009),
        stops: [
          ReservationStop(
            address: 'Odenplan, Stockholm',
            point: GeoPoint(59.3430, 18.0496),
          ),
        ],
      );
      Widget sheet(OfferCardDetails details) => ReservationRequestSheet(
        request: request,
        details: details,
        clock: () => DateTime(2026, 10, 15, 7),
      );
      // Full width, as on Home.
      Future<void> show(Widget child) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Every detail is on the sheet itself: badges, price, trip numbers
      // and stops.
      await show(sheet(const OfferCardDetails()));
      expect(find.byKey(const ValueKey<String>('reservation-cash')), findsOneWidget);
      expect(find.text('1 stop'), findsOneWidget);
      expect(find.textContaining('19 min', findRichText: true), findsOneWidget);
      await show(const SizedBox());
      await show(
        sheet(
          const OfferCardDetails(
            netFare: true,
            stops: false,
            tripMinutesKm: false,
            badges: false,
            dropoffAreaOnly: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('reservation-cash')), findsNothing);
      // Only the area of the drop-off.
      expect(find.text('Solna'), findsOneWidget);
      expect(find.text('95,06 kr', findRichText: true), findsOneWidget);
      expect(find.text('1 stop'), findsNothing);
      expect(find.textContaining('19 min', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('waiting at pickup (Q19/Q20)', () {
    testWidgets('the sheet shows the rule, the amounts and the share', (
      tester,
    ) async {
      final terms = WaitingRules.current.termsFor(
        category: 'Premium',
        type: WaitingRideType.scheduled,
      );
      WaitingTerms.active = terms;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingTimeSheet(readSeconds: () => 30, terms: terms),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Rule for this pickup: Premium · Scheduled ride'),
        findsOneWidget,
      );
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('16,90 kr / min'), findsOneWidget);
      expect(find.text('65,00 kr'), findsOneWidget);
      expect(
        find.text(
          'You get 100% of the wait time and 80% of the no-show fee '
          '(52,00 kr).',
        ),
        findsOneWidget,
      );
      // Still inside the 5 free minutes.
      expect(find.text('Included minutes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('rate rules (Q16/Q22)', () {
    Future<void> screen(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(home: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cancel rate: the rule, never the limit number', (tester) async {
      await screen(tester, const CancelationRate());
      expect(
        find.text('Keep your cancel rate low to keep full access to trips'),
        findsOneWidget,
      );
      expect(find.textContaining('Doesn’t count'), findsOneWidget);
      expect(find.textContaining('30'), findsNothing);
    });

    testWidgets('acceptance rate: only Exclusive offers count', (tester) async {
      await screen(tester, const AcceptanceRate());
      expect(find.text('Only Exclusive offers count'), findsOneWidget);
      expect(find.textContaining('Radar trips never count'), findsOneWidget);
    });
  });

  testWidgets('trip details of a cash trip: cash collected, +/- balance', (
    tester,
  ) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'cash-1',
              riderName: 'Karin',
              whenLabel: '15/10/2026, 07:59',
              pickup: 'Gamla vägen',
              dropoff: 'Solna centrum',
              fare: '126,75 kr',
              category: 'Comfort',
              paymentMethod: 'Cash',
              cashCollected: '150 kr',
            ),
            loadRideChecks: (_) async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // R8-4: balance = fare − cash = 126,75 − 150 = −23,25 kr.
    final owed = find.text('You owe Movera');
    await tester.ensureVisible(owed);
    expect(find.text('Cash collected'), findsOneWidget);
    expect(find.text('150,00 kr'), findsOneWidget);
    expect(owed, findsOneWidget);
    expect(find.text('−23,25 kr'), findsOneWidget);
    expect(find.text('Settled in your next payout'), findsOneWidget);
    tester.takeException();
  });
}
