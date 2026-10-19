import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One route-line look for every driver map (Home destination, direct offer
/// preview, trip to pickup/drop-off, reservation popup and full-screen map):
/// like Uber, a dark grey core with a thin black outline that grows a little
/// as the map zooms in.
abstract final class DriverRouteStyle {
  static const Color casingColor = Color(0xFF111518);
  static const Color color = Color(0xFF45494F);

  /// Zoom used before a map reports its camera (the middle step).
  static const double defaultZoom = 14;

  /// The step a camera zoom falls in, as that step's representative zoom:
  /// 10 (region, zoom < 11), 11 (city), 12 (part of a trip, zoom 12-12.9),
  /// 14 (zoom 13-15) or 16 (street, zoom >= 16). Maps keep this value and
  /// rebuild only when it changes.
  static double stepZoom(double zoom) => zoom < 11
      ? 10
      : zoom < 12
          ? 11
          : zoom < 13
              ? 12
              : zoom < 16
                  ? 14
                  : 16;

  /// Visible line width (the casing) at [zoom]; the core sits inside it.
  /// Polyline widths are whole logical pixels, so the 10.5 pt middle step
  /// rounds to 11.
  static int widthAt(double zoom) => zoom < 12 ? 9 : zoom < 16 ? 11 : 12;

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
