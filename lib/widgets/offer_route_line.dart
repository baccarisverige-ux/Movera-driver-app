import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/route_camera_fit.dart';
import 'package:movera/widgets/driver_route_style.dart';

/// Where the offer line's motion is at one moment of its cycle.
@immutable
class OfferLinePhase {
  const OfferLinePhase({required this.front, required this.resting});

  /// The centre of the bright band, as a share of the route's length; it
  /// starts before the pickup (negative) and ends past the drop-off (> 1),
  /// so the band enters and leaves the line completely.
  final double front;

  /// The line is at rest in its dark colours: no band is shown.
  final bool resting;

  @override
  bool operator ==(Object other) =>
      other is OfferLinePhase &&
      other.front == front &&
      other.resting == resting;

  @override
  int get hashCode => Object.hash(front, resting);

  @override
  String toString() => 'OfferLinePhase(front: $front, resting: $resting)';
}

/// R14-2 / owner round 4: the offer route line on Home (Reservation,
/// Exclusive and Radar). The line is the Movera route in its dark colours
/// ([DriverRouteStyle]), no outline; the motion is a soft band in the same
/// hues' bright shades that flows from the pickup to the drop-off, rests,
/// and repeats. Nothing turns white.
///
/// Cycle 2.6 s: 0–2.0 s the band's centre runs from just before the pickup
/// to just past the drop-off (ease-in-out cubic); 2.0–2.6 s the line rests.
abstract final class OfferRouteLine {
  static const Duration cycle = Duration(milliseconds: 2600);

  /// The band's run, from the cycle's start.
  static const Duration run = Duration(milliseconds: 2000);

  /// The band's length, as a share of the route; its colour fades to the
  /// line's own towards both ends.
  static const double band = 0.26;

  /// The band drawn as this many short lines, brightest in the middle.
  static const int bandSteps = 10;

  /// Polyline ids: the first line piece keeps the offer route's id, so
  /// lookups by it still find the route; the band's pieces carry [bandId].
  static const String coreId = 'direct_offer_road_route';
  static const String bandId = 'offer_route_band';

  /// Line width at a [DriverRouteStyle.stepZoom] step (R15-8): the same 5
  /// on every offer, however far the map zooms out to fit the trip; 7 only
  /// close up.
  static int widthAt(double zoom) => zoom < 16 ? 5 : 7;

  static double _ease(double t) => t < 0.5
      ? 4 * t * t * t
      : 1 - (-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2) / 2;

  /// The motion's phase [elapsed] into the repeating cycle.
  static OfferLinePhase phaseAt(Duration elapsed) {
    final k = elapsed.inMicroseconds % cycle.inMicroseconds;
    if (k >= run.inMicroseconds) {
      return const OfferLinePhase(front: 1 + band / 2, resting: true);
    }
    final t = _ease(k / run.inMicroseconds);
    return OfferLinePhase(front: -band / 2 + (1 + band) * t, resting: false);
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

  /// The still line: the dark gradient pieces (the first keeps [coreId]).
  /// With reduced motion this is all there is.
  static Set<Polyline> polylines(List<LatLng> points, {double zoom = 14}) =>
      DriverRouteStyle.gradientPieces(
        id: coreId,
        points: points,
        width: widthAt(zoom),
      );

  /// Whether [line] is a piece of the offer line itself.
  static bool isCore(Polyline line) =>
      line.polylineId.value == coreId ||
      line.polylineId.value.startsWith('$coreId-g');

  /// Whether [line] is a piece of the moving band.
  static bool isBand(Polyline line) => line.polylineId.value.startsWith(bandId);

  /// The band at [phase] over [route]: [bandSteps] short lines around the
  /// band's centre, each in the route's bright shade at its place mixed
  /// into the dark line colour towards the band's ends. Empty at rest.
  static Set<Polyline> flow(
    List<GeoPoint> route,
    OfferLinePhase phase, {
    double zoom = 14,
  }) {
    if (route.length < 2 || phase.resting) {
      return const <Polyline>{};
    }
    final width = widthAt(zoom);
    final lines = <Polyline>{};
    final from = phase.front - band / 2;
    for (var i = 0; i < bandSteps; i++) {
      final a = from + band * i / bandSteps;
      final b = from + band * (i + 1) / bandSteps;
      if (b <= 0 || a >= 1) continue;
      final points = [
        for (final p in routeSlice(route, a < 0 ? 0 : a, b > 1 ? 1 : b))
          LatLng(p.latitude, p.longitude),
      ];
      if (points.length < 2) continue;
      final centre = (a + b) / 2;
      final d = (centre - phase.front).abs() / (band / 2);
      final bright = (1 - d * d).clamp(0.0, 1.0);
      lines.add(
        _line(
          '$bandId-$i',
          points,
          Color.lerp(
            DriverRouteStyle.at(centre),
            DriverRouteStyle.lightAt(centre),
            bright,
          )!,
          width,
          3,
          startCap: a <= 0 ? Cap.roundCap : Cap.buttCap,
          endCap: b >= 1 ? Cap.roundCap : Cap.buttCap,
        ),
      );
    }
    return lines;
  }

  /// [lines] with the offer line's pieces and band resized for [zoom];
  /// other polylines pass through unchanged.
  static Set<Polyline> sized(Set<Polyline> lines, double zoom) => {
    for (final line in lines)
      isCore(line) || isBand(line)
          ? line.copyWith(widthParam: widthAt(zoom))
          : line,
  };
}
