import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Shared snap geometry and spring for Home and Active Ride sheets.
class MoveraSheetMetrics {
  const MoveraSheetMetrics._();

  static const double collapsedHeight = 108;
  /// Content of the collapsed Active Ride bar.
  static const double activeCollapsedHeight = 77;

  /// Empty space under the bar's content, or the phone's own bottom safe
  /// area when that is taller; same proportions as common driver apps.
  static const double activeBottomGap = 34;

  /// Full collapsed Active Ride bar for a phone with [safeBottom].
  static double activeCollapsedTotal(double safeBottom) =>
      activeCollapsedHeight + math.max(safeBottom, activeBottomGap);

  /// Content of the middle Active Ride sheet: header, rider row and the
  /// slide action.
  static const double activeMiddleHeight = 199;

  /// Full middle Active Ride sheet for a phone with [safeBottom].
  static double activeMiddleTotal(double safeBottom) =>
      activeMiddleHeight + math.max(safeBottom, activeBottomGap);

  /// Panel position of the middle Active Ride sheet, between [collapsed]
  /// and [expanded] heights.
  static double activeSnapPoint({
    required double collapsed,
    required double middle,
    required double expanded,
  }) {
    final span = expanded - collapsed;
    if (span <= 0) { return 0.5; }
    return ((middle - collapsed) / span).clamp(0.08, 0.92);
  }
  static const double middleFraction = 0.46;
  static const double expandedFraction = 0.90;
  static const double springMass = 1.0;
  static const double springStiffness = 400;
  static const double springDampingRatio = 1.05;
  static const double flickVelocity = 240;

  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: springMass,
    stiffness: springStiffness,
    ratio: springDampingRatio,
  );

  static double expandedHeight(double viewportHeight) =>
      viewportHeight * expandedFraction;

  static double middleHeight(double viewportHeight) =>
      viewportHeight * middleFraction;

  static double snapPoint({
    required double viewportHeight,
    double collapsed = collapsedHeight,
  }) {
    final maxH = expandedHeight(viewportHeight);
    final midH = middleHeight(viewportHeight);
    final span = maxH - collapsed;
    if (span <= 0) { return 0.5; }
    return ((midH - collapsed) / span).clamp(0.08, 0.92);
  }

  static double targetPosition({
    required double position,
    required double velocityPxPerSec,
    required double snap,
  }) {
    if (velocityPxPerSec < -flickVelocity) {
      return position < snap - 0.03 ? snap : 1.0;
    }
    if (velocityPxPerSec > flickVelocity) {
      return position > snap + 0.03 ? snap : 0.0;
    }

    final dCollapsed = position.abs();
    final dSnap = (position - snap).abs();
    final dExpanded = (1 - position).abs();
    if (dCollapsed <= dSnap && dCollapsed <= dExpanded) { return 0; }
    if (dSnap <= dExpanded) { return snap; }
    return 1;
  }

  /// Where a released drag goes: a flick follows its direction; a small
  /// push already opens (or closes) the next stage; otherwise nearest.
  static double directionalTarget({
    required double start,
    required double position,
    required double velocityPxPerSec,
    required double snap,
  }) {
    if (velocityPxPerSec.abs() > flickVelocity) {
      return targetPosition(
        position: position,
        velocityPxPerSec: velocityPxPerSec,
        snap: snap,
      );
    }
    final stops = <double>[0, snap, 1];
    // Only stages past the one the drag started from count.
    if (position > start + 0.03) {
      return stops.firstWhere(
        (s) => s > start + 0.01 && s >= position - 0.06,
        orElse: () => 1,
      );
    }
    if (position < start - 0.03) {
      return stops.lastWhere(
        (s) => s < start - 0.01 && s <= position + 0.06,
        orElse: () => 0,
      );
    }
    return targetPosition(position: position, velocityPxPerSec: 0, snap: snap);
  }

  /// Two-stop sheets (closed and open, nothing in between): a flick
  /// follows its direction, a small push already goes to the other end,
  /// otherwise the nearest end wins.
  static double twoStopTarget({
    required double start,
    required double position,
    required double velocityPxPerSec,
  }) {
    if (velocityPxPerSec < -flickVelocity) { return 1; }
    if (velocityPxPerSec > flickVelocity) { return 0; }
    if (position > start + 0.03) { return 1; }
    if (position < start - 0.03) { return 0; }
    return position >= 0.5 ? 1 : 0;
  }

  static double notchDepthFor(double position) {
    const collapsed = 58.0;
    const expanded = 8.0;
    final t = position.clamp(0.0, 1.0);
    return collapsed + (expanded - collapsed) * t;
  }
}
