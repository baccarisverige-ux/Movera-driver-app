// Batch D1 (navigation / GPS) regressions: D-01, D-03, D-06 and the
// driver-map tilt rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/location_freshness.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

const _origin = GeoPoint(59.3293, 18.0686);

GeoPoint _east(GeoPoint p, double m) =>
    GeoPoint(p.latitude, p.longitude + m / (111320 * 0.5094));
GeoPoint _north(GeoPoint p, double m) =>
    GeoPoint(p.latitude + m / 111320, p.longitude);

/// The router snaps a car parked near [_origin] to the road 80 m north of
/// it (a depot, beyond the 50 m off-route threshold).
class _SnappedRoutes implements RouteRepository {
  int calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    final start = _north(_origin, 80);
    return RoadRoute(
      points: [start, _east(start, 500), _east(start, 1000)],
      distanceMeters: 1000,
      durationSeconds: 120,
    );
  }
}

/// A straight road east from [_origin].
class _StraightRoutes implements RouteRepository {
  int calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    return RoadRoute(
      points: [for (var i = 0; i <= 20; i++) _east(_origin, i * 100.0)],
      distanceMeters: 2000,
      durationSeconds: 200,
    );
  }
}

class _Port implements DriverCameraPort, DriverCameraTilting {
  final poses = <DriverCameraPose>[];
  final tilts = <double>[];
  @override
  double? currentZoom;
  @override
  double? currentTilt;
  @override
  Future<void> animate(DriverCameraPose pose) async => poses.add(pose);
  @override
  void retarget(DriverCameraPose pose) {}
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  Future<void> tiltTo(double tilt) async {
    tilts.add(tilt);
    currentTilt = tilt;
  }

  @override
  void interrupt() {}
  @override
  void dispose() {}
}

DriverLocation _fix(GeoPoint p, {DateTime? at, double accuracy = 5}) =>
    DriverLocation(
      point: p,
      headingDegrees: 90,
      speedMetersPerSecond: 12,
      measuredAt: at ?? DateTime.now(),
      accuracyMeters: accuracy,
    );

void main() {
  group('D-01 reroute while parked off the road', () {
    testWidgets('no new GPS fix: no reroute loop', (tester) async {
      final routes = _SnappedRoutes();
      final nav = NavigationController(routeRepository: routes);
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: _origin));
      await nav.ensureRoute(origin: _origin, destination: _east(_origin, 1000));
      expect(nav.snapshot.offRoute, isTrue);
      for (var s = 0; s < 300; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Before: a new request every ~2 s, 151 in five minutes.
      expect(routes.calls, 1);
      expect(nav.reroutes, 0);
    });

    testWidgets('GPS jitter in place: reroutes back off to once a minute', (
      tester,
    ) async {
      final routes = _SnappedRoutes();
      final nav = NavigationController(routeRepository: routes);
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: _origin));
      await nav.ensureRoute(origin: _origin, destination: _east(_origin, 1000));
      for (var s = 0; s < 300; s++) {
        // A metre or so of GPS noise every two seconds.
        if (s.isEven) {
          nav.setVehicle(
            DriverLocation(point: _east(_origin, s % 4 == 0 ? 1.2 : -1.2)),
          );
        }
        await tester.pump(const Duration(seconds: 1));
      }
      // 2, 4, 8, 16, 32 s, then 60 s apart: at most about ten.
      expect(routes.calls, lessThanOrEqualTo(10));
      expect(routes.calls, greaterThan(1));
      // The same road back each time is not "Route updated".
      expect(nav.reroutes, 0);
      // Driving away from the spot reroutes promptly again.
      final before = routes.calls;
      nav.setVehicle(DriverLocation(point: _east(_origin, 60)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(routes.calls, before + 1);
    });
  });

  group('D-03 GPS clock a little ahead of the phone', () {
    test('a fix stamped 200 ms ahead is fresh, 6 s ahead is not', () {
      final now = DateTime.now();
      final ahead = _fix(_origin, at: now.add(const Duration(milliseconds: 200)));
      expect(ahead.isUsableAt(now), isTrue);
      expect(ahead.isDisplayableAt(now), isTrue);
      expect(hasFreshLocation(_origin, now.add(const Duration(seconds: 1)), now),
          isTrue);
      final future = _fix(_origin, at: now.add(const Duration(seconds: 6)));
      expect(future.isUsableAt(now), isFalse);
      expect(hasFreshLocation(_origin, now.add(const Duration(seconds: 6)), now),
          isFalse);
    });

    test('navigation and camera follow a fix stamped just ahead', () {
      final nav = NavigationController(routeRepository: _StraightRoutes());
      addTearDown(nav.dispose);
      final point = _east(_origin, 300);
      nav.setVehicle(
        _fix(point, at: DateTime.now().add(const Duration(seconds: 1))),
      );
      expect(nav.snapshot.vehicle, point);

      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _Port();
      camera.attach(port);
      camera.update(
        location: _fix(
          _origin,
          at: DateTime.now().add(const Duration(milliseconds: 50)),
        ),
        navigating: true,
      );
      expect(port.poses, isNotEmpty);
    });
  });

  group('D-06 one far GPS outlier', () {
    testWidgets('is held back: no reroute, progress stays monotonic', (
      tester,
    ) async {
      final routes = _StraightRoutes();
      final nav = NavigationController(routeRepository: routes);
      addTearDown(nav.dispose);
      final t0 = DateTime.now().subtract(const Duration(seconds: 20));
      nav.setVehicle(_fix(_origin, at: t0));
      await nav.ensureRoute(origin: _origin, destination: _east(_origin, 2000));
      final onRoad = _east(_origin, 100);
      expect(nav.setVehicle(_fix(onRoad, at: t0.add(const Duration(seconds: 7)))),
          isTrue);
      final fraction = nav.routeFraction!;
      // 250 m to the side one second later, accuracy still 10 m.
      final outlier = _north(onRoad, 250);
      expect(
        nav.setVehicle(_fix(outlier,
            at: t0.add(const Duration(seconds: 8)), accuracy: 10)),
        isFalse,
      );
      expect(nav.snapshot.vehicle, onRoad);
      expect(nav.snapshot.offRoute, isFalse);
      expect(nav.status, isNull);
      // Then a 10 s GPS gap.
      for (var s = 0; s < 10; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(routes.calls, 1, reason: 'No reroute from the outlier');
      // The car reappears further along the road.
      final later = _east(_origin, 240);
      expect(nav.setVehicle(_fix(later, at: t0.add(const Duration(seconds: 19)))),
          isTrue);
      expect(nav.routeFraction, greaterThan(fraction));
      await tester.pump(const Duration(seconds: 3));
      expect(routes.calls, 1);
      expect(nav.reroutes, 0);
    });

    test('a second fix that agrees with the jump is accepted', () {
      final nav = NavigationController(routeRepository: _StraightRoutes());
      addTearDown(nav.dispose);
      final t0 = DateTime.now().subtract(const Duration(seconds: 3));
      nav.setVehicle(_fix(_origin, at: t0));
      final far = _east(_origin, 2000);
      expect(nav.setVehicle(_fix(far, at: t0.add(const Duration(seconds: 1)))),
          isFalse);
      expect(nav.snapshot.vehicle, _origin);
      final next = _east(far, 10);
      expect(nav.setVehicle(_fix(next, at: t0.add(const Duration(seconds: 2)))),
          isTrue);
      expect(nav.snapshot.vehicle, next);
    });

    test('demo points without a timestamp are never filtered', () {
      final nav = NavigationController(routeRepository: _StraightRoutes());
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: _origin));
      final far = _east(_origin, 5000);
      expect(nav.setVehicle(DriverLocation(point: far)), isTrue);
      expect(nav.snapshot.vehicle, far);
    });
  });

  group('every driver map tilts with its zoom', () {
    test('the curve: flat region view, SDK maximum at street zoom', () {
      double t(double z) => DriverCameraPolicy.tiltForZoom(z);
      expect(t(11), 0);
      expect(t(12), closeTo(10.5, .1));
      expect(t(13), closeTo(33.75, .1));
      expect(t(14), 45); // Android/iOS allow 45 degrees at zoom 14.
      expect(t(15), 60); // ... and 60 at zoom 15.
      expect(t(15.5), 67.5);
      expect(t(16.5), 67.5);
      expect(t(17), 67.5);
      for (var z = 0.0; z <= 21; z += .05) {
        expect(t(z), lessThanOrEqualTo(DriverCameraPolicy.sdkMaxTilt(z)));
      }
    });

    test('Home opens on the area around the driver, nearly flat', () {
      expect(DriverCameraPolicy.exploreZoom, 11.7);
      final pose = DriverCameraPolicy().resolve(location: _fix(_origin));
      expect(pose.zoom, 11.7);
      expect(pose.bearing, 0);
      expect(pose.tilt, closeTo(5.5, .3));
    });

    test('guidance cruise is at full tilt; arrival eases to 60; waiting flat',
        () {
      final road = RoadRoute(
        points: [for (var i = 0; i <= 20; i++) _east(_origin, i * 100.0)],
        distanceMeters: 2000,
        durationSeconds: 200,
      );
      final policy = DriverCameraPolicy();
      final cruise = policy.resolve(
          location: _fix(_origin), route: road, navigating: true,
          immediate: true);
      expect(cruise.tilt, greaterThanOrEqualTo(58));
      final arrival = DriverCameraPolicy().resolve(
          location: _fix(_east(_origin, 2000)), route: road, navigating: true,
          immediate: true);
      expect(arrival.tilt, DriverCameraPolicy.arrivalTilt);
      expect(DriverCameraPolicy.arrivalTilt, 60);
      final waiting = DriverCameraPolicy().resolve(
          location: _fix(_origin), navigating: true, waiting: true,
          immediate: true);
      expect(waiting.tilt, 0);
    });

    test('a pinch zoom on Home tilts once let go; zooming out flattens', () {
      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _Port();
      camera.attach(port);
      camera.update(location: _fix(_origin)); // Home: not navigating.
      camera.userGesture();
      port
        ..currentZoom = 17
        ..currentTilt = 5;
      camera.browseSettled();
      expect(port.tilts.single, closeTo(67.5, .01));
      port.currentZoom = 12;
      camera.browseSettled();
      expect(port.tilts.last, closeTo(DriverCameraPolicy.tiltForZoom(12), .01));
      port.currentZoom = 10.5;
      camera.browseSettled();
      expect(port.tilts.last, 0);
    });

    test('waiting at the pickup stays flat after a pinch', () {
      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _Port();
      camera.attach(port);
      camera.update(location: _fix(_origin), navigating: true, waiting: true);
      camera.userGesture();
      port
        ..currentZoom = 17
        ..currentTilt = 0;
      camera.browseSettled();
      expect(port.tilts, isEmpty);
    });
  });
}
