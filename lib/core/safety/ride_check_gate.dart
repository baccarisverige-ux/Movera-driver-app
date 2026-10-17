import 'package:flutter/foundation.dart';

/// A driver's Ride check is open: from the pulsing pill until the driver has
/// answered (R10-2). While it is, no new offer is shown (no Radar card, no
/// Exclusive, no reservation popup, no next-trip offer); offers that come
/// meanwhile wait, or drop if they expire, and resume after the answer.
///
/// Only [RideCheckController] opens and closes it.
abstract final class RideCheckGate {
  static final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  /// Listen to know when the Ride check opens and when it is answered.
  static ValueListenable<bool> get listenable => _open;

  /// A Ride check is open: hold new offers back.
  static bool get open => _open.value;

  static void set(bool open) => _open.value = open;
}
