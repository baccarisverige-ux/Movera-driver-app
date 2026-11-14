import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/money/money.dart';

/// Price audit 2026-11-14 gap 1 (Rules
/// audits/price-display-2026-11-14/REPORT.md): the offer must show exactly
/// what the finished screen shows, in every currency.
void main() {
  const leg = PickupLeg(km: 6.4, minutes: 12);

  Map<String, Object?> m(int minor, String currency) => {
    'amountMinor': minor,
    'currency': currency,
  };

  // The driver's earnings, the server's pickup pay, and the finished
  // trip's one number from the server (earnings + pickup pay).
  final cases = <({String currency, int earnings, int pickup, String shown})>[
    (currency: 'SEK', earnings: 14230, pickup: 1250, shown: '154,80 kr'),
    (currency: 'EUR', earnings: 1000, pickup: 1250, shown: '22,50 €'),
    (currency: 'TND', earnings: 12500, pickup: 1250, shown: '13.750 DT'),
  ];

  for (final c in cases) {
    test('gap 1 ${c.currency}: offer = earnings + server pickup pay = '
        'finished screen', () {
      final earnings = Money(minorUnits: c.earnings, currency: c.currency);
      final pickup = Money(minorUnits: c.pickup, currency: c.currency);
      final quote = PickupPayQuote(pay: pickup, leg: leg);
      final offer = quote.totalOf(earnings.formatted);
      expect(offer, c.shown);
      // Accepted terms keep the same number (driver-12).
      expect(quote.termsOf(fare: earnings.formatted).fare, c.shown);
      expect(quote.termsOf(fare: earnings.formatted).driverBonus, pickup);
      // The finished screen reads the server's driverTotal.
      final finished = LiveTripMoney.tryParse({
        'fare': m(c.earnings * 2, c.currency),
        'driverEarnings': m(c.earnings, c.currency),
        'pickupPay': m(c.pickup, c.currency),
        'driverTotal': m(c.earnings + c.pickup, c.currency),
      })!;
      expect(finished.driverTotal!.formatted, offer);
    });
  }
}
