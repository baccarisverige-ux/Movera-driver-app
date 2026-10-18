import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

/// Parses an OSRM `route` object into Movera domain models.
///
/// Presentation never sees provider JSON. A future backend adapter can
/// return [RoadRoute] without this parser.
class OsrmRouteParser {
  const OsrmRouteParser();

  RoadRoute parseRoute(Map<String, dynamic> route) {
    final geometry = route['geometry'];
    if (geometry is! Map<String, dynamic>) {
      throw const FormatException('Invalid route geometry.');
    }

    final coordinatesJson = geometry['coordinates'];
    if (coordinatesJson is! List || coordinatesJson.length < 2) {
      throw const FormatException('Route geometry is empty.');
    }

    final points = <GeoPoint>[];
    for (final coordinate in coordinatesJson) {
      if (coordinate is! List || coordinate.length < 2) {
        throw const FormatException('Malformed route coordinates.');
      }
      final longitude = coordinate[0];
      final latitude = coordinate[1];
      if (longitude is! num ||
          latitude is! num ||
          !longitude.isFinite ||
          !latitude.isFinite ||
          longitude.abs() > 180 ||
          latitude.abs() > 90) {
        // Dropping one waypoint could draw an artificial shortcut through
        // unsafe roads. Invalidate the whole route and use the Retry UI.
        throw const FormatException('Invalid route coordinates.');
      }
      points.add(GeoPoint(latitude.toDouble(), longitude.toDouble()));
    }

    if (points.length < 2) {
      throw const FormatException('Route geometry is empty.');
    }

    final distance = route['distance'];
    final duration = route['duration'];
    // Provider corruption must not produce negative/NaN ETA or progress.
    if (distance is! num || !distance.isFinite || distance < 0) {
      throw const FormatException('Invalid route distance.');
    }
    if (duration is! num || !duration.isFinite || duration < 0) {
      throw const FormatException('Invalid route duration.');
    }

    return RoadRoute(
      points: points,
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      instructions: parseInstructions(route),
    );
  }

  List<RouteInstruction> parseInstructions(Map<String, dynamic> route) {
    final legs = route['legs'];
    if (legs is! List) {
      return const <RouteInstruction>[];
    }

    final instructions = <RouteInstruction>[];
    for (final leg in legs) {
      if (leg is! Map<String, dynamic>) {
        continue;
      }
      final steps = leg['steps'];
      if (steps is! List) {
        continue;
      }
      for (var index = 0; index < steps.length; index++) {
        final step = steps[index];
        if (step is! Map<String, dynamic>) {
          continue;
        }
        final parsed = _parseStep(
          step,
          exitAngleDegrees: _exitAngle(steps, index),
        );
        if (parsed != null) {
          instructions.add(parsed);
        }
      }
    }
    return instructions;
  }

  // Entry bearing_after is the tangent onto the circle, not the exit.
  // Pair it with an explicit exit maneuver before drawing an outgoing arrow.
  double? _exitAngle(List<dynamic> steps, int index) {
    final step = steps[index];
    if (step is! Map<String, dynamic>) {
      return null;
    }
    final entry = step['maneuver'];
    if (entry is! Map<String, dynamic>) {
      return null;
    }
    final type = entry['type'];
    if (type != 'roundabout' && type != 'rotary' && type != 'roundabout turn') {
      return null;
    }
    double? bearing(dynamic value) =>
        value is num && value.isFinite && value >= 0 && value <= 360
        ? value.toDouble() % 360
        : null;
    final before = bearing(entry['bearing_before']);
    if (before == null) {
      return null;
    }
    double? after;
    if (type == 'roundabout turn') {
      after = bearing(entry['bearing_after']);
    } else {
      for (var next = index + 1; next < steps.length; next++) {
        final candidate = steps[next];
        if (candidate is! Map<String, dynamic>) {
          break;
        }
        final exit = candidate['maneuver'];
        if (exit is! Map<String, dynamic>) {
          break;
        }
        if (exit['type'] == 'exit roundabout' ||
            exit['type'] == 'exit rotary') {
          after = bearing(exit['bearing_after']);
          break;
        }
        if (exit['type'] != 'continue' &&
            exit['type'] != 'notification' &&
            exit['type'] != 'new name') {
          break;
        }
      }
    }
    return after == null ? null : (after - before + 540) % 360 - 180;
  }

  RouteInstruction? _parseStep(
    Map<String, dynamic> step, {
    double? exitAngleDegrees,
  }) {
    final maneuver = step['maneuver'];
    if (maneuver is! Map<String, dynamic>) {
      return null;
    }

    final location = maneuver['location'];
    if (location is! List || location.length < 2) {
      return null;
    }
    final longitude = location[0];
    final latitude = location[1];
    if (longitude is! num ||
        latitude is! num ||
        !longitude.isFinite ||
        !latitude.isFinite ||
        longitude.abs() > 180 ||
        latitude.abs() > 90) {
      return null;
    }

    final type = RouteManeuverTypeX.fromOsrm(
      maneuver['type'] is String ? maneuver['type'] as String : null,
    );
    final modifier = maneuver['modifier'] is String
        ? maneuver['modifier'] as String
        : '';
    final roadName = step['name'] is String ? step['name'] as String : null;
    final exit = maneuver['exit'];
    final int? parsedExit = exit is int
        ? exit
        : exit is String
            ? int.tryParse(exit)
            : exit is num && exit.isFinite && exit == exit.truncateToDouble()
                ? exit.toInt()
                : null;
    final exitNumber = parsedExit != null && parsedExit > 0
        ? parsedExit.toString()
        : null;
    final distance = step['distance'];
    String? text(String key) {
      final value = step[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    // The first intersection is the maneuver itself: its lanes are the
    // lanes leading into it. Classes anywhere on the step describe the
    // road after the maneuver (toll, tunnel, motorway).
    final intersections = step['intersections'];
    final lanes = <RouteLane>[];
    final classes = <String>{};
    if (intersections is List) {
      for (var i = 0; i < intersections.length; i++) {
        final crossing = intersections[i];
        if (crossing is! Map<String, dynamic>) continue;
        final named = crossing['classes'];
        if (named is List) classes.addAll(named.whereType<String>());
        final rawLanes = crossing['lanes'];
        if (i == 0 && rawLanes is List) {
          for (final lane in rawLanes) {
            if (lane is! Map<String, dynamic>) continue;
            final indications = lane['indications'];
            lanes.add(
              RouteLane(
                indications: indications is List
                    ? indications.whereType<String>().toList()
                    : const <String>[],
                valid: lane['valid'] == true,
              ),
            );
          }
        }
      }
    }
    final roadRef = text('ref');
    final destinations = text('destinations');
    final drivingSide = text('driving_side') == 'left' ? 'left' : 'right';

    return RouteInstruction(
      type: type,
      modifier: modifier,
      text: RouteInstructionCopy.build(
        type: type,
        modifier: modifier,
        roadName: roadName,
        exitNumber: exitNumber,
      ),
      distanceMeters: distance is num && distance.isFinite && distance >= 0
          ? distance.toDouble()
          : 0,
      maneuverLocation: GeoPoint(latitude.toDouble(), longitude.toDouble()),
      roadName: roadName?.trim().isEmpty == true ? null : roadName,
      exitNumber: exitNumber,
      exitAngleDegrees: exitAngleDegrees,
      roadRef: roadRef,
      destinations: destinations,
      exitRef: text('exits')?.split(';').first.trim(),
      lanes: lanes,
      drivingSide: drivingSide,
      highway:
          classes.contains('motorway') ||
          type == RouteManeuverType.onRamp ||
          type == RouteManeuverType.offRamp ||
          RoadShield.parse(
            RoadShield.splitDestinations(destinations).$1 ?? roadRef,
          ).isNotEmpty,
      toll: classes.contains('toll'),
      tunnel: classes.contains('tunnel'),
    );
  }
}
