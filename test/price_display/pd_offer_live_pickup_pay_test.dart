import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

import 'live_fake.dart';

/// Price audit 2026-11-14 gap 2 (Rules
/// audits/price-display-2026-11-14/REPORT.md): a live offer never shows a
/// pickup pay worked out on the phone. Gap 1 (currency): PD-1's
/// pd_pickup_pay_currency_test.dart.
void main() {
  tearDown(uninstallLive);

  test('gap 2: a live offer without Offer.pickupPay has no pickup pay', () {
    installLive();
    Money.zoneCurrency = 'SEK';
    final quote = PickupPayCalculator.quote(
      category: 'Movera',
      kind: PickupPayOfferKind.radar,
      leg: const PickupLeg(km: 25, minutes: 40),
    );
    expect(quote.pay.minorUnits, 0);
    expect(quote.hasPay, isFalse);
    expect(quote.totalOf('104,80 kr'), '104,80 kr');
  });

  test('gap 2: a live offer shows the server pickup pay, in its currency', () {
    installLive();
    final quote = PickupPayCalculator.quote(
      category: 'Movera',
      kind: PickupPayOfferKind.radar,
      leg: const PickupLeg(km: 25, minutes: 40),
      serverPay: const Money(minorUnits: 2500, currency: 'TND'),
    );
    expect(quote.totalOf('10.000 DT'), '12.500 DT');
  });
}
