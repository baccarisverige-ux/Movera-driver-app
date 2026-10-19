import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/routing/route_repository.dart';

/// When a map that draws a road route from the car should ask for a new one.
///
/// Driving along the route never asks: only leaving it (after moving
/// [minMoveMeters] from where the last one was asked), a slow [interval]
/// refresh for the time to arrival, or a retry when there is no route.
class MovingRouteRefresh {
  MovingRouteRefresh({
    this.interval = const Duration(seconds: 90),
    this.retryAfter = const Duration(seconds: 8),
    this.minMoveMeters = 20,
    double offRouteMeters = 50,
  }) : _progress = RouteProgressCalculator(
         offRouteThresholdMeters: offRouteMeters,
       );

  final Duration interval;
  final Duration retryAfter;
  final double minMoveMeters;
  final RouteProgressCalculator _progress;

  DateTime? _askedAt;
  GeoPoint? _askedFrom;

  void reset() {
    _askedAt = null;
    _askedFrom = null;
  }

  /// A route was just asked for from [from].
  void asked(GeoPoint from, DateTime at) {
    _askedAt = at;
    _askedFrom = from;
  }

  bool due({
    required GeoPoint position,
    required RoadRoute? route,
    required DateTime now,
  }) {
    final at = _askedAt;
    if (at == null) return true;
    final since = now.difference(at);
    if (since >= interval) return true;
    if (since < retryAfter) return false;
    if (route == null || route.points.length < 2) return true;
    final from = _askedFrom;
    if (from != null && position.distanceMetersTo(from) < minMoveMeters) {
      return false;
    }
    return _progress.measure(route: route, position: position).offRoute;
  }
}
