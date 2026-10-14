import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small stopwatch for driving time: a ring with a top button and a side
/// button (the Basil timer shape). The dark arc and the needle show how
/// much of today's limit is used.
class DrivingTimeGauge extends StatelessWidget {
  const DrivingTimeGauge({
    super.key,
    required this.used,
    this.size = 30,
    this.color = const Color(0xFF121619),
    this.track = const Color(0xFFE9ECEF),
  });

  /// 0..1 of the daily limit.
  final double used;
  final double size;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GaugePainter(used.clamp(0.0, 1.0), color, track),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.used, this.color, this.track);

  final double used;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 200 x 200 grid, then scaled.
    final k = size.width / 200;
    canvas.save();
    canvas.scale(k);
    const stroke = 14.0;
    const center = Offset(100, 112);
    const radius = 72.0;
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Top button and side button.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(78, 12, 44, 12),
        const Radius.circular(6),
      ),
      Paint()..color = color,
    );
    canvas.drawLine(const Offset(46, 44), const Offset(30, 60), ink);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final sweep = math.max(used, 0.01) * 2 * math.pi;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, ink);
    final a = used * 2 * math.pi;
    final tip = Offset(
      center.dx + (radius - 26) * math.sin(a),
      center.dy - (radius - 26) * math.cos(a),
    );
    canvas.drawLine(center, tip, ink..strokeWidth = stroke * 0.95);
    canvas.drawCircle(center, stroke * 1.05, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.used != used || old.color != color || old.track != track;
}
