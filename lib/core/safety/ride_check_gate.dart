import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A driver's Ride check is open: from the pulsing pill until the driver has
/// answered (R10-2). While it is, no new offer is shown (no Radar card, no
/// Exclusive, no reservation popup, no next-trip offer); offers that come
/// meanwhile wait, or drop if they expire, and resume after the answer.
///
/// Only [RideCheckController] opens and closes it.
abstract final class RideCheckGate {
  static final ValueNotifier<bool> _open = ValueNotifier<bool>(false);
  static bool _value = false;
  static bool _notifyAfterFrame = false;

  /// Listen to know when the Ride check opens and when it is answered.
  static ValueListenable<bool> get listenable => _open;

  /// A Ride check is open: hold new offers back.
  static bool get open => _value;

  static void set(bool open) {
    _value = open;
    // driver-36: closed from a State.dispose (the trip screen leaving), the
    // tree is locked and Home's listener must not rebuild now; it hears
    // the change once the frame is done.
    if (_inFrame) {
      if (_notifyAfterFrame) return;
      _notifyAfterFrame = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyAfterFrame = false;
        _open.value = _value;
      });
      return;
    }
    _open.value = open;
  }

  static bool get _inFrame {
    try {
      return SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks;
    } catch (_) {
      return false; // No binding (a plain unit test): nothing is built.
    }
  }
}
