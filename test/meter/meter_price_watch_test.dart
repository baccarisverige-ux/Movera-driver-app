import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/meter_price_watch.dart';

Money _sek(int minor) => Money(minorUnits: minor, currency: 'SEK');

void main() {
  test('the first price is only known; a new price is returned once', () {
    final watch = MeterPriceWatch()..seed(null);
    expect(watch.observe(_sek(21500)), isNull);
    expect(watch.observe(_sek(21500)), isNull);
    expect(watch.observe(_sek(24000)), _sek(24000));
    expect(watch.observe(_sek(24000)), isNull);
    expect(watch.observe(null), isNull);
    expect(watch.meter, _sek(24000));
  });

  test('a price waits for the stored one', () {
    final watch = MeterPriceWatch();
    expect(watch.observe(_sek(24000)), isNull);
    expect(watch.seed(_sek(21500)), _sek(24000));
    final same = MeterPriceWatch();
    same.observe(_sek(21500));
    expect(same.seed(_sek(21500)), isNull);
    final none = MeterPriceWatch();
    none.observe(_sek(24000));
    expect(none.seed(null), isNull);
    expect(none.meter, _sek(24000));
  });

  test('a new currency is a new price', () {
    final watch = MeterPriceWatch()..seed(null);
    watch.observe(_sek(21500));
    expect(
      watch.observe(const Money(minorUnits: 21500, currency: 'EUR')),
      isNotNull,
    );
  });

  test('the store is written only when the value changes', () {
    final watch = MeterPriceWatch()..seed(_sek(21500));
    expect(watch.needsStore(_sek(21500)), isFalse);
    expect(watch.needsStore(_sek(24000)), isTrue);
    expect(watch.needsStore(_sek(24000)), isFalse);
  });
}
