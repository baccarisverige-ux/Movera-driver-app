import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.2, part b): the smart gap's times.
// - driver-u143: a reservation accepted after its pickup time does not
//   stay the "next" ride for good, holding every trip offer back.
// - driver-u144: a drive longer than the "be online" window: "Leave now"
//   opens the trip at the latest moment to set off, not later, and an
//   offline driver is told to go online before it.

/// Dispatch with the trips the test publishes.
class _Dispatch implements DispatchRepository {
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
  Future<ClaimResult> claimOffer(String offerId) =>
      Completer<ClaimResult>().future;

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

/// A short Radar trip near the driver.
final _trip = RideOffer(
  id: 'near',
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

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Location blocked: Home measures from its map placeholder.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('location denied');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// Where Home measures the drive from without a position.
const _placeholder = GeoPoint(59.3293, 18.0686);

Future<void> _pumpHome(
  WidgetTester tester,
  _Dispatch dispatch, {
  bool online = true,
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
            sessionController: DriverSessionController(),
            dispatchRepository: dispatch,
            locationRepository: _NoGps(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  if (!online) { return; }
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() {
    DemoReservations.reset();
    ScheduledRideStore.reset();
  });

  group('driver-u143: a reservation accepted after its pickup time', () {
    testWidgets('it leaves Accepted and Radar trips reach Home', (
      tester,
    ) async {
      // 07:00 on the fast test day: the rides are at 07:40 and 08:05.
      ScheduledClock.instance.now();
      DemoReservations.reset();
      ScheduledRideStore.reset();
      // 08:10: the 08:05 Lidingö request is still listed; the driver
      // accepts it.
      await tester.pump(const Duration(seconds: 140));
      expect(clockLabel(ScheduledClock.instance.now()), '08:10');
      ScheduledRideStore.answer('Högsätravägen, Lidingö', accepted: true);
      expect(ScheduledRideStore.upcoming.first.pickupTime, '08:05');
      final dispatch = _Dispatch()..publish([_trip]);
      await _pumpHome(tester, dispatch);
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 3500),
      );
      expect(find.byKey(const ValueKey<String>('radar-offer-card-near')),
          findsOneWidget,
          reason: 'trips are no longer held back for a past pickup');
      expect(ScheduledRideStore.upcoming.map((r) => r.pickupTime),
          isNot(contains('08:05')),
          reason: 'its pickup passed before anything could be planned');
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('driver-u144: a drive longer than the "be online" window', () {
    /// A normal ride 19 km north, accepted for later: with its drive and
    /// 15 spare minutes the driver must leave at 07:30, before its "be
    /// online" time (30 min before pickup).
    ReservationRequestPreview farRide() {
      final now = ScheduledClock.instance.now();
      const pickup = GeoPoint(59.50, 18.07);
      final rule = ScheduledRideRules.current.ruleFor(ScheduledRideKind.normal);
      final drive = SmartGap.driveMinutes(_placeholder, pickup);
      final leave = DateTime(now.year, now.month, now.day, 7, 30);
      final at = leave.add(Duration(minutes: drive + rule.spareMinutes));
      expect(drive + rule.spareMinutes, greaterThan(rule.onlineBeforeMinutes),
          reason: 'leaving comes before the "be online" time');
      return ReservationRequestPreview(
        id: 'far-ride',
        kind: ScheduledRideKind.normal,
        category: 'Movera',
        fare: '312,40 kr',
        pickupLabel: 'Pickup today at ${clockLabel(at)}',
        pickupAddress: 'Norrviken, Sollentuna',
        dropoffAddress: 'Kungsgatan, Stockholm',
        pickupTime: clockLabel(at),
        pickupDay: 'Today',
        tripMinutes: 30,
        tripKm: 20,
        pickup: pickup,
        dropoff: const GeoPoint(59.3343, 18.0615),
        scheduledAt: at,
      );
    }

    /// The demo minutes from 07:00 on the fast test day (30 times faster).
    Duration demo(int minutes) => Duration(seconds: minutes * 2);

    testWidgets('online: the trip opens at 07:30, the latest moment', (
      tester,
    ) async {
      ScheduledClock.instance.now();
      DemoReservations.reset();
      ScheduledRideStore.reset();
      ScheduledRideStore.acceptAssigned(farRide());
      await _pumpHome(tester, _Dispatch());
      // 07:29: not yet.
      await _frames(tester, demo(29) - const Duration(milliseconds: 1700));
      expect(find.byType(AcceptRide, skipOffstage: false), findsNothing);
      // 07:32: on the way, not at the "be online" time (pickup - 30 min).
      await _frames(tester, demo(3));
      expect(find.byType(AcceptRide, skipOffstage: false), findsOneWidget,
          reason: 'Leave now at 07:30');
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offline: "Go online" comes by 07:30', (tester) async {
      ScheduledClock.instance.now();
      DemoReservations.reset();
      ScheduledRideStore.reset();
      final ride = farRide();
      ScheduledRideStore.acceptAssigned(ride);
      await _pumpHome(tester, _Dispatch(), online: false);
      await _frames(tester, demo(31));
      expect(IslandMessages.posted.map((m) => m.title),
          contains(HomeIslandNotices.goOnlineFor(ride.pickupTime).title));
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
