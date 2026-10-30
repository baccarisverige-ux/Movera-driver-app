import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'web_map_bitmap.dart';

/// The driver's own position on Home and the active ride map: an upright
/// blue navigation arrow with a white outline, the same size at every
/// zoom, standing on a small soft grey ring (uat-d3, the owner's design).
///
/// Arrow and ring are one picture ([paintMarker]) on one billboard marker
/// (`flat: false`), anchored at the arrow's base in the ring's centre: on
/// a tilted map the whole marker stays upright, so the ring is never
/// squashed into an ellipse and never drifts from the arrow, and neither
/// scales with the zoom or the tilt. Google turns a billboard with the
/// screen, so its rotation is the heading less the map's bearing
/// ([screenRotation]); CustomGoogleMap applies it.
///
/// web/driver_map_camera.js draws the same arrow and ring as native Maps
/// markers; keep the sizes and colours in step.
class MoveraVehicleMarker {
  const MoveraVehicleMarker._();

  /// Web: the marker title by which web/driver_map_camera.js knows the own
  /// car (and draws its turning arrow and ring); it strips the title, so
  /// it is never shown.
  static const String webCameraTag = 'Driver camera vehicle';

  /// The own car's marker title: [webCameraTag] on the web (driver group
  /// 3: a translated title made the web map show the car's raster picture
  /// in a broken image box), "Your car" elsewhere.
  static String get ownTitle => kIsWeb ? webCameraTag : tr.mapYourCar;

  /// The arrow's own box (logical pixels): the arrow is 25 of its 38
  /// points wide, small like the reference (owner: 52 looked too big).
  static const double size = 38;

  /// The ring's diameter: about 1.3 x the arrow's width.
  static const double ringSize = 32;

  /// The whole picture's box: the arrow's box with room for the ring
  /// around its base.
  static const double box = 44;

  /// Where the arrow's box sits inside [box].
  static const double _inset = (box - size) / 2;

  /// The arrow's base notch inside its own box, as a part of its height.
  static const double _arrowBase = 0.62;

  /// Where the marker touches the ground: the arrow's base notch, the
  /// ring's centre, so it turns about its own middle.
  static const Offset anchor = Offset(0.5, (_inset + _arrowBase * size) / box);

  /// Arrow colours: top face, its lighter tip, the edge under it.
  static const Color face = Color(0xFF3FB6D3);
  static const Color faceLight = Color(0xFF7FD3E7);
  static const Color edge = Color(0xFF237F9B);

  /// The ring's grey, at 28 % in the middle, fading out at its edge.
  static const Color ring = Color(0x487D8C99);

  /// Pixel density the bitmap is drawn at: crisp on 3x screens.
  static const double _density = 3;

  static BitmapDescriptor? _icon;

  /// The marker's icon, ready once [createIcon] has completed.
  static BitmapDescriptor? get icon => _icon;

  /// The marker's icon (the arrow over its ring), made once.
  static Future<BitmapDescriptor> createIcon() async {
    if (_icon != null) return _icon!;
    final png = await _png(box, paintMarker);
    if (png == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    // Web: one URL for the picture, not a new Blob URL per push
    // (driver-u174).
    return _icon ??=
        WebMapBitmaps.of(png, width: box, height: box) ??
        BitmapDescriptor.bytes(png, width: box, height: box);
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
  /// degrees, 0 north, clockwise) on a map turned to [bearing]: the
  /// heading relative to the screen's up. The tilt plays no part: a
  /// billboard is not in the ground plane, so leaning its rotation by the
  /// tilt turned the arrow off the road.
  static double screenRotation(double heading, double bearing) =>
      ((heading - bearing) % 360 + 360) % 360;

  /// The whole picture in a [box] x [box] square: the ring centred on
  /// [anchor], the arrow over it with its base at [anchor].
  static void paintMarker(Canvas c, double box) {
    final k = box / MoveraVehicleMarker.box;
    paintRing(c, Offset(anchor.dx * box, anchor.dy * box), ringSize * k);
    c
      ..save()
      ..translate(_inset * k, _inset * k);
    paintArrow(c, size * k);
    c.restore();
  }

  /// A soft translucent grey disc of [diameter] at [centre]: full to 70 %
  /// of its radius, then fading out, so it has no hard edge.
  static void paintRing(Canvas c, Offset centre, double diameter) {
    final radius = diameter / 2;
    c.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          radius,
          [ring, ring, ring.withAlpha(0)],
          const [0, 0.7, 1],
        ),
    );
  }

  /// The arrow pointing up in a [box] x [box] square, its base notch at
  /// [_arrowBase] of its height: a flat navigation arrow like the owner's reference (blue
  /// face, white outline, soft shadow), with no fake 3D edge, so it reads
  /// the same at every heading.
  static void paintArrow(Canvas c, double box) {
    final s = box / 52;
    final arrow = Path()
      ..moveTo(26 * s, 8 * s)
      ..lineTo(43 * s, 42 * s)
      ..lineTo(26 * s, 32.2 * s)
      ..lineTo(9 * s, 42 * s)
      ..close();
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * s
      ..strokeJoin = StrokeJoin.round;
    // Soft shadow right under the arrow.
    c.drawPath(
      arrow.shift(Offset(0, 1.2 * s)),
      stroke(const Color(0x401D2B33), 6)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.6 * s),
    );
    // White outline.
    c
      ..drawPath(arrow, stroke(Colors.white, 5))
      ..drawPath(arrow, Paint()..color = Colors.white);
    // Blue face, a little lighter toward the tip.
    c.drawPath(
      arrow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(26 * s, 8 * s),
          Offset(26 * s, 42 * s),
          const [faceLight, face],
        ),
    );
    c.drawPath(arrow, stroke(edge, .8));
  }
}
