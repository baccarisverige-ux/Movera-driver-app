// ignore_for_file: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';

// v0.18.171 (plan section 4.4): a moving car that stays off route asked
// GET /routes/driving every ~2 s. Once the pill is quiet (#709: 2 answers,
// or 15 s), one more prompt re-route, then 10 s, 20, 40, up to 60 s. Back
// on the line, or leaving a parked spot, resets it.

const _north = 1 / 111195.0, _east = 1 / 57270.0;
GeoPoint _at(double n, double e) => GeoPoint(59 + n * _north, 18 + e * _east);
final _dest = _at(30000, 0);
const _recalculating = 'Recalculating route…';
final _start = DateTime.now();

class _Routes implements RouteRepository {
  _Routes(this.elapsed, {this.source});
  final Duration Function() elapsed;
  final String? source;
  final asked = <Duration>[];
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    asked.add(elapsed());
    return RoadRoute(
      points: [_at(0, 0), _dest],
      distanceMeters: 30000,
      durationSeconds: 1800,
      source: source,
      approximate: source == 'estimate',
    );
  }
}

void _run(
  void Function(FakeAsync async, NavigationController nav, _Routes routes)
  body, {
  String? source,
}) {
  fakeAsync((async) {
    final start = _start;
    DateTime now() => start.add(async.elapsed);
    final routes = _Routes(() => async.elapsed, source: source);
    final nav = NavigationController(routeRepository: routes, now: now);
    nav.setStage(ActiveRideStage.onTrip);
    nav.setVehicle(DriverLocation(point: _at(0, 0)));
    nav.ensureRoute(origin: _at(0, 0), destination: _dest);
    async.flushMicrotasks();
    body(async, nav, routes);
    nav.dispose();
    async.flushTimers();
  });
}

/// Fixes carry no measuredAt: the controller checks freshness against the
/// wall clock, which fake time does not move.
/// One fix every 2 s on a parallel road 120 m east of the answered line.
void _driveOff(
  FakeAsync async,
  NavigationController nav,
  int fixes, {
  int from = 1,
  void Function()? each,
}) {
  for (var i = from; i < from + fixes; i++) {
    nav.setVehicle(DriverLocation(point: _at(i * 50.0, 120)));
    async.elapse(const Duration(seconds: 2));
    each?.call();
  }
}

List<int> _gaps(List<Duration> asked) => [
  for (var i = 1; i < asked.length; i++)
    (asked[i] - asked[i - 1]).inMilliseconds,
];

void main() {
  test('moving off route: one prompt, then 10, 20, 40, 60 s once quiet', () {
    _run((async, nav, routes) {
      final seen = <String?>[];
      _driveOff(async, nav, 150, each: () => seen.add(nav.status));
      expect(seen, contains(_recalculating)); // #709: it shows at first
      expect(nav.status, isNull); // #709: and goes quiet
      // asked[0] is the first route, [1] and [2] the loud re-routes.
      final quiet = _gaps(routes.asked.sublist(2));
      expect(quiet.length, greaterThanOrEqualTo(6));
      const want = [2000, 10000, 20000, 40000, 60000, 60000];
      for (var i = 0; i < want.length; i++) {
        expect(
          quiet[i],
          inInclusiveRange(want[i], want[i] + 2500),
          reason: 'gap $i: $quiet',
        );
      }
      // Never faster than once a minute after that.
      for (final gap in quiet.skip(5)) {
        expect(gap, greaterThanOrEqualTo(60000));
      }
    });
  });

  test('back on the line resets the backoff', () {
    _run((async, nav, routes) {
      _driveOff(async, nav, 40); // into the 40 s step
      for (var i = 0; i < 3; i++) {
        nav.setVehicle(DriverLocation(point: _at(2100.0 + i * 50, 0)));
        async.elapse(const Duration(seconds: 2));
      }
      final before = routes.asked.length;
      final leftAt = async.elapsed;
      _driveOff(async, nav, 4, from: 45);
      // Off again: the quick 2 s re-route, not the long wait.
      expect(routes.asked.length, greaterThan(before));
      expect(
        routes.asked[before] - leftAt,
        lessThanOrEqualTo(const Duration(seconds: 5)),
      );
    });
  });

  test('an estimate answer is not a failed re-route', () {
    _run((async, nav, routes) {
      _driveOff(async, nav, 30);
      expect(nav.route, isNotNull);
      expect(nav.route!.approximate, isTrue);
      expect(nav.routeState, RouteLoadState.ready);
      expect(nav.status, isNot(NavigationRouteStatus.unavailableRetry.text));
      expect(nav.reroutes, 0); // not "Route updated"
      // The quiet backoff holds for estimate answers too.
      final quiet = _gaps(routes.asked.sublist(3));
      expect(quiet.first, greaterThanOrEqualTo(10000));
    }, source: 'estimate');
  });
}
