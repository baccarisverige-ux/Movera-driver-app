import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

import 'live_fake.dart';

/// BQ-F1c (owner R2; Rules audits/impact/f1b-waybill-bonus-supervisor.md
/// follow-up 2): a secured next trip keeps the server's `Offer.driverTotal`
/// and `Offer.driverBonus` when saved, and a restored one (closing a stale
/// saved trip, home_recovery) becomes the trip with those server numbers:
/// never its pay plus the pickup pay added up on the phone; "—" on live
/// when no server total was saved.
void main() {
  final cases = <({String currency, int earnings, int bonus, int pickup})>[
    (currency: 'SEK', earnings: 22400, bonus: 4000, pickup: 1395),
    (currency: 'TND', earnings: 15000, bonus: 2000, pickup: 1250),
  ];

  tearDown(uninstallLive);

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    PersistedQueuedTrip queued({Money? total, Money? bonus, Money? pickup}) =>
        PersistedQueuedTrip(
          tripId: 'next-${c.currency}',
          riderName: 'Sara',
          fare: m(c.earnings).formatted,
          category: 'Movera',
          pickup: 'A',
          dropoff: 'B',
          pickupLat: 59.33,
          pickupLng: 18.06,
          dropoffLat: 59.34,
          dropoffLng: 18.07,
          pickupPay: pickup,
          driverTotal: total,
          driverBonus: bonus,
        );

    test('${c.currency} saved and read back with its server numbers', () {
      final total = m(c.earnings + c.pickup);
      final back = PersistedQueuedTrip.fromJson(
        queued(total: total, bonus: m(c.bonus), pickup: m(c.pickup)).toJson(),
      )!;
      expect(back.driverTotal, total);
      expect(back.driverBonus, m(c.bonus));
      expect(back.pickupPay, m(c.pickup));
      // An older save has neither.
      final old = PersistedQueuedTrip.fromJson(queued().toJson())!;
      expect(old.driverTotal, isNull);
      expect(old.driverBonus, isNull);
    });

    test('${c.currency} live restore: the server total and bonus', () {
      installLive();
      final total = m(c.earnings + c.pickup);
      final active = queued(
        total: total,
        bonus: m(c.bonus),
        pickup: m(c.pickup),
      ).asHeadingToPickup(matchedVia: 'Exclusive');
      expect(active.stage, ActiveRideStage.headingToPickup);
      expect(active.fare, total.formatted);
      expect(active.driverBonus, m(c.bonus));
      expect(active.pickupPay, m(c.pickup));
      expect(active.matchedVia, 'Exclusive');
    });

    test('${c.currency} live restore of an older save: "—", no phone sum', () {
      installLive();
      final active = queued(
        pickup: m(c.pickup),
      ).asHeadingToPickup(matchedVia: 'Exclusive');
      expect(active.fare, '—');
      expect(active.fare, isNot(m(c.earnings + c.pickup).formatted));
      expect(active.pickupPay, m(c.pickup));
      expect(active.driverBonus, isNull);
    });

    test('${c.currency} live restore with no pickup pay: the saved pay', () {
      installLive();
      final active = queued(
        bonus: m(c.bonus),
      ).asHeadingToPickup(matchedVia: 'Exclusive');
      expect(active.fare, m(c.earnings).formatted);
      expect(active.driverBonus, m(c.bonus));
      expect(active.pickupPay, isNull);
    });

    test('${c.currency} demo restore keeps its sample sum', () {
      final active = queued(
        pickup: m(c.pickup),
      ).asHeadingToPickup(matchedVia: 'Exclusive');
      expect(active.fare, m(c.earnings + c.pickup).formatted);
      expect(active.driverBonus, m(c.pickup));
    });
  }
}
