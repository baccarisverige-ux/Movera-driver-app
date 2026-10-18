import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum OfferRoutePinKind { pickup, dropoff }

/// R11-7: the pins of an offer's route on Home, each with a white time chip.
///
/// - Pickup: a Movera-green dot with a white ring, the chip on its LEFT
///   with the minutes to drive there ("7 min").
/// - Drop-off: a black square with a white ring, the chip on its RIGHT
///   with the trip's own length ("30 min").
///
/// Pin and chip are one marker bitmap; [anchor] puts the pin's centre on
/// the point, so the chip sits beside it on web and native alike.
class OfferRoutePins {
  const OfferRoutePins._();

  static const Color green = Color(0xFF5FB87D);
  static const Color ink = Color(0xFF111614);

  /// Font for the chip text; null uses the platform font, as the app does.
  @visibleForTesting
  static String? debugFontFamily;

  static const double _ratio = 3;
  static const double _margin = 5; // room for the shadows
  static const double _pinBox = 24;
  static const double _gap = 6;
  static const double _chipHeight = 28;
  static const double _chipPadH = 11;

  /// "7 min": never "0 min".
  static String minutes(int value) => '${math.max(1, value)} min';

  static Size size(String label) {
    final text = _text(label);
    final chipWidth = text.width + _chipPadH * 2;
    return Size(
      _margin * 2 + chipWidth + _gap + _pinBox,
      _margin * 2 + math.max(_chipHeight, _pinBox),
    );
  }

  /// The pin's centre inside the bitmap, as a marker anchor.
  static Offset anchor(OfferRoutePinKind kind, String label) {
    final s = size(label);
    final x = kind == OfferRoutePinKind.pickup
        ? s.width - _margin - _pinBox / 2
        : _margin + _pinBox / 2;
    return Offset(x / s.width, 0.5);
  }

  static void paint(
    Canvas canvas,
    Size size,
    OfferRoutePinKind kind,
    String label,
  ) {
    final text = _text(label);
    final chipWidth = text.width + _chipPadH * 2;
    final cy = size.height / 2;
    final pickup = kind == OfferRoutePinKind.pickup;
    final pinCenter = Offset(
      pickup ? size.width - _margin - _pinBox / 2 : _margin + _pinBox / 2,
      cy,
    );
    final chipLeft = pickup ? _margin : _margin + _pinBox + _gap;
    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(chipLeft, cy - _chipHeight / 2, chipWidth, _chipHeight),
      const Radius.circular(_chipHeight / 2),
    );
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5);
    canvas.drawRRect(chip.shift(const Offset(0, 1.5)), shadow);
    canvas.drawRRect(chip, Paint()..color = Colors.white);
    text.paint(
      canvas,
      Offset(chip.left + _chipPadH, cy - text.height / 2),
    );
    paintPin(canvas, pinCenter, kind);
  }

  /// The bare pin centred on [center].
  static void paintPin(Canvas canvas, Offset center, OfferRoutePinKind kind) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.8);
    final white = Paint()..color = Colors.white;
    if (kind == OfferRoutePinKind.pickup) {
      canvas.drawCircle(center.translate(0, 1), 10.5, shadow);
      canvas.drawCircle(center, 10.5, white);
      canvas.drawCircle(center, 7.5, Paint()..color = green);
    } else {
      RRect square(double half, double r) => RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: half * 2, height: half * 2),
        Radius.circular(r),
      );
      canvas.drawRRect(square(10, 3.5).shift(const Offset(0, 1)), shadow);
      canvas.drawRRect(square(10, 3.5), white);
      canvas.drawRRect(square(7, 1.5), Paint()..color = ink);
    }
  }

  static final Map<String, Future<BitmapDescriptor>> _cache = {};

  /// The marker bitmap for [kind] with [label]; cached per label.
  static Future<BitmapDescriptor> icon(OfferRoutePinKind kind, String label) =>
      _cache.putIfAbsent('${kind.name}|$label', () => _toBitmap(kind, label));

  static Future<BitmapDescriptor> _toBitmap(
    OfferRoutePinKind kind,
    String label,
  ) async {
    final s = size(label);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_ratio);
    paint(canvas, s, kind, label);
    final image = await recorder.endRecording().toImage(
      (s.width * _ratio).ceil(),
      (s.height * _ratio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: _ratio,
    );
  }

  static TextPainter _text(String s) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 1.1,
        fontFamily: debugFontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}
