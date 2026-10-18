import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/sheets/movera_snap_sheet_controller.dart';
import 'package:movera/presentation/driver/sheets/sheet_drag_driver.dart';

/// The trip sheet's three faces: the flat bar, the middle sheet (rider and
/// the next action) and the full sheet (trip details).
enum TripSheetFace { compact, middle, full }

/// Motion of the trip sheet: the finger drag, one spring to the stops, a
/// steady height when the content is measured again, and which face shows.
/// The face only changes at its thresholds, so the content is not rebuilt
/// on every frame of a drag.
class TripSheetMotion {
  TripSheetMotion({
    required this.sheet,
    required this.position,
    required this.snap,
    required void Function(double velocityPxPerSec, double start) onRelease,
    required bool Function() canDrag,
    required RenderObject? Function() scrollArea,
  }) : _scrollArea = scrollArea {
    drag = SheetDragDriver(
      sheet: sheet,
      onRelease: onRelease,
      canDrag: canDrag,
      scrollOwns: _scrollOwns,
    );
    face = ValueNotifier<TripSheetFace>(faceAt(position.value));
    position.addListener(_onPosition);
  }

  final MoveraSnapSheetController sheet;
  final ValueListenable<double> position;
  final double Function() snap;
  final RenderObject? Function() _scrollArea;
  late final SheetDragDriver drag;
  late final ValueNotifier<TripSheetFace> face;

  /// The full sheet's details laid out (not shown) under the middle
  /// sheet, so the full height is known before the sheet gets there.
  final GlobalKey aheadKey = GlobalKey();

  /// The grip line, and its full height (top padding and line).
  final GlobalKey gripKey = GlobalKey();
  static const double gripHeight = 12;

  /// How much of the grip has not opened yet, so a measurement taken while
  /// it opens is the same as one taken after.
  double gripMissing() {
    final grip = gripKey.currentContext?.findRenderObject();
    if (grip is! RenderBox || !grip.hasSize) { return 0; }
    return (gripHeight - grip.size.height).clamp(0.0, gripHeight);
  }

  /// The full sheet's scroll view.
  final ScrollController fullScroll = ScrollController();

  /// Where the full face starts, as a panel position.
  double fullAt(double snap) => snap + (1 - snap) * 0.35;

  TripSheetFace faceAt(double pos) {
    final s = snap();
    if (pos < s * 0.5) { return TripSheetFace.compact; }
    if (pos > fullAt(s)) { return TripSheetFace.full; }
    return TripSheetFace.middle;
  }

  /// 0 below the full face, 1 on it: the full sheet's rounded top grows in
  /// over the last stretch before it instead of popping.
  double roundness(double pos) {
    final at = fullAt(snap());
    return ((pos - (at - 0.06)) / 0.06).clamp(0.0, 1.0);
  }

  /// The face shown before the current one.
  TripSheetFace previousFace = TripSheetFace.compact;

  void _onPosition() {
    final next = faceAt(position.value);
    if (next == face.value) { return; }
    previousFace = face.value;
    face.value = next;
  }

  /// Every layout: the sheet's travel and middle stop as laid out now.
  /// The sheet has three stops, so any stop between closed and open is the
  /// middle one, wherever the new layout puts it.
  void keep({required double rangePx, required double snap}) {
    sheet.keepHeight(
      rangePx,
      settle: !drag.dragging,
      mapStop: (stop) {
        if (stop < 0.004) { return 0; }
        if (stop > 0.996) { return 1; }
        return snap;
      },
    );
  }

  /// The full sheet's content scrolls (rather than the sheet moving) when
  /// it is scrolled down already, or when the open sheet is pushed up.
  bool _scrollOwns(Offset down, double dy) {
    if (!fullScroll.hasClients) { return false; }
    final scroll = fullScroll.position;
    if (scroll.maxScrollExtent <= 0) { return false; }
    final area = _scrollArea();
    if (area is! RenderBox || !area.attached) { return false; }
    final origin = area.localToGlobal(Offset.zero);
    if (!(origin & area.size).contains(down)) { return false; }
    return scroll.pixels > 0 || (dy < 0 && sheet.position > 0.996);
  }

  void dispose() {
    position.removeListener(_onPosition);
    face.dispose();
    fullScroll.dispose();
  }
}

/// Bounces at the bottom like before, but never pulls down past the top:
/// a pull down there moves the sheet instead.
class TopClampedBouncingScrollPhysics extends BouncingScrollPhysics {
  const TopClampedBouncingScrollPhysics({super.parent});

  @override
  TopClampedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      TopClampedBouncingScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    return 0;
  }
}

/// Fades its child in when it first shows (a face change), instead of
/// popping in at full strength.
class TripSheetFadeIn extends StatelessWidget {
  const TripSheetFadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) { return child; }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// The grip line: no height on the flat bar, opening smoothly above the
/// header as the sheet lifts, so the header does not jump.
class TripSheetGrip extends StatelessWidget {
  const TripSheetGrip({super.key, required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: shown ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      ),
      child: child,
    );
  }
}
