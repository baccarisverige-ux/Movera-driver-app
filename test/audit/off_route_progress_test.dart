import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/routing/route_instruction.dart';
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

// Metres to degrees at latitude 59.
const _north = 1 / 111195.0, _east = 1 / 57270.0;
GeoPoint _at(double northMeters, double eastMeters) =>
    GeoPoint(59 + northMeters * _north, 18 + eastMeters * _east);

/// Around the block: 300 m north, 80 m east, 300 m back south, with a turn
/// at both corners. The return leg runs 80 m from the outbound one.
RoadRoute _aroundTheBlock() => RoadRoute(
  points: [_at(0, 0), _at(300, 0), _at(300, 80), _at(0, 80)],
  distanceMeters: 680,
  durationSeconds: 120,
  instructions: [
    RouteInstruction(
      type: RouteManeuverType.turn,
      modifier: 'right',
      text: 'Turn right',
      distanceMeters: 300,
      maneuverLocation: _at(300, 0),
    ),
    RouteInstruction(
      type: RouteManeuverType.turn,
      modifier: 'right',
      text: 'Turn right',
      distanceMeters: 80,
      maneuverLocation: _at(300, 80),
    ),
    RouteInstruction(
      type: RouteManeuverType.arrive,
      modifier: '',
      text: 'Arrive',
      distanceMeters: 300,
      maneuverLocation: _at(0, 80),
    ),
  ],
);

void main() {
  testWidgets('driver-u26 / driver-u28: an off-route fix keeps the driven '
      'share instead of resetting ETA and leg progress to the full route', (
    tester,
  ) async {
    final routes = _Routes(
      RoadRoute(
        points: const [_origin, _destination],
        distanceMeters: 600,
        durationSeconds: 1080,
      ),
    );
    final nav = NavigationController(routeRepository: routes);
    addTearDown(nav.dispose);
    nav.setVehicle(const DriverLocation(point: _origin));
    await nav.ensureRoute(origin: _origin, destination: _destination);
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.009)));
    expect(nav.routeFraction, closeTo(.9, .01));

    // About 110 m north of the road: off route, reroute pending.
    nav.setVehicle(const DriverLocation(point: GeoPoint(59.001, 18.009)));
    expect(nav.snapshot.offRoute, isTrue);
    expect(
      nav.routeFraction,
      closeTo(.9, .01),
      reason:
          'the island ETA and leg progress must not jump back to the '
          'whole route while the reroute is on its way',
    );

    // Back on the road: progress continues from the road again.
    nav.setVehicle(const DriverLocation(point: GeoPoint(59, 18.0095)));
    expect(nav.snapshot.offRoute, isFalse);
    expect(nav.routeFraction, closeTo(.95, .01));
  });

  testWidgets('driver-u26: a new route starts its driven share from zero', (
    tester,
  ) async {
    final routes = _Routes(
      RoadRoute(
        points: const [_origin, _destination],
        distanceMeters: 600,
        durationSeconds: 1080,
      ),
    );
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

  test('driver-u29: one fix that drifts toward a later leg does not skip '
      'the turns in between', () {
    const calc = RouteProgressCalculator();
    final route = _aroundTheBlock();
    var hint = 0;
    double? along;
    RouteProgress fix(GeoPoint point) {
      final progress = calc.measure(
        route: route,
        position: point,
        instructionHint: hint,
        previousAlongMeters: along,
      );
      hint = progress.instructionIndex;
      along = progress.offRoute ? null : progress.alongMeters;
      return progress;
    }

    for (var y = 100.0; y <= 190; y += 15) {
      fix(_at(y, 0));
    }
    expect(hint, 0);
    // 48 m east of the outbound leg, 32 m from the return leg.
    final drift = fix(_at(190, 48));
    expect(drift.offRoute, isFalse);
    expect(
      drift.alongMeters,
      closeTo(190, 5),
      reason: 'the car must not snap onto the other street',
    );
    expect(drift.instructionIndex, 0);
    final back = fix(_at(205, 0));
    expect(back.instructionIndex, 0);
    expect(back.nextInstruction?.text, 'Turn right');
    expect(back.distanceToManeuverMeters, closeTo(95, 5));
  });

  test('driver-u29: a stale instruction hint ahead of the car steps back '
      'to the next maneuver it has not passed', () {
    final progress = const RouteProgressCalculator().measure(
      route: _aroundTheBlock(),
      position: _at(205, 0),
      instructionHint: 2,
    );
    expect(progress.instructionIndex, 0);
    expect(progress.nextInstruction?.text, 'Turn right');
  });

  testWidgets('driver-u29: the trip banner keeps the turn after a drifting '
      'fix', (tester) async {
    final route = _aroundTheBlock();
    final nav = NavigationController(routeRepository: _Routes(route));
    addTearDown(nav.dispose);
    nav.setVehicle(DriverLocation(point: _at(0, 0)));
    await nav.ensureRoute(origin: _at(0, 0), destination: _at(0, 80));
    for (var y = 100.0; y <= 190; y += 15) {
      nav.setVehicle(DriverLocation(point: _at(y, 0)));
    }
    expect(nav.snapshot.banner?.primary, startsWith('Turn right'));
    nav.setVehicle(DriverLocation(point: _at(190, 48)));
    nav.setVehicle(DriverLocation(point: _at(205, 0)));
    nav.setVehicle(DriverLocation(point: _at(220, 0)));
    expect(
      nav.snapshot.banner?.primary,
      startsWith('Turn right'),
      reason: 'the banner must still show the coming turn, not Pickup',
    );
  });
}
