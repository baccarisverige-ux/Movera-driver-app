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
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Home, Round 3 (D1): the smart gap before an accepted scheduled ride
// (Q10), trips toward its pickup, rides Movera assigns (Q29), and trips
// opened from Home or the Live list carry the offer's rider and stops.
// The demo day starts at 07:00 and runs 30 times faster.

/// Dispatch with only what a test publishes, and assignments it sends.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  final assignments = StreamController<ReservationRequestPreview>.broadcast();
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
  Stream<ReservationRequestPreview> watchAssignments() => assignments.stream;

  @override
  Future<ClaimResult> claimOffer(String offerId) async {
    claims.add(offerId);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    RideOffer? offer;
    for (final item in offers) {
      if (item.id == offerId) offer = item;
    }
    publish([for (final o in offers) if (o.id != offerId) o]);
    return ClaimResult.success(
      offer ?? RideOffer.reservation(demoReservationRequest),
    );
  }
}

RideOffer _trip(
  String id, {
  required GeoPoint dropoff,
  int pickupMinutes = 2,
  int tripMinutes = 6,
}) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Sara',
  riderTrips: 86,
  pickupMinutes: pickupMinutes,
  pickupKm: 0.8,
  tripMinutes: tripMinutes,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: dropoff,
  isNearby: true,
  followsDestination: false,
  stops: const [
    ReservationStop(
      address: 'Rådmansgatan, Stockholm',
      point: GeoPoint(59.3400, 18.0590),
    ),
  ],
);

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  DispatchRepository dispatch, {
  bool online = false,
}) async {
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
            sessionController: DriverSessionController(initialOnline: online),
            initialOnline: online,
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Radar on, as the driver does: the demo offers start.
Future<void> _goOnline(WidgetTester tester) async {
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

AcceptRide _trip0(WidgetTester tester) =>
    tester.widget<AcceptRide>(find.byType(AcceptRide));

const _assignedCard = ValueKey<String>(
  'exclusive-offer-card-$demoAssignedReservationId',
);

/// While an Exclusive offer is live the blue radar is its Accept.
final _exclusiveRadar = find.byKey(const ValueKey<String>('home-radar-exclusive'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  group('smart gap before an accepted ride (Q10)', () {
    testWidgets(
      '"Leave now" puts the ride on screen as the active trip, heading to '
      'pickup, with its rider and stop',
      (tester) async {
        ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
        await _pumpHome(tester, _Dispatch(), online: true);
        // 07:40 − the drive − 15 spare minutes is about 07:23: 46 s in.
        await _frames(tester, const Duration(seconds: 40));
        expect(find.byType(AcceptRide), findsNothing);
        await _frames(tester, const Duration(seconds: 9));
        expect(find.byType(AcceptRide), findsOneWidget);
        final trip = _trip0(tester);
        expect(trip.matchedVia, 'Scheduled ride');
        expect(trip.initialStage.name, 'headingToPickup');
        expect(trip.pickupAddress, 'Gamla vägen, Stockholm');
        expect(trip.stopAddresses, ['Odenplan, Stockholm']);
        expect(trip.riderName, 'Karin');
        expect(trip.riderTrips, 128);
        expect(trip.riderRating, 4.94);
        expect(_said, contains('Leave now for 07:40 pickup'));
        // It is the current trip now, no longer waiting in Accepted.
        expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
        await _end(tester);
      },
    );

    testWidgets('not on the way: a late warning, then a backup driver', (
      tester,
    ) async {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(seconds: 48));
      expect(find.byType(AcceptRide), findsNothing);
      expect(_said, contains('Head to your 07:40 pickup'));
      expect(_said, isNot(contains('Given to backup driver')));
      expect(ScheduledRideStore.reminder.value, contains('07:40 pickup now'));
      // 5 admin minutes later (10 s of the demo day) it goes to a backup.
      await _frames(tester, const Duration(seconds: 11));
      expect(_said, contains('Given to backup driver'));
      expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
      expect(ScheduledRideStore.backupNote.value, contains('07:40'));
      // No longer this driver's: the 08:05 ride no longer clashes and is
      // open to them again.
      expect(ScheduledRideStore.openRequests.value, 1);
      await _end(tester);
    });

    testWidgets('reminders at the ride type\'s times, island and in-app', (
      tester,
    ) async {
      // 08:05 Premium: reminders 60 and 15 min before; online 45 before.
      ScheduledRideStore.answer('Högsätravägen, Lidingö', accepted: true);
      await _pumpHome(tester, _Dispatch());
      await _frames(tester, const Duration(seconds: 11));
      expect(_said, contains('08:05 pickup in 1 h'));
      expect(ScheduledRideStore.reminder.value, startsWith('Pickup at 08:05 in 1 h'));
      await _frames(tester, const Duration(seconds: 30));
      expect(_said, contains('Go online for 08:05 pickup'));
      expect(
        ScheduledRideStore.reminder.value,
        'Go online now for your 08:05 pickup.',
      );
      await _end(tester);
    });

    testWidgets('before the ride only trips toward its pickup that still fit', (
      tester,
    ) async {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      final dispatch = _Dispatch()
        ..publish([
          // Ends far south: it would make the driver late.
          _trip('away', dropoff: const GeoPoint(59.2705, 18.0515)),
          // Ends near the scheduled pickup.
          _trip('toward', dropoff: const GeoPoint(59.3380, 18.0700)),
        ]);
      await _pumpHome(tester, dispatch);
      await _goOnline(tester);
      // The demo's own Exclusive offer (Hornstull) does not fit either.
      await _frames(tester, const Duration(seconds: 4));
      expect(
        find.byKey(const ValueKey<String>('exclusive-offer-card-home-direct-close')),
        findsNothing,
      );
      // The demo puts the first Radar trips on Home 3 s and 6 s after the
      // Exclusive offer's time to accept.
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 3500),
      );
      final deck = tester.widget<RadarOfferDeck>(
        find.byKey(const ValueKey<String>('radar-home-deck')),
      );
      expect(deck.ids, ['toward']);

      // The Live list follows the same rule and says so.
      await tester.tap(find.byKey(const ValueKey<String>('radar-home-all-offers')));
      await _frames(tester, const Duration(milliseconds: 800));
      final live = find.byType(RideRequests);
      expect(live, findsOneWidget);
      expect(find.text('Trips toward your 07:40 pickup'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-toward')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-away')),
        findsNothing,
      );
      await _end(tester);
    });
  });

  group('a ride Movera assigns (Q29)', () {
    Future<_Dispatch> assigned(WidgetTester tester) async {
      final dispatch = _Dispatch();
      await _pumpHome(tester, dispatch);
      await _goOnline(tester);
      // After the demo's own Exclusive offer has gone (its time to accept
      // is Dispatch's, 15 s).
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 2500),
      );
      dispatch.assignments.add(demoAssignedReservation);
      await _frames(tester, const Duration(milliseconds: 600));
      return dispatch;
    }

    testWidgets('arrives like an Exclusive: "Assigned by Movera", a timer', (
      tester,
    ) async {
      final dispatch = await assigned(tester);
      final card = find.byKey(_assignedCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('Assigned by Movera')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Reservation · 09:30')),
        findsOneWidget,
      );
      // The admin's time to accept runs on the radar's hairline ring.
      expect(
        find.descendant(of: _exclusiveRadar, matching: find.text('MATCH')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _exclusiveRadar,
          matching: find.byKey(const ValueKey<String>('radar-exclusive-ring')),
        ),
        findsOneWidget,
      );
      expect(_said, contains('Assigned by Movera'));

      await tester.tap(_exclusiveRadar);
      await _frames(tester, const Duration(milliseconds: 1000));
      expect(dispatch.claims, [demoAssignedReservationId]);
      expect(_said, contains('Scheduled ride accepted'));
      expect(card, findsNothing);
      // Kept for later, not opened as a trip now.
      expect(find.byType(AcceptRide), findsNothing);
      expect(ScheduledRideStore.upcoming, contains(demoAssignedReservation));
      await _end(tester);
    });

    testWidgets('not accepted in time: it goes, and does not count as taken', (
      tester,
    ) async {
      await assigned(tester);
      expect(find.byKey(_assignedCard), findsOneWidget);
      await _frames(tester, const Duration(seconds: 31));
      expect(find.byKey(_assignedCard), findsNothing);
      expect(_said, contains('Assignment not accepted'));
      expect(ScheduledRideStore.upcoming, isNot(contains(demoAssignedReservation)));
      await _end(tester);
    });
  });

  group('trips opened from Home carry the offer (demo bugs)', () {
    testWidgets('the Exclusive offer\'s rider, not "Angelica 4.9"', (
      tester,
    ) async {
      await _pumpHome(tester, _Dispatch());
      await _goOnline(tester);
      await _frames(tester, const Duration(milliseconds: 2600));
      final card = find.byKey(
        const ValueKey<String>('exclusive-offer-card-home-direct-close'),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Kungsgatan 42')),
        findsOneWidget,
      );
      await tester.tap(_exclusiveRadar);
      await _frames(tester, const Duration(milliseconds: 800));
      final trip = _trip0(tester);
      expect(trip.riderName, 'Nils');
      expect(trip.riderRating, 4.96);
      expect(trip.riderTrips, 93);
      expect(trip.matchedVia, 'Exclusive offer');
      await _end(tester);
    });

    testWidgets('a reservation taken as Exclusive brings its stops and rider', (
      tester,
    ) async {
      final dispatch = _Dispatch();
      await _pumpHome(tester, dispatch);
      await _goOnline(tester);
      // 20 min before 07:40 on the demo day: 40 s after it starts.
      await _frames(tester, const Duration(seconds: 40));
      final card = find.byKey(
        const ValueKey<String>('exclusive-offer-card-$demoReservationId'),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey<String>(
            'exclusive-offer-reservation-$demoReservationId',
          )),
        ),
        findsOneWidget,
      );
      await tester.tap(_exclusiveRadar);
      await _frames(tester, const Duration(milliseconds: 1200));
      expect(dispatch.claims, [demoReservationId]);
      final trip = _trip0(tester);
      expect(trip.stopAddresses, ['Odenplan, Stockholm']);
      expect(trip.stopPositions.single.latitude, 59.3430);
      expect(trip.riderName, 'Karin');
      expect(trip.matchedVia, 'Exclusive reservation');
      await _end(tester);
    });

    testWidgets('a trip matched in the Live list has its rider and stops', (
      tester,
    ) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dispatch = _Dispatch()
        ..publish([_trip('live-1', dropoff: const GeoPoint(59.3428, 18.0475))]);
      await tester.pumpWidget(
        MaterialApp(
          home: RideRequests(
            dispatchRepository: dispatch,
            sessionController: DriverSessionController(initialOnline: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Match'));
      await _frames(tester, const Duration(milliseconds: 1400));
      final trip = _trip0(tester);
      expect(trip.riderName, 'Sara');
      expect(trip.riderRating, 4.92);
      expect(trip.riderTrips, 86);
      expect(trip.stopAddresses, ['Rådmansgatan, Stockholm']);
      await _end(tester);
    });
  });
}
