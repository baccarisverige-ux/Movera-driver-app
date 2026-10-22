import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One route-line look for every driver map (Home destination, direct offer
/// preview, trip to pickup/drop-off, reservation popup, destination-mode
/// arc and the scheduled-rides preview): one line, no outline, that runs
/// from the pickup green to the destination blue in their dark shades
/// (owner round 4: "same colours but darker, no white"). The bright shades
/// of the same hues ([lightAt]) are kept for the offer line's motion.
/// google_maps_flutter has no gradient polylines, so the line is drawn as
/// [gradientSteps] short pieces. It widens as the map zooms in, as before.
abstract final class DriverRouteStyle {
  /// The line at the pickup end: the Movera green, darkened.
  static const Color pickupColor = Color(0xFF05663F);

  /// The line at the destination end: the Movera blue, darkened.
  static const Color destinationColor = Color(0xFF0F4599);

  /// The bright green the dark line is made from (the offer motion's band).
  static const Color pickupLight = Color(0xFF079A60);

  /// The bright blue the dark line is made from (the offer motion's band).
  static const Color destinationLight = Color(0xFF1769E8);

  /// One colour for places that need a single one (half-way on the line).
  static final Color color = at(0.5);

  /// The route colour at [t] (0 = pickup, 1 = destination).
  static Color at(double t) =>
      Color.lerp(pickupColor, destinationColor, t.clamp(0, 1))!;

  /// The bright shade of the route colour at [t].
  static Color lightAt(double t) =>
      Color.lerp(pickupLight, destinationLight, t.clamp(0, 1))!;

  /// Number of coloured pieces the line is drawn with.
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

  /// Line width at [zoom]: 4 pt at overview / region (zoom <= 11), 6 at
  /// city (13), 7 at 14, 10 at street (16) and 12 from zoom 17: one pixel
  /// per step, so a zoom never makes the line jump. Polyline widths are
  /// whole pixels.
  static int widthAt(double zoom) {
    final step = stepZoom(zoom);
    if (step <= 11) return 4;
    if (step <= 15) return step.round() - 7;
    return (8 + (step - 15) * 2).round();
  }

  /// The id of piece [index] of the route [id]: the first piece keeps
  /// [id] itself, so lookups by the route's id still find the route.
  static String pieceId(String id, int index) =>
      index == 0 ? id : '$id-g$index';

  /// Whether [line] is a piece of some route drawn by this style.
  static bool isPiece(Polyline line) =>
      line.zIndex == 2 && gradientColors.contains(line.color);

  /// The pieces of one route. The first piece keeps [id] (see [pieceId]).
  static Set<Polyline> polylines({
    required String id,
    required List<LatLng> points,
    bool geodesic = false,
    double zoom = defaultZoom,
  }) => gradientPieces(
    id: id,
    points: points,
    width: widthAt(zoom),
    geodesic: geodesic,
  );

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

  /// [lines] with every route piece resized for [zoom]; other polylines
  /// pass through unchanged.
  static Set<Polyline> sized(Set<Polyline> lines, double zoom) => {
    for (final line in lines)
      isPiece(line) ? line.copyWith(widthParam: widthAt(zoom)) : line,
  };

  /// Draws [path] in the route-line look on a drawn (non-Google) map
  /// picture: a line [width] wide that runs from [pickupColor] at the
  /// path's start to [destinationColor] at its end, no outline.
  static void paintOn(Canvas canvas, Path path, {double width = 4}) {
    final metrics = path.computeMetrics().toList();
    Offset start = path.getBounds().centerLeft;
    Offset end = path.getBounds().centerRight;
    if (metrics.isNotEmpty) {
      start = metrics.first.getTangentForOffset(0)?.position ?? start;
      final last = metrics.last;
      end = last.getTangentForOffset(last.length)?.position ?? end;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: const [pickupColor, destinationColor],
        ).createShader(Rect.fromPoints(start, end)),
    );
  }
}
