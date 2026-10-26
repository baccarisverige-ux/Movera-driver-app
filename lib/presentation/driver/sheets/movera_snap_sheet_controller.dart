import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Shared finger-follow + SpringSimulation snap for Home and Active Ride.
class MoveraSnapSheetController {
  MoveraSnapSheetController({
    required this.panel,
    required TickerProvider vsync,
    this.reduceMotion,
  }) : _vsync = vsync;

  final bool Function()? reduceMotion;
  final PanelController panel;
  final TickerProvider _vsync;
  double rangePx = 1;
  AnimationController? _spring;
  double? _target;

  double get position => panel.isAttached ? panel.panelPosition : 0;

  bool get isAttached => panel.isAttached;

  bool get isSpringing => _spring != null;

  void stopSpring() {
    _spring?.dispose();
    _spring = null;
  }

  /// SlidingUpPanel still starts a 410ms decelerate fling when
  /// `panelSnapping` is false. Assigning position stops that controller
  /// so our spring owns the settle.
  void stopPanelAnimation() {
    if (!panel.isAttached) {
      return;
    }
    panel.panelPosition = panel.panelPosition.clamp(0.0, 1.0);
  }

  /// [noOvershoot] keeps a fast release's speed but never lets it carry
  /// the sheet past [target] and back (no bounce at a stop).
  Future<void> springTo(
    double target, {
    double velocityPxPerSec = 0,
    bool noOvershoot = false,
  }) async {
    stopSpring();
    if (!panel.isAttached) {
      return;
    }
    target = target.clamp(0.0, 1.0);
    stopPanelAnimation();
    if (reduceMotion?.call() == true) {
      stopSpring();
      panel.panelPosition = target;
      return;
    }
    final start = panel.panelPosition;
    if ((start - target).abs() < 0.003) {
      panel.panelPosition = target;
      return;
    }

    stopSpring();
    final controller = AnimationController.unbounded(vsync: _vsync);
    _spring = controller;
    var velocity = rangePx <= 0 ? 0.0 : -velocityPxPerSec / rangePx;
    if (noOvershoot) {
      // A spring at least critically damped crosses its target only when
      // it heads there faster than its natural frequency times the gap.
      final spring = MoveraSheetMetrics.spring;
      final limit =
          math.sqrt(spring.stiffness / spring.mass) * (target - start).abs();
      if (velocity * (target - start) > 0 && velocity.abs() > limit) {
        velocity = velocity.sign * limit;
      }
    }
    _target = target;
    _noOvershoot = noOvershoot;
    final simulation = SpringSimulation(
      MoveraSheetMetrics.spring,
      start,
      target,
      velocity,
    );
    controller.addListener(() {
      if (!panel.isAttached) {
        return;
      }
      panel.panelPosition = controller.value.clamp(0.0, 1.0);
    });
    try {
      await controller.animateWith(simulation).orCancel;
      if (kDebugMode) {
        debugPrint(
          'SHEET spring-end position=$position target=$target velocity=$velocityPxPerSec',
        );
      }
    } on TickerCanceled {
      // A new drag or disposal owns the panel now.
    } finally {
      if (identical(_spring, controller)) {
        controller.dispose();
        _spring = null;
      }
    }
  }

  bool _noOvershoot = false;

  /// The sheet's travel changed to [newRangePx] (its content was measured
  /// again). Keeps the sheet's height on screen instead of letting it jump,
  /// then goes on to the matching stop: [mapStop] turns an old stop (a
  /// running spring's target, or where the sheet rests) into the new one,
  /// or returns null for a position that is not a stop. [settle] false
  /// (a finger on the sheet) only keeps the height.
  void keepHeight(
    double newRangePx, {
    required double? Function(double oldStop) mapStop,
    bool settle = true,
  }) {
    final oldRange = rangePx;
    rangePx = newRangePx;
    if (!panel.isAttached || oldRange <= 1 || newRangePx <= 1) {
      return;
    }
    final spring = _spring;
    final target = _target;
    final velocityPx = spring == null ? 0.0 : spring.velocity * oldRange;
    if ((newRangePx - oldRange).abs() < 0.5) {
      // Same travel, but the stop a running spring heads for moved.
      final moved = spring == null || target == null ? null : mapStop(target);
      if (moved != null && (moved - target!).abs() > 0.001) {
        unawaited(
          springTo(
            moved,
            velocityPxPerSec: -velocityPx,
            noOvershoot: _noOvershoot,
          ),
        );
      }
      return;
    }
    // The panel's own open/close animation runs to its end.
    if (spring == null && panel.isPanelAnimating) {
      return;
    }
    final oldPosition = panel.panelPosition;
    stopSpring();
    final position = (oldPosition * oldRange / newRangePx).clamp(0.0, 1.0);
    panel.panelPosition = position;
    if (spring != null && target != null) {
      final next = mapStop(target) ?? target;
      // Speed away from the new stop would only carry past it and back.
      final toward = velocityPx * (next - position) > 0;
      unawaited(
        springTo(
          next,
          velocityPxPerSec: toward ? -velocityPx : 0,
          noOvershoot: _noOvershoot,
        ),
      );
      return;
    }
    final stop = settle ? mapStop(oldPosition) : null;
    if (stop != null) {
      unawaited(springTo(stop, noOvershoot: true));
    }
  }

  Future<void> snapToNearest({
    required double snapPoint,
    required double velocityPxPerSec,
  }) {
    final target = MoveraSheetMetrics.targetPosition(
      position: position,
      velocityPxPerSec: velocityPxPerSec,
      snap: snapPoint,
    );
    return springTo(target, velocityPxPerSec: velocityPxPerSec);
  }

  void dispose() => stopSpring();
}
