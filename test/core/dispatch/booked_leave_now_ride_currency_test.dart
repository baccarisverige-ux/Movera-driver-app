import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// BQ-F2b (Rules audits/impact/f2-driver-leave-now-supervisor.md follow-up
/// 1): `RideOffer._amount` reads a booked ride's labels in the ride's own
/// currency, never the zone's. A label with no symbol ("12.350") fell back
/// to the zone currency, SEK until a zone config arrives: 1 235 000 öre.
ReservationRequestPreview _bare({
  required String fare,
  required String currency,
  String? fareBoost,
  String? cashToCollect,
}) => ReservationRequestPreview(
  category: 'Movera',
  fare: fare,
  earnings: fare,
  currency: currency,
  pickupLabel: 'Pickup 08:30',
  pickupAddress: 'A',
  dropoffAddress: 'B',
  pickupTime: '08:30',
  pickupDay: 'Today',
  tripMinutes: 16,
  tripKm: 8.2,
  pickup: const GeoPoint(36.8, 10.18),
  dropoff: const GeoPoint(36.85, 10.2),
  paidByCash: cashToCollect != null,
  cashToCollect: cashToCollect,
  fareBoost: fareBoost,
);

void main() {
  tearDown(Money.forgetZone);

  test('TND: "12.350" with no zone yet is 12.350 DT, not 12 350,00 kr', () {
    final offer = RideOffer.reservation(
      _bare(
        fare: '12.350',
        currency: 'TND',
        fareBoost: '+1.500',
        cashToCollect: '13.000',
      ),
    );
    expect(offer.fare, const Money(minorUnits: 12350, currency: 'TND'));
    expect(
      offer.driverEarnings,
      const Money(minorUnits: 12350, currency: 'TND'),
    );
    expect(offer.fareBoost, const Money(minorUnits: 1500, currency: 'TND'));
    expect(
      offer.cashToCollect,
      const Money(minorUnits: 13000, currency: 'TND'),
    );
  });

  test('SEK: "224,50" in a TND zone is 224,50 kr, not 224.500 DT', () {
    Money.zoneCurrency = 'TND';
    final offer = RideOffer.reservation(
      _bare(fare: '224,50', currency: 'SEK', fareBoost: '+40'),
    );
    expect(offer.fare, const Money(minorUnits: 22450, currency: 'SEK'));
    expect(offer.fareBoost, const Money(minorUnits: 4000, currency: 'SEK'));
  });

  test('a server row carries its currency into the preview', () {
    ReservationRequestPreview preview(Money earnings) => ServerReservation(
      tripId: 'trip-${earnings.currency}',
      version: 3,
      scheduledAt: DateTime.utc(2026, 11, 20, 8, 30),
      categoryId: 'economy',
      rideType: 'normal',
      pickupAddress: 'A',
      dropoffAddress: 'B',
      pickup: const GeoPoint(36.8, 10.18),
      dropoff: const GeoPoint(36.85, 10.2),
      distanceMeters: 8200,
      durationSeconds: 960,
      earnings: earnings,
      status: 'accepted',
      mustBeOnlineAt: DateTime.utc(2026, 11, 20, 8, 0),
    ).toPreview(dayWord: (_) => 'Today', pickupLabel: (t) => 'Pickup $t');
    expect(
      preview(const Money(minorUnits: 12350, currency: 'TND')).currency,
      'TND',
    );
    expect(
      preview(const Money(minorUnits: 22450, currency: 'SEK')).currency,
      'SEK',
    );
  });

  test('scheduledFor keeps the ride currency (TND and SEK)', () {
    final at = DateTime.utc(2026, 11, 21, 9);
    for (final code in ['TND', 'SEK']) {
      final moved = _bare(fare: '12.350', currency: code).scheduledFor(at);
      expect(moved.currency, code);
      expect(moved.scheduledAt, at);
    }
    expect(
      RideOffer.reservation(
        _bare(fare: '12.350', currency: 'TND').scheduledFor(at),
      ).fare,
      const Money(minorUnits: 12350, currency: 'TND'),
    );
  });
}
