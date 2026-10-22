import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';

/// R8-4: a cash trip's balance between the driver and Movera.
///
/// The cash the rider pays in the car can differ from the driver's fare
/// (rider promotions etc.). Balance = fare − cash collected:
/// - fare 200, cash 250 → −50: the driver owes Movera 50.
/// - fare 300, cash 200 → +100: Movera owes the driver 100.
class CashBalance {
  const CashBalance({required this.fare, required this.cashCollected});

  /// From display labels such as "200 kr"; null when either is unknown.
  static CashBalance? fromLabels({
    required String fare,
    required String cashCollected,
  }) {
    final fareMoney = Money.parseLabel(fare);
    final cash = fareMoney == null
        ? null
        : Money.parseLabel(cashCollected, currency: fareMoney.currency);
    if (fareMoney == null || cash == null) return null;
    return CashBalance(fare: fareMoney, cashCollected: cash);
  }

  /// The driver's fare for the trip.
  final Money fare;

  /// What the driver took from the rider in cash.
  final Money cashCollected;

  /// Positive: Movera owes the driver. Negative: the driver owes Movera.
  Money get balance => fare - cashCollected;

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
