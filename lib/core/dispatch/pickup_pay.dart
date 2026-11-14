import 'dart:math' as math;

import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/geo/driver_distance.dart';

/// The drive to an offer's pickup, from where the driver is when the offer
/// shows (for a next trip while driving: from the current trip's
/// drop-off).
class PickupLeg {
  const PickupLeg({required this.km, required this.minutes});

  final double km;
  final int minutes;

  /// "4.2 km · 9 min", "650 m · 2 min" (Q20).
  String get label => driverDistanceAndMinutes(km, minutes);
}

/// The pickup pay of one offer, as shown now. Worked out again every time
/// the offer shows: it is never kept by offer id, so a driver who moved
/// gets the pay for the new distance.
class PickupPayQuote {
  const PickupPayQuote({
    required this.pay,
    required this.leg,
    this.display = PickupPayDisplay.totalOnly,
    this.serverTotal,
  });

  final Money pay;
  final PickupLeg leg;
  final PickupPayDisplay display;

  /// Contract v0.18.89 `Offer.driverTotal` (§90): what the driver gets for
  /// the trip, pickup pay included, as the server worked it out. When set
  /// it is the only number the offer shows (owner Q-M6, s06:1164); the
  /// phone adds nothing to it.
  final Money? serverTotal;

  bool get hasPay => pay.ore > 0;

  /// The amount the offer card shows for [fare] (the driver's own money,
  /// e.g. "142,30 kr", "12,50 €", "12.500 DT"): the server's
  /// [serverTotal] when it sent one; else [fare] plus the server's pickup
  /// pay (contract §3.2 before v0.18.89), read in the pay's own currency
  /// with its decimals (price audit 2026-11-14 gap 1: a SEK-only reader
  /// dropped the pickup pay of every euro and dinar offer). Unchanged when
  /// there is no pickup pay or the label is not an amount in it.
  String totalOf(String fare) {
    if (serverTotal case final total?) return total.formatted;
    if (!hasPay) {
      return fare;
    }
    final base = Money.parseLabel(fare, currency: pay.currency);
    return base == null ? fare : (base + pay).formatted;
  }

  /// The accepted trip's terms with this pickup pay in them, so the trip,
  /// its waybill and history keep the total the card showed (driver-12).
  /// [fare] is the driver's own money for the trip (`RideOffer.driverPay`,
  /// owner decision 2026-10-26), never the rider's fare. Movera pays the
  /// pickup pay from its commission, like a bonus: it is added to
  /// [driverBonus] (no fee on it, all of it the driver's). [cashToCollect],
  /// the rider's cash on a cash trip (`RideOffer.riderCash`), is kept as
  /// given: the rider pays their own fare, never this total. Unchanged
  /// without pickup pay. The fare is [totalOf], so the trip keeps the
  /// card's own number ([serverTotal] when the server sent one).
  ({String fare, Money? driverBonus, String? cashToCollect}) termsOf({
    required String fare,
    Money? driverBonus,
    String? cashToCollect,
  }) {
    final total = serverTotal;
    final base = hasPay && total == null
        ? Money.parseLabel(fare, currency: pay.currency)
        : null;
    if (total == null && base == null) {
      return (
        fare: fare,
        driverBonus: driverBonus,
        cashToCollect: cashToCollect,
      );
    }
    final bonus = !hasPay
        ? driverBonus
        : driverBonus == null
        ? pay
        : driverBonus.currency == pay.currency
        ? driverBonus + pay
        : driverBonus;
    return (
      fare: total?.formatted ?? (base! + pay).formatted,
      driverBonus: bonus,
      cashToCollect: cashToCollect,
    );
  }
}

/// Pure pickup pay maths:
/// `max(0, km − freeKm) × kr/km + max(0, min − freeMin) × kr/min`,
/// rounded to öre; 0 when the category or the offer kind is off. With
/// distance ranges, kr/km and kr/min are the whole leg's range's.
abstract final class PickupPayCalculator {
  static Money pay({
    required String category,
    required PickupPayOfferKind kind,
    required PickupLeg leg,
    PickupPayConfig? config,
  }) {
    final rules = config ?? PickupPayConfig.current;
    if (!rules.kindOn(kind)) {
      return Money.zone(0);
    }
    final rate = rules.rateFor(category);
    if (!rate.enabled) {
      return Money.zone(0);
    }
    final km = math.max(0.0, leg.km - (rate.freeKmOn ? rate.freeKm : 0));
    final minutes = math.max(
      0,
      leg.minutes - (rate.freeMinutesOn ? rate.freeMinutes : 0),
    );
    // The range is picked by the whole leg's km, before free km.
    final kronor =
        km * rate.krPerKmFor(leg.km) + minutes * rate.krPerMinuteFor(leg.km);
    // Round once, to öre; the tiny epsilon keeps 12.6 from being 12.5999….
    final ore = (kronor * 100 + 1e-6).round();
    // Job 3 / L12: the rates are the zone's pickup pay settings
    // (`DriverAppConfig.pickupPay`), so the pay is in the zone's currency.
    return Money.zone(math.max(0, ore));
  }

  /// The quote an offer card shows now. [serverPay] is the offer's own
  /// `Offer.pickupPay` and [serverTotal] its `Offer.driverTotal`
  /// (v0.18.89). Against a live server the server's pay is the pay and no
  /// `pickupPay` means none (price audit 2026-11-14 gap 2: never worked out
  /// on the phone; the server sends it only above 0); the local rates are
  /// for the demo's own offers only.
  static PickupPayQuote quote({
    required String category,
    required PickupPayOfferKind kind,
    required PickupLeg leg,
    PickupPayConfig? config,
    Money? serverPay,
    Money? serverTotal,
    String? currency,
    bool? live,
  }) {
    final rules = config ?? PickupPayConfig.current;
    final onServer = live ?? LiveDriverServices.active;
    return PickupPayQuote(
      pay:
          serverPay ??
          (onServer
              ? Money(
                  minorUnits: 0,
                  currency:
                      serverTotal?.currency ?? currency ?? Money.zoneCurrency,
                )
              : pay(category: category, kind: kind, leg: leg, config: rules)),
      leg: leg,
      display: rules.display,
      serverTotal: serverTotal,
    );
  }
}
