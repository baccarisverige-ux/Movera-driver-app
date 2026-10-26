import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Painted map markers for Destination mode, so web and mobile show the same
/// Movera look instead of Google's default (red on web) pins: the blue
/// destination pin, the black place chip that stands on it, and the car ring
/// of the choose-destination map. All of them are real map markers and stay
/// on their coordinates when the map moves.
abstract final class MoveraDestinationMarker {
  static const Color blue = Color(0xFF1769E8);
  static const Color ink = Color(0xFF111315);

  /// Blue disc with a white square, centred on the destination.
  static const Size pinSize = Size(34, 34);
  static const Offset pinAnchor = Offset(0.5, 0.5);

  /// White disc, black ring and arrow, centred on the car.
  static const Size carSize = Size(36, 36);
  static const Offset carAnchor = Offset(0.5, 0.5);

  /// The chip's stem ends at the bottom centre, on the destination.
  static const Offset chipAnchor = Offset(0.5, 1);
  static const double chipStem = 30;
  static const double _chipHeight = 32;
  static const double _chipMaxWidth = 190;

  static const double _ratio = 3;

  static Future<BitmapDescriptor>? _pin;
  static Future<BitmapDescriptor>? _car;
  static BitmapDescriptor? _pinReady;

  /// The pin once it has been painted (see [pin]); null before that.
  static BitmapDescriptor? get cachedPin => _pinReady;

  static Future<BitmapDescriptor> pin() =>
      _pin ??= _bitmap(pinSize, paintPin).then((icon) => _pinReady = icon);

  static Future<BitmapDescriptor> car() => _car ??= _bitmap(carSize, paintCar);

  static Future<BitmapDescriptor> chip(String label) {
    final text = chipText(label);
    final size = Size(text.width + 34, _chipHeight + chipStem);
    return _bitmap(size, (canvas, size) => paintChip(canvas, size, text));
  }

  static void paintPin(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c.translate(0, 1),
      r - 1,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(c, r - 1, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - 3, Paint()..color = blue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: r * 0.62, height: r * 0.62),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white,
    );
  }

  static void paintCar(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    final arrow = Path()
      ..moveTo(c.dx + 6, c.dy - 7)
      ..lineTo(c.dx - 6, c.dy + 7)
      ..lineTo(c.dx - 0.5, c.dy + 1.5)
      ..lineTo(c.dx + 1, c.dy + 7)
      ..close();
    canvas.drawPath(arrow, Paint()..color = ink);
  }

  static TextPainter chipText(String label) => TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
    maxLines: 1,
    ellipsis: '…',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _chipMaxWidth - 34);

  /// Black chip (white dot + name) on top, a thin stem down to the pin.
  static void paintChip(Canvas canvas, Size size, TextPainter text) {
    final ink = Paint()..color = MoveraDestinationMarker.ink;
    final cx = size.width / 2;
    canvas.drawLine(
      Offset(cx, _chipHeight - 2),
      Offset(cx, size.height),
      Paint()
        ..color = MoveraDestinationMarker.ink
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, _chipHeight),
        const Radius.circular(_chipHeight / 2),
      ),
      ink,
    );
    canvas.drawCircle(
      const Offset(14, _chipHeight / 2),
      4,
      Paint()..color = Colors.white,
    );
    text.paint(canvas, Offset(24, (_chipHeight - text.height) / 2));
  }

  static Future<BitmapDescriptor> _bitmap(
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
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: size.width,
      height: size.height,
    );
  }
}

/// A curved arc from [from] to [to] as [count] map points: a quadratic
/// curve bulging to the north side by a third of the distance. The first
/// point is exactly [from] and the last exactly [to].
List<LatLng> destinationArcPoints(LatLng from, LatLng to, {int count = 48}) {
  if (from == to) {
    return [from, to];
  }
  // Work in a flat frame where one unit east equals one unit north.
  final k = math.cos((from.latitude + to.latitude) / 2 * math.pi / 180);
  final ax = from.longitude * k, ay = from.latitude;
  final bx = to.longitude * k, by = to.latitude;
  final dx = bx - ax, dy = by - ay;
  var nx = -dy, ny = dx;
  if (ny < 0 || (ny == 0 && nx < 0)) {
    nx = -nx;
    ny = -ny;
  }
  final n = math.sqrt(nx * nx + ny * ny);
  final d = math.sqrt(dx * dx + dy * dy);
  final cx = (ax + bx) / 2 + nx / n * d * 0.32;
  final cy = (ay + by) / 2 + ny / n * d * 0.32;
  return List<LatLng>.generate(count, (i) {
    if (i == 0) {
      return from;
    }
    if (i == count - 1) {
      return to;
    }
    final t = i / (count - 1), u = 1 - t;
    final x = u * u * ax + 2 * u * t * cx + t * t * bx;
    final y = u * u * ay + 2 * u * t * cy + t * t * by;
    return LatLng(y, x / k);
  });
}
