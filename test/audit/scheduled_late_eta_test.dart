import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';
import '../flutter_test_config.dart' show testRuntimeConfig;

// Owner rule (late ETA): an ONLINE driver who accepted a reservation is
// watched from "Leave now" until arrival at the pickup. When now + ETA is
// later than the pickup time + the admin's tolerance, the ride goes to
// another driver early and the driver is told why.

/// The pickup of the test day's 07:40 ride (Gamla vägen, Stockholm).
const _pickup = GeoPoint(59.3362, 18.0714);

/// About 1 km from the pickup: a few minutes away.
const _near = GeoPoint(59.3440, 18.0700);

/// Uppsala: more than two hours from the pickup by the smart-gap estimate.
const _far = GeoPoint(59.8586, 17.6389);

/// GPS that reports [point] and moves when told.
class _Gps implements DriverLocationRepository {
  _Gps(this.point);

  GeoPoint point;
  final _moves = StreamController<DriverLocation>.broadcast();

  /// A fresh, accurate fix: a live position.
  DriverLocation get _fix => DriverLocation(
    point: point,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  /// A far move is held once as a possible GPS jump; the second fix there
  /// confirms it.
  void moveTo(GeoPoint to) {
    point = to;
    _moves
      ..add(_fix)
      ..add(_fix);
  }

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _moves.stream;

  Future<void> close() => _moves.close();
}

/// GPS that never gives a fix: the trip keeps its fallback position.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('no location');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// A road route of a fixed duration, whatever the ends.
class _Route implements RouteRepository {
  _Route(this.seconds);

  final double seconds;

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async => RoadRoute(
    points: [origin, destination],
    distanceMeters: origin.distanceMetersTo(destination),
    durationSeconds: seconds,
  );
}

/// Dispatch with no offers of its own.
class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(const <RideOffer>[]);

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
      ClaimResult.success(RideOffer.reservation(demoReservationRequest));
}

Iterable<String> get _saidTitles => IslandMessages.posted.map((m) => m.title);

/// 07:40 on the test day's scheduled clock.
DateTime get _pickupAt {
  final now = ScheduledClock.instance.now();
  return DateTime(now.year, now.month, now.day, 7, 40);
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Home with a button that opens the trip, as Home's "Leave now" does.
Future<void> _pumpTrip(
  WidgetTester tester, {
  required DriverLocationRepository gps,
  required MemoryDriverRealtime realtime,
  DateTime? scheduledPickupAt,
  String? scheduledRideId = 'res-0740',
  RouteRepository? routes,
  ActiveRideRepository? repository,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AcceptRide(
                    tripId: 'late-eta-trip',
                    riderName: 'Angelica',
                    pickupAddress: 'Gamla vägen, Stockholm',
                    pickupPosition: _pickup.toLatLng(),
                    locationRepository: gps,
                    routeRepository: routes,
                    activeRideRepository:
                        repository ?? MemoryActiveRideRepository(),
                    sessionController: DriverSessionController()
                      ..setOnline(true),
                    realtime: realtime,
                    waybillRepository: InMemoryWaybillRepository.instance,
                    scheduledPickupAt: scheduledPickupAt,
                    scheduledRideId:
                        scheduledPickupAt == null ? null : scheduledRideId,
                  ),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Home'));
  await _frames(tester, const Duration(milliseconds: 600));
}

Future<void> _pumpHome(WidgetTester tester, {bool online = true}) async {
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
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController: DriverSessionController(initialOnline: online),
            initialOnline: online,
            dispatchRepository: _Dispatch(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late MemoryDriverRealtime realtime;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    InMemoryWaybillRepository.instance.reset();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    ScheduledRideRules.current = const ScheduledRideRules();
    realtime = MemoryDriverRealtime();
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    ScheduledRideRules.current = const ScheduledRideRules();
    DriverRuntimeConfig.current = testRuntimeConfig;
    realtime.dispose();
  });

  group('late ETA on a scheduled trip heading to pickup', () {
    testWidgets(
      'an ETA past pickup + tolerance gives the ride to another driver: '
      'the trip leaves, the ride is marked reassigned, the driver is told',
      (tester) async {
        final gps = _Gps(_far);
        addTearDown(gps.close);
        final repository = MemoryActiveRideRepository();
        await _pumpTrip(
          tester,
          gps: gps,
          realtime: realtime,
          scheduledPickupAt: _pickupAt,
          repository: repository,
        );
        await _frames(tester, const Duration(seconds: 1));

        expect(find.byType(AcceptRide), findsNothing);
        expect(find.text('Home'), findsOneWidget);
        final record = ScheduledRideStore.reassigned.single;
        expect(record.id, 'res-0740');
        expect(record.pickupTime, '07:40');
        expect(record.reassignTo, LateEtaReassignTo.exclusive);
        expect(record.lateMinutes, greaterThan(60));
        final late = record.lateMinutes;
        expect(_saidTitles, contains('Given to another driver: $late min late'));
        expect(
          ScheduledRideStore.backupNote.value,
          'Ride given to another driver — you would reach the 07:40 pickup '
          'about $late min late.',
        );
        expect(
          DriverNotificationFeed.instance.items.map((n) => n.title),
          contains('Ride given to another driver'),
        );
        // Over on this phone, like a server release: nothing to restore.
        expect(await repository.read(), isNull);
        await _end(tester);
      },
    );

    testWidgets('the road route\'s remaining time is the ETA when known',
        (tester) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: true,
        externalRouting: true,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
        radarSound: false,
      );
      final gps = _Gps(_near);
      addTearDown(gps.close);
      // Near by distance, but the road takes 90 min (closed bridge).
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
        routes: _Route(90 * 60),
      );
      await _frames(tester, const Duration(seconds: 1));
      expect(find.byType(AcceptRide), findsNothing);
      expect(ScheduledRideStore.reassigned, hasLength(1));
      await _end(tester);
    });

    testWidgets(
        'driver-fixrev-1: no GPS fix: a road route from the fallback '
        'position never reassigns the ride', (tester) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: true,
        externalRouting: true,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
        radarSound: false,
      );
      // The fallback (Stockholm centre) is not where the car is: a route
      // from there says nothing about this driver's ETA.
      await _pumpTrip(
        tester,
        gps: _NoGps(),
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
        routes: _Route(90 * 60),
      );
      await _frames(tester, const Duration(seconds: 6));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(ScheduledRideStore.reassigned, isEmpty);
      await _end(tester);
    });

    testWidgets(
        'driver-fixrev-4: a rider cancel during the exit after a late-ETA '
        'reassign is not journalled', (tester) async {
      final gps = _Gps(_far);
      addTearDown(gps.close);
      // The rider cancels just as the ride goes to another driver, while
      // the trip screen is still leaving (realtime still subscribed).
      var emitted = false;
      void riderCancels() {
        if (emitted) {
          return;
        }
        emitted = true;
        realtime.emit(
          tripId: 'late-eta-trip',
          kind: DriverRealtimeKind.riderCancelled,
          status: TripStatus.cancelledByRider,
        );
      }

      ScheduledRideStore.backupNote.addListener(riderCancels);
      addTearDown(() => ScheduledRideStore.backupNote.removeListener(riderCancels));
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
      );
      expect(emitted, isTrue);
      expect(ScheduledRideStore.reassigned, hasLength(1));
      await _frames(tester, const Duration(seconds: 1));
      expect(find.byType(AcceptRide), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('movera_driver_completed_trips') ?? '',
        isNot(contains('cancelled_by_rider')),
      );
      await _end(tester);
    });

    testWidgets('on time: the trip stays and the ride stays this driver\'s',
        (tester) async {
      final gps = _Gps(_near);
      addTearDown(gps.close);
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
      );
      // Several checks (60 s of the demo day is 2 s of test time).
      await _frames(tester, const Duration(seconds: 8));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(ScheduledRideStore.reassigned, isEmpty);
      expect(ScheduledRideStore.backupNote.value, isNull);
      await _end(tester);
    });

    testWidgets('on time, then far away: a later check reassigns',
        (tester) async {
      final gps = _Gps(_near);
      addTearDown(gps.close);
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
      );
      await _frames(tester, const Duration(seconds: 3));
      expect(find.byType(AcceptRide), findsOneWidget);

      gps.moveTo(_far);
      await _frames(tester, const Duration(seconds: 3));
      expect(find.byType(AcceptRide), findsNothing);
      expect(ScheduledRideStore.reassigned, hasLength(1));
      await _end(tester);
    });

    testWidgets('admin lateEta off: a late driver keeps the trip',
        (tester) async {
      ScheduledRideRules.current = const ScheduledRideRules(
        lateEta: LateEtaRule(on: false),
      );
      final gps = _Gps(_far);
      addTearDown(gps.close);
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
      );
      await _frames(tester, const Duration(seconds: 6));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(ScheduledRideStore.reassigned, isEmpty);
      await _end(tester);
    });

    testWidgets('a trip that is not a scheduled ride is never checked',
        (tester) async {
      final gps = _Gps(_far);
      addTearDown(gps.close);
      await _pumpTrip(tester, gps: gps, realtime: realtime);
      await _frames(tester, const Duration(seconds: 6));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(ScheduledRideStore.reassigned, isEmpty);
      await _end(tester);
    });

    testWidgets('after arriving at the pickup the watch stops',
        (tester) async {
      final gps = _Gps(_near);
      addTearDown(gps.close);
      final repository = MemoryActiveRideRepository();
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
        repository: repository,
      );
      await _frames(tester, const Duration(seconds: 2));
      realtime.emit(
        tripId: 'late-eta-trip',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.arrived,
      );
      await _frames(tester, const Duration(seconds: 1));
      expect(
        (await repository.read())?.stage,
        ActiveRideStage.waitingForRider,
      );

      // Far away now, but already at the pickup stage: no more checks.
      gps.moveTo(_far);
      await _frames(tester, const Duration(seconds: 6));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(ScheduledRideStore.reassigned, isEmpty);
      await _end(tester);
    });

    testWidgets('the pickup time and reservation are kept in the snapshot',
        (tester) async {
      final gps = _Gps(_near);
      addTearDown(gps.close);
      final repository = MemoryActiveRideRepository();
      await _pumpTrip(
        tester,
        gps: gps,
        realtime: realtime,
        scheduledPickupAt: _pickupAt,
        repository: repository,
      );
      final saved = await repository.read();
      expect(saved?.scheduledPickupAt, _pickupAt);
      expect(saved?.scheduledRideId, 'res-0740');
      final restored = AcceptRide.fromPersisted(saved!);
      expect(restored.scheduledPickupAt, _pickupAt);
      expect(restored.scheduledRideId, 'res-0740');
      await _end(tester);
    });
  });

  group('Home "Leave now"', () {
    testWidgets('opens the trip with the ride\'s pickup time', (tester) async {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      await _pumpHome(tester);
      await _frames(tester, const Duration(seconds: 50));
      final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
      expect(trip.scheduledPickupAt, _pickupAt);
      expect(trip.scheduledRideId, demoReservationRequest.id);
      await _end(tester);
    });

    // driver-fixrev-5 / owner decision 1: there is no Leave now switch.
    // A config that still says leaveNow false opens the trip all the same,
    // so an online driver's accepted ride is never stuck in Accepted.
    testWidgets('an old config with leaveNow false still opens the trip',
        (tester) async {
      ScheduledRideRules.current =
          ScheduledRideRules.fromJson(const {'leaveNow': false});
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      await _pumpHome(tester);
      await _frames(tester, const Duration(seconds: 50));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(_saidTitles, contains('Leave now for 07:40 pickup'));
      expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
      await _end(tester);
    });

    testWidgets('admin lateWarn off: no "Head to your pickup" warning',
        (tester) async {
      // Offline at Leave now: the trip cannot open, the late path runs.
      ScheduledRideRules.current = const ScheduledRideRules(
        lateWarning: false,
      );
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(seconds: 50));
      expect(find.byType(AcceptRide), findsNothing);
      expect(_saidTitles, isNot(contains('Head to your 07:40 pickup')));
      await _end(tester);
    });
  });
}
