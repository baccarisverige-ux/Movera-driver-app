import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

// Round-5 medium audit bugs (FIX_PLAN Wave 6b), one group per bug.

void main() {
  group('driver-r5-14', () {
    test('a cash rider with pickup pay still pays the fare without the '
        'Movera bonus', () {
      final quote = PickupPayQuote(
        pay: Money.ore(1300),
        leg: const PickupLeg(km: 4, minutes: 6),
      );
      final terms = quote.termsOf(
        fare: '152,40 kr',
        driverBonus: Money.ore(4000),
        paidByCash: true,
      );
      expect(terms.fare, '165,40 kr');
      expect(terms.driverBonus, Money.ore(5300));
      // 152,40 kr includes Movera's 40 kr bonus: the rider pays 112,40 kr.
      expect(terms.cashToCollect, '112,40 kr');
      // A server cash amount still wins.
      expect(
        quote
            .termsOf(
              fare: '152,40 kr',
              driverBonus: Money.ore(4000),
              cashToCollect: '120,00 kr',
              paidByCash: true,
            )
            .cashToCollect,
        '120,00 kr',
      );
    });
  });
}
