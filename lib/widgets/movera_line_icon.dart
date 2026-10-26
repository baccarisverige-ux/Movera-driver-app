import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thin stroke mark. Same family as the ride instruction cues.
enum MoveraMark {
  pin,
  route,
  star,
  close,
  timer,
  lock,
  sync,
  calendar,
  place,
  wallet,
  insights,
  car,
  city,
  trend,
  explore,
  bolt,
  check,
  receipt,
  phone,
  message,
  arrow,
  user,
  warning,
  more,
  shield,
}

class MoveraLineIcon extends StatelessWidget {
  const MoveraLineIcon({
    super.key,
    required this.mark,
    required this.size,
    required this.color,
  });

  final MoveraMark mark;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LinePainter(mark: mark, color: color),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.mark, required this.color});

  final MoveraMark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final stroke = 1.7;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (mark) {
      case MoveraMark.pin:
      case MoveraMark.place:
        canvas.drawCircle(const Offset(12, 10), 3, paint);
        canvas.drawPath(
          Path()
            ..moveTo(12, 21.5)
            ..cubicTo(12, 21.5, 5, 15.2, 5, 10)
            ..arcToPoint(
              const Offset(19, 10),
              radius: const Radius.circular(7),
              clockwise: true,
            )
            ..cubicTo(19, 15.2, 12, 21.5, 12, 21.5),
          paint,
        );
      case MoveraMark.route:
        canvas.drawCircle(const Offset(7, 18), 2.2, paint);
        canvas.drawCircle(const Offset(17, 6), 2.2, paint);
        canvas.drawPath(
          Path()
            ..moveTo(9, 17)
            ..cubicTo(13, 16, 11, 8, 15, 7),
          paint,
        );
      case MoveraMark.star:
        canvas.drawPath(_star(), paint);
      case MoveraMark.close:
        canvas.drawLine(const Offset(7, 7), const Offset(17, 17), paint);
        canvas.drawLine(const Offset(17, 7), const Offset(7, 17), paint);
      case MoveraMark.timer:
        canvas.drawCircle(const Offset(12, 13), 7, paint);
        canvas.drawLine(const Offset(12, 13), const Offset(12, 9), paint);
        canvas.drawLine(const Offset(12, 13), const Offset(15, 14.5), paint);
        canvas.drawLine(const Offset(9, 4), const Offset(15, 4), paint);
      case MoveraMark.lock:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6, 11, 12, 8),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawArc(
          const Rect.fromLTWH(8, 5, 8, 8),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case MoveraMark.sync:
        canvas.drawArc(
          const Rect.fromLTWH(5, 5, 12, 12),
          -0.6,
          4.2,
          false,
          paint,
        );
        canvas.drawLine(const Offset(16, 6), const Offset(17.5, 4), paint);
        canvas.drawLine(const Offset(16, 6), const Offset(14, 4.5), paint);
      case MoveraMark.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.5, 6, 15, 13.5),
            const Radius.circular(2.5),
          ),
          paint,
        );
        canvas.drawLine(const Offset(4.5, 10), const Offset(19.5, 10), paint);
        canvas.drawLine(const Offset(8, 4), const Offset(8, 7.5), paint);
        canvas.drawLine(const Offset(16, 4), const Offset(16, 7.5), paint);
      case MoveraMark.wallet:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 7, 16, 11),
            const Radius.circular(2.5),
          ),
          paint,
        );
        canvas.drawLine(const Offset(4, 10), const Offset(20, 10), paint);
        canvas.drawCircle(
          const Offset(15.5, 13.5),
          0.8,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      case MoveraMark.insights:
        canvas.drawLine(const Offset(5, 19), const Offset(19, 19), paint);
        canvas.drawLine(const Offset(7, 19), const Offset(7, 12), paint);
        canvas.drawLine(const Offset(12, 19), const Offset(12, 7), paint);
        canvas.drawLine(const Offset(17, 19), const Offset(17, 10), paint);
      case MoveraMark.car:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 11, 16, 6),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 11)
            ..lineTo(9, 7.5)
            ..lineTo(15, 7.5)
            ..lineTo(17, 11),
          paint,
        );
        canvas.drawCircle(const Offset(8, 17), 1.3, paint);
        canvas.drawCircle(const Offset(16, 17), 1.3, paint);
      case MoveraMark.city:
        canvas.drawRect(const Rect.fromLTWH(4, 10, 6, 9), paint);
        canvas.drawRect(const Rect.fromLTWH(10, 5, 6, 14), paint);
        canvas.drawRect(const Rect.fromLTWH(16, 12, 4, 7), paint);
      case MoveraMark.trend:
        canvas.drawPath(
          Path()
            ..moveTo(4, 16)
            ..lineTo(9, 11)
            ..lineTo(13, 14)
            ..lineTo(20, 6),
          paint,
        );
        canvas.drawLine(const Offset(15, 6), const Offset(20, 6), paint);
        canvas.drawLine(const Offset(20, 6), const Offset(20, 11), paint);
      case MoveraMark.explore:
        canvas.drawCircle(const Offset(12, 12), 8, paint);
        canvas.drawLine(const Offset(12, 7), const Offset(12, 17), paint);
        canvas.drawLine(const Offset(7, 12), const Offset(17, 12), paint);
      case MoveraMark.bolt:
        canvas.drawPath(
          Path()
            ..moveTo(13, 3.5)
            ..lineTo(6, 13)
            ..lineTo(11, 13)
            ..lineTo(10, 20.5)
            ..lineTo(18, 10)
            ..lineTo(13, 10)
            ..close(),
          paint,
        );
      case MoveraMark.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(10, 17.5)
            ..lineTo(19, 7),
          paint,
        );
      case MoveraMark.receipt:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6, 3.5, 12, 17),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawLine(const Offset(9, 8), const Offset(15, 8), paint);
        canvas.drawLine(const Offset(9, 12), const Offset(15, 12), paint);
        canvas.drawLine(const Offset(9, 16), const Offset(13, 16), paint);
      case MoveraMark.phone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 3, 10, 18),
            const Radius.circular(2.5),
          ),
          paint,
        );
        canvas.drawLine(const Offset(10, 17.5), const Offset(14, 17.5), paint);
      case MoveraMark.message:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 5, 17, 11),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawLine(const Offset(7, 16), const Offset(8, 19.5), paint);
        canvas.drawLine(const Offset(8, 19.5), const Offset(12, 16), paint);
      case MoveraMark.arrow:
        canvas.drawLine(const Offset(9, 6), const Offset(15, 12), paint);
        canvas.drawLine(const Offset(15, 12), const Offset(9, 18), paint);
      case MoveraMark.user:
        canvas.drawCircle(const Offset(12, 8), 3, paint);
        canvas.drawArc(
          const Rect.fromLTWH(6, 13, 12, 10),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case MoveraMark.warning:
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..lineTo(21, 19)
            ..lineTo(3, 19)
            ..close(),
          paint,
        );
        canvas.drawLine(const Offset(12, 10), const Offset(12, 14), paint);
      case MoveraMark.more:
        canvas.drawCircle(
          const Offset(6, 12),
          1.1,
          paint..style = PaintingStyle.fill,
        );
        canvas.drawCircle(const Offset(12, 12), 1.1, paint);
        canvas.drawCircle(const Offset(18, 12), 1.1, paint);
        paint.style = PaintingStyle.stroke;
      case MoveraMark.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..lineTo(19, 6.5)
            ..lineTo(19, 12)
            ..cubicTo(19, 16.5, 15.5, 19.5, 12, 21)
            ..cubicTo(8.5, 19.5, 5, 16.5, 5, 12)
            ..lineTo(5, 6.5)
            ..close(),
          paint,
        );
    }
  }

  Path _star() {
    const points = <Offset>[
      Offset(12, 3.5),
      Offset(14.2, 9),
      Offset(20, 9.4),
      Offset(15.6, 13.2),
      Offset(17, 19),
      Offset(12, 15.8),
      Offset(7, 19),
      Offset(8.4, 13.2),
      Offset(4, 9.4),
      Offset(9.8, 9),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.color != color;
}
