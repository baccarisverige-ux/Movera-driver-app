import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';

import 'live_fake.dart';

/// BQ-F1d (owner R2; owner s06:1164: the waybill shows all the details):
/// the "next trip secured" waybill of a restored queued trip (Home,
/// home.dart `_waybillFromQueued`) shows the server's saved driverTotal and
/// its bonus and pickup pay lines; "—" on live when an older save has a
/// pickup pay but no server total, never a sum worked out on the phone.
void main() {
  final cases = <({String currency, int earnings, int bonus, int pickup})>[
    (currency: 'SEK', earnings: 22400, bonus: 4000, pickup: 1395),
    (currency: 'TND', earnings: 15000, bonus: 2000, pickup: 1250),
  ];

  setUp(installLive);
  tearDown(uninstallLive);

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    PersistedQueuedTrip queued({Money? total, Money? bonus, Money? pickup}) =>
        PersistedQueuedTrip(
          tripId: 'next-${c.currency}',
          riderName: 'Sara',
          fare: m(c.earnings).formatted,
          category: 'Comfort',
          pickup: 'Odengatan',
          dropoff: 'Kista',
          pickupLat: 59.34,
          pickupLng: 18.05,
          dropoffLat: 59.40,
          dropoffLng: 17.94,
          pickupPay: pickup,
          driverTotal: total,
          driverBonus: bonus,
        );

    test('${c.currency} secured waybill: server total, bonus, pickup pay', () {
      final total = m(c.earnings + c.pickup);
      final waybill = queued(
        total: total,
        bonus: m(c.bonus),
        pickup: m(c.pickup),
      ).securedWaybill();
      expect(waybill.statusLabel, WaybillRecord.nextTripSecured);
      expect(waybill.tripId, 'next-${c.currency}');
      expect(waybill.fare, total.formatted);
      expect(waybill.driverBonus, WaybillRecord.bonusLabel(m(c.bonus)));
      expect(waybill.pickupPay, WaybillRecord.bonusLabel(m(c.pickup)));
      expect(waybill.riderName, 'Sara');
      expect(waybill.service, 'Comfort');
    });

    test('${c.currency} secured waybill of an older save: "—"', () {
      final waybill = queued(pickup: m(c.pickup)).securedWaybill();
      expect(waybill.fare, '—');
      expect(waybill.fare, isNot(m(c.earnings + c.pickup).formatted));
      expect(waybill.driverBonus, isNull);
      expect(waybill.pickupPay, WaybillRecord.bonusLabel(m(c.pickup)));
    });

    test('${c.currency} secured waybill without pickup pay: the saved pay', () {
      final waybill = queued().securedWaybill();
      expect(waybill.fare, m(c.earnings).formatted);
      expect(waybill.driverBonus, isNull);
      expect(waybill.pickupPay, isNull);
    });
  }
}
