import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/dispatch/offer_rules.dart';

/// Why an offer is Exclusive: the short text next to the black mark on the
/// Exclusive card. The offer carries a reason id; its text comes from the
/// admin's list ([DriverOfferRules.exclusiveReasons], Q15), so every reason
/// the app shows has one source.
class ExclusiveReasons {
  const ExclusiveReasons._();

  /// The best driver for this trip.
  static const String bestMatch = 'best-match';

  /// The rider marked this driver as a favourite.
  static const String favourite = 'favourite';

  /// The driver finishes a trip close to this pickup.
  static const String finishingNearby = 'finishing-nearby';

  /// First in the airport queue.
  static const String airportQueue = 'airport-queue';

  /// A reservation close to pickup that still has no driver.
  static const String pickupSoon = 'pickup-soon';

  /// A trip offered to this driver only, close by.
  static const String nearby = 'nearby';

  /// A scheduled ride Movera assigned to this driver (Q29). Not one of
  /// the dispatch reasons, so it is not in the admin list.
  static const String assigned = 'assigned';

  /// The text for reason [id]: '' when admin switched it off.
  static String text(String id, [DriverOfferRules? rules]) {
    if (id == assigned) {
      return tr.assignedByMovera;
    }
    return (rules ?? DriverOfferRules.current).reasonText(id);
  }

  /// The reason text when an offer does not bring its own.
  static String defaultFor({required bool reservation}) =>
      text(reservation ? pickupSoon : nearby);
}
