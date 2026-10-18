import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Owns only the capsule's motion, never trip state or the map camera.
/// Content is laid out at its destination size and clipped, never scaled.
class IslandMorph extends StatefulWidget {
  const IslandMorph({
    super.key,
    required this.size,
    required this.face,
    required this.child,
    this.radius,
    this.shell = true,
    this.reducedMotion = false,
    this.followSize = false,
  });

  /// The parent animates the size itself (the strip tucking under the
  /// island): while the face stays the same, take each size as it comes,
  /// without a spring or a crossfade.
  final bool followSize;

  /// False when the child draws its own island (the Home island), so the
  /// outline is never doubled. Fades with the morph.
  final bool shell;

  /// The fine white contour around every island shape, 0.5 px.
  static const double contourWidth = 0.5;

  final Size size;

  /// Corner radius; a pill (half the height) when omitted. Morphs with size.
  final double? radius;
  final Object face;
  final Widget child;
  final bool reducedMotion;

  @override
  State<IslandMorph> createState() => _IslandMorphState();
}

class _IslandMorphState extends State<IslandMorph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addStatusListener(_settled);
  late Size _from = widget.size;
  late Size _to = widget.size;
  late double _fromRadius = _radiusOf(widget);
  late double _toRadius = _radiusOf(widget);
  late double _fromShell = widget.shell ? 1 : 0;
  late double _toShell = widget.shell ? 1 : 0;
  double get _visibleShell => _fromShell + (_toShell - _fromShell) * _phase;

  static double _radiusOf(IslandMorph w) => w.radius ?? w.size.height / 2;
  List<_IslandLayer> _outgoing = [];

  double get _incomingOpacity =>
      _outgoing.isEmpty ? 1 : ((_phase - .15) / .85).clamp(0, 1);

  double get _phase => _motion.value.clamp(0.0, 1.0);
  Size get _visible => Size.lerp(_from, _to, _phase)!;
  double get _visibleRadius => _fromRadius + (_toRadius - _fromRadius) * _phase;

  void _settled(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // Land exactly on the final size once the spring has settled.
    if (_motion.value != 1) _motion.value = 1;
    if (_outgoing.isNotEmpty) setState(() => _outgoing = []);
  }

  @override
  void didUpdateWidget(IslandMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion) {
      _motion.stop();
      _from = _to = widget.size;
      _fromRadius = _toRadius = _radiusOf(widget);
      _fromShell = _toShell = widget.shell ? 1 : 0;
      _outgoing = [];
      _motion.value = 1;
      return;
    }
    // Same size: no morph, no crossfade. Only the content changes.
    if (widget.size == _to &&
        _radiusOf(widget) == _toRadius &&
        (widget.shell ? 1 : 0) == _toShell) {
      return;
    }
    if (widget.followSize &&
        oldWidget.followSize &&
        widget.face == oldWidget.face &&
        !_motion.isAnimating) {
      setState(() {
        _from = _to = widget.size;
        _fromRadius = _toRadius = _radiusOf(widget);
        _fromShell = _toShell = widget.shell ? 1 : 0;
      });
      return;
    }
    final visible = _visible;
    final visibleRadius = _visibleRadius;
    final visibleShell = _visibleShell;
    final oldDelta = Size(_to.width - _from.width, _to.height - _from.height);
    final nextDelta = Size(
      widget.size.width - visible.width,
      widget.size.height - visible.height,
    );
    final length =
        nextDelta.width * nextDelta.width + nextDelta.height * nextDelta.height;
    // Project the current geometric velocity onto the new target. Preserve
    // continuity without carrying excessive momentum into a short resize.
    final velocity = length < 1
        ? 0.0
        : ((_motion.velocity *
                      (oldDelta.width * nextDelta.width +
                          oldDelta.height * nextDelta.height)) /
                  length)
              .clamp(0.0, 3.0)
              .toDouble();
    // Capture the opacity of every visible layer as well as its geometry.
    // A rapid new instruction must not flash an only-partly-visible face.
    final fade = (1 - _phase / .35).clamp(0.0, 1.0);
    final layers = [
      for (final layer in _outgoing)
        if (layer.opacity * fade > .01)
          _IslandLayer(layer.child, layer.size, layer.opacity * fade),
      if (_incomingOpacity > .01)
        _IslandLayer(oldWidget.child, oldWidget.size, _incomingOpacity),
    ];
    _motion.stop();
    _outgoing = layers;
    _from = visible;
    _to = widget.size;
    _fromRadius = visibleRadius;
    _toRadius = _radiusOf(widget);
    _fromShell = visibleShell;
    _toShell = widget.shell ? 1 : 0;
    _motion.value = 0;
    _motion.animateWith(
      SpringSimulation(
        // About half a second with a soft settle, like the iPhone island.
        const SpringDescription(mass: 1, stiffness: 210, damping: 25),
        0,
        1,
        velocity,
        tolerance: const Tolerance(distance: .001, velocity: .01),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Widget _face(
    Widget child,
    Size size,
    double opacity, {
    bool outgoing = false,
  }) => Positioned.fill(
    child: IgnorePointer(
      ignoring: outgoing || opacity < .5,
      child: ExcludeSemantics(
        excluding: outgoing || opacity < .5,
        child: Opacity(
          opacity: opacity,
          // Content arrives a little soft and small, then settles sharp.
          child: ImageFiltered(
            enabled: opacity < .99,
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 5 * (1 - opacity),
              sigmaY: 5 * (1 - opacity),
            ),
            child: Transform.scale(
              scale: .96 + .04 * opacity,
              alignment: Alignment.topCenter,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: size.width,
                maxWidth: size.width,
                minHeight: size.height,
                maxHeight: size.height,
                child: SizedBox.fromSize(size: size, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final size = _visible;
      final t = _phase;
      return RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('island-morph-shell'),
          width: size.width,
          height: size.height,
          // One island, the same black glass as on Home.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_visibleRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF111316).withValues(alpha: _visibleShell),
                  const Color(0xFF060708).withValues(alpha: _visibleShell),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0x40000000,
                  ).withValues(alpha: .25 * _visibleShell),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // The contour sits on top of the faces, around the whole
            // shape, and fades with the shell.
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_visibleRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _visibleShell),
                  width: IslandMorph.contourWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_visibleRadius),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (t < .35)
                      for (final layer in _outgoing)
                        _face(
                          layer.child,
                          layer.size,
                          layer.opacity * (1 - t / .35).clamp(0, 1),
                          outgoing: true,
                        ),
                    _face(widget.child, widget.size, _incomingOpacity),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _IslandLayer {
  const _IslandLayer(this.child, this.size, this.opacity);
  final Widget child;
  final Size size;
  final double opacity;
}
