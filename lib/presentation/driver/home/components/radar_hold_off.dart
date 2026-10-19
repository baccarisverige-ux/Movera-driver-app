import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

/// Wraps the online radar while the Home sheet is open: holding it for
/// [holdFor] fills a green ring around it, gives one vibration and calls
/// [onConfirmed]. Letting go early, or dragging, undoes the ring.
class RadarHoldOff extends StatefulWidget {
  const RadarHoldOff({
    super.key,
    required this.child,
    required this.onConfirmed,
    this.holdFor = const Duration(milliseconds: 1000),
    this.size = 104,
    this.semanticsLabel = 'Hold to go offline',
    this.holdKey = const ValueKey<String>('home-radar-hold-off'),
  });

  final Widget child;
  final VoidCallback onConfirmed;
  final Duration holdFor;
  final double size;

  /// What a screen reader says, e.g. "Hold to stop next trips".
  final String semanticsLabel;
  final Key holdKey;

  @override
  State<RadarHoldOff> createState() => _RadarHoldOffState();
}

class _RadarHoldOffState extends State<RadarHoldOff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdFor,
    reverseDuration: const Duration(milliseconds: 220),
  )..addStatusListener(_onStatus);

  bool _fired = false;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _fired) { return; }
    _fired = true;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
  }

  void _press() {
    _fired = false;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _release() {
    if (_fired) { return; }
    _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      onLongPress: widget.onConfirmed,
      child: GestureDetector(
        key: widget.holdKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              widget.child,
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => _hold.value == 0
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          size: Size.square(widget.size + 8),
                          painter: _HoldRingPainter(_hold.value),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldRingPainter extends CustomPainter {
  _HoldRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      Paint()
        ..color = MoveraRadarOrb.offerAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) => old.progress != progress;
}
