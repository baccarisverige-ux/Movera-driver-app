import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/core/money/money.dart';

/// The money of a live trip as its projection carries it (contract §2,
/// §3.5): the rider's `fare`, the driver's `driverEarnings` with
/// `pickupPay` and `driverBonus` on top (the server keeps both out of
/// `driverEarnings` and pays them from Movera's share), the waiting lines and
/// what a cash rider hands over. The server works it out on `complete`:
/// a finish away from the drop-off is priced by what was driven (km and
/// minutes on board), never below the category's minimum
/// (`minimum_adjust`) and never above the booked fare (owner N9, live
/// test 2026-10-26), so the booked numbers the app kept from the offer
/// are not the trip's.
class LiveTripMoney {
  const LiveTripMoney({
    required this.riderFare,
    required this.driverEarnings,
    this.pickupPay,
    this.driverBonus,
    this.waitingFee,
    Money? cashToCollect,
    this.driverTotal,
    this.earningsBreakdown = const [],
    this.tip,
    this.debtCollected,
    this.finish,
  }) : _cashToCollect = cashToCollect;

  /// The projection's money, or null without a `fare` and
  /// `driverEarnings` (the rider's view, an old server).
  static LiveTripMoney? tryParse(Map<String, dynamic> projection) {
    Money? money(Object? value) {
      if (value is! Map) return null;
      try {
        return Money.fromJson(Map<String, dynamic>.from(value));
      } on FormatException {
        return null;
      }
    }

    final fare = money(projection['fare']);
    final earnings = money(projection['driverEarnings']);
    if (fare == null || earnings == null) return null;
    Money? waiting;
    final lines = projection['fareLines'];
    if (lines is List) {
      for (final line in lines) {
        if (line is! Map) continue;
        if (line['code'] != 'waiting' && line['code'] != 'stop_waiting') {
          continue;
        }
        final amount = money(line['amount']);
        if (amount == null || amount.currency != fare.currency) continue;
        waiting = waiting == null ? amount : waiting + amount;
      }
    }
    final pickupPay = money(projection['pickupPay']);
    final bonus = money(projection['driverBonus']);
    final finish = TripFinishInfo.tryParse(projection['finish']);
    final total = money(projection['driverTotal']) ?? finish?.driverTotal;
    final debt = money(projection['debtCollected']);
    return LiveTripMoney(
      driverTotal: total != null && total.currency == earnings.currency
          ? total
          : null,
      earningsBreakdown: EarningsLine.parseList(
        projection['earningsBreakdown'] ??
            (projection['finish'] is Map
                ? (projection['finish'] as Map)['earningsBreakdown']
                : null),
        currency: earnings.currency,
      ),
      tip: TripTipInfo.tryParse(projection['tip']),
      debtCollected:
          debt != null && debt.currency == fare.currency && debt.minorUnits > 0
          ? debt
          : null,
      finish: finish,
      riderFare: fare,
      driverEarnings: earnings,
      pickupPay: pickupPay != null && pickupPay.currency == earnings.currency
          ? pickupPay
          : null,
      driverBonus: bonus != null && bonus.currency == earnings.currency
          ? bonus
          : null,
      waitingFee: waiting != null && waiting.minorUnits > 0 ? waiting : null,
      cashToCollect:
          money(projection['cashToCollect']) ?? finish?.cashToCollect,
    );
  }

  /// What the rider pays (`fare`).
  final Money riderFare;

  /// The driver's share after Movera's commission (`driverEarnings`).
  final Money driverEarnings;

  /// Movera's pickup pay, on top of the earnings; null for none.
  final Money? pickupPay;

  /// The admin's driver bonus, on top of the earnings; null for none.
  final Money? driverBonus;

  /// The `waiting` and `stop_waiting` lines, all the driver's; null for
  /// none.
  final Money? waitingFee;

  final Money? _cashToCollect;

  /// Contract v0.18.10 (owner G8 Q3 "One number"): the server's one driver
  /// money number (earnings + pickup pay + bonus + tip + Movera's changes);
  /// null from an older server.
  final Money? driverTotal;
  final List<EarningsLine> earningsBreakdown;

  /// The rider's tip, all the driver's; null for none.
  final TripTipInfo? tip;

  /// An earlier unpaid fee the rider paid with this trip: it goes to that
  /// trip, never Movera's commission (G8 live bug 318 kr).
  final Money? debtCollected;

  /// How the trip ended (rider or driver ended early).
  final TripFinishInfo? finish;

  /// The driver's own money for the trip ("You get"): earnings plus
  /// pickup pay plus bonus, so `fare − commission` is exactly this.
  Money get driverPay {
    if (driverTotal case final total?) return total;
    var pay = driverEarnings;
    if (pickupPay case final extra?) pay = pay + extra;
    if (driverBonus case final extra?) pay = pay + extra;
    return pay;
  }

  /// On a cash trip, what the rider hands over: the server's
  /// `cashToCollect` when a wallet paid part, else the whole fare.
  Money get cash => _cashToCollect ?? riderFare;
}
