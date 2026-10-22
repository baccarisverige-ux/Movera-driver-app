import 'package:movera/core/l10n/driver_l10n.dart';

/// Single source of truth for rider phone contact.
///
/// No per-trip number is connected. Demo names must never be dialed.
class RiderContactPolicy {
  const RiderContactPolicy._();

  static const bool available = false;

  /// Why the call button does nothing, in the driver's language.
  static String get unavailableMessage => tr.riderPhoneNotConnected;
}
