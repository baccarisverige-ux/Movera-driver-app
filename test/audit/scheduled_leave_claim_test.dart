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
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// driver-fixrev-7 / driver-fixrev-6: "Leave now" for an accepted ride while
// a Match is being sent. The scheduled trip waits for the claim's answer
// (a won claim must not get a second trip screen on top), and a claim that
// does not win lets the late ride start at once, not at the backup timer.
// driver-fixrev-8: trips are filtered toward the pickup from the admin's
// `reservations.towardPickupBeforeMin`, not the ride type's online window.

/// Dispatch whose claims the test answers.
class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <Completer<ClaimResult>>[];

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
  Future<ClaimResult> claimOffer(String offerId) {
    final claim = Completer<ClaimResult>();
    claims.add(claim);
    return claim.future;
  }
}

/// A short Radar trip that ends near the 07:40 pickup: it fits the gap.
final _toward = RideOffer(
  id: 'toward',
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 2,
  pickupKm: 0.8,
  tripMinutes: 6,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3380, 18.0700),
  isNearby: true,
  followsDestination: false,
);

/// A short trip that fits the gap but ends south, away from the pickup.
final _away = RideOffer(
  id: 'away',
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 1,
  pickupKm: 0.8,
  tripMinutes: 3,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Södermalm, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3240, 18.0700),
  isNearby: true,
  followsDestination: false,
);

/// An admin direct assign (contract §3.1) that fits the gap before 07:40.
final _assign = RideOffer(
  id: 'assign',
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Karim',
  pickupMinutes: 2,
  pickupKm: 0.8,
  tripMinutes: 6,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3380, 18.0700),
  isNearby: true,
  followsDestination: false,
  priority: true,
  source: OfferSource.admin,
);

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Home with the 07:40 ride accepted, online, with "toward" on the deck.
/// With [deck] false it returns once the Radar is on.
Future<_Dispatch> _pumpHome(
  WidgetTester tester, {
  List<RideOffer>? offers,
  bool deck = true,
}) async {
  ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
  final dispatch = _Dispatch()..publish(offers ?? [_toward]);
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
  // Radar on, as the driver does.
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
  if (!deck) { return dispatch; }
  await _frames(
    tester,
    DriverOfferRules.current.exclusiveAcceptTime +
        const Duration(milliseconds: 3500),
  );
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-toward')),
    findsOneWidget,
  );
  return dispatch;
}

/// Past "Leave now" (about 46 s into the demo day) with the claim open.
Future<void> _pastLeaveNow(WidgetTester tester) =>
    _frames(tester, const Duration(seconds: 30));

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() => ScheduledRideRules.current = const ScheduledRideRules());

  group('driver-fixrev-7: a Radar list Match in flight at "Leave now"', () {
    Future<_Dispatch> matchInList(WidgetTester tester) async {
      final dispatch = await _pumpHome(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('island-radar-offers')),
      );
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.byType(RideRequests), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('radar-match-toward')));
      await tester.pump();
      expect(dispatch.claims, hasLength(1));
      await _pastLeaveNow(tester);
      // The scheduled trip waits for the claim's answer.
      expect(find.byType(AcceptRide), findsNothing);
      expect(ScheduledRideStore.upcoming, contains(demoReservationRequest));
      return dispatch;
    }

    testWidgets('won: only the Radar trip opens, one trip screen', (
      tester,
    ) async {
      final dispatch = await matchInList(tester);
      dispatch.claims.single.complete(ClaimResult.success(_toward));
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide, skipOffstage: false), findsOneWidget);
      expect(
        tester
            .widget<AcceptRide>(find.byType(AcceptRide, skipOffstage: false))
            .matchedVia,
        'Movera Radar',
      );
      await _end(tester);
    });

    testWidgets('lost: the late scheduled trip opens right away', (
      tester,
    ) async {
      final dispatch = await matchInList(tester);
      dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(
        tester.widget<AcceptRide>(find.byType(AcceptRide)).matchedVia,
        'Scheduled ride',
      );
      await _end(tester);
    });
  });

  group('driver-fixrev-6: a Home Radar Match in flight at "Leave now"', () {
    for (final outcome in ['lost', 'network error']) {
      testWidgets('$outcome: the late scheduled trip opens right away', (
        tester,
      ) async {
        final dispatch = await _pumpHome(tester);
        await tester.tap(find.byKey(const ValueKey<String>('radar-match-toward')));
        await tester.pump();
        expect(dispatch.claims, hasLength(1));
        await _pastLeaveNow(tester);
        expect(find.byType(AcceptRide), findsNothing);

        dispatch.claims.single.complete(
          outcome == 'lost'
              ? const ClaimResult.alreadyClaimed()
              : const ClaimResult.networkError(),
        );
        // Well before the backup minutes (10 s of the demo day).
        await _frames(tester, const Duration(seconds: 2));
        expect(find.byType(AcceptRide), findsOneWidget);
        expect(
          tester.widget<AcceptRide>(find.byType(AcceptRide)).matchedVia,
          'Scheduled ride',
        );
        await _end(tester);
      });
    }
  });

  group('driver-fixrev2-1: an Exclusive Accept in flight at "Leave now"', () {
    Future<_Dispatch> acceptAssign(WidgetTester tester) async {
      final dispatch = await _pumpHome(tester, offers: [_assign], deck: false);
      expect(
        find.byKey(const ValueKey<String>('exclusive-offer-card-assign')),
        findsOneWidget,
      );
      // The sheet settles, then Accept.
      await _frames(tester, const Duration(milliseconds: 1500));
      await tester.tap(
        find.byKey(const ValueKey<String>('home-radar-exclusive')),
      );
      await tester.pump();
      expect(dispatch.claims, hasLength(1));
      // Accept held open about as long as the Radar tests wait in all.
      await _frames(tester, const Duration(seconds: 50));
      // The scheduled trip waits for dispatch's answer.
      expect(find.byType(AcceptRide, skipOffstage: false), findsNothing);
      expect(ScheduledRideStore.upcoming, contains(demoReservationRequest));
      return dispatch;
    }

    testWidgets('won: only the assigned trip opens, one trip screen', (
      tester,
    ) async {
      final dispatch = await acceptAssign(tester);
      dispatch.claims.single.complete(ClaimResult.success(_assign));
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide, skipOffstage: false), findsOneWidget);
      final trip = tester.widget<AcceptRide>(
        find.byType(AcceptRide, skipOffstage: false),
      );
      expect(trip.offerId, 'assign');
      expect(trip.matchedVia, 'Assigned by Movera');
      await _end(tester);
    });

    testWidgets('lost: the late scheduled trip opens right away', (
      tester,
    ) async {
      final dispatch = await acceptAssign(tester);
      dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
      // Well before the backup minutes (10 s of the demo day).
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(
        tester.widget<AcceptRide>(find.byType(AcceptRide)).matchedVia,
        'Scheduled ride',
      );
      await _end(tester);
    });
  });

  group('driver-fixrev-8: the toward-pickup window', () {
    testWidgets(
        'is reservations.towardPickupBeforeMin, not the ride type\'s '
        'online minutes', (tester) async {
      // Online 5 min before a normal ride, trips toward it from 60 min.
      ScheduledRideRules.current = const ScheduledRideRules(
        kinds: {
          ScheduledRideKind.normal:
              ScheduledRideKindRule(onlineBeforeMinutes: 5),
        },
      );
      await _pumpHome(tester, offers: [_toward, _away]);
      // The demo deals the second Radar trip 3 s after the first. About
      // 07:12 now: under 30 min before the 07:40 pickup.
      await _frames(tester, const Duration(seconds: 4));
      final deck = tester.widget<RadarOfferDeck>(
        find.byKey(const ValueKey<String>('radar-home-deck')),
      );
      expect(deck.ids, ['toward']);
      await tester.tap(
        find.byKey(const ValueKey<String>('island-radar-offers')),
      );
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.text('Trips toward your 07:40 pickup'), findsOneWidget);
      await _end(tester);
    });
  });
}
