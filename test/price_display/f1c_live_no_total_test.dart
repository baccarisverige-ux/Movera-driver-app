import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

import 'live_fake.dart';

/// BQ-F1c (owner R2: the apps never work money out; Rules
/// audits/impact/f1b-waybill-bonus-supervisor.md follow-up 1): on live, an
/// accepted offer with a server pickup pay but no `Offer.driverTotal`
/// (an older server) shows "—", never its earnings plus the pickup pay
/// added up on the phone. Its bonus and pickup pay lines stay the
/// server's own.
void main() {
  const leg = PickupLeg(km: 6.4, minutes: 12);

  final cases = <({String currency, int earnings, int bonus, int pickup})>[
    (currency: 'SEK', earnings: 22400, bonus: 4000, pickup: 1395),
    (currency: 'TND', earnings: 15000, bonus: 2000, pickup: 1250),
  ];

  setUp(installLive);
  tearDown(uninstallLive);

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    test('${c.currency} live accept, no server total: "—", no phone sum', () {
      final terms = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
      ).termsOf(fare: m(c.earnings).formatted, driverBonus: m(c.bonus));
      expect(terms.fare, '—');
      expect(terms.fare, isNot(m(c.earnings + c.pickup).formatted));
      expect(terms.driverBonus, m(c.bonus));
      expect(terms.pickupPay, m(c.pickup));
    });

    test(
      '${c.currency} live accept, no pickup pay, no total: the earnings',
      () {
        final terms = PickupPayQuote(
          pay: m(0),
          leg: leg,
        ).termsOf(fare: m(c.earnings).formatted);
        expect(terms.fare, m(c.earnings).formatted);
        expect(terms.pickupPay, isNull);
      },
    );

    test('${c.currency} live accept with a server total: the total', () {
      final terms = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
        serverTotal: m(c.earnings + c.pickup),
      ).termsOf(fare: m(c.earnings).formatted, driverBonus: m(c.bonus));
      expect(terms.fare, m(c.earnings + c.pickup).formatted);
    });

    test('${c.currency} demo keeps its written-out sample sum', () {
      final terms = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
      ).termsOf(fare: m(c.earnings).formatted, live: false);
      expect(terms.fare, m(c.earnings + c.pickup).formatted);
    });
  }
}
