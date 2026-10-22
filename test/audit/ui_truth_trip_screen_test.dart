// Wave 5 D5.2 (UI truth), part a: the trip screen shows only what really
// happened.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';

/// No GPS: the trip screen runs on the simulated arrival.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// One fresh fix south of the demo pickup, then silence: the car stands.
class _OneFix implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
        point: const GeoPoint(59.3189, 18.0615),
        speedMetersPerSecond: 0,
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// A straight road route between the two points.
class _Routes implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async => RoadRoute(
        points: [
          for (var i = 0; i <= 20; i++)
            GeoPoint(
              origin.latitude + (destination.latitude - origin.latitude) * i / 20,
              origin.longitude +
                  (destination.longitude - origin.longitude) * i / 20,
            ),
        ],
        distanceMeters: 1500,
        durationSeconds: 300,
      );
}

/// Location allowed only approximately (iOS Precise Location off).
class _ApproximateOnly implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw const PreciseLocationRequiredException();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// Trip storage that fails every save while [fail] is set.
class _FailingSave extends MemoryActiveRideRepository {
  bool fail = true;
  @override
  Future<void> save(PersistedActiveRide ride) async {
    if (fail) throw StateError('quota exceeded');
    await super.save(ride);
  }
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The trip screen on a phone, sheet at the middle.
Future<void> _trip(WidgetTester tester, AcceptRide ride) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: ride),
  ));
  await _frames(tester);
  tester
      .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .controller!
      .animatePanelToSnapPoint();
  await _frames(tester, 16);
}

void _clearSnackBars(WidgetTester tester) =>
    ScaffoldMessenger.of(tester.element(find.byType(AcceptRide)))
        .clearSnackBars();

Widget _island({String? status, double width = 390}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 220,
          child: AdaptiveTripIsland(
            status: 'To pickup',
            address: 'Sveavägen 20',
            detail: 'Picking up Angelica',
            eta: '2 min',
            progress: .4,
            navigationStatus: status,
            waitingMessage: 'Waiting for Angelica',
            lastTripLabel: '120 kr',
            onRadar: () {},
            onMenu: () {},
            onSearch: () {},
            onHistory: () {},
            onRoute: () {},
            onSafety: () {},
            onWait: () {},
          ),
        ),
      ),
    );

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: true,
      skipAccountActivation: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  testWidgets('driver-u88: a long status island stops at the documented '
      'maximum width', (tester) async {
    await tester.pumpWidget(_island(status: 'Mise à jour de la position…'));
    await tester.pump(const Duration(seconds: 1));
    final shell = tester.getSize(find.byKey(const ValueKey('island-morph-shell')));
    expect(shell.width, lessThanOrEqualTo(TripIslandGeometry.maximumWidth + .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('driver-u73: a reroute that arrives between fixes is not drawn as '
      'already driven', () {
    final old = [for (var i = 0; i <= 10; i++) GeoPoint(59.3 + i * .001, 18)];
    final reroute = [
      for (var i = 0; i <= 10; i++) GeoPoint(59.304, 18 + i * .001),
    ];
    final policy = DriverCameraPolicy()
      ..resolve(
        location: DriverLocation(point: old[4], measuredAt: DateTime.now()),
        route: RoadRoute(points: old, distanceMeters: 1100, durationSeconds: 90),
        navigating: true,
      );
    expect(policy.alongMetersOn(old), greaterThan(300));
    expect(policy.alongMetersOn(reroute), 0);
  });

  test('driver-u72: a finished trip no longer reports an old background '
      'save failure', () async {
    final ride = ActiveRideController(
        tripId: 'A', repository: _FailingSave(),
        initialStage: ActiveRideStage.onTrip);
    expect(await ride.persistNow(), isFalse);
    expect(ride.failures, 1);
    expect(await ride.complete(clearSnapshot: false), isTrue);
    expect(ride.persistenceError, isNull);
    ride.dispose();
  });

  testWidgets('driver-u72: Retry after a failed Arrived save repeats the '
      'arrival', (tester) async {
    final store = _FailingSave();
    await _trip(tester, AcceptRide(tripId: 'save-trip',
        locationRepository: _NoGps(), activeRideRepository: store));
    _clearSnackBars(tester);
    await _frames(tester);
    final arrive =
        find.byKey(const ValueKey<String>('active-ride-arrived-button'));
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await _frames(tester);
    const waiting = ValueKey<String>('active-ride-panel-waitingForRider');
    expect(find.byKey(waiting), findsNothing);
    expect(find.text('Trip progress could not be saved. Keep this screen '
        'open and retry.'), findsOneWidget);
    store.fail = false;
    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await _frames(tester);
    expect(find.byKey(waiting), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('driver-42: after Arrived the pickup route line leaves the map '
      'while the car stands still', (tester) async {
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: true,
      skipAccountActivation: false,
    );
    await _trip(tester, AcceptRide(tripId: 'route-trip',
        locationRepository: _OneFix(), routeRepository: _Routes()));
    _clearSnackBars(tester);
    await _frames(tester);
    Set<Object> lines() => tester
        .widget<CustomGoogleMap>(find.byKey(const ValueKey('active-ride-map')))
        .polylines ?? const <Object>{};
    expect(lines(), isNotEmpty, reason: 'the pickup route is drawn');
    final arrive =
        find.byKey(const ValueKey<String>('active-ride-arrived-button'));
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await _frames(tester);
    expect(find.byKey(const ValueKey('active-ride-panel-waitingForRider')),
        findsOneWidget);
    expect(lines(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('driver-u79: with a next trip secured the island menu does '
      'not offer to turn Exclusive offers off', (tester) async {
    await _trip(tester, AcceptRide(
      tripId: 'secured-trip',
      initialStage: ActiveRideStage.onTrip,
      locationRepository: _NoGps(),
      restoredSnapshot: const PersistedActiveRide(
        tripId: 'secured-trip',
        stage: ActiveRideStage.onTrip,
        next: PersistedQueuedTrip(
          tripId: 'next-1', riderName: 'Sara', fare: '128,40 kr',
          category: 'Comfort', pickup: 'Odengatan', dropoff: 'Kista',
          pickupLat: 59.3428, pickupLng: 18.0475,
          dropoffLat: 59.4032, dropoffLng: 17.9447,
        ),
      ),
    ));
    final island =
        tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland));
    expect(island.nextTripFare, isNotNull, reason: 'the next trip is secured');
    expect(island.radarVisible, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('driver-u23: approximate-only location says precise location '
      'is off instead of a "Location updating…" that never ends',
      (tester) async {
    await _trip(tester, AcceptRide(locationRepository: _ApproximateOnly()));
    final island =
        tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland));
    expect(island.navigationStatus, 'Precise location off');
    expect(find.text('Location updating…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
