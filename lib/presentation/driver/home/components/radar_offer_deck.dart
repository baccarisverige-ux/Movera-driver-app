import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Radar offers on Home as a deck of cards: the front card on top, the
/// next two peeking above it.
///
/// - The first time it shows, the front card wiggles once so the driver
///   sees there are more behind.
/// - Swiping the front card sends it to the back; the next one comes
///   forward, and the order keeps cycling.
/// - A trip taken while behind leaves at once. A trip taken while in front
///   blurs out, then the next comes forward.
class RadarOfferDeck extends StatefulWidget {
  const RadarOfferDeck({
    super.key,
    required this.ids,
    required this.cardFor,
    required this.onFrontChanged,
    this.taken = const <String>{},
    this.top,
  });

  /// Offers in their first order.
  final List<String> ids;
  final Widget Function(String id) cardFor;

  /// Called with the id now in front (also on first show).
  final ValueChanged<String?> onFrontChanged;

  /// Offers another driver took.
  final Set<String> taken;

  /// Shown above the deck (the count badge).
  final Widget? top;

  @override
  State<RadarOfferDeck> createState() => _RadarOfferDeckState();
}

class _RadarOfferDeckState extends State<RadarOfferDeck>
    with TickerProviderStateMixin {
  final List<String> _order = <String>[];
  final Set<String> _gone = <String>{};
  String? _reportedFront;
  String? _blurring;

  double _dx = 0;
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _blur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  Animation<double>? _flyAnim;

  @override
  void initState() {
    super.initState();
    _sync();
    _fly.addListener(() {
      final a = _flyAnim;
      if (a != null) { setState(() => _dx = a.value); }
    });
    _hint.addListener(() => setState(() {}));
    _blur.addListener(() => setState(() {}));
    _blur.addStatusListener((status) {
      if (status != AnimationStatus.completed) { return; }
      final id = _blurring;
      if (id == null) { return; }
      setState(() {
        _gone.add(id);
        _blurring = null;
      });
      _blur.value = 0;
      _reportFront();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { return; }
      _reportFront();
      if (_visible.length > 1) { _hint.forward(); }
    });
  }

  @override
  void didUpdateWidget(RadarOfferDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _reportFront(); }
    });
  }

  /// Keep our cycling order; drop removed offers, add new ones at the back.
  void _sync() {
    final ids = widget.ids.toSet();
    _order.removeWhere((id) => !ids.contains(id));
    _gone.removeWhere((id) => !ids.contains(id));
    for (final id in widget.ids) {
      if (!_order.contains(id)) { _order.add(id); }
    }
    final front = _visible.isEmpty ? null : _visible.first;
    // Taken behind: leaves at once. Taken in front: blurs out first.
    for (final id in widget.taken) {
      if (!_order.contains(id) || _gone.contains(id)) { continue; }
      if (id == front) {
        if (_blurring != id) {
          _blurring = id;
          _blur.forward(from: 0);
        }
      } else {
        _gone.add(id);
      }
    }
  }

  List<String> get _visible =>
      _order.where((id) => !_gone.contains(id)).toList(growable: false);

  void _reportFront() {
    final front = _visible.isEmpty ? null : _visible.first;
    if (front == _reportedFront) { return; }
    _reportedFront = front;
    widget.onFrontChanged(front);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_blurring != null || _visible.length < 2) { return; }
    _fly.stop();
    _hint.stop();
    setState(() => _dx += d.delta.dx);
  }

  void _onDragEnd(DragEndDetails d, double width) {
    if (_blurring != null || _visible.length < 2) {
      _animateTo(0);
      return;
    }
    final v = d.primaryVelocity ?? 0;
    final away = _dx.abs() > width * 0.28 || v.abs() > 650;
    if (!away) {
      _animateTo(0);
      return;
    }
    final dir = (_dx == 0 ? v : _dx).sign;
    _animateTo(dir * (width + 60), then: _sendFrontToBack);
  }

  void _animateTo(double target, {VoidCallback? then}) {
    _flyAnim = Tween<double>(begin: _dx, end: target)
        .animate(CurvedAnimation(parent: _fly, curve: Curves.easeOutCubic));
    _fly.forward(from: 0).whenComplete(() {
      if (mounted && then != null) { then(); }
    });
  }

  void _sendFrontToBack() {
    final visible = _visible;
    if (visible.length < 2) { return; }
    HapticFeedback.selectionClick();
    setState(() {
      _order.remove(visible.first);
      _order.add(visible.first);
      _dx = 0;
    });
    _reportFront();
  }

  @override
  void dispose() {
    _fly.dispose();
    _hint.dispose();
    _blur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    if (visible.isEmpty) { return const SizedBox.shrink(); }
    final shown = visible.take(3).toList();
    final h = _hint.value;
    final hintDx = _hint.isAnimating
        ? math.sin(h * math.pi * 2) * -26 * (1 - h * 0.3)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cards = <Widget>[];
        for (var i = shown.length - 1; i >= 0; i--) {
          final id = shown[i];
          // Cards behind sit a little higher and smaller so their top
          // edges peek above the front card.
          const lifts = <double>[0, 27, 54];
          const scales = <double>[1, 0.94, 0.88];
          final front = i == 0;
          final dx = front ? _dx + hintDx : 0.0;
          Widget card = widget.cardFor(id);
          if (front && _blurring == id) {
            final b = _blur.value;
            card = Opacity(
              opacity: 1 - Curves.easeIn.transform(b),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 8 * b, sigmaY: 8 * b),
                child: card,
              ),
            );
          }
          if (front) {
            card = GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: (d) => _onDragEnd(d, width),
              child: card,
            );
          }
          final placed = TweenAnimationBuilder<double>(
            key: ValueKey<String>('deck-slot-$id'),
            tween: Tween<double>(end: i.toDouble()),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, slot, child) {
              final lo = slot.floor().clamp(0, 2);
              final hi = slot.ceil().clamp(0, 2);
              final t = slot - lo;
              final lift = lifts[lo] + (lifts[hi] - lifts[lo]) * t;
              final scale = scales[lo] + (scales[hi] - scales[lo]) * t;
              return Transform.translate(
                offset: Offset(dx, -lift),
                child: Transform.rotate(
                  angle: dx / width * 0.14,
                  alignment: Alignment.bottomCenter,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: card,
          );
          cards.add(placed);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.top != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: 8 + (shown.length > 2 ? 54 : shown.length > 1 ? 27 : 0),
                ),
                child: Center(child: widget.top),
              ),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              fit: StackFit.passthrough,
              children: cards,
            ),
          ],
        );
      },
    );
  }
}
