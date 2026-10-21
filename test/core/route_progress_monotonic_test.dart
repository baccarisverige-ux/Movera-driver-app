import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

// Out-and-back on one road: start -> turnaround -> start.
const _start = GeoPoint(59.3300, 18.0600);
const _turn = GeoPoint(59.3300, 18.0700);
const _mid = GeoPoint(59.3300, 18.0650);

RoadRoute _outAndBack() => RoadRoute(
  points: const [_start, _mid, _turn, _mid, _start],
  distanceMeters: 2280,
  durationSeconds: 300,
  instructions: const [
    RouteInstruction(
      type: RouteManeuverType.turn,
      modifier: 'uturn',
      text: 'Make a U-turn',
      distanceMeters: 570,
      maneuverLocation: _turn,
    ),
    RouteInstruction(
      type: RouteManeuverType.arrive,
      modifier: '',
      text: 'Arrive',
      distanceMeters: 570,
      maneuverLocation: _start,
    ),
  ],
);

class _OneRoute implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async => _outAndBack();
}

DriverLocation _at(double lat, double lng) => DriverLocation(
  point: GeoPoint(lat, lng),
  measuredAt: DateTime.now(),
  accuracyMeters: 5,
);

void main() {
  const calculator = RouteProgressCalculator();

  // driver-r4-34: one fix off the road must not lose which pass the car is on.
  test('after one off-route fix the car stays on the return pass', () async {
    final navigation = NavigationController(routeRepository: _OneRoute());
    addTearDown(navigation.dispose);
    navigation.setVehicle(_at(59.33, 18.0610));
    await navigation.ensureRoute(origin: _start, destination: _start);
    for (final lng in [18.0640, 18.0670, 18.0695, 18.0700, 18.0690, 18.0670, 18.0650]) {
      navigation.setVehicle(_at(59.33, lng));
    }
    final before = navigation.routeFraction!;
    expect(before, greaterThan(0.5));
    navigation.setVehicle(_at(59.3307, 18.0650)); // 80 m off the road
    navigation.setVehicle(_at(59.33, 18.0648));
    navigation.setVehicle(_at(59.33, 18.0636));
    expect(navigation.routeFraction, greaterThanOrEqualTo(before));
    expect(navigation.snapshot.banner?.symbol, isNot(NavigationBannerSymbol.uTurn));
  });

  test('arrival at the route start is resolved after the U-turn, not at 0 m', () {
    final route = _outAndBack();
    final first = calculator.measure(route: route, position: const GeoPoint(59.3300, 18.0610));
    expect(first.nextInstruction?.type, RouteManeuverType.turn);
    expect(first.remainingMeters, greaterThan(1000));
  });

  test('progress on the return leg stays on the return leg', () {
    final route = _outAndBack();
    // Drive out, through the U-turn and back to the midpoint.
    double? along;
    var hint = 0;
    RouteProgress? progress;
    for (final lng in [18.0610, 18.0640, 18.0670, 18.0695, 18.0700]) {
      progress = calculator.measure(route: route, position: GeoPoint(59.3300, lng), instructionHint: hint, previousAlongMeters: along);
      along = progress.alongMeters;
      hint = progress.instructionIndex;
    }
    for (final lng in [18.0690, 18.0670, 18.0650]) {
      progress = calculator.measure(route: route, position: GeoPoint(59.3300, lng), instructionHint: hint, previousAlongMeters: along);
      expect(progress.alongMeters, greaterThanOrEqualTo(along!), reason: 'progress must not jump back to the outbound leg');
      along = progress.alongMeters;
      hint = progress.instructionIndex;
    }
    expect(progress!.nextInstruction?.type, RouteManeuverType.arrive);
    expect(progress.remainingMeters, lessThan(700));
    expect(progress.offRoute, isFalse);
  });

  test('a far jump outside the window still finds the road (rejoin)', () {
    final route = _outAndBack();
    final progress = calculator.measure(
      route: route,
      position: const GeoPoint(59.3300, 18.0690),
      previousAlongMeters: 0,
    );
    expect(progress.offRoute, isFalse);
    expect(progress.distanceFromRouteMeters, lessThan(5));
  });

  test('2,000-point route measures quickly with cached geometry', () {
    final points = [for (var i = 0; i < 2000; i++) GeoPoint(59.30 + i * 0.0001, 18.05)];
    final route = RoadRoute(points: points, distanceMeters: 22000, durationSeconds: 1800, instructions: [
      for (var i = 100; i < 2000; i += 100)
        RouteInstruction(type: RouteManeuverType.turn, modifier: 'left', text: 'Turn left', distanceMeters: 0, maneuverLocation: points[i]),
    ]);
    final watch = Stopwatch()..start();
    double? along;
    var hint = 0;
    for (var i = 0; i < 2000; i += 4) {
      final p = calculator.measure(route: route, position: points[i], instructionHint: hint, previousAlongMeters: along);
      along = p.alongMeters;
      hint = p.instructionIndex;
    }
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  test('routing host is configurable and the demo host is flagged', () {
    final demo = RoadRouteService();
    expect(demo.usesPublicDemoServer, RoadRouteService.defaultHost == RoadRouteService.publicDemoHost);
    final contracted = RoadRouteService(host: 'routing.example.test');
    expect(contracted.usesPublicDemoServer, isFalse);
    demo.dispose();
    contracted.dispose();
  });
}
