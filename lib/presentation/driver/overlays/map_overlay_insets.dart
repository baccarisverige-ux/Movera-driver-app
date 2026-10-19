import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';

/// UI-aware map padding so fitted routes stay in the unobstructed viewport.
class MapOverlayInsets {
  const MapOverlayInsets({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final double top;
  final double bottom;
  final double left;
  final double right;

  EdgeInsets get edgeInsets => EdgeInsets.fromLTRB(left, top, right, bottom);

  /// Anchor at 75% of the screen, clamped above overlays with car clearance.
  /// Web does not implement SDK padding: its projection adapter applies this.
  EdgeInsets drivingInsets(double height, {required bool following}) {
    if (kIsWeb) {
      return edgeInsets;
    }
    if (height <= top + bottom) {
      return EdgeInsets.symmetric(horizontal: 32, vertical: height * .2);
    }
    final visible = math.max(0.0, height - top - bottom);
    final margin = math.min(24.0, visible / 2);
    final desired = (height * .75).clamp(
      top + margin,
      height - bottom - margin,
    );
    return EdgeInsets.fromLTRB(
      32,
      following ? math.max(top, 2 * desired - height + bottom) : top,
      32,
      bottom,
    );
  }

  double get boundsPadding {
    final shortest = [top, bottom, left, right].reduce(math.min);
    return shortest.clamp(36.0, 72.0);
  }

  factory MapOverlayInsets.forHome({
    required double safeTop,
    required double obscuredBottom,
    bool hasTopBanner = false,
  }) {
    return MapOverlayInsets(
      top: safeTop + (hasTopBanner ? 68 : 16),
      bottom: obscuredBottom + 18,
      left: 36,
      right: 72,
    );
  }

  factory MapOverlayInsets.forActiveRide({
    required double safeTop,
    double collapsedSheet = MoveraSheetMetrics.activeCollapsedHeight,
  }) {
    return MapOverlayInsets(
      top: safeTop + 210,
      bottom: collapsedSheet + 10,
      left: 32,
      right: 56,
    );
  }
}
