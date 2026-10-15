/// Why an offer is Exclusive: the short text next to the black mark on the
/// Exclusive card. Every reason the app shows is here, in one place; the
/// offer carries its reason and the card shows that one.
class ExclusiveReasons {
  const ExclusiveReasons._();

  /// A trip offered to this driver only, close by.
  static const String nearby = 'Only for you · nearby';

  /// A reservation close to pickup that still has no driver.
  static const String pickupSoon = 'Pickup soon · no driver yet';

  /// A scheduled ride Movera assigned to this driver (Q29).
  static const String assigned = 'Assigned by Movera';

  /// The reason when an offer does not bring its own.
  static String defaultFor({required bool reservation}) =>
      reservation ? pickupSoon : nearby;
}
