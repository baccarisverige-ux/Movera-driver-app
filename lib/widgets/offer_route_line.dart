import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/route_camera_fit.dart';

/// Where the offer line's animation is at one moment of its cycle.
@immutable
class OfferLinePhase {
  const OfferLinePhase({required this.light, required this.front});

  /// The white core's opacity, 0 (all black) to 1.
  final double light;

  /// How far the black core has filled back in from the pickup, 0 to 1
  /// of the route's length.
  final double front;

  /// Nothing white is shown: the line is plain black.
  bool get dark => light <= 0.01 || front >= 1;

  @override
  bool operator ==(Object other) =>
      other is OfferLinePhase && other.light == light && other.front == front;

  @override
  int get hashCode => Object.hash(light, front);

  @override
  String toString() => 'OfferLinePhase(light: $light, front: $front)';
}

/// R14-2: the offer route line on Home (Reservation, Exclusive and Radar),
/// "Black & white": a black outline at all times around a core that turns
/// white along the whole line, then fills back in black from the pickup to
/// the drop-off like a progress bar, with a soft edge, rests, and repeats.
///
/// Cycle 3.6 s: 0–0.25 s the core fades to white; 0.35–2.35 s the black
/// front runs pickup → drop-off (ease-in-out cubic), its edge fading over
/// [soft] of the route; 2.35–3.6 s the line rests all black.
abstract final class OfferRouteLine {
  static const Color outlineColor = Color(0xFF000000);
  static const Color coreColor = Color(0xFF141414);
  static const Color lightColor = Color(0xFFFFFFFF);

  static const Duration cycle = Duration(milliseconds: 3600);

  /// The soft edge's length, as a share of the route.
  static const double soft = 0.10;

  /// The soft edge drawn as this many short lines of rising opacity.
  static const int softSteps = 6;

  /// Polyline ids: the core keeps the offer route's id, so lookups by it
  /// still find the route.
  static const String coreId = 'direct_offer_road_route';
  static const String outlineId = '$coreId-outline';
  static const String lightId = 'offer_route_light';

  /// Outline width at a [DriverRouteStyle.stepZoom] step (R15-8): the same
  /// 8 on every offer, however far the map zooms out to fit the trip; 11
  /// only close up.
  static int outlineWidthAt(double zoom) => zoom < 16 ? 8 : 11;

  /// Core width inside the outline (about half of it).
  static int coreWidthAt(double zoom) => zoom < 16 ? 4 : 6;

  static double _ease(double t) => t < 0.5
      ? 4 * t * t * t
      : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;

  /// The animation's phase [elapsed] into the repeating cycle.
  static OfferLinePhase phaseAt(Duration elapsed) {
    final k = (elapsed.inMicroseconds % cycle.inMicroseconds) / 1e6;
    if (k >= 2.35) { return const OfferLinePhase(light: 0, front: 1); }
    final light = k < 0.25 ? _ease(k / 0.25) : 1.0;
    final front = k < 0.35 ? 0.0 : _ease(((k - 0.35) / 2.0).clamp(0.0, 1.0));
    return OfferLinePhase(light: light, front: front);
  }

  static Polyline _line(
    String id,
    List<LatLng> points,
    Color color,
    int width,
    int z, {
    Cap startCap = Cap.roundCap,
    Cap endCap = Cap.roundCap,
  }) => Polyline(
    polylineId: PolylineId(id),
    points: points,
    color: color,
    width: width,
    zIndex: z,
    jointType: JointType.round,
    startCap: startCap,
    endCap: endCap,
  );

  /// The still line: the black outline and the black core. With reduced
  /// motion this is all there is.
  static Set<Polyline> polylines(
    List<LatLng> points, {
    double zoom = 14,
  }) => {
    _line(outlineId, points, outlineColor, outlineWidthAt(zoom), 1),
    _line(coreId, points, coreColor, coreWidthAt(zoom), 2),
  };

  /// The white part of the core at [phase] over [route]: the soft edge
  /// just ahead of the black front ([softSteps] short lines of rising
  /// opacity), then plain white to the drop-off. Empty when all black.
  static Set<Polyline> light(
    List<GeoPoint> route,
    OfferLinePhase phase, {
    double zoom = 14,
  }) {
    if (route.length < 2 || phase.dark) { return const <Polyline>{}; }
    final width = coreWidthAt(zoom);
    List<LatLng> slice(double a, double b) => [
      for (final p in routeSlice(route, a, b)) LatLng(p.latitude, p.longitude),
    ];
    Color white(double alpha) =>
        lightColor.withValues(alpha: (alpha * phase.light).clamp(0.0, 1.0));
    final lines = <Polyline>{};
    for (var i = 0; i < softSteps; i++) {
      final a = phase.front + soft * i / softSteps;
      final b = phase.front + soft * (i + 1) / softSteps;
      if (a >= 1) { break; }
      final points = slice(a, b > 1 ? 1 : b);
      if (points.length < 2) { continue; }
      lines.add(_line(
        '$lightId-soft-$i',
        points,
        white((i + 0.5) / softSteps),
        width,
        3,
        startCap: Cap.buttCap,
        endCap: b >= 1 ? Cap.roundCap : Cap.buttCap,
      ));
    }
    final rest = phase.front + soft;
    if (rest < 1) {
      final points = slice(rest, 1);
      if (points.length >= 2) {
        lines.add(_line(lightId, points, white(1), width, 3,
            startCap: Cap.buttCap));
      }
    }
    return lines;
  }

  /// [lines] with the offer line's outline, core and white parts resized
  /// for [zoom]; other polylines pass through unchanged.
  static Set<Polyline> sized(Set<Polyline> lines, double zoom) => {
    for (final line in lines)
      line.polylineId.value == outlineId
          ? line.copyWith(widthParam: outlineWidthAt(zoom))
          : line.polylineId.value == coreId ||
                line.polylineId.value.startsWith(lightId)
          ? line.copyWith(widthParam: coreWidthAt(zoom))
          : line,
  };
}
