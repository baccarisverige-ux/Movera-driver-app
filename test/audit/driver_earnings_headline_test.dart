import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Owner decision 2026-10-26 ("price must be after commission that show to
// driver"): every amount the driver sees for a trip is their own money,
// `Offer.driverEarnings` + `Offer.pickupPay` (the bonus is already inside
// the earnings), never the rider's `Offer.fare`. A demo offer without
// server earnings shows the demo's share of its fare after the commission.

/// A server offer: a 200 kr fare of which the driver earns 170 kr, with
/// 9 kr pickup pay.
Map<String, dynamic> _wire({String id = 'api', String payment = 'card'}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-26T12:00:15Z',
  'fare': {'amountMinor': 20000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 17000, 'currency': 'SEK'},
  'pickupPay': {'amountMinor': 900, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': payment,
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

/// [offer]'s card view, as Home and the Live list build it.
RadarOfferView _view(RideOffer offer) => RadarOfferView(
  id: offer.id,
  category: offer.category,
  payment: offer.payment,
  rating: offer.rating,
  fare: offer.fareLabel,
  pickupMinutes: offer.pickupMinutes,
  pickupKm: offer.pickupKm,
  tripMinutes: offer.tripMinutes,
  tripKm: offer.tripKm,
  pickup: offer.pickup,
  dropoff: offer.dropoff,
  driverBonus: WaybillRecord.bonusLabel(offer.driverBonus),
  driverEarnings: offer.driverEarnings?.formatted,
  pickupPay: PickupPayCalculator.quote(
    category: offer.category,
    kind: PickupPayOfferKind.radar,
    leg: PickupLeg(km: offer.pickupKm, minutes: offer.pickupMinutes),
    serverPay: offer.pickupPay,
  ),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Dispatch whose claims the test answers.
class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);

  final List<RideOffer> offers;
  final claims = <Completer<ClaimResult>>[];

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    sink.addSync(offers);
  }, isBroadcast: true);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) {
    final claim = Completer<ClaimResult>();
    claims.add(claim);
    return claim.future;
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });
  tearDown(() {
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  group('the driver\'s money for an offer', () {
    test('a server offer: driverEarnings, with the pickup pay on top', () {
      final offer = OfferWire.parse(_wire());
      expect(offer.driverPay, Money.ore(17000));
      expect(offer.driverPayLabel, '170,00 kr');
      expect(_view(offer).shownFare(const OfferCardDetails()), '179,00 kr');
      // The rider's fare is only the cash to collect, on a cash trip.
      expect(offer.riderCashLabel, '200,00 kr');
    });

    test('an old payload without driverEarnings falls back to the share, '
        'never to 0', () {
      final old = OfferWire.parse(_wire()..remove('driverEarnings'));
      expect(old.driverEarnings, isNull);
      expect(old.driverPay, WaybillPayment.shareOf(Money.ore(20000)));
      expect(old.driverPayLabel, '150,00 kr');
      expect(_view(old).shownFare(const OfferCardDetails()), '159,00 kr');
    });

    test('a demo offer: the fare after the demo commission, the bonus kept '
        'whole, the same number its card shows', () {
      // 168,00 kr fare, no bonus: 25 % commission → 126,00 kr.
      expect(DemoRideCheckTrips.farDropoff.driverPayLabel, '126,00 kr');
      // 152,40 kr with a 40 kr Movera bonus in it: commission on 112,40 kr
      // only → 152,40 − 28,10 = 124,30 kr.
      expect(DemoAdminOffers.radarGroup.fare, Money.ore(15240));
      expect(DemoAdminOffers.radarGroup.driverBonus, Money.ore(4000));
      expect(DemoAdminOffers.radarGroup.driverPayLabel, '124,30 kr');
      for (final offer in [
        DemoRideCheckTrips.farDropoff,
        DemoRideCheckTrips.longStop,
        DemoAdminOffers.radarGroup,
        DemoAdminOffers.radarGroupTaken,
        DemoAdminOffers.directAssign,
        RideOffer.reservation(DemoReservations.main),
      ]) {
        final card = DriverOfferRules.current.card.fare(
          offer.fareLabel,
          bonus: WaybillRecord.bonusLabel(offer.driverBonus),
          earnings: offer.driverEarnings?.formatted,
        );
        expect(offer.driverPayLabel, card, reason: offer.id);
        expect(offer.driverPay.minorUnits, lessThan(offer.fare.minorUnits));
        expect(offer.driverPay.minorUnits, greaterThan(0));
      }
    });

    test('the commission rate admin sets is the one used', () {
      DriverOfferRules.current = const DriverOfferRules(commissionRate: 0.2);
      expect(DemoRideCheckTrips.farDropoff.driverPayLabel, '134,40 kr');
    });

    test('a reservation preview shows the share of its fare', () {
      expect(DemoReservations.main.fare, '126.75 kr');
      expect(DemoReservations.main.driverPayLabel, '95,06 kr');
    });
  });

  group('the offer card and sheets show driverEarnings + pickupPay', () {
    testWidgets('Radar card: 179,00 kr, never the 200,00 kr fare', (
      tester,
    ) async {
      final offer = OfferWire.parse(_wire());
      await _pump(tester, RadarOfferCard(offer: _view(offer), onMatch: () {}));
      expect(find.text('179,00 kr', findRichText: true), findsOneWidget);
      expect(find.textContaining('200,00', findRichText: true), findsNothing);
      expect(find.textContaining('209,00', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Exclusive sheet: the same total', (tester) async {
      final offer = OfferWire.parse(_wire());
      await _pump(
        tester,
        ExclusiveRequestSheet(offer: _view(offer), secondsLeft: 12),
      );
      final fare = tester.widget<Text>(
        find.byKey(const ValueKey<String>('exclusive-fare')),
      );
      expect(fare.textSpan!.toPlainText(), '179,00 kr');
      expect(find.textContaining('200,00', findRichText: true), findsNothing);
    });

    testWidgets('reservation sheet: the share of the fare, never the fare', (
      tester,
    ) async {
      await _pump(
        tester,
        ReservationRequestSheet(
          request: DemoReservations.main,
          clock: () => DateTime(2026, 10, 26, 6, 7),
        ),
      );
      final fare = tester.widget<Text>(
        find.byKey(const ValueKey<String>('reservation-fare')),
      );
      expect(fare.textSpan!.toPlainText(), '95,06 kr');
      expect(find.textContaining('126,75', findRichText: true), findsNothing);
    });
  });

  testWidgets('from the Live list to the trip and its summary: the driver\'s '
      'money, the rider\'s fare only as cash to collect', (tester) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    final offer = OfferWire.parse(_wire(payment: 'cash'));
    final dispatch = _Dispatch([offer]);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: RideRequests(dispatchRepository: dispatch),
      ),
    ));
    await tester.pump();
    // The card: 170 kr earnings + 9 kr pickup pay. No 200 kr anywhere.
    expect(find.text('179,00 kr', findRichText: true), findsWidgets);
    expect(find.textContaining('200,00', findRichText: true), findsNothing);
    final match = find.byKey(const ValueKey<String>('radar-match-api'));
    await tester.ensureVisible(match);
    await tester.tap(match);
    await tester.pump();
    dispatch.claims.single.complete(ClaimResult.success(offer));
    await _frames(tester, const Duration(seconds: 2));

    // The trip opened with the driver's money; the cash to collect is the
    // rider's own fare.
    final trip = tester.widget<AcceptRide>(
      find.byType(AcceptRide, skipOffstage: false),
    );
    expect(trip.fare, '179,00 kr');
    expect(trip.driverBonus, Money.ore(900));
    expect(trip.paidByCash, isTrue);
    expect(trip.cashToCollect, '200,00 kr');
    // Owner N11: the rider's fare travels with the trip for the waybill.
    expect(trip.riderFare, '200,00 kr');
    // Its waybill, which the summary and history are made from.
    final waybill = WaybillStore.current;
    expect(waybill, isNotNull);
    expect(waybill!.fare, '179,00 kr');
    expect(waybill.riderFare, '200,00 kr');
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await _frames(tester, const Duration(seconds: 1));
    tester.takeException();

    // The trip summary (Ride completed) shows that waybill's money.
    WaybillStore.completeCurrent();
    expect(WaybillStore.last?.fare, '179,00 kr');
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    session.beginTrip(trip.tripId);
    await tester.pumpWidget(MaterialApp(
      home: DriverRideCompleted(
        sessionController: session,
        waybillRepository: InMemoryWaybillRepository.instance,
      ),
    ));
    await tester.pumpAndSettle();
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey<String>('ride-completed-fare')),
    );
    expect(summary.textSpan!.toPlainText(), '179,00 kr');
    expect(find.textContaining('200,00', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
