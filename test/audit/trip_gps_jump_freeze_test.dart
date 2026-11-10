// BrowserStack Tunis 2026-11-10: the trip map froze (car and route stood
// still while the rider saw the car at the drop-off) until the screen was
// reopened. One far fix (a location set once, GPS back far away) was held
// back as a GPS jump, and with no second fix to confirm it the trip
// screen never applied it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

const _start = GeoPoint(59.3416, 18.0649);

/// 6 km north of [_start], given at once.
const _far = GeoPoint(59.3956, 18.0649);

class _Gps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: _start,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

class _Routes implements RouteRepository {
  final origins = <GeoPoint>[];
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    origins.add(origin);
    return RoadRoute(
      points: [
        for (var i = 0; i <= 20; i++)
          GeoPoint(
            origin.latitude + (destination.latitude - origin.latitude) * i / 20,
            origin.longitude +
                (destination.longitude - origin.longitude) * i / 20,
          ),
      ],
      distanceMeters: 3000,
      durationSeconds: 400,
    );
  }
}

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: true,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  testWidgets('a far fix with no second one still moves the trip map', (
    tester,
  ) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gps = _Gps();
    final routes = _Routes();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AcceptRide(
            tripId: 'gps-jump-trip',
            initialStage: ActiveRideStage.onTrip,
            locationRepository: gps,
            routeRepository: routes,
          ),
        ),
      ),
    );
    await _frames(tester, 40);
    expect(routes.origins, isNotEmpty);
    expect(routes.origins.last.latitude, closeTo(_start.latitude, 1e-4));

    gps.updates.add(
      DriverLocation(
        point: _far,
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    await _frames(tester);
    // No other fix comes (a parked phone, a location set once).
    await tester.pump(const Duration(seconds: 5));
    await _frames(tester, 40);
    expect(
      routes.origins.last.latitude,
      closeTo(_far.latitude, 1e-4),
      reason: 'the route must follow the car, not freeze on a held-back fix',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
    await gps.updates.close();
  });
}
