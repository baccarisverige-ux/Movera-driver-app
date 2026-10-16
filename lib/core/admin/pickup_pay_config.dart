import 'package:movera/core/vehicle/ride_categories.dart';

/// Which kind of offer a pickup pay is worked out for. Admin switches each
/// kind on or off (Dispatch › Pickup pay).
enum PickupPayOfferKind {
  /// A Radar trip on Home or in the Ride offers list.
  radar,

  /// An Exclusive (one-driver) offer on Home.
  exclusive,

  /// A reservation close to pickup that still has no driver: its Exclusive
  /// offer, and the same reservation when it joins the Radar trips.
  exclusiveReservation,

  /// A scheduled ride Movera assigned to this driver.
  assignedByMovera,

  /// The next trip offered while the driver still drives a rider. Its
  /// pickup leg starts at the current trip's drop-off.
  nextTripWhileDriving,

  /// A normal reservation the driver took from the Scheduled rides list.
  /// Never pickup pay, whatever admin sets.
  scheduledListReservation;

  /// The kind of a Home offer. [onRadar] is true for the Radar deck, false
  /// for the Exclusive card. [driverSigned] marks a reservation the driver
  /// already took from the Scheduled rides list.
  static PickupPayOfferKind forHomeOffer({
    required bool onRadar,
    required bool reservation,
    bool assigned = false,
    bool driverSigned = false,
  }) {
    if (driverSigned) {
      return scheduledListReservation;
    }
    if (assigned) {
      return assignedByMovera;
    }
    if (reservation) {
      return exclusiveReservation;
    }
    return onRadar ? radar : exclusive;
  }
}

/// How an offer card shows the pickup pay.
enum PickupPayDisplay {
  /// One total (fare + pickup pay) where the fare is shown.
  totalOnly,

  /// The total, plus a small grey line with what the pickup pay is.
  fareWithPickupLine,
}

/// Admin's pickup pay for one ride category. No cap.
class PickupPayRate {
  const PickupPayRate({
    this.enabled = true,
    required this.krPerKm,
    required this.krPerMinute,
    this.freeKm = 0,
    this.freeKmOn = false,
    this.freeMinutes = 0,
    this.freeMinutesOn = false,
  });

  /// Off: no pickup pay for this category.
  static const PickupPayRate off = PickupPayRate(
    enabled: false,
    krPerKm: 0,
    krPerMinute: 0,
  );

  final bool enabled;
  final double krPerKm;
  final double krPerMinute;

  /// The first km of the pickup are not paid, when [freeKmOn].
  final double freeKm;
  final bool freeKmOn;

  /// The first minutes of the pickup are not paid, when [freeMinutesOn].
  final int freeMinutes;
  final bool freeMinutesOn;

  PickupPayRate copyWith({
    bool? enabled,
    double? krPerKm,
    double? krPerMinute,
    double? freeKm,
    bool? freeKmOn,
    int? freeMinutes,
    bool? freeMinutesOn,
  }) => PickupPayRate(
    enabled: enabled ?? this.enabled,
    krPerKm: krPerKm ?? this.krPerKm,
    krPerMinute: krPerMinute ?? this.krPerMinute,
    freeKm: freeKm ?? this.freeKm,
    freeKmOn: freeKmOn ?? this.freeKmOn,
    freeMinutes: freeMinutes ?? this.freeMinutes,
    freeMinutesOn: freeMinutesOn ?? this.freeMinutesOn,
  );
}

/// Pickup pay as admin sets it (mock until a backend sends it). The
/// driver is paid for the drive to the pickup; the rider's price does not
/// change; Movera pays it from its commission.
class PickupPayConfig {
  const PickupPayConfig({
    this.categories = demoRates,
    this.kinds = defaultKinds,
    this.display = PickupPayDisplay.totalOnly,
  });

  /// Everything off.
  static const PickupPayConfig disabled = PickupPayConfig(
    categories: <String, PickupPayRate>{},
    kinds: <PickupPayOfferKind>{},
  );

  /// The config in use. Mirrors the admin defaults until a backend sets it.
  static PickupPayConfig current = const PickupPayConfig();

  /// Every kind on that admin can switch on.
  static const Set<PickupPayOfferKind> defaultKinds = <PickupPayOfferKind>{
    PickupPayOfferKind.radar,
    PickupPayOfferKind.exclusive,
    PickupPayOfferKind.exclusiveReservation,
    PickupPayOfferKind.assignedByMovera,
    PickupPayOfferKind.nextTripWhileDriving,
  };

  /// Demo rates per category, by the names in [DriverCategoryAccess.all].
  static const Map<String, PickupPayRate> demoRates = <String, PickupPayRate>{
    'Movera': PickupPayRate(
      krPerKm: 2.5,
      krPerMinute: 0.8,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Comfort': PickupPayRate(
      krPerKm: 3,
      krPerMinute: 1,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Premium': PickupPayRate(
      krPerKm: 4,
      krPerMinute: 1.5,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Priority': PickupPayRate(
      krPerKm: 3,
      krPerMinute: 1,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Movera XL': PickupPayRate(
      krPerKm: 3.5,
      krPerMinute: 1.2,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Electric': PickupPayRate(
      krPerKm: 2.5,
      krPerMinute: 0.8,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Movera Pet': PickupPayRate(
      krPerKm: 3,
      krPerMinute: 1,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
    'Booster Seat': PickupPayRate(
      krPerKm: 3,
      krPerMinute: 1,
      freeKm: 1,
      freeKmOn: true,
      freeMinutes: 2,
      freeMinutesOn: true,
    ),
  };

  /// Rates by category name; a category not listed has no pickup pay.
  final Map<String, PickupPayRate> categories;

  /// The offer kinds that get pickup pay.
  final Set<PickupPayOfferKind> kinds;

  final PickupPayDisplay display;

  /// The rate for [category] ("XL" is "Movera XL"); [PickupPayRate.off]
  /// when admin has none or switched it off.
  PickupPayRate rateFor(String category) {
    final rate = categories[DriverCategoryAccess.nameOf(category.trim())];
    return rate == null || !rate.enabled ? PickupPayRate.off : rate;
  }

  /// Whether [kind] gets pickup pay. A reservation taken from the
  /// Scheduled rides list never does.
  bool kindOn(PickupPayOfferKind kind) =>
      kind != PickupPayOfferKind.scheduledListReservation &&
      kinds.contains(kind);

  PickupPayConfig copyWith({
    Map<String, PickupPayRate>? categories,
    Set<PickupPayOfferKind>? kinds,
    PickupPayDisplay? display,
  }) => PickupPayConfig(
    categories: categories ?? this.categories,
    kinds: kinds ?? this.kinds,
    display: display ?? this.display,
  );
}
