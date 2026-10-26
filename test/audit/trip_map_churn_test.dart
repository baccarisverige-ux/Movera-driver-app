// D-07 / D-08 / D-14: what one GPS fix costs on the trip screen. Ported
// from the D-CODE repro (W1 and the full drive).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Maps extends HeadlessMapPlatform {
  int moves = 0, animates = 0, markerUpdates = 0, polylineUpdates = 0;
  int polylineChanges = 0;
  @override
  Future<void> moveCamera(CameraUpdate u, {required int mapId}) async =>
      moves++;
  @override
  Future<void> animateCamera(
    CameraUpdate u, {
    required int mapId,
    Duration? duration,
  }) async => animates++;
  @override
  Future<void> updateMarkers(MarkerUpdates u, {required int mapId}) async =>
      markerUpdates++;
  @override
  Future<void> updatePolylines(PolylineUpdates u, {required int mapId}) async {
    polylineUpdates++;
    if (u.polylinesToAdd.isNotEmpty ||
        u.polylinesToChange.isNotEmpty ||
        u.polylineIdsToRemove.isNotEmpty) {
      polylineChanges++;
    }
  }
}

GeoPoint _south(GeoPoint p, double m) =>
    GeoPoint(p.latitude - m / 111320, p.longitude);

class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  final DriverLocation first;
  _Loc(this.first);
  @override
  Future<DriverLocation> getCurrentPosition() async => first;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

class _Routes implements RouteRepository {
  int calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    return RoadRoute(
      points: [
        for (var i = 0; i <= 50; i++)
          GeoPoint(
            origin.latitude + (destination.latitude - origin.latitude) * i / 50,
            origin.longitude +
                (destination.longitude - origin.longitude) * i / 50,
          ),
      ],
      distanceMeters: 1500,
      durationSeconds: 300,
    );
  }
}

class _Run {
  int acceptBuilds = 0, mapBuilds = 0;
  int moves = 0, animates = 0, markers = 0, polylines = 0, polylineChanges = 0;
  int routeCalls = 0;
  String label(int fixes) =>
      'AcceptRide builds=$acceptBuilds (${(acceptBuilds / fixes).toStringAsFixed(2)}/fix), '
      'CustomGoogleMap builds=$mapBuilds, moveCamera=$moves animateCamera=$animates, '
      'updateMarkers=$markers (${(markers / fixes).toStringAsFixed(1)}/fix), '
      'updatePolylines=$polylines (${(polylines / fixes).toStringAsFixed(1)}/fix, '
      'with changes $polylineChanges), route requests=$routeCalls';
}

Future<_Run> _drive(WidgetTester tester, {required bool ticker}) async {
  DriverRuntimeConfig.current = DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: true,
    skipAccountActivation: true,
    liveMapTicker: ticker,
    reservationPopup: false,
    islandHint: false,
    radarSound: false,
  );
  final original = GoogleMapsFlutterPlatform.instance;
  final maps = _Maps();
  GoogleMapsFlutterPlatform.instance = maps;
  addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const pickup = GeoPoint(59.3279, 18.0615);
  DriverLocation fix(int i) => DriverLocation(
    point: _south(pickup, 1500 - i * 12.0),
    headingDegrees: 0,
    speedMetersPerSecond: 12,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  final location = _Loc(fix(0));
  final routes = _Routes();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(locationRepository: location, routeRepository: routes),
      ),
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final run = _Run();
  debugOnRebuildDirtyWidget = (e, _) {
    if (e.widget is AcceptRide) run.acceptBuilds++;
    if (e.widget.runtimeType.toString() == 'CustomGoogleMap') run.mapBuilds++;
  };
  final m0 = maps.moves, a0 = maps.animates, mk0 = maps.markerUpdates;
  final p0 = maps.polylineUpdates, pc0 = maps.polylineChanges;
  final r0 = routes.calls;
  for (var i = 1; i <= _fixes; i++) {
    location.updates.add(fix(i));
    for (var f = 0; f < 20; f++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  debugOnRebuildDirtyWidget = null;
  run
    ..moves = maps.moves - m0
    ..animates = maps.animates - a0
    ..markers = maps.markerUpdates - mk0
    ..polylines = maps.polylineUpdates - p0
    ..polylineChanges = maps.polylineChanges - pc0
    ..routeCalls = routes.calls - r0;
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await location.updates.close();
  return run;
}

const _fixes = 30;

void main() {
  final previous = DriverRuntimeConfig.current;
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    debugOnRebuildDirtyWidget = null;
  });

  testWidgets('D-07: a GPS fix does not rebuild the whole trip screen', (
    tester,
  ) async {
    final run = await _drive(tester, ticker: false);
    // ignore: avoid_print
    print('D-07 ticker off, $_fixes fixes @1 Hz: ${run.label(_fixes)}');
    // Before: one whole-screen rebuild a fix (30 for 30 fixes).
    expect(run.acceptBuilds, lessThanOrEqualTo(3));
    // The map still follows: its route lines move with the car.
    expect(run.polylineChanges, greaterThanOrEqualTo(_fixes - 2));
  });

  testWidgets('D-08: the moving car does not resend the route lines', (
    tester,
  ) async {
    final run = await _drive(tester, ticker: true);
    // ignore: avoid_print
    print('D-08 ticker on, $_fixes fixes @1 Hz: ${run.label(_fixes)}');
    // Before: 383 map rebuilds and 383 line updates (30 with a change).
    // Now the lines go out only when they change, once a fix.
    expect(run.polylines, run.polylineChanges);
    expect(run.polylines, lessThanOrEqualTo(_fixes + 2));
    expect(run.mapBuilds, lessThanOrEqualTo(_fixes + 2));
    // The car still moves between fixes, as marker updates of its own.
    expect(run.markers, greaterThan(_fixes * 5));
  });
}
