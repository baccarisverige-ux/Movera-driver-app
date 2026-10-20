import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// The demo reservation as dispatch lists it among the Radar trips.
const _reservationTrip = RideOffer(
  id: demoReservationId,
  category: 'Comfort',
  fare: Money(minorUnits: 12675),
  rating: '4.94',
  pickupMinutes: 16,
  pickupKm: 2.1,
  tripMinutes: 19,
  tripKm: 9.4,
  pickup: 'Gamla vägen, Stockholm',
  dropoff: 'Solna centrum, Solna',
  pickupPosition: GeoPoint(59.3362, 18.0714),
  dropoffPosition: GeoPoint(59.3603, 18.0009),
  isNearby: true,
  followsDestination: false,
  reservationTime: '07:40',
);

/// Dispatch with only what a test publishes: no demo Radar trips.
class _Radar implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  _Radar({this.lose = false});

  final bool lose;
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <String>[];

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
  Future<ClaimResult> claimOffer(String offerId) async {
    claims.add(offerId);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    publish([for (final o in offers) if (o.id != offerId) o]);
    return lose
        ? const ClaimResult.alreadyClaimed()
        : const ClaimResult.success(_reservationTrip);
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  DispatchRepository dispatch, {
  bool popup = true,
}) async {
  final previous = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = DriverRuntimeConfig(
    simulatedArrival: previous.simulatedArrival,
    externalRouting: previous.externalRouting,
    skipAccountActivation: previous.skipAccountActivation,
    liveMapTicker: previous.liveMapTicker,
    islandHint: previous.islandHint,
    reservationPopup: popup,
  );
  addTearDown(() => DriverRuntimeConfig.current = previous);
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    LayoutViewport(
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
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  // Radar on, as the driver does: the demo offer schedule starts.
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

const _exclusiveCard = ValueKey<String>(
  'exclusive-offer-card-$demoReservationId',
);
const _radarCard = ValueKey<String>('radar-offer-card-$demoReservationId');
const _radarBadge = ValueKey<String>(
  'radar-offer-reservation-$demoReservationId',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  testWidgets(
    'near pickup the popup becomes an Exclusive offer with its Reservation '
    'badge, then a Radar trip that never says Exclusive',
    (tester) async {
      final radar = _Radar();
      await _pumpHome(tester, radar);
      await _frames(tester, const Duration(seconds: 3));
      expect(find.byKey(const ValueKey<String>('reservation-popup')).hitTestable(), findsOneWidget);

      // Dispatch lists it among the Radar trips close to pickup …
      await _frames(tester, const Duration(seconds: 33));
      radar.publish(const [_reservationTrip]);
      // … and Home offers it as an Exclusive reservation.
      await _frames(
        tester,
        ReservationDemoTimings.nearPickupAfter -
            const Duration(seconds: 36) +
            const Duration(milliseconds: 600),
      );
      final card = find.byKey(_exclusiveCard);
      expect(card, findsOneWidget);
      final badge = find.byKey(
        const ValueKey<String>('exclusive-offer-reservation-$demoReservationId'),
      );
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('Reservation · 07:40')),
        findsOneWidget,
      );
      expect(_said, contains('Exclusive reservation'));
      // The popup gave it its place; it is still in Scheduled rides.
      expect(find.byKey(const ValueKey<String>('reservation-popup')), findsNothing);
      expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);

      // Untaken, the Exclusive offer goes after Dispatch's time to accept
      // and it joins the Home deck.
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 500),
      );
      expect(card, findsNothing);
      final deckCard = find.byKey(_radarCard);
      expect(deckCard, findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_radarBadge), matching: find.text('Reservation · 07:40')),
        findsOneWidget,
      );
      final deck = find.byKey(const ValueKey<String>('radar-home-deck'));
      expect(
        find.descendant(of: deck, matching: find.textContaining('Exclusive')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('home-radar-accept')),
        findsOneWidget,
      );

      // The full-screen Live list shows it the same way.
      await tester.tap(find.byKey(const ValueKey<String>('radar-home-all-offers')));
      await _frames(tester, const Duration(milliseconds: 800));
      final live = find.byType(RideRequests);
      expect(live, findsOneWidget);
      expect(
        find.descendant(of: live, matching: find.byKey(_radarBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: live, matching: find.textContaining('Exclusive')),
        findsNothing,
      );
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'demo flow: Radar trips wait behind the popup, the near-pickup '
    'Exclusive still comes first, then all of them are on the deck',
    (tester) async {
      final dispatch = DemoDispatchRepository(
        newOfferDelay: const Duration(days: 1),
        externalClaimDelay: const Duration(days: 1),
      );
      await _pumpHome(tester, dispatch);
      await _frames(tester, const Duration(seconds: 15));
      // The popup holds the dock; the demo's first Radar trips wait.
      expect(find.byKey(const ValueKey<String>('reservation-popup')).hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('radar-home-deck')), findsNothing);

      await _frames(
        tester,
        ReservationDemoTimings.nearPickupAfter -
            const Duration(seconds: 15) +
            const Duration(milliseconds: 600),
      );
      expect(find.byKey(_exclusiveCard), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('reservation-popup')), findsNothing);

      // Untaken: the waiting Radar trips come in, the reservation with them.
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 500),
      );
      expect(find.byKey(_exclusiveCard), findsNothing);
      final deck = tester.widget<RadarOfferDeck>(
        find.byKey(const ValueKey<String>('radar-home-deck')),
      );
      // New trips join the back of the deck, the reservation too.
      expect(deck.ids, contains(demoReservationId));
      expect(deck.ids.last, demoReservationId);
      expect(find.textContaining('Exclusive'), findsNothing);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
      dispatch.dispose();
    },
  );

  testWidgets('taken by another driver from the Exclusive offer: gone', (
    tester,
  ) async {
    final radar = _Radar(lose: true);
    await _pumpHome(tester, radar, popup: false);
    await _frames(
      tester,
      ReservationDemoTimings.nearPickupAfter + const Duration(milliseconds: 300),
    );
    final card = find.byKey(_exclusiveCard);
    expect(card, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
    await _frames(tester, const Duration(milliseconds: 900));

    expect(radar.claims, [demoReservationId]);
    expect(_said, contains('No longer available'));
    expect(card, findsNothing);
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(find.byKey(_radarCard), findsNothing);
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a reservation Radar card says Reservation, never Exclusive', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: RadarOfferCard(
              offer: const RadarOfferView(
                id: demoReservationId,
                category: 'Comfort',
                payment: 'Card',
                rating: '4.94',
                fare: '126,75 kr',
                pickupMinutes: 16,
                pickupKm: 2.1,
                tripMinutes: 19,
                tripKm: 9.4,
                pickup: 'Gamla vägen, Stockholm',
                dropoff: 'Solna centrum, Solna',
                reservationTime: '07:40',
              ),
              onMatch: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Reservation · 07:40'), findsOneWidget);
    expect(find.textContaining('Exclusive'), findsNothing);
    expect(find.text('Cash'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('Scheduled rides', () {
    Future<void> openDetails(
      WidgetTester tester, {
      DispatchRepository? dispatch,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: ScheduledRidesScreen(dispatchRepository: dispatch)),
      );
      await tester.pumpAndSettle();
      // The list row opens Reservation details, not the route.
      await tester.tap(find.text('Gamla vägen, Stockholm'));
      await tester.pumpAndSettle();
      expect(find.text('Reservation details'), findsOneWidget);
      expect(find.byType(ReservationRouteMapPage), findsNothing);
    }

    testWidgets('only the Reservation details map opens the route screen', (
      tester,
    ) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await openDetails(tester);
      await tester.tap(find.byKey(const ValueKey<String>('scheduled-route-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final page = tester.widget<ReservationRouteMapPage>(
        find.byType(ReservationRouteMapPage),
      );
      expect(page.request.id, demoReservationId);
      tester.takeException();
      await tester.tap(find.byKey(const ValueKey<String>('reservation-map-close')));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationRouteMapPage), findsNothing);
      expect(find.text('Reservation details'), findsOneWidget);
      tester.takeException();
    });

    for (final won in [true, false]) {
      testWidgets(
        'Accept asks dispatch first: ${won ? 'won → Accepted' : 'lost → '
            '"No longer available" and gone'}',
        (tester) async {
          final dispatch = DemoDispatchRepository(
            claimDelay: const Duration(milliseconds: 400),
            losingOfferId: won ? 'nearby-2' : demoReservationId,
          );
          addTearDown(dispatch.dispose);
          await openDetails(tester, dispatch: dispatch);
          await tester.tap(find.text('Accept  •  126.75 kr'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.byKey(const ValueKey<String>('scheduled-ride-matching')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
          // Won, the 08:05 request clashes with it and leaves the list.
          expect(ScheduledRideStore.openRequests.value, won ? 0 : 1);
          if (won) {
            expect(find.text('Accepted · pickup 07:40'), findsOneWidget);
            expect(find.text('Upcoming'), findsOneWidget);
            expect(find.text('Gamla vägen, Stockholm'), findsOneWidget);
          } else {
            expect(find.text('No longer available'), findsOneWidget);
            expect(find.text('Gamla vägen, Stockholm'), findsNothing);
            await tester.tap(find.text('Accepted'));
            await tester.pumpAndSettle();
            expect(find.text('Gamla vägen, Stockholm'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
