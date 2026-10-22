import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One route-line look for every driver map (Home destination, direct offer
/// preview, trip to pickup/drop-off, reservation popup and full-screen map):
/// the Movera route, a white casing under a line that runs from the pickup
/// green to the destination blue (owner round 4, the same look as the
/// Rider app). google_maps_flutter has no gradient polylines, so the core
/// is drawn as [gradientSteps] short pieces. The casing grows as the map
/// zooms in, as before.
abstract final class DriverRouteStyle {
  /// The line at the pickup end.
  static const Color pickupColor = Color(0xFF079A60);

  /// The line at the destination end.
  static const Color destinationColor = Color(0xFF1769E8);

  /// The casing around the core.
  static const Color casingColor = Color(0xFFFFFFFF);

  /// One colour for places that need a single one (half-way on the line).
  static const Color color = Color(0xFF0F82A4);

  /// The route colour at [t] (0 = pickup, 1 = destination).
  static Color at(double t) =>
      Color.lerp(pickupColor, destinationColor, t.clamp(0, 1))!;

  /// Number of coloured pieces the core is drawn with.
  static const int gradientSteps = 12;

  /// The colours of the [gradientSteps] pieces, pickup → destination.
  static final List<Color> gradientColors = List<Color>.unmodifiable([
    for (var s = 0; s < gradientSteps; s++) at((s + 0.5) / gradientSteps),
  ]);

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

  /// The id of core piece [index] of the route [id]: the first piece keeps
  /// [id] itself, so lookups by the route's id still find the route.
  static String pieceId(String id, int index) =>
      index == 0 ? id : '$id-g$index';

  /// Whether [line] is a core piece of some route drawn by this style.
  static bool isCorePiece(Polyline line) =>
      line.zIndex == 2 && gradientColors.contains(line.color);

  /// Whether [line] is a casing drawn by this style.
  static bool isCasing(Polyline line) =>
      line.polylineId.value.endsWith('-casing') && line.color == casingColor;

  /// The casing and core pieces for one route. The first core piece keeps
  /// [id] (see [pieceId]); the casing is `$id-casing`.
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
    ...gradientPieces(
      id: id,
      points: points,
      width: coreWidthAt(zoom),
      geodesic: geodesic,
    ),
  };

  /// [points] split by distance into [gradientSteps] pieces coloured from
  /// [pickupColor] to [destinationColor], [width] wide, on z 2. A route of
  /// fewer than two points, or of no length, is one piece in [color].
  static Set<Polyline> gradientPieces({
    required String id,
    required List<LatLng> points,
    required int width,
    bool geodesic = false,
  }) {
    Polyline piece(int index, List<LatLng> part, Color colour) => Polyline(
      polylineId: PolylineId(pieceId(id, index)),
      points: part,
      color: colour,
      width: width,
      geodesic: geodesic,
      zIndex: 2,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );
    if (points.length < 2) return {piece(0, points, color)};
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dLat = b.latitude - a.latitude;
      final dLng = b.longitude - a.longitude;
      cumulative.add(cumulative.last + math.sqrt(dLat * dLat + dLng * dLng));
    }
    final total = cumulative.last;
    if (total == 0) return {piece(0, points, color)};
    LatLng pointAt(double distance) {
      for (var i = 1; i < points.length; i++) {
        if (cumulative[i] >= distance) {
          final span = cumulative[i] - cumulative[i - 1];
          final f = span == 0 ? 0.0 : (distance - cumulative[i - 1]) / span;
          final a = points[i - 1];
          final b = points[i];
          return LatLng(
            a.latitude + (b.latitude - a.latitude) * f,
            a.longitude + (b.longitude - a.longitude) * f,
          );
        }
      }
      return points.last;
    }

    final pieces = <Polyline>{};
    for (var s = 0; s < gradientSteps; s++) {
      final start = total * s / gradientSteps;
      final end = total * (s + 1) / gradientSteps;
      final part = <LatLng>[pointAt(start)];
      for (var i = 1; i < points.length - 1; i++) {
        if (cumulative[i] > start && cumulative[i] < end) part.add(points[i]);
      }
      part.add(pointAt(end));
      pieces.add(piece(s, part, gradientColors[s]));
    }
    return pieces;
  }

  /// [lines] with every route casing and core piece resized for [zoom];
  /// other polylines pass through unchanged.
  static Set<Polyline> sized(Set<Polyline> lines, double zoom) => {
    for (final line in lines)
      isCasing(line)
          ? line.copyWith(widthParam: widthAt(zoom))
          : isCorePiece(line)
          ? line.copyWith(widthParam: coreWidthAt(zoom))
          : line,
  };

  /// Draws [path] in the route-line look on a drawn (non-Google) map
  /// picture: a [casingColor] outline [outline] wide on each side of a core
  /// [coreWidth] wide that runs from [pickupColor] at the path's start to
  /// [destinationColor] at its end.
  static void paintOn(
    Canvas canvas,
    Path path, {
    double coreWidth = 3.5,
    double outline = 1.25,
  }) {
    Paint line(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = path.computeMetrics().toList();
    Offset start = path.getBounds().centerLeft;
    Offset end = path.getBounds().centerRight;
    if (metrics.isNotEmpty) {
      start = metrics.first.getTangentForOffset(0)?.position ?? start;
      final last = metrics.last;
      end = last.getTangentForOffset(last.length)?.position ?? end;
    }
    canvas
      ..drawPath(path, line(coreWidth + outline * 2)..color = casingColor)
      ..drawPath(
        path,
        line(coreWidth)
          ..shader = LinearGradient(
            colors: const [pickupColor, destinationColor],
          ).createShader(Rect.fromPoints(start, end)),
      );
  }
}
