import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';

/// A subtle activity lane, deliberately not a route-progress percentage.
class IslandWaitingLane extends StatefulWidget {
  const IslandWaitingLane({super.key, required this.color});
  final Color color;
  @override
  State<IslandWaitingLane> createState() => _IslandWaitingLaneState();
}

class _IslandWaitingLaneState extends State<IslandWaitingLane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
      _motion.value = .5;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr.waitingInProgress,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => SizedBox(
          width: double.infinity,
          height: 3,
          child: CustomPaint(
            painter: _LanePainter(widget.color, _motion.value),
          ),
        ),
      ),
    ),
  );
}

class _LanePainter extends CustomPainter {
  _LanePainter(this.color, this.phase);
  final Color color;
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final round = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(round, Paint()..color = const Color(0xFF353C46));
    canvas.save();
    canvas.clipRRect(round);
    final width = size.width * .22;
    final left = (size.width + width) * phase - width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        const Radius.circular(2),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: .15),
            color,
            color.withValues(alpha: .15),
          ],
        ).createShader(Rect.fromLTWH(left, 0, width, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      color != old.color || phase != old.phase;
}

/// Only digits that changed roll. Tabular widths prevent horizontal jitter.
class IslandRollingClock extends StatelessWidget {
  const IslandRollingClock({
    super.key,
    required this.text,
    required this.style,
  });
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var n = 0; n < text.length; n++)
        ClipRect(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .35),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
            child: Text(
              text[n],
              key: ValueKey('$n-${text[n]}'),
              style: style,
              maxLines: 1,
            ),
          ),
        ),
    ],
  );
}
