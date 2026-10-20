import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';

/// What the Home island says while the driver is online and waiting for a
/// trip (R13-1): "Finding trips" with three dots, and every few seconds a
/// short message for 2.5 s. Any offer or trip, or a touch on the island,
/// puts the island back to normal at once; a touched island picks the
/// waiting messages up again once it has been left alone.
class IslandWaitingController extends ChangeNotifier {
  IslandWaitingController({
    required this.tips,
    this.firstTipAfter = const Duration(seconds: 5),
    this.tipEvery = const Duration(seconds: 7),
    this.tipFor = const Duration(milliseconds: 2500),
    this.resumeAfter = const Duration(seconds: 8),
  });

  /// The messages the app has real facts for right now.
  final List<IslandWaitingTip> Function() tips;

  /// "Finding trips" before the first message, and between two messages.
  final Duration firstTipAfter;
  final Duration tipEvery;

  /// How long a message stays (2–3 s).
  final Duration tipFor;

  /// A touched island waits this long untouched before "Finding trips".
  final Duration resumeAfter;

  bool _waiting = false;
  bool _touched = false;
  bool _swallowTap = false;
  IslandWaitingTip? _tip;
  String? _lastTipId;
  int _next = 0;
  Timer? _timer;

  /// The island shows a waiting face: "Finding trips" or a message.
  bool get showing => _waiting && !_touched;

  /// The message on the island, or null for "Finding trips".
  IslandWaitingTip? get tip => showing ? _tip : null;

  /// Called on every build with whether the driver is online on Home with
  /// no offer and no trip. Starts or stops the waiting faces without
  /// notifying: the caller is building with the new value already.
  bool sync(bool waiting) {
    if (waiting == _waiting) { return showing; }
    _waiting = waiting;
    _timer?.cancel();
    _tip = null;
    _touched = false;
    if (waiting) { _schedule(firstTipAfter, _showTip); }
    return showing;
  }

  /// The driver touched the island: normal behaviour at once. True when a
  /// waiting face was showing, so the touch's tap only closes it.
  bool touch() {
    final hid = showing;
    _swallowTap = hid;
    if (!_waiting) { return hid; }
    _timer?.cancel();
    _tip = null;
    _touched = true;
    _schedule(resumeAfter, () {
      _touched = false;
      notifyListeners();
      _schedule(firstTipAfter, _showTip);
    });
    if (hid) { notifyListeners(); }
    return hid;
  }

  /// True once after a touch that closed a waiting face.
  bool takeSwallowedTap() {
    final swallow = _swallowTap;
    _swallowTap = false;
    return swallow;
  }

  void _schedule(Duration after, VoidCallback run) {
    _timer?.cancel();
    _timer = Timer(after, run);
  }

  void _showTip() {
    final all = tips();
    IslandWaitingTip? pick;
    for (var i = 0; i < all.length; i++) {
      final candidate = all[(_next + i) % all.length];
      // Never the same kind twice in a row (a lone kind still returns
      // after "Finding trips").
      if (candidate.id != _lastTipId || all.length == 1) {
        pick = candidate;
        _next = (_next + i + 1) % all.length;
        break;
      }
    }
    if (pick == null) {
      _schedule(tipEvery, _showTip);
      return;
    }
    _tip = pick;
    _lastTipId = pick.id;
    notifyListeners();
    _schedule(tipFor, () {
      _tip = null;
      notifyListeners();
      _schedule(tipEvery, _showTip);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Colour of a waiting face's dot.
Color islandTipColor(IslandTipLook look) => switch (look) {
      IslandTipLook.boost => const Color(0xFFFF8A3D),
      IslandTipLook.demand => const Color(0xFFFFB020),
      IslandTipLook.info => const Color(0xFF4C97FF),
      IslandTipLook.promotion => const Color(0xFFB38CFF),
      IslandTipLook.good => const Color(0xFF2BD47D),
    };

/// A waiting face: a breathing dot and a few words, and for "Finding
/// trips" three dots lighting up one after another.
class DigitalWaitingFace extends StatefulWidget {
  const DigitalWaitingFace({
    super.key,
    required String title,
    required this.color,
    this.dots = false,
  }) : _title = title;

  /// "Finding trips".
  const DigitalWaitingFace.finding({super.key})
      : _title = null,
        color = const Color(0xFF2BD47D),
        dots = true;

  static String get findingTitle => tr.findingTrips;

  final String? _title;

  /// The words; "Finding trips" in the driver's language for [finding].
  String get title => _title ?? findingTitle;
  final Color color;
  final bool dots;

  static const double _lamp = 24;
  static const double _gap = 9;
  static const double _dot = 5;
  static const double _dotGap = 6;
  static const double _dotsWidth = 3 * _dot + 3 * _dotGap;

  /// Width the face needs: lamp, gap, words and dots, balanced so the words
  /// stay centred.
  static double widthFor(BuildContext context, String title, {bool dots = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: (Theme.of(context).textTheme.bodyMedium ??
                DefaultTextStyle.of(context).style)
            .merge(messageStyle),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return _lamp + _gap + painter.width + (dots ? _dotsWidth : 0) + 6;
  }

  @override
  State<DigitalWaitingFace> createState() => _DigitalWaitingFaceState();
}

class _DigitalWaitingFaceState extends State<DigitalWaitingFace>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// One loop of the three dots: each lights up in turn, then all rest.
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _breath.stop();
      _dots.stop();
    } else {
      if (!_breath.isAnimating) { _breath.repeat(reverse: true); }
      if (widget.dots && !_dots.isAnimating) { _dots.repeat(); }
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _dots.dispose();
    super.dispose();
  }

  Widget _lamp() => AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          final t = _still ? 0.5 : _breath.value;
          final color = widget.color;
          return SizedBox(
            width: DigitalWaitingFace._lamp,
            height: DigitalWaitingFace._lamp,
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16 + 0.08 * t),
                ),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35 + 0.35 * t),
                        blurRadius: 5 + 6 * t,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// How lit dot [i] is, 0–1: dot 1, then 1 and 2, then all three, then a
  /// short rest with all dim.
  double _lit(int i) {
    if (_still) { return 1; }
    final step = (_dots.value * 4).floor();
    return step > i && step < 4 ? 1 : 0.28;
  }

  Widget _dotsRow() => AnimatedBuilder(
        animation: _dots,
        builder: (context, _) => Row(
          key: const ValueKey<String>('island-finding-dots'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(left: DigitalWaitingFace._dotGap),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _lit(i),
                  child: Container(
                    width: DigitalWaitingFace._dot,
                    height: DigitalWaitingFace._dot,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x66FFFFFF), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final face = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _lamp(),
          const SizedBox(width: DigitalWaitingFace._gap),
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: messageStyle,
            ),
          ),
          if (widget.dots) _dotsRow(),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      label: widget.dots ? '${widget.title}…' : widget.title,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final least = DigitalWaitingFace._lamp +
              DigitalWaitingFace._gap +
              (widget.dots ? DigitalWaitingFace._dotsWidth : 0) +
              24;
          if (constraints.maxWidth >= least) { return face; }
          return ClipRect(
            child: OverflowBox(
              minWidth: 0,
              maxWidth: math.max(least, constraints.maxWidth),
              child: face,
            ),
          );
        },
      ),
    );
  }
}
