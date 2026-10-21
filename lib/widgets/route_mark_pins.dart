import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/web_map_bitmap.dart';

enum RouteMarkKind { pickup, stop, dropoff }

/// One route mark as a widget, e.g. in the trip bar or the top card.
class RouteMarkIcon extends StatelessWidget {
  const RouteMarkIcon(this.kind, {super.key, this.size = RouteMarkPins.markSize});

  final RouteMarkKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _RouteMarkPainter(kind)),
  );
}

class _RouteMarkPainter extends CustomPainter {
  const _RouteMarkPainter(this.kind);

  final RouteMarkKind kind;

  @override
  void paint(Canvas canvas, Size size) =>
      RouteMarkPins.paintMark(canvas, size.center(Offset.zero), kind);

  @override
  bool shouldRepaint(covariant _RouteMarkPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// Route marks for maps and trip bars: a green dot for pickup, an orange
/// diamond for a stop and a black dot for drop-off, each with a white
/// centre. [RouteMarkPins.labelled] adds a bubble above the mark with a
/// title and a time, e.g. "Pickup" / "07:40".
class RouteMarkPins {
  const RouteMarkPins._();

  static const Color ink = Color(0xFF111614);
  static const double _ratio = 3;

  /// Size of a bare mark, in logical pixels.
  static const double markSize = 18;

  /// Font for the bubble text; null uses the platform font, as the app does.
  @visibleForTesting
  static String? debugFontFamily;

  /// Logical size of a labelled pin for [title] and [time].
  static Size labelledSize(String title, String? time) {
    final bubble = _bubbleSize(title, time);
    return Size(bubble.width + 4, bubble.height + _gap + markSize + 4);
  }

  /// Where the mark's centre sits inside a labelled pin, as a marker anchor.
  static Offset labelledAnchor(String title, String? time) {
    final size = labelledSize(title, time);
    return Offset(0.5, (size.height - 2 - markSize / 2) / size.height);
  }

  static Future<BitmapDescriptor> mark(RouteMarkKind kind) {
    return _toBitmap(
      const Size(markSize, markSize),
      (canvas, size) => paintMark(canvas, size.center(Offset.zero), kind),
    );
  }

  static Future<BitmapDescriptor> labelled(
    RouteMarkKind kind,
    String title,
    String? time,
  ) {
    return _toBitmap(
      labelledSize(title, time),
      (canvas, size) => paintLabelled(canvas, size, kind, title, time),
    );
  }

  /// Colour of each kind: green pickup, orange stop, black drop-off.
  static Color colorOf(RouteMarkKind kind) => switch (kind) {
        RouteMarkKind.pickup => pickupGreen,
        RouteMarkKind.stop => stopOrange,
        RouteMarkKind.dropoff => ink,
      };

  static const Color pickupGreen = Color(0xFF1FA463);
  static const Color stopOrange = Color(0xFFE08A1E);

  /// Draws one mark centred on [center]: a dot for pickup and drop-off, a
  /// diamond for a stop (a stop is never the end of the trip).
  static void paintMark(Canvas canvas, Offset center, RouteMarkKind kind) {
    final stop = kind == RouteMarkKind.stop;
    final outer = stop ? 13.0 : 15.0;
    final inner = stop ? 4.5 : 5.5;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);
    final fill = Paint()..color = colorOf(kind);
    final white = Paint()..color = Colors.white;
    if (stop) {
      Path diamond(double half) => Path()
        ..moveTo(center.dx, center.dy - half)
        ..lineTo(center.dx + half, center.dy)
        ..lineTo(center.dx, center.dy + half)
        ..lineTo(center.dx - half, center.dy)
        ..close();
      canvas.drawPath(diamond(outer / 2 + 2.5).shift(const Offset(0, 0.8)), shadow);
      canvas.drawPath(diamond(outer / 2 + 2.5), white);
      canvas.drawPath(diamond(outer / 2), fill);
      canvas.drawPath(diamond(inner / 2 + 0.6), white);
    } else {
      canvas.drawCircle(center.translate(0, 0.8), outer / 2 + 1.5, shadow);
      canvas.drawCircle(center, outer / 2 + 1.5, white);
      canvas.drawCircle(center, outer / 2, fill);
      canvas.drawCircle(center, inner / 2, white);
    }
  }

  /// Map pin: a drop-shaped head in the kind's colour with its white mark
  /// inside, the tip on the point. Anchor with [pinAnchor].
  static Future<BitmapDescriptor> pin(RouteMarkKind kind) =>
      _toBitmap(pinSize, (canvas, size) => paintPin(canvas, size, kind));

  static const Size pinSize = Size(30, 40);
  static const Offset pinAnchor = Offset(0.5, 0.97);

  static void paintPin(Canvas canvas, Size size, RouteMarkKind kind) {
    final cx = size.width / 2;
    const r = 13.0;
    final cy = r + 1.5;
    final tip = Offset(cx, size.height - 1.5);
    Path drop(double grow) => Path()
      ..moveTo(tip.dx, tip.dy + grow)
      ..cubicTo(cx - 5 - grow, cy + r * 0.95, cx - r - grow, cy + r * 0.45,
          cx - r - grow, cy)
      ..arcToPoint(Offset(cx + r + grow, cy),
          radius: Radius.circular(r + grow))
      ..cubicTo(cx + r + grow, cy + r * 0.45, cx + 5 + grow, cy + r * 0.95,
          tip.dx, tip.dy + grow)
      ..close();
    canvas.drawPath(
      drop(0).shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
    );
    canvas.drawPath(drop(1.5), Paint()..color = Colors.white);
    canvas.drawPath(drop(0), Paint()..color = colorOf(kind));
    final c = Offset(cx, cy);
    final white = Paint()..color = Colors.white;
    if (kind == RouteMarkKind.stop) {
      const h = 5.0;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + h, c.dy)
          ..lineTo(c.dx, c.dy + h)
          ..lineTo(c.dx - h, c.dy)
          ..close(),
        white,
      );
    } else {
      canvas.drawCircle(c, 4.5, white);
    }
  }

  /// Bubble with [title] (small) and [time] (bold) above the mark.
  static void paintLabelled(
    Canvas canvas,
    Size size,
    RouteMarkKind kind,
    String title,
    String? time,
  ) {
    final dark = kind != RouteMarkKind.stop;
    final bubble = _bubbleSize(title, time);
    final rect = Rect.fromLTWH(
      (size.width - bubble.width) / 2,
      2,
      bubble.width,
      bubble.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
    );
    final bg = Paint()..color = dark ? ink : Colors.white;
    canvas.drawRRect(rrect, bg);
    // Small pointer from the bubble down to the mark.
    final cx = size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, rect.bottom - 1)
        ..lineTo(cx, rect.bottom + 6)
        ..lineTo(cx + 6, rect.bottom - 1)
        ..close(),
      bg,
    );
    final titlePainter = _text(
      title,
      dark ? const Color(0xFFB4BCC0) : const Color(0xFF5E6461),
      10.5,
      FontWeight.w500,
    );
    final timePainter = time == null
        ? null
        : _text(time, dark ? Colors.white : ink, 14, FontWeight.w800);
    var y = rect.top + _padV;
    if (timePainter != null) {
      titlePainter.paint(canvas, Offset(cx - titlePainter.width / 2, y));
      y += titlePainter.height;
      timePainter.paint(canvas, Offset(cx - timePainter.width / 2, y));
    } else {
      final big = _text(
        title,
        dark ? Colors.white : ink,
        12.5,
        FontWeight.w700,
      );
      big.paint(
        canvas,
        Offset(cx - big.width / 2, rect.center.dy - big.height / 2),
      );
    }
    paintMark(canvas, Offset(cx, size.height - 2 - markSize / 2), kind);
  }

  static const double _padH = 10;
  static const double _padV = 5;
  static const double _gap = 8;

  static Size _bubbleSize(String title, String? time) {
    if (time == null) {
      final big = _text(title, ink, 12.5, FontWeight.w700);
      return Size(big.width + _padH * 2, big.height + _padV * 2 + 2);
    }
    final t = _text(title, ink, 10.5, FontWeight.w500);
    final v = _text(time, ink, 14, FontWeight.w800);
    final w = (t.width > v.width ? t.width : v.width) + _padH * 2;
    return Size(w < 52 ? 52 : w, t.height + v.height + _padV * 2);
  }

  static TextPainter _text(String s, Color c, double size, FontWeight w) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: c,
          fontSize: size,
          fontWeight: w,
          height: 1.15,
          fontFamily: debugFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static Future<BitmapDescriptor> _toBitmap(
    Size size,
    void Function(Canvas canvas, Size size) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_ratio);
    paint(canvas, size);
    final image = await recorder.endRecording().toImage(
      (size.width * _ratio).ceil(),
      (size.height * _ratio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return bitmapOf(data.buffer.asUint8List(), size);
  }

  /// [png] painted at [size] (logical) as a map icon. Web: one URL per
  /// picture, not a new Blob URL on every marker update, e.g. each step of
  /// a route fade (driver-r4-21, like the car in driver-u174).
  static BitmapDescriptor bitmapOf(Uint8List png, Size size) =>
      WebMapBitmaps.of(png, width: size.width, height: size.height) ??
      BitmapDescriptor.bytes(png, imagePixelRatio: _ratio);
}
