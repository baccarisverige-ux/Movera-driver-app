import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

/// Audit phase 6: what one minute of driving costs the trip's navigation.
/// A fix a second at 12 m/s along the route, and the trip screen asking
/// for the route on every fix (its worst case). Each route request is a
/// network call; each notification rebuilds the island and the map
/// overlays. Measured on this branch: 1 route request and 62 notifications
/// (one a fix, two for the route loading and landing).
const _origin = GeoPoint(59.3293, 18.0686);

GeoPoint _east(GeoPoint p, double m) =>
    GeoPoint(p.latitude, p.longitude + m / (111320 * 0.5094));

class _Routes implements RouteRepository {
  int calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    return RoadRoute(
      points: [for (var i = 0; i <= 40; i++) _east(_origin, i * 100.0)],
      distanceMeters: 4000,
      durationSeconds: 400,
    );
  }
}

/// On the route, the route is fetched once and refreshed silently every
/// 90 s: at most one more request in a minute.
const int routeRequestsPerMinute = 2;

/// One notification per fix (progress, banner), plus the route's own.
const int notificationsPerMinute = 60 + 4;

void main() {
  testWidgets('one minute of driving stays within its request budget', (
    tester,
  ) async {
    final routes = _Routes();
    final nav = NavigationController(routeRepository: routes);
    addTearDown(nav.dispose);
    var notified = 0;
    nav.addListener(() => notified++);
    final destination = _east(_origin, 4000);
    for (var second = 0; second < 60; second++) {
      final here = _east(_origin, second * 12.0);
      nav.setVehicle(
        DriverLocation(
          point: here,
          headingDegrees: 90,
          speedMetersPerSecond: 12,
          measuredAt: DateTime.now(),
          accuracyMeters: 5,
        ),
      );
      await nav.ensureRoute(origin: here, destination: destination);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(nav.snapshot.offRoute, isFalse);
    expect(routes.calls, lessThanOrEqualTo(routeRequestsPerMinute));
    expect(notified, lessThanOrEqualTo(notificationsPerMinute));
    expect(notified, greaterThan(0));
  });
}
