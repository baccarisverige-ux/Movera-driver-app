import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_instruction.dart';

class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.instructions = const <RouteInstruction>[],
    this.source,
    this.approximate = false,
  });

  /// Domain polyline. Presentation converts via `RoadRouteMaps.latLngPoints`.
  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteInstruction> instructions;

  /// v0.18.171 (contract.json#googleRoadLines): where GET /routes/driving
  /// took the line from: "google", "stored" or "estimate". Null from an
  /// older server or another router.
  final String? source;

  /// The line is the server's straight estimate (source "estimate"), not a
  /// road line. Drawn dashed in Movera grey; never a failed re-route.
  final bool approximate;

  List<GeoPoint> get geoPoints => points;
}

abstract interface class RouteRepository {
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  });
}
