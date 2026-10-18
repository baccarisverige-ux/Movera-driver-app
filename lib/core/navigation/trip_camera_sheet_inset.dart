import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How much of the trip map's bottom the trip sheet covers, for the
/// camera: the sheet's resting height once it stops moving (a drag or
/// spring in progress never moves the camera), capped so a strip of map
/// stays free above it for the car. Null until the sheet first moves:
/// the camera then frames for the collapsed sheet.
class TripCameraSheetInset extends ValueNotifier<double?> {
  TripCameraSheetInset({this.settle = const Duration(milliseconds: 180)})
    : super(null);

  /// How long the sheet must rest before the camera follows it.
  final Duration settle;

  /// Map height that stays free above the sheet for the car.
  static const double minFreeMap = 160;

  Timer? _settleTimer;

  /// The sheet is [height] tall now; the map's free area above it ends
  /// [maxInset] from the bottom at most.
  void sheetMoved(double height, {required double maxInset}) {
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, () {
      final next = math.max(0.0, math.min(height, maxInset));
      if (value == null || (value! - next).abs() >= 2) value = next;
    });
  }

  /// The bottom inset for the camera: never less than [collapsed].
  double resolve(double collapsed) => math.max(collapsed, value ?? collapsed);

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }
}
