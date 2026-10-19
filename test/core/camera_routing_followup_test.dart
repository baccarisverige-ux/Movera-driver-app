import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

const _start = GeoPoint(59, 18);
const _end = GeoPoint(59.02, 18);

class _Port implements DriverCameraPort {
  final commands = <DriverCameraPose>[];
  final completions = <Completer<void>>[];
  int disposals = 0;

  @override
  Future<void> animate(DriverCameraPose pose) {
    commands.add(pose);
    final completion = Completer<void>();
    completions.add(completion);
    return completion.future;
  }

  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  void retarget(DriverCameraPose pose) {}
  @override
  void interrupt() {}
  @override
  void dispose() {
    disposals++;
    for (final completion in completions) {
      if (!completion.isCompleted) completion.complete();
    }
  }
}

class _DelayedRoutes implements RouteRepository {
  final first = Completer<RoadRoute>();
  int requests = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    requests++;
    if (requests == 1) return first.future;
    return Future.value(
      RoadRoute(
        points: [origin, destination],
        distanceMeters: 1000,
        durationSeconds: 60,
      ),
    );
  }
}

DriverLocation _fix(GeoPoint point, DateTime now) => DriverLocation(
  point: point,
  measuredAt: now,
  accuracyMeters: 5,
  speedMetersPerSecond: 10,
);

void main() {
  testWidgets(
    'C01 off-route response queues recovery without another GPS fix',
    (tester) async {
      final routes = _DelayedRoutes();
      final nav = NavigationController(routeRepository: routes);
      addTearDown(nav.dispose);
      const destination = GeoPoint(59, 18.01);
      nav.setVehicle(const DriverLocation(point: _start));
      final pending = nav.ensureRoute(origin: _start, destination: destination);
      nav.setVehicle(const DriverLocation(point: GeoPoint(59.002, 18.005)));
      routes.first.complete(
        const RoadRoute(
          points: [_start, destination],
          distanceMeters: 570,
          durationSeconds: 60,
        ),
      );
      await pending;
      expect(nav.snapshot.offRoute, isTrue);
      expect(nav.status, 'Recalculating route…');
      await tester.pump(const Duration(seconds: 2));
      expect(routes.requests, 2);
      expect(nav.routeState, RouteLoadState.ready);
      expect(nav.snapshot.offRoute, isFalse);
    },
  );

  test(
    'C02 leaving waiting overview restores guidance entry framing',
    () async {
      final now = DateTime.utc(2026, 10, 9);
      final camera = DriverCameraController(now: () => now);
      final port = _Port();
      addTearDown(camera.dispose);
      camera.attach(port);
      camera.update(
        location: _fix(_start, now),
        navigating: true,
        waiting: true,
      );
      await camera.preview([_start, _end]);
      camera.update(location: _fix(_start, now), navigating: true);
      expect(camera.mode, DriverCameraMode.following);
      expect(port.commands.last.duration, const Duration(milliseconds: 900));
    },
  );

  testWidgets(
    'C03 expired queued pose is dropped and fresh GPS resumes movement',
    (tester) async {
      var now = DateTime.utc(2026, 10, 9);
      final camera = DriverCameraController(now: () => now);
      final port = _Port();
      addTearDown(camera.dispose);
      camera.attach(port);
      camera.update(location: _fix(_start, now));
      camera.update(location: _fix(_end, now));
      now = now.add(const Duration(seconds: 31));
      port.completions.first.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(port.commands, hasLength(1));
      camera.update(location: _fix(_end, now));
      expect(port.commands, hasLength(2));
      camera.dispose();
      await tester.pump();
    },
  );

  test('C04 attaching the active map port twice preserves it', () {
    final camera = DriverCameraController();
    final port = _Port();
    camera.attach(port);
    camera.attach(port);
    expect(port.disposals, 0);
    camera.dispose();
    expect(port.disposals, 1);
  });

  test(
    'C05 disposed routing service rejects new requests on a borrowed client',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final service = RoadRouteService(client: client);
      service.dispose();
      await expectLater(
        service.drivingRoute(origin: _start, destination: _end),
        throwsA(isA<RoadRouteException>()),
      );
      expect(requests, 0);
      // Disposal must not close a caller-owned transport.
      await client.get(Uri.https('example.com', '/'));
      expect(requests, 1);
    },
  );

  test(
    'C05 disposed routing service rejects a late successful response',
    () async {
      final response = Completer<http.Response>();
      final client = MockClient((_) => response.future);
      addTearDown(client.close);
      final service = RoadRouteService(client: client);
      final pending = service.drivingRoute(origin: _start, destination: _end);
      final rejected = expectLater(pending, throwsA(isA<RoadRouteException>()));
      service.dispose();
      response.complete(
        http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [18, 59],
                    [18, 59.02],
                  ],
                },
                'distance': 2224,
                'duration': 200,
              },
            ],
          }),
          200,
        ),
      );
      await rejected;
    },
  );

  test(
    'C06 corrected turns on unchanged road geometry reset maneuver progress',
    () {
      final now = DateTime.utc(2026, 10, 9);
      RouteInstruction step(GeoPoint at, RouteManeuverType type) =>
          RouteInstruction(
            type: type,
            modifier: 'left',
            text: 'Turn left',
            distanceMeters: 0,
            maneuverLocation: at,
          );
      RoadRoute road(GeoPoint turn) => RoadRoute(
        points: const [_start, _end],
        distanceMeters: 2224,
        durationSeconds: 200,
        instructions: [
          step(turn, RouteManeuverType.turn),
          step(_end, RouteManeuverType.arrive),
        ],
      );
      final camera = DriverCameraPolicy();
      final location = _fix(const GeoPoint(59.01, 18), now);
      final cruise = camera.resolve(
        location: location,
        route: road(_start),
        navigating: true,
        immediate: true,
      );
      final pose = camera.resolve(
        location: location,
        route: road(const GeoPoint(59.0109, 18)),
        navigating: true,
        immediate: true,
      );
      // The corrected turn is now ~100 m ahead: the camera closes in a
      // little and never gets flatter (cruise may already be at full tilt).
      expect(pose.zoom, greaterThan(cruise.zoom));
      expect(pose.tilt, greaterThanOrEqualTo(cruise.tilt));
    },
  );
}
