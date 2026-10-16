import 'package:flutter/material.dart';

/// Top lip of the radar sheet (left corner → notch cradle → right corner),
/// matching [RadarSheetClipper].
Path radarSheetTopEdge(
  Size size, {
  required double notchWidth,
  required double notchDepth,
  required double cornerRadius,
  bool includeCorners = false,
}) {
  final path = Path();
  final centerX = size.width / 2;
  final notchLeft = centerX - (notchWidth / 2);
  final notchRight = centerX + (notchWidth / 2);
  final radius = cornerRadius.clamp(0.0, size.width / 2).toDouble();

  if (includeCorners) {
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
  } else {
    path.moveTo(radius, 0);
  }
  path.lineTo(notchLeft, 0);
  path.cubicTo(notchLeft + 9, 0, centerX - 54, notchDepth, centerX, notchDepth);
  path.cubicTo(centerX + 54, notchDepth, notchRight - 9, 0, notchRight, 0);
  path.lineTo(size.width - radius, 0);
  if (includeCorners) {
    path.quadraticBezierTo(size.width, 0, size.width, radius);
  }
  return path;
}

/// Fine grey contour along the top lip of the radar sheet.
class RadarSheetOutline extends StatelessWidget {
  final double notchWidth;
  final double notchDepth;
  final double cornerRadius;
  final Color color;

  /// The line's width; 2 while an Exclusive offer turns it blue.
  final double strokeWidth;

  const RadarSheetOutline({
    super.key,
    this.notchWidth = 126,
    this.notchDepth = 58,
    this.cornerRadius = 24,
    this.color = const Color(0xFFCDD2D6),
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarSheetOutlinePainter(
        notchWidth: notchWidth,
        notchDepth: notchDepth,
        cornerRadius: cornerRadius,
        color: color,
        strokeWidth: strokeWidth,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarSheetOutlinePainter extends CustomPainter {
  final double notchWidth;
  final double notchDepth;
  final double cornerRadius;
  final Color color;
  final double strokeWidth;

  const _RadarSheetOutlinePainter({
    required this.notchWidth,
    required this.notchDepth,
    required this.cornerRadius,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) { return; }
    final edge = radarSheetTopEdge(
      size,
      notchWidth: notchWidth,
      notchDepth: notchDepth,
      cornerRadius: cornerRadius,
      includeCorners: true,
    );
    // Half the line inside the sheet so the clip does not cut it.
    canvas.translate(0, strokeWidth / 2);
    canvas.drawPath(
      edge,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarSheetOutlinePainter oldDelegate) {
    return oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Radar live on the sheet edge: the whole top lip (corners and notch) turns
/// [color], and a soft white light glides along it, left to right, on a loop.
/// Visible only when the caller mounts it (Trip radar ON).
class RadarEdgeDash extends StatefulWidget {
  final double notchWidth;
  final double notchDepth;
  final double cornerRadius;
  final Color color;
  final Duration duration;

  const RadarEdgeDash({
    super.key,
    this.notchWidth = 126,
    this.notchDepth = 58,
    this.cornerRadius = 24,
    this.color = const Color(0xFF1FA463),
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  State<RadarEdgeDash> createState() => _RadarEdgeDashState();
}

class _RadarEdgeDashState extends State<RadarEdgeDash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _RadarEdgeSweepPainter(
            progress: _controller.value,
            notchWidth: widget.notchWidth,
            notchDepth: widget.notchDepth,
            cornerRadius: widget.cornerRadius,
            color: widget.color,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RadarEdgeSweepPainter extends CustomPainter {
  final double progress;
  final double notchWidth;
  final double notchDepth;
  final double cornerRadius;
  final Color color;

  const _RadarEdgeSweepPainter({
    required this.progress,
    required this.notchWidth,
    required this.notchDepth,
    required this.cornerRadius,
    required this.color,
  });

  /// Length of the light, in logical pixels along the edge.
  static const double _lightLength = 160;
  static const int _segments = 20;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) { return; }
    final edge = radarSheetTopEdge(
      size,
      notchWidth: notchWidth,
      notchDepth: notchDepth,
      cornerRadius: cornerRadius,
      includeCorners: true,
    );
    final metrics = edge.computeMetrics().toList();
    if (metrics.isEmpty) { return; }
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) { return; }

    // Same half-pixel inset as [RadarSheetOutline].
    canvas.translate(0, 0.5);
    canvas.drawPath(
      edge,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // The light enters before the left corner and leaves after the right.
    final head = progress.clamp(0.0, 1.0) * (total + _lightLength) -
        _lightLength / 2;
    const step = _lightLength / _segments;
    final light = Color.lerp(color, Colors.white, 0.75)!;
    for (var i = 0; i < _segments; i++) {
      final from = head - _lightLength / 2 + i * step;
      final to = from + step + 0.6;
      if (to < 0 || from > total) { continue; }
      // Brightest in the middle of the light, fading to both ends.
      final k = 1 - ((i + 0.5) - _segments / 2).abs() / (_segments / 2);
      canvas.drawPath(
        metric.extractPath(from.clamp(0.0, total), to.clamp(0.0, total)),
        Paint()
          ..color = light.withValues(alpha: k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + 0.9 * k
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarEdgeSweepPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.color != color;
  }
}
