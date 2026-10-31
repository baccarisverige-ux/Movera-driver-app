import 'package:flutter/foundation.dart';

/// The accuracy (metres) of the driver's latest GPS fix, for the halo
/// under the own position arrow on every driver map; null when unknown.
abstract final class OwnPositionAccuracy {
  static final ValueNotifier<double?> meters = ValueNotifier<double?>(null);
}
