import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Roundabout for right-hand traffic (Sweden): enter from the bottom, drive
/// counterclockwise, leave at the exit's direction, exit number on a badge.
class RoundaboutCuePainter extends CustomPainter {
  const RoundaboutCuePainter({
    required this.exitDegrees,
    this.exitNumber,
    this.color = Colors.white,
    this.badge = const Color(0xFF58A6FF),
    this.fontFamily,
  });

  /// Direction of the exit, counterclockwise from the right:
  /// 0 right, 90 straight ahead, 180 left, about 250 back (U-turn).
  final double exitDegrees;
  final String? exitNumber;
  final Color color, badge;
  final String? fontFamily;

  /// Provider angle (clockwise from straight ahead) or, without it, the
  /// usual direction of the numbered exit.
  static double degreesFor({double? exitAngle, String? exitNumber}) {
    if (exitAngle != null && exitAngle.isFinite) {
      final d = (90 - exitAngle) % 360;
      // A U-turn exit sits just beside the entry, not on top of it.
      return d > 240 && d < 300 ? 250 : d;
    }
    return switch (int.tryParse(exitNumber ?? '')) {
      1 => 0,
      2 => 90,
      3 => 180,
      null => 90,
      _ => 250,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final o = Offset(size.width / 2, size.height * .5);
    final r = u * .17, w = u * .09, out = u * .17, head = u * .12;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = color.withValues(alpha: .25),
    );
    canvas.drawLine(Offset(o.dx, size.height * .97), o + Offset(0, r), line);
    const start = math.pi / 2;
    var sweep = -exitDegrees * math.pi / 180 - start;
    while (sweep > -.01) {
      sweep -= 2 * math.pi;
    }
    canvas.drawArc(
      Rect.fromCircle(center: o, radius: r),
      start,
      sweep,
      false,
      line,
    );
    final a = start + sweep;
    final dir = Offset(math.cos(a), math.sin(a));
    final tip = o + dir * (r + out);
    canvas.drawLine(o + dir * r, tip, line);
    final side = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + dir.dx * head * .8, tip.dy + dir.dy * head * .8)
        ..lineTo(tip.dx + side.dx * head * .75, tip.dy + side.dy * head * .75)
        ..lineTo(tip.dx - side.dx * head * .75, tip.dy - side.dy * head * .75)
        ..close(),
      Paint()..color = color,
    );
    final number = exitNumber;
    if (number != null) {
      final centre = Offset(size.width * .86, size.height * .14);
      canvas.drawCircle(centre, u * .19, Paint()..color = badge);
      final text = TextPainter(
        text: TextSpan(
          text: number,
          style: TextStyle(
            color: Colors.white,
            fontSize: u * .26,
            fontWeight: FontWeight.w800,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(RoundaboutCuePainter old) =>
      old.exitDegrees != exitDegrees ||
      old.exitNumber != exitNumber ||
      old.color != color;
}
