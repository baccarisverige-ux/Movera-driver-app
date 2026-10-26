import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/money/money.dart';

void main() {
  test('R8-4: cash balance is fare − cash, both directions', () {
    final owes = CashBalance.fromLabels(
      fare: '200 kr',
      cashCollected: '250 kr',
    )!;
    expect(owes.balance, Money.sek(-50));
    expect(owes.driverOwesMovera, isTrue);
    expect(owes.signedLabel, '−50,00 kr');
    expect(owes.directionLabel, 'You owe Movera');

    final due = CashBalance.fromLabels(
      fare: '300 kr',
      cashCollected: '200 kr',
    )!;
    expect(due.balance, Money.sek(100));
    expect(due.moveraOwesDriver, isTrue);
    expect(due.signedLabel, '+100,00 kr');
    expect(due.directionLabel, 'Movera owes you');

    expect(CashBalance.total([owes, due]), Money.sek(50));
  });
}
