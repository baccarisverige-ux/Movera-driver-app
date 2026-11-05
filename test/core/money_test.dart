import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/earnings/earnings.dart';
import 'package:movera/core/money/money.dart';

void main() {
  test('SEK formats with comma decimals and grouped thousands', () {
    expect(Money.units(104.80, currency: 'SEK').formatted, '104,80 kr');
    expect(Money(minorUnits: 299480, currency: 'SEK').formatted, '2 994,80 kr');
    expect(Money.units(-325.40, currency: 'SEK').formatted, '−325,40 kr');
  });

  test('earnings net is gross minus commission plus tips', () {
    final week = EarningsPeriod(
      periodId: 'test',
      label: 'Test',
      gross: Money.units(1724.15, currency: 'SEK'),
      commission: Money.units(325.40, currency: 'SEK'),
      tips: Money.units(84.00, currency: 'SEK'),
      adjustments: Money(minorUnits: 0, currency: 'SEK'),
    );

    expect(week.net.ore, 148275);
    expect(week.net.formatted, '1 482,75 kr');
  });

  test('in-memory earnings seed a Stockholm week', () async {
    final repo = InMemoryEarningsRepository();
    final periods = await repo.load();
    expect(periods, hasLength(1));
    expect(periods.first.net.currency, 'SEK');
  });
}
