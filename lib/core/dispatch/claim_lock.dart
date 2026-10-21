import 'package:flutter/foundation.dart';

/// Decision 4 ("lock settings while matching"): while a Match or Accept
/// is with dispatch, or its won trip is opening, the driver's offer
/// settings stay as they were. The ride categories and Destination mode
/// are locked until the claim resolves. Home sets it; the screens with
/// those controls read it.
abstract final class ClaimLock {
  static final ValueNotifier<bool> _locked = ValueNotifier<bool>(false);

  /// Listen to know when a claim starts and when it is answered.
  static ValueListenable<bool> get listenable => _locked;

  /// A claim is with dispatch: the offer settings cannot change.
  static bool get locked => _locked.value;

  static void set(bool locked) => _locked.value = locked;
}
