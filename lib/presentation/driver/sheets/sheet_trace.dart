import 'dart:async';
import 'package:flutter/foundation.dart';

/// Passive debug samples: never writes panel position or drives animation.
class SheetTrace {
  SheetTrace(this.name, this.position);
  final String name;
  final double Function() position;
  final List<Timer> _timers = [];
  void sample(String event, [double velocity = 0]) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'SHEET $name $event position=${position().toStringAsFixed(4)} velocity=${velocity.toStringAsFixed(2)}',
    );
  }

  void down() {
    dispose();
    sample('pointer-down');
  }

  void up(double velocity) {
    if (!kDebugMode) {
      return;
    }
    sample('pointer-up', velocity);
    for (final milliseconds in [180, 460]) {
      _timers.add(
        Timer(
          Duration(milliseconds: milliseconds),
          () => sample('release+$milliseconds', velocity),
        ),
      );
    }
  }

  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
