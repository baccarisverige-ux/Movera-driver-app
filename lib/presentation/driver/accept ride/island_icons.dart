import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';

/// Roundabout for right-hand traffic (Sweden): enter from the bottom, drive
/// counterclockwise, leave at the exit's direction, exit number on a badge.
class RoundaboutCuePainter extends CustomPainter {
  const RoundaboutCuePainter({
    required this.exitDegrees,
    this.exitNumber,
    this.color = Colors.white,
    this.badge = const Color(0xFF58A6FF),
    this.fontFamily,
    this.clockwise = false,
  });

  /// Driven clockwise (left-hand traffic): the same drawing mirrored.
  final bool clockwise;

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
    // Mirrored for clockwise traffic; the exit is mirrored with it so the
    // arrow still leaves towards the real exit.
    canvas.save();
    if (clockwise) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final degrees = clockwise ? 180 - exitDegrees : exitDegrees;
    canvas.drawLine(Offset(o.dx, size.height * .97), o + Offset(0, r), line);
    const start = math.pi / 2;
    var sweep = -degrees * math.pi / 180 - start;
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
    canvas.restore();
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
      old.color != color ||
      old.clockwise != clockwise;
}

/// Arriving icon: a short road in perspective with a pin on a post at the
/// roadside. Pin colour by point: green pickup, white stop, red drop-off.
class ArrivingRoadPainter extends CustomPainter {
  const ArrivingRoadPainter({required this.pin});

  final Color pin;

  static const road = Color(0xFF6B737B);
  static const pickup = Color(0xFF5FB87D);
  static const stop = Colors.white;
  static const dropOff = Color(0xFFE5484D);

  /// 'Pickup', 'Stop 2', 'Destination' -> the pin colour. The labels come
  /// in the driver's language ("Arrêt 2", "Upphämtning").
  static Color pinFor(String? label) {
    final l = (label ?? '').toLowerCase();
    if (l.startsWith('pickup') || l.startsWith(tr.pickup.toLowerCase())) {
      return pickup;
    }
    if (isStop(label)) return stop;
    return dropOff;
  }

  /// "Stop 2" in any of the app's languages.
  static bool isStop(String? label) {
    final l = (label ?? '').toLowerCase();
    final word = tr.stopNumber('').trim().toLowerCase();
    return l.startsWith('stop') || (word.isNotEmpty && l.startsWith(word));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final u = size.shortestSide;
    canvas.drawPath(
      Path()
        ..moveTo(w * .06, h * .97)
        ..lineTo(w * .40, h * .30)
        ..lineTo(w * .52, h * .30)
        ..lineTo(w * .80, h * .97)
        ..close(),
      Paint()..color = road,
    );
    // Dashed centre line, the dashes shorter towards the horizon.
    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = u * .045
      ..strokeCap = StrokeCap.butt;
    double cx(double y) => w * .43 + (w * .46 - w * .43) * (y - .30) / .67;
    for (final (a, b) in [(.36, .45), (.53, .66), (.75, .93)]) {
      canvas.drawLine(Offset(cx(a), h * a), Offset(cx(b), h * b), dash);
    }
    // Short post at the roadside, then the pin on top.
    final post = Offset(w * .80, h * .62);
    canvas.drawLine(
      post,
      Offset(post.dx, h * .36),
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..strokeWidth = u * .06
        ..strokeCap = StrokeCap.round,
    );
    final head = Offset(post.dx, h * .19);
    final r = u * .15;
    final pinPath = Path()
      ..moveTo(head.dx, h * .44)
      ..cubicTo(
        head.dx - r * .55,
        head.dy + r * 1.35,
        head.dx - r,
        head.dy + r * .65,
        head.dx - r,
        head.dy,
      )
      ..arcToPoint(Offset(head.dx + r, head.dy), radius: Radius.circular(r))
      ..cubicTo(
        head.dx + r,
        head.dy + r * .65,
        head.dx + r * .55,
        head.dy + r * 1.35,
        head.dx,
        h * .44,
      )
      ..close();
    canvas.drawPath(pinPath, Paint()..color = pin);
    canvas.drawCircle(
      head,
      r * .38,
      Paint()
        ..color = pin.computeLuminance() > .8
            ? const Color(0xFF0B0C0E)
            : Colors.white,
    );
  }

  @override
  bool shouldRepaint(ArrivingRoadPainter old) => old.pin != pin;
}

/// A road number as a small sign: green E-roads, blue national roads.
class RoadShieldChip extends StatelessWidget {
  const RoadShieldChip(this.shield, {super.key});

  final RoadShield shield;

  static const european = Color(0xFF1E8E4E);
  static const national = Color(0xFF1F5FBF);

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('road-shield-${shield.label}'),
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 4.5),
    height: 17,
    decoration: BoxDecoration(
      color: shield.kind == RoadShieldKind.european ? european : national,
      borderRadius: BorderRadius.circular(3.5),
      border: Border.all(color: Colors.white),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        shield.label,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    ),
  );
}

/// Lane tiles, left to right: lanes to use are a white arrow on green,
/// the others grey on dark. Arrows are the island's own cue shapes.
class LaneGuidanceRow extends StatelessWidget {
  const LaneGuidanceRow({super.key, required this.lanes, this.modifier = ''});

  final List<RouteLane> lanes;
  final String modifier;

  static const use = Color(0xFF2E9E5B);
  static const other = Color(0xFF2A3038);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < lanes.length; i++)
        Container(
          key: ValueKey('lane-$i-${lanes[i].valid ? 'use' : 'other'}'),
          width: 24,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: lanes[i].valid ? use : other,
            borderRadius: BorderRadius.circular(6),
          ),
          child: CustomPaint(
            size: const Size(15, 15),
            painter: NavigationCuePainter(
              symbol: lanes[i].symbolFor(modifier),
              icon: Icons.navigation_rounded,
              color: lanes[i].valid ? Colors.white : const Color(0xFF7C8590),
            ),
          ),
        ),
    ],
  );
}
