import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';

// TestFlight FR 2026-11-27 21:28 ("Recalcule de l'itinéraire reste bloqué"):
// prod logs show /api/v1/routes/driving answering 200 every 2-20 s while
// the pill stayed. Each re-route answer left the car still off route.

const _north = 1 / 111195.0, _east = 1 / 57270.0;
GeoPoint _at(double n, double e) => GeoPoint(59 + n * _north, 18 + e * _east);
final _dest = _at(3000, 0);
const _recalculating = 'Recalculating route…';

class _Routes implements RouteRepository {
  _Routes(this.answer);
  Future<RoadRoute> Function() answer;
  int requests = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    requests++;
    return answer();
  }
}

// The router always answers with the road along east = 0.
RoadRoute _road() => RoadRoute(
  points: [_at(0, 0), _dest],
  distanceMeters: 3000,
  durationSeconds: 300,
);

Future<NavigationController> _onboard(_Routes routes) async {
  final nav = NavigationController(routeRepository: routes);
  nav.setStage(ActiveRideStage.onTrip);
  nav.setVehicle(DriverLocation(point: _at(0, 0), measuredAt: DateTime.now()));
  await nav.ensureRoute(origin: _at(0, 0), destination: _dest);
  return nav;
}

/// The car drives north on a parallel road 120 m east of the answered line.
Future<void> _drive(
  NavigationController nav,
  int fixes,
  void Function() each,
) async {
  for (var i = 1; i <= fixes; i++) {
    nav.setVehicle(
      DriverLocation(
        point: _at(i * 60.0, 120),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    each();
  }
}

void main() {
  test(
    're-route answers still off route: the pill goes, re-routing goes on',
    () async {
      final routes = _Routes(() async => _road());
      final nav = await _onboard(routes);
      addTearDown(nav.dispose);
      final seen = <String?>[];
      await _drive(nav, 8, () => seen.add(nav.status));
      expect(seen, contains(_recalculating)); // it does show at first
      expect(nav.status, isNull); // ...but does not stay
      expect(nav.route, isNotNull); // the new line is kept
      expect(routes.requests, greaterThan(3)); // quiet re-routing goes on
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('a re-route that never answers times out and frees the lane', () async {
    var hang = false;
    final routes = _Routes(
      () => hang ? Completer<RoadRoute>().future : Future.value(_road()),
    );
    final nav = await _onboard(routes);
    addTearDown(nav.dispose);
    hang = true;
    await _drive(nav, 7, () {});
    expect(routes.requests, 2);
    expect(nav.routeState, RouteLoadState.failed);
    expect(nav.status, isNot(_recalculating));
    // The lane is free again: a retry asks for a new route.
    hang = false;
    await nav.retryRoute();
    expect(routes.requests, 3);
    expect(nav.routeState, RouteLoadState.ready);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('back on route resets: the pill can show again next time', () async {
    final routes = _Routes(() async => _road());
    final nav = await _onboard(routes);
    addTearDown(nav.dispose);
    await _drive(nav, 6, () {});
    expect(nav.status, isNull);
    // Back on the answered line, then off it again.
    nav.setVehicle(
      DriverLocation(
        point: _at(420, 0),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    nav.setVehicle(
      DriverLocation(
        point: _at(480, 0),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    expect(nav.status, isNull);
    nav.setVehicle(
      DriverLocation(
        point: _at(540, 80),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    nav.setVehicle(
      DriverLocation(
        point: _at(600, 120),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    expect(nav.status, _recalculating);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
