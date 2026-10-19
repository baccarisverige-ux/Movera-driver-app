import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One route-line look for every driver map (Home destination, direct offer
/// preview, trip to pickup/drop-off, reservation popup and full-screen map):
/// like the owner's reference navigation app, a purple core with a thin dark
/// purple outline (about 1.5 pt each side) that grows as the map zooms in.
abstract final class DriverRouteStyle {
  static const Color casingColor = Color(0xFF280E4B);
  static const Color color = Color(0xFF6419CF);

  /// Zoom used before a map reports its camera (a city step).
  static const double defaultZoom = 14;

  /// The step a camera zoom falls in, as that step's representative zoom:
  /// 10 (region, zoom < 11), then one step per whole zoom level 11-14
  /// (zoom 11-14.9), half levels 15, 15.5, 16, 16.5 close in, and 17
  /// (street, zoom >= 17). Maps keep this value and rebuild only when it
  /// changes, so the line widens one logical pixel per step.
  static double stepZoom(double zoom) {
    if (!zoom.isFinite || zoom < 11) return 10;
    if (zoom >= 17) return 17;
    if (zoom < 15) return zoom.floorToDouble();
    return (zoom * 2).floorToDouble() / 2;
  }

  /// Visible line width (the casing) at [zoom]; the core sits inside it.
  /// About 6 pt at overview / region (zoom <= 11), 8 at city (13), 9 at
  /// 14, 12 at street (16) and 14 from zoom 17: one pixel per step, so a
  /// zoom never makes the line jump. Polyline widths are whole pixels.
  static int widthAt(double zoom) {
    final step = stepZoom(zoom);
    if (step <= 11) return 6;
    if (step <= 15) return step.round() - 5;
    return (10 + (step - 15) * 2).round();
  }

  /// Core width at [zoom]: the casing minus a 1.5 pt outline on each side.
  static int coreWidthAt(double zoom) => widthAt(zoom) - 3;

  /// The casing and core polylines for one route. The core keeps [id], so
  /// lookups by polyline id still find the route; the casing is `$id-casing`.
  static Set<Polyline> polylines({
    required String id,
    required List<LatLng> points,
    bool geodesic = false,
    double zoom = defaultZoom,
  }) => {
    Polyline(
      polylineId: PolylineId('$id-casing'),
      points: points,
      color: casingColor,
      width: widthAt(zoom),
      geodesic: geodesic,
      zIndex: 1,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
    Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: coreWidthAt(zoom),
      geodesic: geodesic,
      zIndex: 2,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
  };

  /// [lines] with every route casing and core resized for [zoom]; other
  /// polylines pass through unchanged.
  static Set<Polyline> sized(Set<Polyline> lines, double zoom) => {
    for (final line in lines)
      line.polylineId.value.endsWith('-casing') && line.color == casingColor
          ? line.copyWith(widthParam: widthAt(zoom))
          : line.color == color
          ? line.copyWith(widthParam: coreWidthAt(zoom))
          : line,
  };

  /// Draws [path] in the route-line look on a drawn (non-Google) map
  /// picture: a [casingColor] outline [outline] wide on each side of a
  /// [color] core [coreWidth] wide.
  static void paintOn(
    Canvas canvas,
    Path path, {
    double coreWidth = 3.5,
    double outline = 1.25,
  }) {
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(path, line(casingColor, coreWidth + outline * 2))
      ..drawPath(path, line(color, coreWidth));
  }
}
