import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/events/driver_events.dart';
import 'package:movera/widgets/web_map_bitmap.dart';

/// G4-F6 (owner "small premium icon in the map in the exact location of
/// event"): Movera's own event mark, a small black disc with a fine gold
/// ring and a gold four-point star, centred on the event's point. A map
/// marker is drawn at the same screen size at every zoom, on web and on
/// the phones alike.
abstract final class MoveraEventMarker {
  static const Size size = Size(30, 30);
  static const Offset anchor = Offset(0.5, 0.5);

  static const Color ink = Color(0xFF111315);
  static const Color gold = Color(0xFFD4AF5A);
  static const Color goldLight = Color(0xFFF3DC9A);

  static const double _ratio = 3;

  /// The marker id of [event] on the Home map.
  static MarkerId idOf(DriverEvent event) =>
      MarkerId('driver_event_${event.eventId}');

  /// The painted icon once it is ready; null before (see [paintIcon]).
  static final ValueNotifier<BitmapDescriptor?> icon =
      ValueNotifier<BitmapDescriptor?>(null);
  static Future<void>? _painting;

  /// Paints the icon once; [icon] tells when it is ready.
  static Future<void> paintIcon() => _painting ??= _bitmap().then((value) {
    icon.value = value;
  });

  /// Tests start over.
  @visibleForTesting
  static void reset() {
    _painting = null;
    icon.value = null;
  }

  /// The Home map's event marks: one per [events], tapping one calls
  /// [onTap]. None until the icon is painted (never Google's default pin).
  static Set<Marker> markers(
    Iterable<DriverEvent> events, {
    required void Function(DriverEvent event) onTap,
  }) {
    final mark = icon.value;
    if (mark == null) return const <Marker>{};
    return {
      for (final event in events)
        Marker(
          markerId: idOf(event),
          position: LatLng(event.location.latitude, event.location.longitude),
          icon: mark,
          anchor: anchor,
          // Under the car and an offer's pins.
          zIndexInt: 1,
          consumeTapEvents: true,
          onTap: () => onTap(event),
        ),
    };
  }

  static void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(
      c.translate(0, 1),
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(c, r, Paint()..color = ink);
    canvas.drawCircle(
      c,
      r - 1.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = ui.Gradient.linear(
          c.translate(-r, -r),
          c.translate(r, r),
          const [goldLight, gold, goldLight],
          const [0, 0.55, 1],
        ),
    );
    // A four-point star: long points up/down/left/right, a narrow waist.
    final s = r * 0.62;
    final w = s * 0.28;
    final star = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy - w * 0.4, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy + w * 0.4, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy + w * 0.4, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy - w * 0.4, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(0, -s),
          c.translate(0, s),
          const [goldLight, gold],
        ),
    );
  }

  static Future<BitmapDescriptor> _bitmap() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_ratio);
    paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      (size.width * _ratio).ceil(),
      (size.height * _ratio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
    final png = data.buffer.asUint8List();
    // Web: one stable URL for the picture (driver-u174).
    return WebMapBitmaps.of(png, width: size.width, height: size.height) ??
        BitmapDescriptor.bytes(png, width: size.width, height: size.height);
  }
}
