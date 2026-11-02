import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/coalescing_map_route_refresh.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';

class Routes implements RouteRepository {
  Routes(this.route);
  RoadRoute route;
  int requests = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    requests++;
    return route;
  }
}

const origin = GeoPoint(59, 18);
const destination = GeoPoint(59, 18.01);
RoadRoute road({List<GeoPoint>? points}) => RoadRoute(
  points: points ?? [origin, destination],
  distanceMeters: 2000,
  durationSeconds: 60,
);
void main() {
  test(
    'R08 coalescing runs the newest callback rather than the first one again',
    () async {
      final queue = CoalescingMapRouteRefresh();
      final gate = Completer<void>();
      final calls = <String>[];
      final pending = queue.request(() async {
        calls.add('first');
        await gate.future;
      });
      await queue.request(() async {
        calls.add('obsolete');
      });
      await queue.request(() async {
        calls.add('latest');
      });
      gate.complete();
      await pending;
      expect(calls, ['first', 'latest']);
    },
  );
  test('R09 failing route request still runs queued latest recovery', () async {
    final queue = CoalescingMapRouteRefresh();
    final gate = Completer<void>();
    var recovered = false;
    final pending = queue.request(() async {
      await gate.future;
      throw StateError('offline');
    });
    final check = expectLater(pending, throwsStateError);
    await queue.request(() async {
      recovered = true;
    });
    gate.complete();
    await check;
    expect(recovered, isTrue);
    expect(queue.isRunning, isFalse);
  });
  test(
    'R10 older fresh GPS cannot rewind the vehicle or clear its warning',
    () {
      final nav = NavigationController(routeRepository: Routes(road()));
      addTearDown(nav.dispose);
      final now = DateTime.now();
      nav.setVehicle(
        DriverLocation(point: destination, measuredAt: now, accuracyMeters: 5),
      );
      nav.keepLastKnown();
      nav.setVehicle(
        DriverLocation(
          point: origin,
          measuredAt: now.subtract(const Duration(seconds: 1)),
          accuracyMeters: 5,
        ),
      );
      expect(nav.snapshot.vehicle, destination);
      expect(nav.status, 'Location updating…');
    },
  );
  testWidgets(
    'R11 rejoining road cancels delayed reroute and stale recalculating copy',
    (tester) async {
      final repo = Routes(road());
      final nav = NavigationController(routeRepository: repo);
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: origin));
      await nav.ensureRoute(origin: origin, destination: destination);
      nav.setVehicle(const DriverLocation(point: GeoPoint(59.002, 18.005)));
      expect(nav.snapshot.offRoute, isTrue);
      expect(nav.status, 'Recalculating route…');
      nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.005)));
      expect(nav.status, isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(repo.requests, 1);
      expect(nav.routeState, RouteLoadState.ready);
    },
  );
  test('R12 progress fraction uses polyline length rather than provider road distance', () async {
    final nav = NavigationController(routeRepository: Routes(road()));
    addTearDown(nav.dispose);
    nav.setVehicle(const DriverLocation(point: origin));
    await nav.ensureRoute(origin: origin, destination: destination);
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.005)));
    expect(nav.routeFraction, closeTo(.5, .001));
    nav.setVehicle(const DriverLocation(point: destination));
    expect(nav.routeFraction, closeTo(1, .001));
  });
  test(
    'R13 custom adapter with invalid geometry fails before guidance projection',
    () async {
      final nav = NavigationController(
        routeRepository: Routes(
          road(points: [origin, const GeoPoint(double.nan, 18)]),
        ),
      );
      addTearDown(nav.dispose);
      await nav.ensureRoute(origin: origin, destination: destination);
      expect(nav.routeState, RouteLoadState.failed);
      expect(nav.route, isNull);
    },
  );
  test(
    'R14 stage transition cannot retry the previous stage destination',
    () async {
      final repo = Routes(road());
      final nav = NavigationController(routeRepository: repo);
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: origin));
      await nav.ensureRoute(origin: origin, destination: destination);
      nav.setStage(ActiveRideStage.onTrip);
      await nav.retryRoute();
      expect(repo.requests, 1);
      expect(nav.routeState, RouteLoadState.idle);
    },
  );

  test(
    'R26 invalid requested coordinates never reach the routing adapter',
    () async {
      for (final invalid in [
        const GeoPoint(double.nan, 18),
        const GeoPoint(91, 18),
        const GeoPoint(59, 181),
      ]) {
        final repo = Routes(road());
        final nav = NavigationController(routeRepository: repo);
        await nav.ensureRoute(origin: origin, destination: invalid);
        expect(repo.requests, 0);
        expect(nav.routeState, RouteLoadState.failed);
        expect(nav.route, isNull);
        await nav.retryRoute();
        expect(repo.requests, 0);
        await nav.ensureRoute(origin: invalid, destination: destination);
        expect(repo.requests, 0);
        nav.dispose();
      }
    },
  );
  test(
    'R27 invalid GPS courses above a full circle retain the previous course',
    () {
      for (final heading in [361.0, 721.0, double.infinity, double.nan, -1.0]) {
        expect(
          DriverLocation(
            point: origin,
            headingDegrees: heading,
            speedMetersPerSecond: 10,
          ).courseOr(90),
          90,
        );
        const current = GeoPoint(59, 18.001);
        expect(
          current.resolvedHeading(
            gpsHeading: heading,
            previous: origin,
            fallback: 90,
          ),
          current.resolvedHeading(
            gpsHeading: double.nan,
            previous: origin,
            fallback: 90,
          ),
        );
      }
      expect(
        const DriverLocation(
          point: origin,
          headingDegrees: 0,
          speedMetersPerSecond: 10,
        ).courseOr(90),
        0,
      );
      expect(
        const DriverLocation(
          point: origin,
          headingDegrees: 360,
          speedMetersPerSecond: 10,
        ).courseOr(90),
        0,
      );
    },
  );
  test(
    'R28 provider list reuse cannot mutate accepted map geometry or guidance',
    () async {
      final points = [origin, destination];
      final steps = <RouteInstruction>[];
      final repo = Routes(
        RoadRoute(
          points: points,
          distanceMeters: 570,
          durationSeconds: 60,
          instructions: steps,
        ),
      );
      final nav = NavigationController(routeRepository: repo);
      addTearDown(nav.dispose);
      nav.setVehicle(const DriverLocation(point: origin));
      await nav.ensureRoute(origin: origin, destination: destination);
      points.clear();
      steps.add(
        const RouteInstruction(
          type: RouteManeuverType.turn,
          modifier: 'left',
          text: 'Turn left',
          distanceMeters: 0,
          maneuverLocation: origin,
        ),
      );
      expect(nav.route!.points, [origin, destination]);
      expect(nav.route!.instructions, isEmpty);
      nav.setVehicle(const DriverLocation(point: destination));
      expect(nav.routeFraction, closeTo(1, .001));
      expect(() => nav.route!.points.clear(), throwsUnsupportedError);
    },
  );
  test(
    'R30 missing fork or end-of-road direction never invents a right turn',
    () {
      for (final type in [
        RouteManeuverType.fork,
        RouteManeuverType.endOfRoad,
      ]) {
        final full = RouteInstructionCopy.build(type: type, modifier: '');
        final short = RouteInstructionCopy.shortAction(
          type: type,
          modifier: '',
        );
        expect(full.toLowerCase(), isNot(contains('right')));
        expect(short.toLowerCase(), isNot(contains('right')));
        for (final direction in ['left', 'right']) {
          expect(
            RouteInstructionCopy.build(type: type, modifier: direction),
            contains(direction),
          );
          expect(
            RouteInstructionCopy.shortAction(type: type, modifier: direction),
            contains(direction),
          );
        }
      }
    },
  );
}
