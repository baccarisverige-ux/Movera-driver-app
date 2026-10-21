import 'dart:math' as math;

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

class RouteProgress {
  const RouteProgress({
    required this.closestIndex,
    required this.distanceFromRouteMeters,
    required this.remainingMeters,
    required this.instructionIndex,
    required this.nextInstruction,
    required this.distanceToManeuverMeters,
    required this.offRoute,
    this.alongMeters = 0,
  });

  final int closestIndex;
  final double distanceFromRouteMeters;
  final double remainingMeters;
  final int instructionIndex;
  final RouteInstruction? nextInstruction;
  final double distanceToManeuverMeters;
  final bool offRoute;

  /// Distance travelled along the route polyline. Feed it back as
  /// `previousAlongMeters` so progress stays monotonic on loops and hairpins.
  final double alongMeters;
}

class RouteProgressCalculator {
  const RouteProgressCalculator({
    this.offRouteThresholdMeters = 50,
    this.passedManeuverMeters = 4,
    this.backwardWindowMeters = 60,
    this.forwardWindowMeters = 400,
    this.maxSkipMeters = 150,
  });

  final double offRouteThresholdMeters;

  /// A maneuver counts as passed once the vehicle is this far beyond it.
  final double passedManeuverMeters;

  /// Search window around the previous progress. Matches outside it are only
  /// used when nothing inside it is on the road (rejoin, tunnel, reroute).
  final double backwardWindowMeters;
  final double forwardWindowMeters;

  /// driver-u29: inside the window, a match this far ahead that also skips
  /// a maneuver is taken only when the car is no longer on the road it was
  /// following. One GPS sample that drifts toward a later leg (around the
  /// block, the other carriageway) must not jump past the turns between.
  final double maxSkipMeters;

  static final Expando<_RouteGeometry> _geometry = Expando<_RouteGeometry>();

  RouteProgress measure({
    required RoadRoute route,
    required GeoPoint position,
    int instructionHint = 0,
    double? previousAlongMeters,
  }) {
    final points = route.geoPoints;
    if (points.length < 2) {
      return RouteProgress(
        closestIndex: 0,
        distanceFromRouteMeters: 0,
        remainingMeters: route.distanceMeters,
        instructionIndex: 0,
        nextInstruction: route.instructions.isEmpty
            ? null
            : route.instructions.first,
        distanceToManeuverMeters: route.instructions.isEmpty
            ? route.distanceMeters
            : route.instructions.first.distanceMeters,
        offRoute: false,
      );
    }

    final geometry = _geometry[route] ??= _RouteGeometry.of(route);
    // A corrupt persisted progress value must never poison route projection.
    final safePreviousAlong =
        previousAlongMeters != null &&
            previousAlongMeters.isFinite &&
            previousAlongMeters >= 0
        ? previousAlongMeters
        : null;
    var projection = safePreviousAlong == null
        ? null
        : geometry.project(
            position,
            fromAlong: safePreviousAlong - backwardWindowMeters,
            toAlong: safePreviousAlong + forwardWindowMeters,
            preferAlong: safePreviousAlong,
          );
    if (projection != null &&
        safePreviousAlong != null &&
        projection.distance <= offRouteThresholdMeters &&
        projection.along - safePreviousAlong > maxSkipMeters &&
        geometry.maneuverBetween(
          safePreviousAlong + passedManeuverMeters,
          projection.along,
        )) {
      final near = geometry.project(
        position,
        fromAlong: safePreviousAlong - backwardWindowMeters,
        toAlong: safePreviousAlong + maxSkipMeters,
        preferAlong: safePreviousAlong,
      );
      if (near.distance <= offRouteThresholdMeters) projection = near;
    }
    if (projection == null || projection.distance > offRouteThresholdMeters) {
      final global = geometry.project(position);
      if (projection == null || global.distance < projection.distance) {
        projection = global;
      }
    }
    final remaining = geometry.total - projection.along;
    final offRoute = projection.distance > offRouteThresholdMeters;

    var instructionIndex = instructionHint
        .clamp(0, math.max(0, route.instructions.length - 1))
        .toInt();
    // driver-u29: the hint only saves work. When the car is behind it
    // (a drifting fix moved it on, then the car projected back), step back
    // to the first maneuver not yet passed so no turn is skipped.
    while (instructionIndex > 0 &&
        projection.along <=
            geometry.maneuverAlong[instructionIndex - 1] +
                passedManeuverMeters) {
      instructionIndex--;
    }
    while (instructionIndex < route.instructions.length) {
      final instruction = route.instructions[instructionIndex];
      final maneuverAlong = geometry.maneuverAlong[instructionIndex];
      final toManeuver = math.max(0.0, maneuverAlong - projection.along);
      final passed = projection.along > maneuverAlong + passedManeuverMeters;
      if (!passed || instruction.isArrival) {
        return RouteProgress(
          closestIndex: projection.index,
          distanceFromRouteMeters: projection.distance,
          remainingMeters: remaining,
          instructionIndex: instructionIndex,
          nextInstruction: instruction.copyWith(distanceMeters: toManeuver),
          distanceToManeuverMeters: toManeuver,
          offRoute: offRoute,
          alongMeters: projection.along,
        );
      }
      instructionIndex++;
    }

    final last = route.instructions.isEmpty ? null : route.instructions.last;
    final toLast = last == null
        ? remaining
        : math.max(0.0, geometry.maneuverAlong.last - projection.along);

    return RouteProgress(
      closestIndex: projection.index,
      distanceFromRouteMeters: projection.distance,
      remainingMeters: remaining,
      instructionIndex: math.max(0, route.instructions.length - 1),
      nextInstruction: last?.copyWith(distanceMeters: toLast) ?? last,
      distanceToManeuverMeters: toLast,
      offRoute: offRoute,
      alongMeters: projection.along,
    );
  }
}

const double _tieMeters = 10;

/// Forward movement is cheap; moving backwards beyond GPS jitter is costly.
double _progressCost(double along, double preferAlong) =>
    along >= preferAlong - 5
    ? along - preferAlong
    : 1000 + (preferAlong - along);

typedef _Projection = ({int index, double distance, double along});

/// Per-route data computed once: cumulative segment lengths and the along-route
/// position of each maneuver, resolved in order so repeated road sections on a
/// loop map to the correct pass.
class _RouteGeometry {
  _RouteGeometry._(this.points, this.cumulative, this.total);

  final List<GeoPoint> points;
  final List<double> cumulative;
  final double total;
  late final List<double> maneuverAlong;

  static _RouteGeometry of(RoadRoute route) {
    final points = route.geoPoints;
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] =
          cumulative[i - 1] + points[i - 1].distanceMetersTo(points[i]);
    }
    final geometry = _RouteGeometry._(points, cumulative, cumulative.last);
    var from = 0.0;
    geometry.maneuverAlong = [
      for (final instruction in route.instructions)
        from = geometry
            .project(instruction.maneuverLocation, fromAlong: from)
            .along,
    ];
    return geometry;
  }

  /// Whether a maneuver lies in (from, to] along the route.
  bool maneuverBetween(double from, double to) =>
      maneuverAlong.any((along) => along > from && along <= to);

  _Projection project(
    GeoPoint position, {
    double fromAlong = double.negativeInfinity,
    double toAlong = double.infinity,
    double? preferAlong,
  }) {
    var bestDistance = double.infinity, along = 0.0;
    var index = 0;
    final scale = math.cos(position.latitude * math.pi / 180);
    for (var i = 0; i < points.length - 1; i++) {
      if (cumulative[i + 1] < fromAlong) {
        continue;
      }
      if (cumulative[i] > toAlong) {
        break;
      }
      final a = points[i], b = points[i + 1];
      final dx = (b.longitude - a.longitude) * scale;
      final dy = b.latitude - a.latitude;
      final px = (position.longitude - a.longitude) * scale;
      final py = position.latitude - a.latitude;
      final length2 = dx * dx + dy * dy;
      final t = length2 == 0
          ? 0.0
          : ((px * dx + py * dy) / length2).clamp(0.0, 1.0);
      final projected = GeoPoint(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final distance = position.distanceMetersTo(projected);
      final candidateAlong =
          cumulative[i] + (cumulative[i + 1] - cumulative[i]) * t;
      // Where two passes of the same road are equally close (U-turn, loop),
      // keep the one that continues forward from the previous progress.
      final tie =
          preferAlong != null && (distance - bestDistance).abs() <= _tieMeters;
      if (tie
          ? _progressCost(candidateAlong, preferAlong) <
                _progressCost(along, preferAlong)
          : distance < bestDistance) {
        bestDistance = tie ? math.min(bestDistance, distance) : distance;
        along = candidateAlong;
        index = i;
      }
    }
    return (index: index, distance: bestDistance, along: along);
  }
}
