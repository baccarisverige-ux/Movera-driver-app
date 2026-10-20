import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

/// Black glass shell of the Home island, drawn like a small live screen:
/// faint scan lines, a glass highlight on top and a slow light sweep.
class DigitalIslandShell extends StatefulWidget {
  const DigitalIslandShell({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.duration = const Duration(milliseconds: 620),
    this.curve = Curves.easeOutBack,
    this.calm = false,
    this.offers = false,
  });

  /// Only the width ever changes; the height stays the same.
  final double width;
  final double height;
  final Widget child;

  /// How the width eases to a new size.
  final Duration duration;
  final Curve curve;

  /// No light sweep, e.g. while the driver is on the road.
  final bool calm;

  /// Radar offers are up on Home: a green ring, the radar's green.
  final bool offers;

  /// The offers ring is 2 px and its glow blurs 14 px on screen (the
  /// island is drawn at 80 %).
  static const double offersRingWidth = 2 / 0.8;
  static const double offersGlowBlur = 14 / 0.8;

  static const Color screen = Color(0xFF060708);

  /// Fine white contour around the whole island. Home and the trip draw
  /// the island at 80 %, so this is 0.5 px on screen.
  static const double contourWidth = 0.5 / 0.8;

  /// Text on the screen glows a little, like lit pixels.
  static const List<Shadow> glow = [
    Shadow(color: Color(0x59FFFFFF), blurRadius: 8),
  ];

  @override
  State<DigitalIslandShell> createState() => _DigitalIslandShellState();
}

class _DigitalIslandShellState extends State<DigitalIslandShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(DigitalIslandShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calm != widget.calm) { _syncSweep(); }
  }

  void _syncSweep() {
    if (widget.calm || MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = 1;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.height / 2);
    const ring = MoveraRadarOrb.offerAccent;
    final strength = widget.offers ? 1.0 : 0.0;
    // The ring and glow sit outside the shell's own easing. Always in the
    // tree, so the shell keeps its state when they come and go.
    return DecoratedBox(
      key: const ValueKey<String>('island-exclusive-glow'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: strength <= 0
            ? null
            : [
                BoxShadow(
                  color: ring.withValues(alpha: 0.40 * strength),
                  blurRadius: DigitalIslandShell.offersGlowBlur,
                ),
              ],
      ),
      position: DecorationPosition.background,
      child: DecoratedBox(
        key: const ValueKey<String>('island-exclusive-ring'),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: strength <= 0
              ? null
              : Border.all(
                  color: ring.withValues(alpha: strength),
                  width: DigitalIslandShell.offersRingWidth,
                ),
        ),
        position: DecorationPosition.foreground,
        child: _shell(radius),
      ),
    );
  }

  Widget _shell(BorderRadius radius) {
    return AnimatedContainer(
      width: widget.width,
      height: widget.height,
      duration: widget.duration,
      curve: widget.curve,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111316), DigitalIslandShell.screen],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      // On top of the screen, so nothing inside covers the contour.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Colors.white,
          width: DigitalIslandShell.contourWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ScanLinesPainter()),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) => CustomPaint(
                    painter: _SweepPainter(_sweep.value),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
            // Glass: a soft highlight on the upper half.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: widget.height * 0.5,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x17FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switches island faces like a digital screen: the old face collapses to
/// a bright line, the new one opens from it with a short flicker.
class DigitalFaceSwitcher extends StatefulWidget {
  const DigitalFaceSwitcher({super.key, required this.child});

  /// Give each face its own key; a new key plays the switch.
  final Widget child;

  @override
  State<DigitalFaceSwitcher> createState() => _DigitalFaceSwitcherState();
}

class _DigitalFaceSwitcherState extends State<DigitalFaceSwitcher>
    with SingleTickerProviderStateMixin {
  static const double _split = 0.42;

  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
    value: 1,
  );
  Widget? _previous;
  late Widget _current = widget.child;

  @override
  void didUpdateWidget(covariant DigitalFaceSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key == widget.child.key) {
      _current = widget.child;
      return;
    }
    _previous = _current;
    _current = widget.child;
    if (MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _switch,
      builder: (context, _) {
        final t = _switch.value;
        final previous = _previous;
        final Widget face;
        if (previous != null && t < _split) {
          // Old face squeezes into a line and dims.
          final k = Curves.easeIn.transform(t / _split);
          face = Opacity(
            opacity: 1 - 0.6 * k,
            child: Transform.scale(scaleX: 1 + 0.06 * k, scaleY: 1 - 0.94 * k, child: previous),
          );
        } else {
          final k = previous == null
              ? 1.0
              : ((t - _split) / (1 - _split)).clamp(0.0, 1.0);
          final open = Curves.easeOutCubic.transform(k);
          // A few quick flickers while the new face powers on.
          final flicker = k < 0.14
              ? 0.35
              : k < 0.24
                  ? 0.95
                  : k < 0.32
                      ? 0.55
                      : 1.0;
          face = Opacity(
            opacity: flicker,
            child: Transform.scale(scaleY: 0.06 + 0.94 * open, child: _current),
          );
        }
        // Bright line at the moment of the switch.
        final line = previous == null
            ? 0.0
            : (1 - (t - _split).abs() * 4).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            face,
            if (line > 0)
              IgnorePointer(
                child: Container(
                  height: 1.6,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85 * line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5 * line),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScanLinesPainter extends CustomPainter {
  const _ScanLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var y = 1.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter oldDelegate) => false;
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // The band crosses during the first part of each cycle, then rests.
    final pass = (t / 0.45).clamp(0.0, 1.0);
    if (pass >= 1) { return; }
    const band = 70.0;
    final x = -band + (size.width + band * 2) * pass;
    final rect = Rect.fromLTWH(x - band / 2, 0, band, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.075),
          Colors.white.withValues(alpha: 0),
        ],
        transform: const GradientRotation(math.pi / 14),
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// "Updating" face: the four dots of the hidden total ripple while the
/// last trip's money is still coming in.
class DigitalUpdatingFace extends StatefulWidget {
  const DigitalUpdatingFace({super.key});

  @override
  State<DigitalUpdatingFace> createState() => _DigitalUpdatingFaceState();
}

class _DigitalUpdatingFaceState extends State<DigitalUpdatingFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'UPDATING',
          style: TextStyle(
            color: Color(0xFF9AA4AA),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++) _dot(i),
              const SizedBox(width: 6),
              const Text(
                'kr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  shadows: DigitalIslandShell.glow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Each dot lifts and brightens in turn, like a signal passing through.
  Widget _dot(int i) {
    final phase = (_wave.value - i * 0.16) % 1.0;
    final lift = math.sin(phase * math.pi * 2).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -4 * lift),
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFF7F8A90),
            const Color(0xFF7FB6FF),
            lift,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B8BFF).withValues(alpha: 0.6 * lift),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Text of a message, shared with [DigitalMessageFace.widthFor].
const TextStyle messageStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.1,
  shadows: DigitalIslandShell.glow,
);

/// A message on the island's screen: a lit icon in the message's colour
/// and a few words, centred; a small arrow when tapping does something.
class DigitalMessageFace extends StatefulWidget {
  const DigitalMessageFace({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    this.pulse = false,
    this.tappable = false,
  });

  final String title;
  final Color color;
  final IconData icon;

  /// A live dot (e.g. "online") breathes instead of showing an icon.
  final bool pulse;

  /// Shows a small arrow: tapping the island acts on the message.
  final bool tappable;

  static const double _lamp = 24;
  static const double _gap = 9;
  static const double _arrow = 18;

  /// Width the face needs in [context]: lamp, gap, text and arrow.
  static double widthFor(BuildContext context, String title, {bool tappable = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        // The app's text style, as the words get it inside the island
        // (the caller may sit above the Scaffold that provides it).
        style: (Theme.of(context).textTheme.bodyMedium ??
                DefaultTextStyle.of(context).style)
            .merge(messageStyle),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return 2 * (_lamp + _gap) + painter.width;
  }

  @override
  State<DigitalMessageFace> createState() => _DigitalMessageFaceState();
}

class _DigitalMessageFaceState extends State<DigitalMessageFace>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// The words are written in from left to right while the island resizes.
  late final AnimationController _write = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (!widget.pulse || still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
    if (still) {
      _write.value = 1;
    } else if (_write.value == 0 && !_write.isAnimating) {
      _write.forward();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _write.dispose();
    super.dispose();
  }

  Widget _written(Widget text) => AnimatedBuilder(
        animation: _write,
        child: text,
        builder: (context, child) {
          final v = Curves.easeOutCubic.transform(_write.value);
          if (v >= 1) { return child!; }
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
              stops: [0, v, math.min(1.0, v + 0.14)],
            ).createShader(rect),
            child: child,
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    const lamp = DigitalMessageFace._lamp;
    final Widget light = widget.pulse
        ? AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              final t = _breath.value;
              return SizedBox(
                width: lamp,
                height: lamp,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35 + 0.4 * t),
                          blurRadius: 6 + 8 * t,
                          spreadRadius: 1 + 3 * t,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : Container(
            width: lamp,
            height: lamp,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8),
              ],
            ),
            child: Icon(widget.icon, size: 14, color: color),
          );
    final face = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          light,
          const SizedBox(width: DigitalMessageFace._gap),
          Flexible(
            child: _written(_TickerLine(text: widget.title, style: messageStyle)),
          ),
          SizedBox(width: DigitalMessageFace._lamp + DigitalMessageFace._gap,
            child: widget.tappable ? const Align(alignment: Alignment.centerRight,
              child: Icon(Icons.chevron_right_rounded, size: DigitalMessageFace._arrow,
                color: Color(0xFF9AA4AA))) : null),
        ],
      ),
    );
    // While the island morphs it can be narrower than the lamp and arrow
    // for a frame; the face is clipped then instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        const least = 2 * (DigitalMessageFace._lamp + DigitalMessageFace._gap);
        if (constraints.maxWidth >= least) { return face; }
        return ClipRect(
          child: OverflowBox(minWidth: 0, maxWidth: least, child: face),
        );
      },
    );
  }
}

/// Long copy remains accessible without moving the message away from center.
class _TickerLine extends StatelessWidget {
  const _TickerLine({required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Tooltip(message: text,
    child: Text(text, textAlign: TextAlign.center, maxLines: 1,
      overflow: TextOverflow.ellipsis, style: style));
}

/// Island pieces shared by Home and the trip screen, so both islands look
/// and read the same.
class DigitalIslandParts {
  DigitalIslandParts._();

  /// Island height before the 80 % scale both screens draw it at.
  static const double height = 50.4;

  /// Normal width, before the scale.
  static const double width = 244;

  // Sample figures until earnings come from the backend.
  static const String sampleToday = '183.25 kr';
  static const String sampleLastTrip = '126 kr';

  /// Menu icon; its arrow points right, the way the menu slides in.
  static Widget menuIcon() => Transform.flip(
        flipX: true,
        child: const Icon(
          Icons.menu_open_rounded,
          size: 24,
          color: Colors.white,
          shadows: DigitalIslandShell.glow,
        ),
      );

  /// The blue arrow, with a small magnifier saying "search".
  static const Widget searchIcon = Stack(
    alignment: Alignment.center,
    children: [
      Icon(
        Icons.navigation_rounded,
        size: 24,
        color: Color(0xFF3B8BFF),
        shadows: [Shadow(color: Color(0x803B8BFF), blurRadius: 10)],
      ),
      Positioned(
        right: 9,
        bottom: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: SizedBox(
            width: 15,
            height: 15,
            child: Icon(Icons.search_rounded, size: 11, color: Colors.black),
          ),
        ),
      ),
    ],
  );

  // Faces shrink to fit rather than overflow on narrow phones.
  static Widget _fit(Widget child) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);

  static const TextStyle _label = TextStyle(
    color: Color(0xFF9AA4AA),
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  /// The hidden total, "•••• kr".
  static Widget hiddenFace() => Center(
        key: const ValueKey<String>('island-hidden'),
        child: _fit(const Text(
          '•••• kr',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            shadows: DigitalIslandShell.glow,
          ),
        )),
      );

  /// A small label over an amount, e.g. "TODAY" / "183.25 kr".
  static Widget amountFace(String key, String label, String value) => Column(
        key: ValueKey<String>(key),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: _label),
          const SizedBox(height: 2),
          _fit(Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: DigitalIslandShell.glow,
            ),
          )),
        ],
      );

  /// "SLIDE TO OPEN / Ride history".
  static Widget historyFace() => Column(
        key: const ValueKey<String>('island-history'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('SLIDE TO OPEN', style: _label),
          const SizedBox(height: 2),
          _fit(const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ride history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: DigitalIslandShell.glow,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: 18,
                color: Color(0xFF3B8BFF),
              ),
            ],
          )),
        ],
      );

  /// Colour and icon of a message tone.
  static (Color, IconData) toneLook(IslandTone tone) => switch (tone) {
        IslandTone.success => (const Color(0xFF2BD47D), Icons.check_rounded),
        IslandTone.info => (const Color(0xFF4C97FF), Icons.info_outline_rounded),
        IslandTone.warning =>
          (const Color(0xFFFFB020), Icons.priority_high_rounded),
        IslandTone.alert => (const Color(0xFFFF5A4E), Icons.close_rounded),
      };
}
