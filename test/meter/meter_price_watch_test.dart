import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/meter_price_watch.dart';

Money _sek(int minor) => Money(minorUnits: minor, currency: 'SEK');

void main() {
  test('before the start the meter follows the price, no notice', () {
    final watch = MeterPriceWatch()..seed(null);
    expect(watch.observe(_sek(21500), started: false), isNull);
    expect(watch.observe(_sek(22000), started: false), isNull);
    expect(watch.meter, _sek(22000));
  });

  test('after the start a new price is returned once, the same is not', () {
    final watch = MeterPriceWatch()..seed(null);
    expect(watch.observe(_sek(21500), started: true), isNull);
    expect(watch.observe(_sek(21500), started: true), isNull);
    expect(watch.observe(_sek(24000), started: true), _sek(24000));
    expect(watch.observe(_sek(24000), started: true), isNull);
    expect(watch.observe(null, started: true), isNull);
  });

  test('a started price waits for the stored one', () {
    final watch = MeterPriceWatch();
    expect(watch.observe(_sek(24000), started: true), isNull);
    expect(watch.seed(_sek(21500)), _sek(24000));
    final same = MeterPriceWatch();
    same.observe(_sek(21500), started: true);
    expect(same.seed(_sek(21500)), isNull);
    final none = MeterPriceWatch();
    none.observe(_sek(24000), started: true);
    expect(none.seed(null), isNull);
    expect(none.meter, _sek(24000));
  });

  test('a new currency is a new price', () {
    final watch = MeterPriceWatch()..seed(null);
    watch.observe(_sek(21500), started: true);
    expect(
      watch.observe(
        const Money(minorUnits: 21500, currency: 'EUR'),
        started: true,
      ),
      isNotNull,
    );
  });
}
