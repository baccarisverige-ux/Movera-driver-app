import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// driver-12: the pickup pay an offer card adds to its fare is kept when the
// driver accepts. The trip, its waybill and history get the total the card
// showed; the pickup pay is Movera's, like a bonus: no fee on it, all of
// it is the driver's, and a cash rider still pays only the fare.
// Owner decision 2026-10-26: the card's amount is the driver's share of the
// fare (the server's driverEarnings, or the demo's commission rule), so the
// total is share + pickup pay; the rider's fare shows only as cash to
// collect.

/// A trip with a long drive to its pickup: it has pickup pay.
RideOffer _far({String id = 'far', bool cash = false}) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: const Money(minorUnits: 12000),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 8,
  pickupKm: 3.5,
  tripMinutes: 12,
  tripKm: 6.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3380, 18.0700),
  isNearby: true,
  followsDestination: false,
  payment: cash ? 'Cash' : 'Card',
);

Money _radarPay() => PickupPayCalculator.pay(
  category: 'Comfort',
  kind: PickupPayOfferKind.radar,
  leg: const PickupLeg(km: 3.5, minutes: 8),
);

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

void _headless() {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
}

AcceptRide _trip(WidgetTester tester) => tester.widget<AcceptRide>(
  find.byType(AcceptRide, skipOffstage: false),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    WaybillStore.reset();
  });

  test('the accepted terms carry the pickup pay', () {
    final quote = PickupPayQuote(
      pay: Money.ore(380),
      leg: const PickupLeg(km: 1.6, minutes: 4),
    );
    // The terms start from the driver's pay (RideOffer.driverPay): 128,40
    // kr fare → 96,30 kr share, plus the pickup pay.
    final share = WaybillPayment.shareOf(Money.ore(12840));
    expect(share, Money.ore(9630));
    final card = quote.termsOf(fare: share.formatted);
    expect(card.fare, '100,10 kr');
    expect(card.driverBonus, Money.ore(380));
    expect(card.cashToCollect, isNull);
    // A cash trip: the rider's cash (their fare without Movera's bonus,
    // RideOffer.riderCash) is kept as given, never worked out from the
    // driver's pay; the pickup pay is Movera's.
    final cash = quote.termsOf(
      fare: share.formatted,
      driverBonus: Money.ore(4000),
      cashToCollect: '88,40 kr',
    );
    expect(cash.fare, '100,10 kr');
    expect(cash.driverBonus, Money.ore(4380));
    expect(cash.cashToCollect, '88,40 kr');
    final none = PickupPayQuote(
      pay: Money.ore(0),
      leg: const PickupLeg(km: 0.5, minutes: 1),
    ).termsOf(fare: share.formatted);
    expect(none.fare, '96,30 kr');
    expect(none.driverBonus, isNull);
    expect(none.cashToCollect, isNull);

    // The driver gets all of the pickup pay on top of the share.
    expect(
      Money.parseSekLabel(card.fare)! - share,
      Money.ore(380),
    );
  });

  test('a secured next trip saved with the live ride keeps its pickup pay',
      () {
    final next = PersistedQueuedTrip(
      tripId: 'next',
      riderName: 'Omar',
      fare: '128,40 kr',
      category: 'Comfort',
      pickup: 'A',
      dropoff: 'B',
      pickupLat: 59.33,
      pickupLng: 18.06,
      dropoffLat: 59.34,
      dropoffLng: 18.07,
      pickupPay: Money.ore(380),
    );
    expect(PersistedQueuedTrip.fromJson(next.toJson())!.pickupPay,
        Money.ore(380));
  });

  testWidgets('Radar list: the won trip has the fare the card showed', (
    tester,
  ) async {
    expect(_radarPay().ore, greaterThan(0));
    _headless();
    final dispatch = _Dispatch([_far(cash: true)]);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: RideRequests(dispatchRepository: dispatch),
      ),
    ));
    await tester.pump();
    // The card: the driver's share of the 120 kr fare plus the pickup pay;
    // the fare itself is nowhere on the list.
    final total =
        (WaybillPayment.shareOf(Money.ore(12000)) + _radarPay()).formatted;
    expect(find.text(total), findsWidgets);
    expect(find.text('120,00 kr'), findsNothing);
    final match = find.byKey(const ValueKey<String>('radar-match-far'));
    await tester.ensureVisible(match);
    await tester.tap(match);
    await tester.pump();
    dispatch.claims.single.complete(ClaimResult.success(_far(cash: true)));
    await _frames(tester, const Duration(seconds: 2));
    final trip = _trip(tester);
    expect(trip.fare, total);
    expect(trip.driverBonus, _radarPay());
    // The cash to collect is the rider's own fare.
    expect(trip.cashToCollect, '120,00 kr');
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await _frames(tester, const Duration(seconds: 1));
    tester.takeException();
  });

  testWidgets('Home Radar card: the won trip has the fare the card showed', (
    tester,
  ) async {
    _headless();
    final dispatch = _Dispatch([_far()]);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await _frames(
      tester,
      DriverOfferRules.current.exclusiveAcceptTime +
          const Duration(milliseconds: 5000),
    );
    final card = find.byKey(const ValueKey<String>('radar-offer-card-far'));
    expect(card, findsOneWidget);
    final total =
        (WaybillPayment.shareOf(Money.ore(12000)) + _radarPay()).formatted;
    expect(
      find.descendant(of: card, matching: find.text(total)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('120,00 kr')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-far')));
    await tester.pump();
    dispatch.claims.single.complete(ClaimResult.success(_far()));
    await _frames(tester, const Duration(seconds: 2));
    final trip = _trip(tester);
    expect(trip.fare, total);
    expect(trip.driverBonus, _radarPay());
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next trip while driving: the secured trip keeps the total', (
    tester,
  ) async {
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    addTearDown(() => DriverOfferRules.current = const DriverOfferRules());
    ExclusiveAnswers.instance.reset();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AcceptRide(fare: '111,02 kr', category: 'Comfort')),
    );
    await tester.pump(const Duration(milliseconds: 160));
    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    Future<void> middle() async {
      if (find.byKey(const ValueKey('active-ride-arrived-button')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('active-ride-primary-action')).evaluate().isNotEmpty) {
        return;
      }
      panel.controller!.animatePanelToSnapPoint();
      await settle(17);
    }
    await middle();
    await tester.tap(find.byKey(const ValueKey('active-ride-arrived-button')));
    await settle(6);
    await middle();
    await tester.drag(
      find.byKey(const ValueKey('active-ride-primary-action')),
      const Offset(320, 0),
    );
    await settle(6);
    await tester.pump(const Duration(milliseconds: 2400));
    // The demo next trip: the driver's 96,30 kr share of its 128,40 kr
    // fare + 3,80 kr pickup pay (1.6 km, 4 min); the fare is not shown.
    expect(find.text('100,10 kr'), findsWidgets);
    expect(find.text('128,40 kr'), findsNothing);
    expect(find.text('132,20 kr'), findsNothing);
    final match = find.byKey(const ValueKey('on-trip-radar-match-next'));
    await tester.ensureVisible(match);
    await tester.tap(match);
    await tester.pump(const Duration(milliseconds: 1600));
    final next = WaybillStore.next;
    expect(next, isNotNull);
    expect(next!.fare, '100,10 kr');
    expect(next.driverBonus, WaybillRecord.bonusLabel(Money.ore(380)));
    // The pay without the pickup pay is the share of the demo fare.
    expect(
      Money.parseSekLabel(next.fare)! - Money.ore(380),
      WaybillPayment.shareOf(Money.ore(12840)),
    );
    expect(tester.takeException(), isNull);
  });
}
