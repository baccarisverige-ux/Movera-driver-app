import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

import 'live_fake.dart';

/// BQ-F1b (owner R2, Rules audits/impact/f1-f2bc-driver-supervisor.md
/// follow-up 1): on live the trip's bonus line is the server's own
/// `driverBonus` (contract `Offer.driverBonus` / `TripProjection
/// .driverBonus`), never the server bonus plus the pickup pay added up on
/// the phone. The pickup pay is its own server line (`pickupPay`).
void main() {
  const leg = PickupLeg(km: 6.4, minutes: 12);

  // Server numbers of one offer: Movera's bonus, the pickup pay and the
  // driver total (driverEarnings with the bonus in it + pickupPay).
  final cases = <({String currency, int bonus, int pickup, int total})>[
    (currency: 'SEK', bonus: 4000, pickup: 1395, total: 26395),
    (currency: 'TND', bonus: 2000, pickup: 1250, total: 16250),
  ];

  setUp(installLive);
  tearDown(uninstallLive);

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    test('${c.currency} accept: the bonus line is the server bonus', () {
      final quote = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
        serverTotal: m(c.total),
      );
      final terms = quote.termsOf(
        fare: m(c.total - c.pickup).formatted,
        driverBonus: m(c.bonus),
      );
      expect(terms.fare, m(c.total).formatted);
      expect(terms.driverBonus, m(c.bonus));
    });

    test('${c.currency} accept with no server bonus: no bonus line', () {
      final terms = PickupPayQuote(
        pay: m(c.pickup),
        leg: leg,
        serverTotal: m(c.total),
      ).termsOf(fare: m(c.total - c.pickup).formatted);
      expect(terms.driverBonus, isNull);
    });

    test('${c.currency} Leave now: the bonus line is the server bonus', () {
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: m(c.total - c.pickup).formatted,
        leg: leg,
        serverTotal: m(c.total),
        acceptedPickupPay: m(c.pickup),
        driverBonus: m(c.bonus),
      );
      expect(terms.fare, m(c.total).formatted);
      expect(terms.driverBonus, m(c.bonus));
      // No server total: "—", and still the server's bonus as it is.
      final none = PickupPayQuote.leaveNowTermsOf(
        fare: m(c.total - c.pickup).formatted,
        leg: leg,
        acceptedPickupPay: m(c.pickup),
        driverBonus: m(c.bonus),
      );
      expect(none.fare, '—');
      expect(none.driverBonus, m(c.bonus));
    });
  }
}
