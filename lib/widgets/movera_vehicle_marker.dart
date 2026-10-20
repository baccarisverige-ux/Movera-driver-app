import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The driver's own position on Home and the active ride map: a blue 3D
/// navigation arrow (lighter top face, darker edge for thickness) that
/// stands up toward the viewer, over a soft grey halo on the ground, like
/// the owner's reference navigation app.
///
/// The arrow is a billboard (`flat: false`): on a tilted map it stays
/// upright instead of lying squashed in the ground plane. Google turns a
/// billboard with the screen, not the map, so its rotation is the heading
/// seen from the camera ([screenRotation]); CustomGoogleMap applies it and
/// adds the halo ([haloMarker]) under it.
///
/// Like the reference app the arrow (and its halo) grows a little as the
/// map zooms in and shrinks zoomed out ([scaleForZoom]). The scale moves in
/// [scaleStep] buckets ([nextScale]); each bucket's bitmap is made once from
/// the same high-resolution picture ([arrowAt], [haloAt]), so a pinch never
/// repaints and a following camera never churns the markers.
class MoveraVehicleMarker {
  const MoveraVehicleMarker._();

  /// The arrow's box on screen (logical pixels) at scale 1 (zoom 15, the
  /// locate and guidance standstill view): the arrow is 40 of its 52 points
  /// wide, about a tenth of a phone's width, as in the reference.
  static const double size = 52;

  /// The halo's diameter on the ground at an untilted map, at scale 1.
  static const double haloSize = 88;

  /// Arrow scale by camera zoom (zoom, scale), linear between, clamped
  /// outside: measured on the reference screenshots, the arrow is about
  /// 6.5 % of the screen width zoomed out over the region, 8 % at
  /// neighbourhood zoom, 10 % at street zoom and 11 % zoomed right in
  /// (zoom 11.7: 0.6, 14: 0.85, 15: 1, 17 and closer: 1.1).
  static const List<(double, double)> scaleStops = [
    (11.5, .6),
    (13.5, .75),
    (15, 1),
    (17, 1.1),
  ];

  /// Smallest and largest arrow scale.
  static double get minScale => scaleStops.first.$2;
  static double get maxScale => scaleStops.last.$2;

  /// Bucket size: the arrow changes size only in steps of this much.
  static const double scaleStep = .05;

  /// The arrow scale at [zoom], interpolated and clamped (not bucketed).
  /// web/driver_map_camera.js uses the same stops; keep both in step.
  static double scaleForZoom(double zoom) {
    if (!zoom.isFinite) return 1;
    if (zoom <= scaleStops.first.$1) return minScale;
    for (var i = 1; i < scaleStops.length; i++) {
      final (z1, s1) = scaleStops[i];
      if (zoom <= z1) {
        final (z0, s0) = scaleStops[i - 1];
        return s0 + (s1 - s0) * (zoom - z0) / (z1 - z0);
      }
    }
    return maxScale;
  }

  /// [scale] rounded to its [scaleStep] bucket.
  static double bucket(double scale) =>
      _round((scale / scaleStep).round() * scaleStep);

  /// The bucket the arrow shows after the camera moved to [zoom] while it
  /// showed [shown]: unchanged until the zoom's own scale is 0.7 of a step
  /// away, so a zoom resting on a bucket edge never flickers.
  static double nextScale(double shown, double zoom) {
    final wanted = scaleForZoom(zoom);
    if ((wanted - shown).abs() < scaleStep * .7) return shown;
    return bucket(wanted);
  }

  /// The bucket a map opening at [zoom] shows.
  static double scaleAt(double zoom) => bucket(scaleForZoom(zoom));

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  /// Pixel density the bitmaps are drawn at: crisp on 3x screens.
  static const double _density = 3;

  /// Where the arrow touches the ground (the notch of its base), so it
  /// turns about its own middle and stands on the halo's centre.
  static const Offset anchor = Offset(0.5, 0.62);

  /// Arrow colours: top face, its lighter tip, the edge under it.
  static const Color face = Color(0xFF3FB6D3);
  static const Color faceLight = Color(0xFF7FD3E7);
  static const Color edge = Color(0xFF237F9B);

  /// The arrow and halo pictures, drawn once at [maxScale] so every bucket
  /// is a downscale (crisp on 3x screens).
  static Uint8List? _arrowPng, _haloPng;
  static final Map<int, BitmapDescriptor> _arrows = {}, _halos = {};

  /// The ground halo at scale 1, ready once [createIcon] has completed.
  static BitmapDescriptor? get halo => haloAt(1);

  /// The arrow at scale 1 (the marker's own icon). CustomGoogleMap shows
  /// the bucket for the camera's zoom instead ([arrowAt]).
  static Future<BitmapDescriptor> createIcon() async {
    _haloPng ??= await _png(haloSize * maxScale, paintHalo);
    _arrowPng ??= await _png(size * maxScale, paintArrow);
    return arrowAt(1) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  /// The arrow at [scale] (a bucket), or null before [createIcon] is done.
  static BitmapDescriptor? arrowAt(double scale) =>
      _at(_arrows, _arrowPng, size, scale);

  /// The halo at [scale] (a bucket), or null before [createIcon] is done.
  static BitmapDescriptor? haloAt(double scale) =>
      _at(_halos, _haloPng, haloSize, scale);

  static BitmapDescriptor? _at(Map<int, BitmapDescriptor> cache,
      Uint8List? png, double logical, double scale) {
    if (png == null) return null;
    final key = (scale * 100).round();
    return cache[key] ??= BitmapDescriptor.bytes(
      png,
      width: logical * key / 100,
      height: logical * key / 100,
    );
  }

  static Future<Uint8List?> _png(
    double logical,
    void Function(Canvas, double) paint,
  ) async {
    final pixels = (logical * _density).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_density);
    paint(canvas, logical);
    final image = await recorder.endRecording().toImage(pixels, pixels);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// The rotation a billboard needs to point along [heading] (compass
  /// degrees) on a map turned to [bearing] and tilted by [tilt]: the
  /// heading relative to the camera, foreshortened like the tilted ground
  /// (a road at 45° to the view looks steeper on a tilted map).
  static double screenRotation(double heading, double bearing, double tilt) {
    final turn = (heading - bearing) * math.pi / 180;
    final lean = math.cos(tilt.clamp(0.0, 89.0) * math.pi / 180);
    final degrees =
        math.atan2(math.sin(turn), math.cos(turn) * lean) * 180 / math.pi;
    return (degrees + 360) % 360;
  }

  /// The halo under the own vehicle: flat on the ground, so it turns into
  /// an ellipse as the map tilts.
  static Marker haloMarker(Marker vehicle, BitmapDescriptor icon) => Marker(
    markerId: MarkerId('${vehicle.markerId.value}_halo'),
    position: vehicle.position,
    icon: icon,
    flat: true,
    anchor: const Offset(0.5, 0.5),
    zIndexInt: vehicle.zIndexInt - 1,
    consumeTapEvents: true,
  );

  /// Soft translucent grey disc filling a [box] x [box] square.
  static void paintHalo(Canvas c, double box) {
    final center = Offset(box / 2, box / 2);
    final radius = box / 2 - 1;
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          const [Color(0x527D8C99), Color(0x427D8C99), Color(0x007D8C99)],
          const [0, 0.82, 1],
        ),
    );
  }

  /// The arrow pointing up in a [box] x [box] square, its base notch at
  /// [anchor].
  static void paintArrow(Canvas c, double box) {
    final s = box / 52;
    Path arrow(double dy) => Path()
      ..moveTo(26 * s, (7 + dy) * s)
      ..lineTo(46 * s, (37 + dy) * s)
      ..quadraticBezierTo(26 * s, (29 + dy) * s, 6 * s, (37 + dy) * s)
      ..close();
    Paint rounded(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    Paint corners(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeJoin = StrokeJoin.round;
    // Soft shadow on the ground.
    c.drawPath(
      arrow(7),
      Paint()
        ..color = const Color(0x3D1D2B33)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 2.4 * s),
    );
    // Thickness: the edge under the top face, stacked down a few pixels.
    for (var dy = 4.5; dy > 0; dy -= .5) {
      final path = arrow(dy);
      c
        ..drawPath(path, rounded(edge))
        ..drawPath(path, corners(edge));
    }
    // A pale lip along the bottom of the edge, as in the reference.
    c.drawPath(
      arrow(4.5),
      corners(const Color(0x66E6F4F7))..strokeWidth = 1.2 * s,
    );
    // Top face: lighter toward the tip.
    final top = arrow(0);
    final light = Paint()
      ..shader = ui.Gradient.linear(
        Offset(26 * s, 7 * s),
        Offset(26 * s, 37 * s),
        const [faceLight, face],
      );
    c
      ..drawPath(top, light)
      ..drawPath(top, corners(face)..shader = light.shader);
    // Thin bright rim on the face.
    c.drawPath(
      top,
      Paint()
        ..color = const Color(0x8CFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * s
        ..strokeJoin = StrokeJoin.round,
    );
  }
}
