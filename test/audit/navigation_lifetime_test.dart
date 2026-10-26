import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';

class _Route implements RouteRepository {
  final result = Completer<RoadRoute>();
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) => result.future;
}

void main() {
  const route = RoadRoute(
    points: [GeoPoint(0, 0), GeoPoint(0, 0.002)],
    distanceMeters: 222,
    durationSeconds: 30,
    instructions: [
      RouteInstruction(
        type: RouteManeuverType.turn,
        modifier: 'left',
        text: 'Turn left',
        distanceMeters: 222,
        maneuverLocation: GeoPoint(0, 0.002),
      ),
    ],
  );
  test(
    'sparse polyline midpoint is on the route and has along-route remaining distance',
    () {
      final progress = const RouteProgressCalculator().measure(
        route: route,
        position: const GeoPoint(0, 0.001),
      );
      expect(progress.offRoute, isFalse);
      expect(progress.distanceFromRouteMeters, lessThan(1));
      expect(progress.remainingMeters, closeTo(111, 2));
    },
  );
  test(
    'route response after disposal never notifies a dead controller',
    () async {
      final repo = _Route();
      final navigation = NavigationController(routeRepository: repo);
      final request = navigation.ensureRoute(
        origin: const GeoPoint(0, 0),
        destination: const GeoPoint(0, 0.002),
      );
      navigation.dispose();
      repo.result.complete(route);
      await request;
    },
  );
  test('a near turn is still a turn, not pickup arrival', () async {
    final repo = _Route(),
        navigation = NavigationController(routeRepository: _Route());
    navigation.dispose();
    final active = NavigationController(routeRepository: repo);
    active.setVehicle(const DriverLocation(point: GeoPoint(0, 0.0018)));
    final request = active.ensureRoute(
      origin: const GeoPoint(0, 0.0018),
      destination: const GeoPoint(0, 0.002),
    );
    repo.result.complete(route);
    await request;
    expect(active.snapshot.banner!.symbol, NavigationBannerSymbol.left);
    active.dispose();
  });
  test('measurement age and accuracy are preserved as safety evidence', () {
    final now = DateTime(2026);
    expect(
      DriverLocation(
        point: const GeoPoint(59, 18),
        measuredAt: now.subtract(const Duration(minutes: 1)),
        accuracyMeters: 5,
      ).isUsableAt(now),
      isFalse,
    );
    expect(
      DriverLocation(
        point: const GeoPoint(59, 18),
        measuredAt: now,
        accuracyMeters: 100,
      ).isUsableAt(now),
      isFalse,
    );
    expect(
      DriverLocation(
        point: const GeoPoint(59, 18),
        measuredAt: now,
        accuracyMeters: 5,
      ).isUsableAt(now),
      isTrue,
    );
  });
}
