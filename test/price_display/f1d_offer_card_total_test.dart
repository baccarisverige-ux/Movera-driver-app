import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

import 'live_fake.dart';

/// BQ-F1d (owner R2: the apps never work money out): on live the offer
/// card's one number ([PickupPayQuote.totalOf]) is the server's
/// `Offer.driverTotal`; with a pickup pay and no driverTotal (an older
/// server) it is "—", never the earnings plus the pickup pay added up on
/// the phone. The demo keeps its own written-out sum.
void main() {
  const leg = PickupLeg(km: 6.4, minutes: 12);

  final cases = <({String currency, int earnings, int pickup})>[
    (currency: 'SEK', earnings: 22400, pickup: 1395),
    (currency: 'TND', earnings: 15000, pickup: 1250),
  ];

  tearDown(uninstallLive);

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    test('${c.currency} live card, pickup pay, no driverTotal: "—"', () {
      installLive();
      final quote = PickupPayQuote(pay: m(c.pickup), leg: leg);
      expect(quote.totalOf(m(c.earnings).formatted), '—');
    });

    test('${c.currency} live card with driverTotal: the server total', () {
      installLive();
      final quote = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
        serverTotal: m(c.earnings + c.pickup),
      );
      expect(
        quote.totalOf(m(c.earnings).formatted),
        m(c.earnings + c.pickup).formatted,
      );
    });

    test('${c.currency} live card, no pickup pay: the earnings', () {
      installLive();
      final quote = PickupPayQuote(pay: m(0), leg: leg);
      expect(quote.totalOf(m(c.earnings).formatted), m(c.earnings).formatted);
    });

    test('${c.currency} demo card keeps its sample sum', () {
      final quote = PickupPayQuote(pay: m(c.pickup), leg: leg);
      expect(
        quote.totalOf(m(c.earnings).formatted),
        m(c.earnings + c.pickup).formatted,
      );
      expect(
        quote.totalOf(m(c.earnings).formatted, live: false),
        m(c.earnings + c.pickup).formatted,
      );
    });
  }
}
