import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

// D3.6 navigation: what the trip shows while the car is off route or GPS
// drifts toward another part of the route.

class _Routes implements RouteRepository {
  _Routes(this.route);
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

const _origin = GeoPoint(59, 18);
const _destination = GeoPoint(59, 18.01);

void main() {
  testWidgets('driver-u26 / driver-u28: an off-route fix keeps the driven '
      'share instead of resetting ETA and leg progress to the full route',
      (tester) async {
    final routes = _Routes(RoadRoute(
      points: const [_origin, _destination],
      distanceMeters: 600,
      durationSeconds: 1080,
    ));
    final nav = NavigationController(routeRepository: routes);
    addTearDown(nav.dispose);
    nav.setVehicle(const DriverLocation(point: _origin));
    await nav.ensureRoute(origin: _origin, destination: _destination);
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.009)));
    expect(nav.routeFraction, closeTo(.9, .01));

    // About 110 m north of the road: off route, reroute pending.
    nav.setVehicle(const DriverLocation(point: GeoPoint(59.001, 18.009)));
    expect(nav.snapshot.offRoute, isTrue);
    expect(nav.routeFraction, closeTo(.9, .01),
        reason: 'the island ETA and leg progress must not jump back to the '
            'whole route while the reroute is on its way');

    // Back on the road: progress continues from the road again.
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.0095)));
    expect(nav.snapshot.offRoute, isFalse);
    expect(nav.routeFraction, closeTo(.95, .01));
  });

  testWidgets('driver-u26: a new route starts its driven share from zero',
      (tester) async {
    final routes = _Routes(RoadRoute(
      points: const [_origin, _destination],
      distanceMeters: 600,
      durationSeconds: 1080,
    ));
    final nav = NavigationController(routeRepository: routes);
    addTearDown(nav.dispose);
    nav.setVehicle(const DriverLocation(point: _origin));
    await nav.ensureRoute(origin: _origin, destination: _destination);
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.009)));
    const detour = GeoPoint(59.001, 18.009);
    nav.setVehicle(const DriverLocation(point: detour));
    routes.route = RoadRoute(
      points: const [detour, GeoPoint(59, 18.0095), _destination],
      distanceMeters: 150,
      durationSeconds: 40,
    );
    await tester.pump(const Duration(seconds: 3)); // reroute debounce
    await tester.pump();
    expect(routes.requests, 2);
    expect(nav.routeFraction, closeTo(0, .01));
  });
}
