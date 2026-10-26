import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/routing/route_repository.dart';

/// Maps-SDK view of a [RoadRoute]. Domain code uses [RoadRoute.points].
extension RoadRouteMaps on RoadRoute {
  List<LatLng> get latLngPoints => [
    for (final point in points) point.toLatLng(),
  ];
}
