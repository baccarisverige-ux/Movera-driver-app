import 'dart:math' as math;
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
class MoveraVehicleMarker {
  const MoveraVehicleMarker._();

  /// The arrow's size on screen (logical pixels), about the reference's.
  static const double size = 52;

  /// The halo's diameter on the ground at an untilted map.
  static const double haloSize = 88;

  /// Pixel density the bitmaps are drawn at: crisp on 3x screens.
  static const double _density = 3;

  /// Where the arrow touches the ground (the notch of its base), so it
  /// turns about its own middle and stands on the halo's centre.
  static const Offset anchor = Offset(0.5, 0.62);

  /// Arrow colours: top face, its lighter tip, the edge under it.
  static const Color face = Color(0xFF3FB6D3);
  static const Color faceLight = Color(0xFF7FD3E7);
  static const Color edge = Color(0xFF237F9B);

  static BitmapDescriptor? _halo;

  /// The ground halo, ready once [createIcon] has completed.
  static BitmapDescriptor? get halo => _halo;

  static Future<BitmapDescriptor> createIcon() async {
    _halo ??= await _bitmap(haloSize, paintHalo);
    return await _bitmap(size, paintArrow) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  static Future<BitmapDescriptor?> _bitmap(
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
    if (data == null) return null;
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
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
