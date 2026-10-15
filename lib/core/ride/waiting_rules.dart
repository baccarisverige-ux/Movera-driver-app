import 'package:movera/core/money/money.dart';

/// Waiting at pickup (Round 3, Q19/Q20), the same rules admin sets in
/// Dispatch › Waiting for one zone or all zones. Today the app uses
/// [WaitingRules.current], whose defaults mirror the admin defaults; a
/// backend feeds it later. Pricing's waiting-per-minute is the same value.
class WaitingTerms {
  const WaitingTerms({
    required this.freeMinutes,
    required this.perMinute,
    required this.noShowAfterMinutes,
    required this.noShowFee,
    this.driverShareWaitPercent = 100,
    this.driverShareNoShowPercent = 100,
    this.rule = '',
  });

  /// The first minutes are part of the fare.
  final int freeMinutes;

  /// After them, each minute is added to the fare.
  final Money perMinute;

  /// From then the driver can cancel for no-show.
  final int noShowAfterMinutes;
  final Money noShowFee;

  /// How much of the waiting money and of the no-show fee goes to the
  /// driver.
  final int driverShareWaitPercent;
  final int driverShareNoShowPercent;

  /// The rule that set these terms, e.g. "Scheduled ride"; '' for the
  /// zone's own terms.
  final String rule;

  int get freeSeconds => freeMinutes * 60;
  int get noShowSeconds => noShowAfterMinutes * 60;

  /// The driver's part of the no-show fee.
  Money get driverNoShowFee => Money.ore(
    (noShowFee.minorUnits * driverShareNoShowPercent / 100).round(),
  );

  /// The terms of the trip on screen now: the waiting clocks read them.
  static WaitingTerms active = WaitingRules.current.base;

  WaitingTerms _with(WaitingRule rule, {String? label}) => WaitingTerms(
    freeMinutes: rule.freeMinutes ?? freeMinutes,
    perMinute: rule.perMinute ?? perMinute,
    noShowAfterMinutes: rule.noShowAfterMinutes ?? noShowAfterMinutes,
    noShowFee: rule.noShowFee ?? noShowFee,
    driverShareWaitPercent: driverShareWaitPercent,
    driverShareNoShowPercent: driverShareNoShowPercent,
    rule: [if (this.rule.isNotEmpty) this.rule, label ?? rule.label].join(' · '),
  );
}

/// Kinds of trip a waiting rule can be for.
enum WaitingRideType { normal, scheduled, airport, event }

/// One extra rule: it changes only the values it sets.
class WaitingRule {
  const WaitingRule({
    required this.label,
    this.freeMinutes,
    this.perMinute,
    this.noShowAfterMinutes,
    this.noShowFee,
  });

  /// Shown to the driver, e.g. "Airport pickup".
  final String label;
  final int? freeMinutes;
  final Money? perMinute;
  final int? noShowAfterMinutes;
  final Money? noShowFee;
}

class WaitingRules {
  const WaitingRules({
    this.base = const WaitingTerms(
      freeMinutes: 2,
      perMinute: Money(minorUnits: 1226),
      noShowAfterMinutes: 5,
      noShowFee: Money(minorUnits: 6500),
      driverShareWaitPercent: 100,
      driverShareNoShowPercent: 80,
    ),
    this.farPickupKm = 5,
    this.farPickup = const WaitingRule(
      label: 'Pickup far away',
      freeMinutes: 1,
      noShowFee: Money(minorUnits: 8500),
    ),
    this.rideTypes = const {
      WaitingRideType.scheduled: WaitingRule(
        label: 'Scheduled ride',
        freeMinutes: 5,
      ),
      WaitingRideType.airport: WaitingRule(
        label: 'Airport pickup',
        freeMinutes: 15,
        noShowAfterMinutes: 20,
      ),
      WaitingRideType.event: WaitingRule(
        label: 'Event pickup',
        freeMinutes: 3,
      ),
    },
    this.categories = const {
      'Premium': WaitingRule(
        label: 'Premium',
        freeMinutes: 5,
        perMinute: Money(minorUnits: 1690),
      ),
      'XL': WaitingRule(label: 'XL', freeMinutes: 3),
    },
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static WaitingRules current = const WaitingRules();

  /// The zone's terms when no extra rule applies.
  final WaitingTerms base;

  /// Over this many km to the pickup, [farPickup] applies.
  final double farPickupKm;
  final WaitingRule farPickup;

  final Map<WaitingRideType, WaitingRule> rideTypes;

  /// By ride category, e.g. "Premium".
  final Map<String, WaitingRule> categories;

  /// The terms for one pickup. Category first, then ride type, then the
  /// distance rule: a later rule wins where it sets a value.
  WaitingTerms termsFor({
    String category = '',
    WaitingRideType type = WaitingRideType.normal,
    double? pickupKm,
  }) {
    var terms = base;
    final byCategory = categories[category.trim()];
    if (byCategory != null) {
      terms = terms._with(byCategory);
    }
    final byType = rideTypes[type];
    if (byType != null) {
      terms = terms._with(byType);
    }
    if (pickupKm != null && pickupKm > farPickupKm) {
      final km = farPickupKm == farPickupKm.roundToDouble()
          ? farPickupKm.toStringAsFixed(0)
          : farPickupKm.toStringAsFixed(1);
      terms = terms._with(farPickup, label: 'Pickup over $km km');
    }
    return terms;
  }

  /// The kind of trip, from how it was matched and where it starts.
  static WaitingRideType typeOf({
    required String matchedVia,
    required String pickupAddress,
  }) {
    if (RegExp(r'airport|arlanda|terminal', caseSensitive: false)
        .hasMatch(pickupAddress)) {
      return WaitingRideType.airport;
    }
    final via = matchedVia.toLowerCase();
    if (via.contains('scheduled') || via.contains('reservation')) {
      return WaitingRideType.scheduled;
    }
    if (via.contains('event')) {
      return WaitingRideType.event;
    }
    return WaitingRideType.normal;
  }
}
