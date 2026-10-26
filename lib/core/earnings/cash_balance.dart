import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';

/// R8-4: a cash trip's balance between the driver and Movera.
///
/// The cash the rider pays in the car is their fare; the driver's money
/// is their earnings after Movera's commission (owner decision
/// 2026-10-26: the trip's [fare] is already that), so
/// balance = earnings − cash:
/// - earnings 150, cash 200 → −50: the driver owes Movera 50.
/// - earnings 225, cash 200 → +25: Movera owes the driver 25.
/// [serviceFee] is kept for a fee not yet taken off [fare]; the app's own
/// records carry none.
class CashBalance {
  const CashBalance({
    required this.fare,
    required this.cashCollected,
    this.serviceFee,
  });

  /// From display labels such as "200 kr"; null when the fare or the cash
  /// is unknown. [serviceFee] is Movera's fee on the trip (the waybill's).
  static CashBalance? fromLabels({
    required String fare,
    required String cashCollected,
    String? serviceFee,
  }) {
    final fareMoney = Money.parseLabel(fare);
    final cash = fareMoney == null
        ? null
        : Money.parseLabel(cashCollected, currency: fareMoney.currency);
    if (fareMoney == null || cash == null) return null;
    final fee = serviceFee == null
        ? null
        : Money.parseLabel(serviceFee, currency: fareMoney.currency);
    return CashBalance(
      fare: fareMoney,
      cashCollected: cash,
      serviceFee: fee == null || fee.isZero ? null : fee,
    );
  }

  /// The driver's money for the trip ([serviceFee], if any, not yet taken
  /// off).
  final Money fare;

  /// What the driver took from the rider in cash.
  final Money cashCollected;

  /// Movera's fee on the fare; null for none.
  final Money? serviceFee;

  /// The driver's: the fare after Movera's fee.
  Money get earnings => serviceFee == null ? fare : fare - serviceFee!;

  /// Positive: Movera owes the driver. Negative: the driver owes Movera.
  Money get balance => earnings - cashCollected;

  bool get driverOwesMovera => balance.minorUnits < 0;
  bool get moveraOwesDriver => balance.minorUnits > 0;

  /// "+100,00 kr", "−50,00 kr" or "0,00 kr".
  String get signedLabel => signed(balance);

  /// "You owe Movera", "Movera owes you" or "Settled".
  String get directionLabel => direction(balance);

  static String signed(Money amount) =>
      amount.minorUnits > 0 ? '+${amount.formatted}' : amount.formatted;

  static String direction(Money amount) => amount.minorUnits < 0
      ? tr.cashYouOweMovera
      : amount.minorUnits > 0
      ? tr.cashMoveraOwesYou
      : tr.cashSettled;

  /// The sum of several trips' balances.
  static Money total(Iterable<CashBalance> balances) =>
      balances.fold(Money.ore(0), (sum, item) => sum + item.balance);
}
