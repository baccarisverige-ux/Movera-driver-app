import 'dart:math' as math;

import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/geo/geo_point.dart';

/// Destination mode (R13-9): does a trip's drop-off take the driver toward
/// their destination? Two checks, then the admin focus:
///
/// * the drop-off is within the corridor (admin km) of the driver's ROAD
///   route to the destination; with no road route yet, of the straight
///   line from the driver to the destination;
/// * the drop-off is closer to the destination than the driver is now.
///
/// Focus "final destination" takes only drop-offs within the corridor km
/// of the destination itself, "on the way" the rest of the corridor, and
/// "both" either.
class DestinationFilter {
  const DestinationFilter._();

  /// Near the destination when no corridor km is set.
  static const double defaultNearKm = 5;

  static bool follows({
    required GeoPoint driver,
    required GeoPoint destination,
    required GeoPoint dropoff,
    List<GeoPoint> route = const <GeoPoint>[],
    DestinationModeRules? rules,
  }) {
    final r = rules ?? DestinationModeRules.current;
    final focus = r.focus;
    if (focus == DestinationFocus.none) {
      return false;
    }

    final left = dropoff.distanceMetersTo(destination);
    if (left >= driver.distanceMetersTo(destination)) {
      return false;
    }

    final km = r.corridorOn ? r.corridorKm : defaultNearKm;
    final nearFinal = left <= km * 1000;
    final path = route.length >= 2 ? route : <GeoPoint>[driver, destination];
    final inCorridor =
        !r.corridorOn || distanceToPathMeters(dropoff, path) <= km * 1000;

    return switch (focus) {
      DestinationFocus.finalDestination => nearFinal,
      DestinationFocus.onTheWay => inCorridor && !nearFinal,
      DestinationFocus.both => nearFinal || inCorridor,
      DestinationFocus.none => false,
    };
  }

  /// Shortest distance from [point] to the polyline [path], in metres.
  static double distanceToPathMeters(GeoPoint point, List<GeoPoint> path) {
    if (path.isEmpty) {
      return double.infinity;
    }
    if (path.length == 1) {
      return point.distanceMetersTo(path.first);
    }
    // Flat metres around [point]: fine at corridor scale (a few km).
    const metresPerDegree = 111320.0;
    final scale = math.cos(point.latitude * math.pi / 180);
    (double, double) flat(GeoPoint p) => (
      (p.longitude - point.longitude) * scale * metresPerDegree,
      (p.latitude - point.latitude) * metresPerDegree,
    );
    var best = double.infinity;
    var (ax, ay) = flat(path.first);
    for (var i = 1; i < path.length; i++) {
      final (bx, by) = flat(path[i]);
      final dx = bx - ax, dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final px = ax + t * dx, py = ay + t * dy;
      best = math.min(best, math.sqrt(px * px + py * py));
      ax = bx;
      ay = by;
    }
    return best;
  }
}
