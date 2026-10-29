import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/onboarding/upload_guide.dart';

/// Owner item 4: the upload guide's example, drawn by Movera in its own
/// plain shapes (a card, a paper, a face, a car from four sides, a
/// sticker). No photo and no other company's picture.
class GuideExampleDrawing extends StatelessWidget {
  const GuideExampleDrawing({super.key, required this.example, this.label});

  final GuideExample example;

  /// Read by screen readers ("Example drawn by Movera").
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          key: ValueKey('guide-example-${example.name}'),
          painter: _ExamplePainter(example),
        ),
      ),
    ),
  );
}

class _ExamplePainter extends CustomPainter {
  _ExamplePainter(this.example);

  final GuideExample example;

  static const _ink = Color(0xFF1C2A23);
  static const _green = Color(0xFF1FA463);
  static const _soft = Color(0xFFCFDAD3);
  static const _paper = Colors.white;

  Paint get _stroke => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _fill(Color color) => Paint()..color = color;

  void _lines(Canvas canvas, Rect area, int count, {double gap = 14}) {
    for (var i = 0; i < count; i++) {
      final y = area.top + i * gap;
      if (y > area.bottom) break;
      final width = area.width * (i.isEven ? 1 : 0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(area.left, y, width, 6),
          const Radius.circular(3),
        ),
        _fill(_soft),
      );
    }
  }

  void _face(Canvas canvas, Rect box) {
    canvas.drawCircle(
      Offset(box.center.dx, box.top + box.height * 0.38),
      box.width * 0.2,
      _fill(_green),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(box.center.dx, box.bottom),
        width: box.width * 0.8,
        height: box.height * 0.7,
      ),
      math.pi,
      math.pi,
      true,
      _fill(_green),
    );
  }

  void _card(Canvas canvas, Size size) {
    final card = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.62,
      height: size.width * 0.62 / 1.586,
    );
    final rounded = RRect.fromRectAndRadius(card, const Radius.circular(12));
    canvas.drawRRect(rounded, _fill(_paper));
    canvas.drawRRect(rounded, _stroke);
    final photo = Rect.fromLTWH(
      card.left + card.width * 0.07,
      card.top + card.height * 0.22,
      card.width * 0.26,
      card.height * 0.6,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(photo, const Radius.circular(6)));
    canvas.drawRect(photo, _fill(const Color(0xFFE3ECE6)));
    _face(canvas, photo);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(card.left, card.top, card.width, card.height * 0.13),
        const Radius.circular(12),
      ),
      _fill(_green),
    );
    _lines(
      canvas,
      Rect.fromLTWH(
        photo.right + card.width * 0.07,
        photo.top + 4,
        card.width * 0.52,
        photo.height,
      ),
      5,
    );
  }

  void _paperSheet(Canvas canvas, Size size) {
    final sheet = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.height * 0.62,
      height: size.height * 0.84,
    );
    final rounded = RRect.fromRectAndRadius(sheet, const Radius.circular(6));
    canvas.drawRRect(rounded, _fill(_paper));
    canvas.drawRRect(rounded, _stroke);
    canvas.drawRect(
      Rect.fromLTWH(sheet.left + 12, sheet.top + 14, sheet.width * 0.4, 9),
      _fill(_green),
    );
    _lines(
      canvas,
      Rect.fromLTWH(
        sheet.left + 12,
        sheet.top + 34,
        sheet.width - 24,
        sheet.height - 60,
      ),
      8,
      gap: 13,
    );
    canvas.drawCircle(
      Offset(sheet.right - 22, sheet.bottom - 20),
      10,
      _stroke..color = _green,
    );
  }

  void _portrait(Canvas canvas, Size size) {
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.height * 0.68,
      height: size.height * 0.84,
    );
    final rounded = RRect.fromRectAndRadius(frame, const Radius.circular(14));
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRRect(rounded, _fill(_paper));
    _face(canvas, frame.deflate(frame.width * 0.08));
    canvas.restore();
    canvas.drawRRect(rounded, _stroke);
  }

  void _plate(Canvas canvas, Offset center, double width) {
    final plate = Rect.fromCenter(
      center: center,
      width: width,
      height: width * 0.3,
    );
    final rounded = RRect.fromRectAndRadius(plate, const Radius.circular(3));
    canvas.drawRRect(rounded, _fill(_paper));
    canvas.drawRRect(rounded, _stroke..strokeWidth = 1.6);
    canvas.drawRect(
      Rect.fromLTWH(plate.left + 4, plate.center.dy - 2, plate.width - 8, 4),
      _fill(_ink),
    );
  }

  void _carFrontOrBack(Canvas canvas, Size size, {required bool front}) {
    final c = size.center(Offset.zero);
    final w = size.width * 0.5;
    final h = size.height * 0.52;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, h * 0.12),
        width: w,
        height: h * 0.6,
      ),
      const Radius.circular(16),
    );
    final cabin = Path()
      ..moveTo(c.dx - w * 0.36, body.top + 2)
      ..lineTo(c.dx - w * 0.26, c.dy - h * 0.5)
      ..lineTo(c.dx + w * 0.26, c.dy - h * 0.5)
      ..lineTo(c.dx + w * 0.36, body.top + 2)
      ..close();
    canvas.drawPath(cabin, _fill(const Color(0xFFDDE8E1)));
    canvas.drawPath(cabin, _stroke);
    canvas.drawRRect(body, _fill(_green));
    canvas.drawRRect(body, _stroke);
    final lightY = body.top + body.height * 0.3;
    for (final dx in [-w * 0.36, w * 0.36]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + dx, lightY),
          width: w * 0.16,
          height: 10,
        ),
        _fill(front ? _paper : const Color(0xFFE25A4A)),
      );
    }
    for (final dx in [-w * 0.38, w * 0.38]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx + dx, body.bottom + 8),
            width: w * 0.14,
            height: 18,
          ),
          const Radius.circular(4),
        ),
        _fill(_ink),
      );
    }
    _plate(canvas, Offset(c.dx, body.top + body.height * 0.66), w * 0.34);
  }

  void _carSide(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width * 0.66;
    final h = size.height * 0.22;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c.translate(0, h * 0.4), width: w, height: h),
      const Radius.circular(14),
    );
    final cabin = Path()
      ..moveTo(c.dx - w * 0.3, body.top + 1)
      ..lineTo(c.dx - w * 0.16, body.top - h * 0.95)
      ..lineTo(c.dx + w * 0.16, body.top - h * 0.95)
      ..lineTo(c.dx + w * 0.32, body.top + 1)
      ..close();
    canvas.drawPath(cabin, _fill(const Color(0xFFDDE8E1)));
    canvas.drawPath(cabin, _stroke);
    canvas.drawLine(
      Offset(c.dx, body.top - h * 0.95),
      Offset(c.dx, body.top),
      _stroke,
    );
    canvas.drawRRect(body, _fill(_green));
    canvas.drawRRect(body, _stroke);
    for (final dx in [-w * 0.3, w * 0.3]) {
      final wheel = Offset(c.dx + dx, body.bottom);
      canvas.drawCircle(wheel, h * 0.42, _fill(_ink));
      canvas.drawCircle(wheel, h * 0.18, _fill(_soft));
    }
  }

  void _carInside(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width * 0.2;
    for (final dx in [-w * 0.75, w * 0.75]) {
      final seat = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(dx, -size.height * 0.08),
          width: w,
          height: size.height * 0.46,
        ),
        const Radius.circular(14),
      );
      canvas.drawRRect(seat, _fill(_green));
      canvas.drawRRect(seat, _stroke);
      final cushion = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(dx, size.height * 0.24),
          width: w * 1.1,
          height: size.height * 0.16,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(cushion, _fill(const Color(0xFF178A52)));
      canvas.drawRRect(cushion, _stroke);
    }
  }

  void _sticker(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final glass = Path()
      ..moveTo(c.dx - size.width * 0.32, c.dy + size.height * 0.32)
      ..lineTo(c.dx - size.width * 0.22, c.dy - size.height * 0.32)
      ..lineTo(c.dx + size.width * 0.22, c.dy - size.height * 0.32)
      ..lineTo(c.dx + size.width * 0.32, c.dy + size.height * 0.32)
      ..close();
    canvas.drawPath(glass, _fill(const Color(0xFFDDE8E1)));
    canvas.drawPath(glass, _stroke);
    final at = Offset(c.dx + size.width * 0.16, c.dy + size.height * 0.16);
    canvas.drawCircle(at, size.height * 0.11, _fill(_green));
    canvas.drawCircle(at, size.height * 0.11, _stroke);
    canvas.drawCircle(at, size.height * 0.05, _fill(_paper));
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (example) {
      case GuideExample.card:
        _card(canvas, size);
      case GuideExample.paper:
        _paperSheet(canvas, size);
      case GuideExample.portrait:
        _portrait(canvas, size);
      case GuideExample.carFront:
        _carFrontOrBack(canvas, size, front: true);
      case GuideExample.carBack:
        _carFrontOrBack(canvas, size, front: false);
      case GuideExample.carSide:
        _carSide(canvas, size);
      case GuideExample.carInside:
        _carInside(canvas, size);
      case GuideExample.sticker:
        _sticker(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_ExamplePainter old) => old.example != example;
}
