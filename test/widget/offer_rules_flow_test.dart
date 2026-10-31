import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

// Round 3 (D2) flows: missed Exclusive offers take the driver offline
// (Q16), a hidden Live trip comes back (Q17), only Exclusive offers while
// driving a rider (Q18), cancel reasons that don't count (Q21), and cash
// (Q23/Q24): the switch in the Home sheet and "Collect cash".

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    final sub = _nearby.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
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
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
}

RideOffer _trip(String id, {String payment = 'Card'}) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  pickupMinutes: 3,
  pickupKm: 0.9,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3428, 18.0475),
  isNearby: true,
  followsDestination: false,
  payment: payment,
);

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<DriverSessionController> _pumpHome(
  WidgetTester tester,
  DispatchRepository dispatch,
) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = DriverSessionController();
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: session,
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
  return session;
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

const _closeOffer = ValueKey<String>('exclusive-offer-card-home-direct-close');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  group('Q16: missed Exclusive offers', () {
    testWidgets('one before the limit no warning (G4 decision 7); at it, '
        'offline', (tester) async {
      DriverOfferRules.current = const DriverOfferRules(autoOfflineAfter: 2);
      final session = await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsOneWidget);
      // × is a "no", like letting it run out.
      await tester.tap(
        find.byKey(const ValueKey<String>('direct-offer-dismiss')),
      );
      // Its sheet goes down first.
      await _frames(tester, const Duration(milliseconds: 900));
      // G4 decision 7 (owner "No warning only when set offline").
      expect(_said, isNot(contains('Next missed offer: offline')));
      expect(_said.where((t) => t.contains('offline')), isEmpty);
      expect(session.availableForOffers, isTrue);
      expect(ExclusiveAnswers.instance.missedInRow, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('letting the last one run out takes the driver offline', (
      tester,
    ) async {
      DriverOfferRules.current = const DriverOfferRules(autoOfflineAfter: 2);
      ExclusiveAnswers.instance.missed();
      final session = await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsOneWidget);
      // It runs out after Dispatch's time to accept (15 s).
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 500),
      );
      expect(find.byKey(_closeOffer), findsNothing);
      expect(_said, contains('Offline: 2 offers missed'));
      expect(session.availableForOffers, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Q45: running out while the app is hidden is not a miss', (
      tester,
    ) async {
      DriverOfferRules.current = const DriverOfferRules(autoOfflineAfter: 2);
      ExclusiveAnswers.instance.missed();
      final session = await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsOneWidget);
      // The phone locks with the offer up; its time runs out meanwhile.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(seconds: 2),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(find.byKey(_closeOffer), findsNothing);
      // Still one in the row (the earlier one), and still online.
      expect(ExclusiveAnswers.instance.missedInRow, 1);
      expect(session.availableForOffers, isTrue);
      expect(_said, isNot(contains('Offline: 2 offers missed')));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Accept starts the row again', (tester) async {
      ExclusiveAnswers.instance.missed();
      await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(milliseconds: 2600));
      // The blue radar is the Accept.
      await tester.tap(
        find.byKey(const ValueKey<String>('home-radar-exclusive')),
      );
      await _frames(tester, const Duration(milliseconds: 600));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q23: cash rides on or off', () {
    testWidgets('the switch is in the Home sheet when it is up', (
      tester,
    ) async {
      await _pumpHome(tester, _Dispatch());
      final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      panel.controller!.open();
      await _frames(tester, const Duration(milliseconds: 800));
      final cash = find.byKey(const ValueKey<String>('home-sheet-cash'));
      expect(cash, findsOneWidget);
      expect(find.text('Cash rides'), findsOneWidget);
      expect(DriverOfferPreferences.acceptsCash.value, isTrue);
      await tester.tap(
        find.byKey(const ValueKey<String>('home-sheet-cash-switch')),
      );
      await _frames(tester, const Duration(milliseconds: 300));
      expect(DriverOfferPreferences.acceptsCash.value, isFalse);
      expect(_said, contains('Cash rides off'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('off: no cash trips on Home or in the Live list', (
      tester,
    ) async {
      DriverOfferPreferences.acceptsCash.value = false;
      final dispatch = _Dispatch()
        ..publish([_trip('cash-trip', payment: 'Cash'), _trip('card-trip')]);
      await _pumpHome(tester, dispatch);
      // The demo's first Radar trips reach Home 3 s and 6 s after the
      // Exclusive offer's time to accept.
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 7500),
      );
      final deck = tester.widget<RadarOfferDeck>(
        find.byKey(const ValueKey<String>('radar-home-deck')),
      );
      expect(deck.ids, ['card-trip']);
      // Owner N1: the island's middle ("N offers · radar") opens the list.
      await tester.tap(
        find.byKey(const ValueKey<String>('island-radar-offers')),
      );
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.byType(RideRequests), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-card-trip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-cash-trip')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q17: a trip hidden in the Live list', () {
    Future<_Dispatch> live(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dispatch = _Dispatch()..publish([_trip('live-1'), _trip('live-2')]);
      await tester.pumpWidget(
        MaterialApp(home: RideRequests(dispatchRepository: dispatch)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey<String>('radar-offer-dismiss-live-1')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-live-1')),
        findsNothing,
      );
      return dispatch;
    }

    testWidgets('comes back after the admin\'s minutes if still open', (
      tester,
    ) async {
      await live(tester);
      await tester.pump(const Duration(minutes: 1));
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-live-1')),
        findsNothing,
      );
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-live-1')),
        findsOneWidget,
      );
    });

    testWidgets('taken meanwhile, it stays away', (tester) async {
      final dispatch = await live(tester);
      dispatch.publish([_trip('live-2')]);
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-live-1')),
        findsNothing,
      );
    });
  });

  group('the trip', () {
    Future<void> pumpTrip(WidgetTester tester, Widget ride) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: ride));
      await tester.pump(const Duration(milliseconds: 160));
    }

    SlidingUpPanel panel(WidgetTester tester) =>
        tester.widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel)).last;

    Future<void> middle(WidgetTester tester) async {
      panel(tester).controller!.animatePanelToSnapPoint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 240));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> startTrip(WidgetTester tester) async {
      await middle(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('active-ride-arrived-button')),
      );
      await settle(tester);
      await middle(tester);
      final action = find.byKey(
        const ValueKey<String>('active-ride-primary-action'),
      );
      await tester.ensureVisible(action);
      await tester.drag(action, const Offset(320, 0));
      await settle(tester);
    }

    testWidgets('Q18: while driving a rider, the offer is Exclusive', (
      tester,
    ) async {
      await pumpTrip(tester, const AcceptRide());
      await startTrip(tester);
      await tester.pump(const Duration(milliseconds: 2400));
      final card = find.byKey(
        const ValueKey<String>('on-trip-radar-offer-button'),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(
            const ValueKey<String>('on-trip-exclusive-mark'),
          ),
        ),
        findsOneWidget,
      );
      // G4-E7 (owner "Remove short line explain"): the mark, no "why you"
      // line.
      expect(
        find.descendant(of: card, matching: find.text('Finishing nearby')),
        findsNothing,
      );
      expect(find.textContaining('Radar trip'), findsNothing);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('Exclusive · '),
        ),
        findsOneWidget,
      );
      // Owner 2026-10-27 (contract v0.8.0 §6.7): a deny while driving a
      // rider never counts toward going offline.
      await tester.tap(
        find.byKey(const ValueKey<String>('on-trip-radar-deny')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Q18: admin switched them off: no offers during the trip', (
      tester,
    ) async {
      DriverOfferRules.current = const DriverOfferRules(
        exclusiveWhileDriving: false,
      );
      await pumpTrip(tester, const AcceptRide());
      await startTrip(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(
        find.byKey(const ValueKey<String>('on-trip-radar-offer-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Q21: reasons that don\'t count say so', (tester) async {
      await pumpTrip(tester, const AcceptRide());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byTooltip('Trip route and options').hitTestable());
      await tester.pump(const Duration(milliseconds: 260));
      await tester.tap(
        find.byKey(const ValueKey<String>('active-ride-cancel-option')),
      );
      await tester.pump(const Duration(milliseconds: 260));
      expect(
        find.byKey(const ValueKey<String>('trip-cancellation-reasons-sheet')),
        findsOneWidget,
      );
      expect(
        find.text('You can’t stop there safely · Doesn’t count'),
        findsOneWidget,
      );
      expect(find.text('The rider doesn’t want to continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Q24 / R8-4: a cash trip ends with "Collect cash" → amount → '
        '"Finish Comfort"', (tester) async {
      await pumpTrip(
        tester,
        const AcceptRide(
          fare: '200 kr',
          cashToCollect: '250 kr',
          paidByCash: true,
          riderName: 'Karin',
          category: 'Comfort',
        ),
      );
      await startTrip(tester);
      final collect = find.byKey(
        const ValueKey<String>('active-ride-collect-cash'),
      );
      expect(collect, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-primary-action')),
        findsNothing,
      );
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      // The sheet slides up.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey<String>('cash-collect-sheet')),
        findsOneWidget,
      );
      expect(find.text('250 kr'), findsWidgets);
      expect(find.text('You owe Movera'), findsOneWidget);
      // The driver's 200 kr earnings (owner decision 2026-10-26: no fee
      // off again) − 250 cash.
      expect(find.text('−50,00 kr'), findsOneWidget);
      expect(find.text('Movera fee'), findsNothing);
      expect(find.text('Finish Comfort'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('cash-complete-ride')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final confirm = find.byKey(const ValueKey<String>('finish-soon-finish'));
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
      }
      for (
        var i = 0;
        i < 60 && find.byType(DriverRideCompleted).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.byType(DriverRideCompleted), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
