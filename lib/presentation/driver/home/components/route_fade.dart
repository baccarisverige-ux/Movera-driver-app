import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Fades a route on the Home map in or out: its pins (with their chips)
/// and its lines. The map takes new markers and lines a few times over
/// the fade, not every frame.
class RouteFade {
  /// 0 hidden, 1 fully drawn.
  double value = 1;
  Timer? _timer;

  /// Steps per fade.
  static const int steps = 8;

  bool get running => _timer != null;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Jumps to [to] at once.
  void set(double to) {
    cancel();
    value = to;
  }

  /// Steps [value] to [to] over [duration]; [onStep] after each step
  /// (redraw the map), [onDone] at the end.
  void fadeTo(
    double to,
    Duration duration,
    VoidCallback onStep, {
    VoidCallback? onDone,
  }) {
    cancel();
    final from = value;
    var step = 0;
    _timer = Timer.periodic(duration ~/ steps, (timer) {
      step++;
      value = from + (to - from) * step / steps;
      if (step >= steps) {
        value = to;
        cancel();
      }
      onStep();
      if (step >= steps) onDone?.call();
    });
  }

  /// [markers] with the ones in [ids] at [value].
  Set<Marker> markers(Set<Marker> markers, Set<MarkerId> ids) {
    if (value >= 1 || ids.isEmpty) return markers;
    return {
      for (final marker in markers)
        ids.contains(marker.markerId)
            ? marker.copyWith(
                alphaParam: marker.alpha * value,
                visibleParam: value > 0.01,
              )
            : marker,
    };
  }

  /// [lines] with the ones in [ids] at [value].
  Set<Polyline> polylines(Set<Polyline> lines, Set<PolylineId> ids) {
    if (value >= 1 || ids.isEmpty) return lines;
    return {
      for (final line in lines)
        ids.contains(line.polylineId)
            ? line.copyWith(
                colorParam: line.color.withValues(alpha: line.color.a * value),
                visibleParam: value > 0.01,
              )
            : line,
    };
  }
}
