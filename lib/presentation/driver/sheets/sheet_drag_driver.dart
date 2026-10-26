import 'package:flutter/gestures.dart';
import 'package:movera/presentation/driver/sheets/movera_snap_sheet_controller.dart';

/// Drags a [MoveraSnapSheetController] sheet 1:1 with the finger from raw
/// pointer events and hands the release velocity (from the events' own
/// timestamps) to [onRelease]. A mostly sideways move (a slide action) or a
/// move [scrollOwns] claims leaves the sheet alone.
class SheetDragDriver {
  SheetDragDriver({
    required this.sheet,
    required this.onRelease,
    this.canDrag,
    this.scrollOwns,
  });

  final MoveraSnapSheetController sheet;
  final bool Function()? canDrag;

  /// Whether an inner scroll view owns a vertical move of [dy] that
  /// started at [down] (global position).
  final bool Function(Offset down, double dy)? scrollOwns;

  /// Finger velocity in px/s (down is positive) and the sheet position
  /// when the drag took hold.
  final void Function(double velocityPxPerSec, double startPosition) onRelease;

  /// Movement before the drag picks an axis. The sheet then catches up the
  /// whole way, so it stays under the finger.
  static const double slop = 6;

  int? _pointer;
  Offset _down = Offset.zero;
  VelocityTracker? _tracker;
  bool? _vertical;
  double _start = 0;

  bool get dragging => _vertical == true;

  void down(PointerDownEvent event) {
    if (_pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _down = event.position;
    _vertical = null;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void move(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _tracker?.addPosition(event.timeStamp, event.position);
    if (_vertical == null) {
      final travel = event.position - _down;
      if (travel.distance < slop) {
        return;
      }
      final vertical =
          travel.dy.abs() > travel.dx.abs() &&
          sheet.isAttached &&
          (canDrag?.call() ?? true) &&
          scrollOwns?.call(_down, travel.dy) != true;
      _vertical = vertical;
      if (!vertical) {
        return;
      }
      // The finger owns the sheet now: no spring or panel fling under it.
      sheet.stopSpring();
      sheet.stopPanelAnimation();
      _start = sheet.position;
      _apply(travel.dy);
      return;
    }
    if (_vertical == true) {
      _apply(event.delta.dy);
    }
  }

  void end(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    if (event is PointerUpEvent) {
      _tracker?.addPosition(event.timeStamp, event.position);
    }
    final wasDrag = _vertical == true;
    final velocity = event is PointerUpEvent
        ? _tracker?.getVelocity().pixelsPerSecond.dy ?? 0
        : 0.0;
    _pointer = null;
    _tracker = null;
    _vertical = null;
    if (wasDrag) {
      onRelease(velocity, _start);
    }
  }

  void _apply(double dy) {
    if (!sheet.isAttached || sheet.rangePx <= 1) {
      return;
    }
    sheet.panel.panelPosition = (sheet.position - dy / sheet.rangePx).clamp(
      0.0,
      1.0,
    );
  }
}
