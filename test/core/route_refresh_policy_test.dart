import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

const _origin = GeoPoint(59, 18);
const _destination = GeoPoint(59, 18.01);

/// Answers every request with a Completer the test resolves.
class _Routes implements RouteRepository {
  final responses = <Completer<RoadRoute>>[];

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final response = Completer<RoadRoute>();
    responses.add(response);
    return response.future;
  }
}

RoadRoute _road({GeoPoint from = _origin}) => RoadRoute(
  points: [from, _destination],
  distanceMeters: 570,
  durationSeconds: 60,
  instructions: const [
    RouteInstruction(
      type: RouteManeuverType.arrive,
      modifier: '',
      text: 'Arrive',
      distanceMeters: 570,
      maneuverLocation: _destination,
    ),
  ],
);

/// A point [meters] along the route, on the road.
GeoPoint _along(double meters) =>
    GeoPoint(59, 18 + 0.01 * meters / _origin.distanceMetersTo(_destination));

void main() {
  late DateTime now;
  late _Routes routes;
  late NavigationController nav;

  Future<void> firstRoute() async {
    nav.setVehicle(const DriverLocation(point: _origin));
    final first = nav.ensureRoute(origin: _origin, destination: _destination);
    expect(nav.status, 'Route updating…');
    routes.responses.single.complete(_road());
    await first;
    expect(nav.routeState, RouteLoadState.ready);
    expect(nav.status, isNull);
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 15, 8);
    routes = _Routes();
    nav = NavigationController(routeRepository: routes, now: () => now);
  });
  tearDown(() => nav.dispose());

  test('driving along the route never asks for a new route', () async {
    await firstRoute();
    final route = nav.route;
    for (var step = 1; step <= 8; step++) {
      // 50 m and 10 s per fix: the old rule refetched on every one.
      now = now.add(const Duration(seconds: 10));
      final point = _along(step * 50);
      nav.setVehicle(DriverLocation(point: point));
      await nav.ensureRoute(origin: point, destination: _destination);
      expect(nav.status, isNull);
      expect(nav.snapshot.banner?.status, isNull);
      expect(nav.route, same(route));
    }
    expect(routes.responses, hasLength(1));
    expect(nav.reroutes, 0);
  });

  test(
    'a slow silent refresh keeps the route and instructions on screen',
    () async {
      await firstRoute();
      final route = nav.route;
      final banner = nav.snapshot.banner;
      now = now.add(NavigationController.silentRefreshInterval);
      final point = _along(100);
      nav.setVehicle(DriverLocation(point: point));
      final refresh = nav.ensureRoute(origin: point, destination: _destination);
      expect(routes.responses, hasLength(2));
      // Loading in the background: same route, same instruction, no status.
      expect(nav.route, same(route));
      expect(nav.routeState, RouteLoadState.ready);
      expect(nav.status, isNull);
      expect(nav.snapshot.banner?.primary, banner?.primary);
      expect(nav.snapshot.banner?.status, isNull);
      // Fixes during the refresh never start another one.
      await nav.ensureRoute(origin: point, destination: _destination);
      expect(routes.responses, hasLength(2));
      routes.responses.last.complete(_road(from: point));
      await refresh;
      expect(nav.route, isNot(same(route)));
      expect(nav.status, isNull);
      expect(nav.reroutes, 0, reason: 'A silent refresh is not a reroute.');
    },
  );

  test('a failed silent refresh keeps following the current route', () async {
    await firstRoute();
    final route = nav.route;
    now = now.add(NavigationController.silentRefreshInterval);
    final refresh = nav.ensureRoute(origin: _origin, destination: _destination);
    routes.responses.last.completeError(TimeoutException('offline'));
    await refresh;
    expect(nav.route, same(route));
    expect(nav.routeState, RouteLoadState.ready);
    expect(nav.status, isNull);
  });

  test('a forced refresh with a route never says "Route updating…"', () async {
    await firstRoute();
    final route = nav.route;
    final retry = nav.ensureRoute(
      origin: _origin,
      destination: _destination,
      force: true,
    );
    expect(routes.responses, hasLength(2));
    expect(nav.status, isNull);
    expect(nav.route, same(route));
    routes.responses.last.complete(_road());
    await retry;
    expect(nav.status, isNull);
    expect(nav.reroutes, 0);
  });

  testWidgets('leaving the route reroutes once and keeps guidance meanwhile', (
    tester,
  ) async {
    await firstRoute();
    final route = nav.route;
    const away = GeoPoint(59.002, 18.005);
    nav.setVehicle(const DriverLocation(point: away));
    expect(nav.snapshot.offRoute, isTrue);
    expect(nav.status, 'Recalculating route…');
    // Fixes while off the route do not ask for routes of their own.
    await nav.ensureRoute(origin: away, destination: _destination);
    expect(routes.responses, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(routes.responses, hasLength(2));
    // The old route stays while the new one loads; no "Route updating…".
    expect(nav.route, same(route));
    expect(nav.status, 'Recalculating route…');
    routes.responses.last.complete(_road(from: away));
    await tester.pump();
    expect(nav.snapshot.offRoute, isFalse);
    expect(nav.status, isNull);
    expect(nav.reroutes, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(routes.responses, hasLength(2));
  });

  testWidgets('back on the road before the reroute is not a reroute', (
    tester,
  ) async {
    await firstRoute();
    nav.setVehicle(const DriverLocation(point: GeoPoint(59.002, 18.005)));
    expect(nav.status, 'Recalculating route…');
    nav.setVehicle(DriverLocation(point: _along(300)));
    expect(nav.status, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(routes.responses, hasLength(1));
    expect(nav.reroutes, 0);
  });

  group('island "Route updated" notice', () {
    TripIslandInput input({
      String? status,
      int reroutes = 0,
      NavigationBanner banner = const NavigationBanner(
        primary: 'Continue on Sveavägen',
        distanceLabel: '800 m',
      ),
    }) => TripIslandInput(
      status: 'To pickup',
      address: 'Storgatan 8',
      waitingMessage: 'Waiting for Angelica',
      banner: banner,
      navigationStatus: status,
      reroutes: reroutes,
    );

    testWidgets('only after a real reroute', (tester) async {
      final island = TripIslandController(input(status: 'Route updating…'));
      addTearDown(island.dispose);
      // First route arrived: no notice.
      island.update(input());
      expect(island.face.kind, TripIslandKind.guidance);
      // Off the route and back without a new route: no notice.
      island.update(input(status: 'Recalculating route…'));
      island.update(input());
      expect(island.face.kind, TripIslandKind.guidance);
      // Failed route and a retry: no notice.
      island.update(input(status: 'Route unavailable — retry'));
      island.update(input());
      expect(island.face.kind, TripIslandKind.guidance);
      // A real reroute.
      island.update(input(status: 'Recalculating route…'));
      island.update(input(reroutes: 1));
      expect(island.face.title, 'Route updated');
      await tester.pump(const Duration(seconds: 2));
      expect(island.face.kind, TripIslandKind.guidance);
    });

    testWidgets('never hides an upcoming maneuver', (tester) async {
      const turn = NavigationBanner(
        primary: 'Turn left in 120 m',
        distanceLabel: '120 m',
        symbol: NavigationBannerSymbol.left,
      );
      final island = TripIslandController(
        input(status: 'Recalculating route…', banner: turn),
      );
      addTearDown(island.dispose);
      island.update(input(reroutes: 1, banner: turn));
      expect(island.face.kind, TripIslandKind.guidance);
      expect(island.face.title, 'Turn left in 120 m');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
