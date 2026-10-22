import 'dart:math' as math;

import 'package:movera/core/admin/pickup_pay_config.dart';
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
  });

  final Money pay;
  final PickupLeg leg;
  final PickupPayDisplay display;

  bool get hasPay => pay.ore > 0;

  /// [fare] (a "142,30 kr" label) plus the pickup pay. Unchanged when
  /// there is no pickup pay or the label is not an amount.
  String totalOf(String fare) {
    if (!hasPay) {
      return fare;
    }
    final base = Money.parseSekLabel(fare);
    return base == null ? fare : (base + pay).formatted;
  }

  /// The accepted trip's terms with this pickup pay in them, so the trip,
  /// its waybill and history keep the total the card showed (driver-12).
  /// Movera pays it from its commission, like a bonus: it is added to
  /// [driverBonus] (no fee on it, all of it the driver's), and a cash
  /// rider still pays only [fare]. Unchanged without pickup pay.
  /// driver-r5-14: [fare] already includes [driverBonus] (the contract),
  /// so with no server [cashToCollect] a cash rider pays [fare] less the
  /// bonus, as AcceptRide's own rider fare (driver-u61) would.
  ({String fare, Money? driverBonus, String? cashToCollect}) termsOf({
    required String fare,
    Money? driverBonus,
    String? cashToCollect,
    required bool paidByCash,
  }) {
    final base = hasPay ? Money.parseSekLabel(fare) : null;
    if (base == null) {
      return (
        fare: fare,
        driverBonus: driverBonus,
        cashToCollect: cashToCollect,
      );
    }
    return (
      fare: (base + pay).formatted,
      driverBonus: driverBonus == null ? pay : driverBonus + pay,
      cashToCollect: paidByCash
          ? cashToCollect ?? _riderFare(fare, base, driverBonus)
          : cashToCollect,
    );
  }

  /// [fare] without Movera's [bonus]; [fare] itself when there is no
  /// bonus, it is another currency or larger than the fare.
  static String _riderFare(String fare, Money base, Money? bonus) {
    if (bonus == null ||
        bonus.minorUnits <= 0 ||
        bonus.currency != base.currency ||
        bonus.minorUnits > base.minorUnits) {
      return fare;
    }
    return (base - bonus).formatted;
  }

  /// "incl. 21,60 kr pickup · 4.2 km · 9 min", only when admin shows the
  /// pickup line.
  String? get line => hasPay && display == PickupPayDisplay.fareWithPickupLine
      ? 'incl. ${pay.formatted} pickup · ${leg.label}'
      : null;
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
      return Money.ore(0);
    }
    final rate = rules.rateFor(category);
    if (!rate.enabled) {
      return Money.ore(0);
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
    return Money.ore(math.max(0, ore));
  }

  /// The quote an offer card shows now. [serverPay] is the offer's own
  /// `Offer.pickupPay`: when the server sent one, it is the pay
  /// (driver-r5-1); the local rates are for demo offers.
  static PickupPayQuote quote({
    required String category,
    required PickupPayOfferKind kind,
    required PickupLeg leg,
    PickupPayConfig? config,
    Money? serverPay,
  }) {
    final rules = config ?? PickupPayConfig.current;
    return PickupPayQuote(
      pay: serverPay ??
          pay(category: category, kind: kind, leg: leg, config: rules),
      leg: leg,
      display: rules.display,
    );
  }
}
