import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/moving_route_refresh.dart';
import 'package:movera/core/routing/route_repository.dart';

const _from = GeoPoint(59.33, 18.06);
GeoPoint _north(double m) =>
    GeoPoint(_from.latitude + m / 111320, _from.longitude);
GeoPoint _east(GeoPoint p, double m) =>
    GeoPoint(p.latitude, p.longitude + m / (111320 * 0.51));

void main() {
  final route = RoadRoute(
    points: [for (var i = 0; i <= 10; i++) _north(i * 200.0)],
    distanceMeters: 2000,
    durationSeconds: 240,
  );
  final t0 = DateTime.utc(2026, 10, 19, 8);

  test('driving along the route asks only every 90 s (D-02)', () {
    final refresh = MovingRouteRefresh();
    expect(refresh.due(position: _from, route: null, now: t0), isTrue);
    refresh.asked(_from, t0);
    var asks = 0;
    for (var s = 1; s <= 60; s++) {
      final at = t0.add(Duration(seconds: s));
      if (refresh.due(position: _north(s * 10.0), route: route, now: at)) {
        asks++;
        refresh.asked(_north(s * 10.0), at);
      }
    }
    expect(asks, 0);
    expect(
      refresh.due(
        position: _north(700),
        route: route,
        now: t0.add(const Duration(seconds: 90)),
      ),
      isTrue,
    );
  });

  test('leaving the route asks again once the car has moved', () {
    final refresh = MovingRouteRefresh()..asked(_from, t0);
    final off = _east(_north(100), 120);
    final at = t0.add(const Duration(seconds: 10));
    expect(refresh.due(position: off, route: route, now: at), isTrue);
    refresh.asked(off, at);
    // Parked off the road: the same spot never asks again before 90 s.
    for (var s = 11; s < 99; s++) {
      expect(
        refresh.due(
          position: off,
          route: route,
          now: t0.add(Duration(seconds: s)),
        ),
        isFalse,
      );
    }
  });

  test('without a route it retries every few seconds, not every fix', () {
    final refresh = MovingRouteRefresh()..asked(_from, t0);
    expect(
      refresh.due(
        position: _from,
        route: null,
        now: t0.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
    expect(
      refresh.due(
        position: _from,
        route: null,
        now: t0.add(const Duration(seconds: 8)),
      ),
      isTrue,
    );
    refresh.reset();
    expect(refresh.due(position: _from, route: route, now: t0), isTrue);
  });
}
