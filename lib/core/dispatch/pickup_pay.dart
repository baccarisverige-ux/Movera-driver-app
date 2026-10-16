import 'dart:math' as math;

import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/money/money.dart';

/// The drive to an offer's pickup, from where the driver is when the offer
/// shows (for a next trip while driving: from the current trip's
/// drop-off).
class PickupLeg {
  const PickupLeg({required this.km, required this.minutes});

  final double km;
  final int minutes;

  /// "4.2 km · 9 min".
  String get label => '${km.toStringAsFixed(1)} km · $minutes min';
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

  /// "incl. 21,60 kr pickup · 4.2 km · 9 min", only when admin shows the
  /// pickup line.
  String? get line => hasPay && display == PickupPayDisplay.fareWithPickupLine
      ? 'incl. ${pay.formatted} pickup · ${leg.label}'
      : null;
}

/// Pure pickup pay maths:
/// `max(0, km − freeKm) × kr/km + max(0, min − freeMin) × kr/min`,
/// rounded to öre; 0 when the category or the offer kind is off.
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
    final kronor = km * rate.krPerKm + minutes * rate.krPerMinute;
    // Round once, to öre; the tiny epsilon keeps 12.6 from being 12.5999….
    final ore = (kronor * 100 + 1e-6).round();
    return Money.ore(math.max(0, ore));
  }

  /// The quote an offer card shows now.
  static PickupPayQuote quote({
    required String category,
    required PickupPayOfferKind kind,
    required PickupLeg leg,
    PickupPayConfig? config,
  }) {
    final rules = config ?? PickupPayConfig.current;
    return PickupPayQuote(
      pay: pay(category: category, kind: kind, leg: leg, config: rules),
      leg: leg,
      display: rules.display,
    );
  }
}
