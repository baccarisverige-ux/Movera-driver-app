import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/navigation/route_camera_geometry.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/widgets/route_mark_pins.dart';

/// D-07/D-08: the trip map's route lines, the part already driven and the
/// rest. Only the map listens, so a GPS fix redraws the lines without the
/// whole trip screen; the same route, progress and zoom keep the same set,
/// so the map is not sent lines that did not change.
class TripRouteLines extends ValueNotifier<Set<Polyline>> {
  TripRouteLines() : super(const <Polyline>{});

  List<GeoPoint>? _points;
  RouteCameraGeometry? _geometry;
  int? _alongMeter;
  double? _zoom;

  /// [points]: the road route (none: no lines). [alongMeters]: how far the
  /// car is along it. [zoom]: the map's line-width step.
  void sync(List<GeoPoint> points, double alongMeters, double zoom) {
    if (points.length < 2) {
      _points = points;
      _geometry = null;
      if (value.isNotEmpty) value = const <Polyline>{};
      return;
    }
    final meter = alongMeters.round();
    if (identical(points, _points) && meter == _alongMeter && zoom == _zoom) {
      return;
    }
    if (!identical(points, _points) || _geometry == null) {
      _points = points;
      _geometry = RouteCameraGeometry(points);
    }
    _alongMeter = meter;
    _zoom = zoom;
    final geometry = _geometry!;
    value = {
      if (alongMeters > 0)
        Polyline(
          polylineId: const PolylineId('traveled-road-route'),
          points: geometry.traveled(alongMeters).map((p) => p.toLatLng()).toList(),
          width: 3,
          color: RouteMarkPins.ink.withValues(alpha: .18),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      ...DriverRouteStyle.polylines(
        id: 'active-road-route',
        points: geometry.remaining(alongMeters).map((p) => p.toLatLng()).toList(),
        zoom: zoom,
      ),
    };
  }
}
