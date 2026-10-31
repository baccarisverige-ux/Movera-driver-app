import 'dart:math' as math;

import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

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
    this.ruleLabels = const <String>[],
    this.pricesKnown = true,
    this.serverFreeSeconds,
    this.serverNoShowSeconds,
  });

  /// G5 checker round 1: the server's own moments, as seconds after the
  /// driver arrived (`waiting.freeUntil` / `waiting.noShowAt` −
  /// `arrivedAt`). A reservation reached early waits until its booked time
  /// plus the free minutes; the phone's count follows the server.
  final int? serverFreeSeconds;
  final int? serverNoShowSeconds;

  /// These terms with the server's moments (null leaves the local count).
  WaitingTerms anchored({int? freeSeconds, int? noShowSeconds}) => WaitingTerms(
    freeMinutes: freeMinutes,
    perMinute: perMinute,
    noShowAfterMinutes: noShowAfterMinutes,
    noShowFee: noShowFee,
    driverShareWaitPercent: driverShareWaitPercent,
    driverShareNoShowPercent: driverShareNoShowPercent,
    ruleLabels: ruleLabels,
    pricesKnown: pricesKnown,
    serverFreeSeconds: freeSeconds,
    serverNoShowSeconds: noShowSeconds,
  );

  /// False when no server terms reached the phone yet (no zone document,
  /// no trip `terms`): the screens then show the waiting TIME only, never
  /// an amount the app made up (G5 checker round 1, owner rule 16).
  final bool pricesKnown;

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

  /// The rules that set these terms as admin wrote them (or
  /// [farPickupLabel] for the distance rule); empty for the zone's own
  /// terms. Kept untranslated, so a language switch mid-trip shows them
  /// in the new language (driver-u38).
  final List<String> ruleLabels;

  /// The rules, e.g. "Scheduled ride", in the driver's language; '' for
  /// the zone's own terms.
  String get rule => ruleLabels.map(_shown).join(' · ');

  /// The distance rule's label for pickups over [km] km.
  static String farPickupLabel(String km) => '$_farPickup$km';
  static const String _farPickup = 'pickupOverKm:';

  int get freeSeconds => serverFreeSeconds ?? freeMinutes * 60;
  int get noShowSeconds =>
      math.max(freeSeconds, serverNoShowSeconds ?? noShowAfterMinutes * 60);

  /// The driver's part of the no-show fee, in the fee's own currency and
  /// minor units (öre, cents, millimes).
  Money get driverNoShowFee => Money(
    minorUnits: (noShowFee.minorUnits * driverShareNoShowPercent / 100).round(),
    currency: noShowFee.currency,
  );

  /// Q42: the waiting fee for [paidSeconds] past the free wait, at
  /// [perMinute] counted by the second and rounded to a whole minor unit.
  /// It is the rider's charge; see [driverWaitingFee] for the driver's part.
  Money waitingFee(int paidSeconds) => Money(
    minorUnits: paidSeconds <= 0
        ? 0
        : (perMinute.minorUnits * paidSeconds / 60).round(),
    currency: perMinute.currency,
  );

  /// Q43: the driver's part of [waitingFee] ([driverShareWaitPercent],
  /// 100% by default).
  Money driverWaitingFee(int paidSeconds) {
    final fee = waitingFee(paidSeconds);
    return Money(
      minorUnits: (fee.minorUnits * driverShareWaitPercent / 100).round(),
      currency: fee.currency,
    );
  }

  /// [label] (e.g. "104,80 kr", "24,50 €", "12,500 DT") with [fee]
  /// added, in the same display form. The label is read in the fee's
  /// currency with that currency's exponent. Unchanged with no fee, or
  /// when the label is not money in the fee's currency.
  static String addFee(String label, Money fee) {
    if (fee.isZero) return label;
    final amount = Money.parseLabel(label, currency: fee.currency);
    return amount == null ? label : (amount + fee).formatted;
  }

  /// The terms of the trip on screen now: the waiting clocks read them.
  static WaitingTerms active = WaitingRules.current.base;

  WaitingTerms _with(WaitingRule rule, {String? label}) => WaitingTerms(
    freeMinutes: rule.freeMinutes ?? freeMinutes,
    perMinute: rule.perMinute ?? perMinute,
    noShowAfterMinutes: rule.noShowAfterMinutes ?? noShowAfterMinutes,
    noShowFee: rule.noShowFee ?? noShowFee,
    driverShareWaitPercent: driverShareWaitPercent,
    driverShareNoShowPercent: driverShareNoShowPercent,
    pricesKnown: rule.pricesKnown ?? pricesKnown,
    ruleLabels: [
      ...ruleLabels,
      if ((label ?? rule.label).isNotEmpty) label ?? rule.label,
    ],
  );

  /// An admin default label still as shipped, in the app's language.
  static String _shown(String label) => switch (label) {
    _ when label.startsWith(_farPickup) => tr.pickupOverKmKm(
      label.substring(_farPickup.length).replaceAll('.', tr.navDecimalMark),
    ),
    'Pickup far away' => tr.waitingRulePickupFarAway,
    'Scheduled ride' => tr.waitingRuleScheduledRide,
    'Airport pickup' => tr.waitingRuleAirportPickup,
    'Event pickup' => tr.waitingRuleEventPickup,
    _ => label,
  };
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
    this.pricesKnown,
  });

  /// True when this rule's served terms (with the zone's) carry both
  /// amounts (G5 checker round 2: `byCategory` may hold the prices).
  final bool? pricesKnown;

  /// Shown to the driver, e.g. "Airport pickup".
  final String label;
  final int? freeMinutes;
  final Money? perMinute;
  final int? noShowAfterMinutes;
  final Money? noShowFee;
}

class WaitingRules {
  const WaitingRules({
    // contract.json#configDefaults (owner Q41): 5 free minutes, and the
    // no-show comes when they end. A live build replaces every number with
    // the zone's served pricing (`GET /driver/config` → `waiting`, contract
    // v0.18.7 `pickupWaiting.servedConfig`) and each trip with its own
    // `terms`; nothing here is a price the driver is ever shown on its own.
    // No prices of the app's own (G5 checker round 1): without server
    // terms the amounts are zero and [WaitingTerms.pricesKnown] is false.
    this.base = const WaitingTerms(
      freeMinutes: 5,
      perMinute: Money(minorUnits: 0),
      noShowAfterMinutes: 5,
      noShowFee: Money(minorUnits: 0),
      driverShareWaitPercent: 100,
      driverShareNoShowPercent: 80,
      pricesKnown: false,
    ),
    // Contract v0.18.7 (driver group 5): the app's own extra rules (far
    // pickup, airport, event) are gone — the server never knew them
    // (admin rules come with group 6). A scheduled ride still waits the
    // reservation policy's included minutes (its server terms say the
    // same); a category's own terms come from `waiting.byCategory`.
    this.farPickupKm = double.infinity,
    this.farPickup = const WaitingRule(label: ''),
    this.rideTypes = const {
      WaitingRideType.scheduled: WaitingRule(label: 'Scheduled ride'),
    },
    this.categories = const {},
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static WaitingRules current = const WaitingRules();

  /// The zone's terms when no extra rule applies.
  final WaitingTerms base;

  /// Over this many km to the pickup, [farPickup] applies.
  final double farPickupKm;
  final WaitingRule farPickup;

  final Map<WaitingRideType, WaitingRule> rideTypes;

  /// By ride category id (`contract.json#categories`), e.g. `premium`.
  final Map<String, WaitingRule> categories;

  /// The rule for a category given as a wire id (`xl`) or as a driver
  /// display name (`Movera XL`, `XL`); null when none is set.
  WaitingRule? ruleForCategory(String category) {
    final raw = category.trim();
    final id = CategoryCatalog.canonicalId(
      CategoryCatalog.idForLabel(raw) ?? raw,
    );
    return id == null ? null : categories[id];
  }

  /// The terms for one pickup. Category first, then ride type, then the
  /// distance rule: a later rule wins where it sets a value.
  WaitingTerms termsFor({
    String category = '',
    WaitingRideType type = WaitingRideType.normal,
    double? pickupKm,
  }) {
    var terms = base;
    final byCategory = ruleForCategory(category);
    if (byCategory != null) {
      // Q41: a category's no-show comes with the end of its free wait.
      terms = terms._with(
        byCategory.noShowAfterMinutes == null && byCategory.freeMinutes != null
            ? WaitingRule(
                label: byCategory.label,
                freeMinutes: byCategory.freeMinutes,
                perMinute: byCategory.perMinute,
                noShowAfterMinutes: byCategory.freeMinutes,
                noShowFee: byCategory.noShowFee,
                pricesKnown: byCategory.pricesKnown,
              )
            : byCategory,
      );
    }
    final byType = rideTypes[type];
    if (byType != null) {
      terms = terms._with(
        type == WaitingRideType.scheduled
            ? WaitingRule(
                label: byType.label,
                freeMinutes: ScheduledRideRules.current.includedWaitingMinutes,
                perMinute: byType.perMinute,
                noShowAfterMinutes: byType.noShowAfterMinutes,
                noShowFee: byType.noShowFee,
              )
            : byType,
      );
    }
    if (pickupKm != null &&
        pickupKm > farPickupKm &&
        farPickupKm.isFinite &&
        farPickup.label.isNotEmpty) {
      final km = farPickupKm == farPickupKm.roundToDouble()
          ? farPickupKm.toStringAsFixed(0)
          : farPickupKm.toStringAsFixed(1);
      terms = terms._with(farPickup, label: WaitingTerms.farPickupLabel(km));
    }
    // Never a no-show before the free wait is over (Q41).
    return terms.noShowAfterMinutes >= terms.freeMinutes
        ? terms
        : terms._with(
            WaitingRule(label: '', noShowAfterMinutes: terms.freeMinutes),
            label: '',
          );
  }

  /// The kind of trip, from how it was matched and where it starts.
  static WaitingRideType typeOf({
    required String matchedVia,
    required String pickupAddress,
  }) {
    if (RegExp(
      r'airport|arlanda|terminal',
      caseSensitive: false,
    ).hasMatch(pickupAddress)) {
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
