import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// F2 (M23 supervisor follow-up): an accepted booked ride from the server
/// carries `fare = earnings.formatted` (server_reservations.dart toPreview).
/// "Leave now" opens it with `RideOffer.reservation`, which read the label
/// as SEK only and threw on "12.350 DT" / "12,50 €": a TN or FR driver's
/// booked ride could not open. It must open with the server's amount, in
/// the ride's own currency (TND with 3 decimals).
ServerReservation _accepted(Money earnings) => ServerReservation(
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
);

ReservationRequestPreview _preview(Money earnings) => _accepted(
  earnings,
).toPreview(dayWord: (_) => 'Today', pickupLabel: (t) => 'Pickup $t');

void _expectMoney(Money? actual, int minor, String currency) {
  expect(actual, isNotNull);
  expect(actual!.minorUnits, minor);
  expect(actual.currency, currency);
}

void main() {
  tearDown(Money.forgetZone);

  test('TND booked ride opens at Leave now with 12.350 DT (3 decimals)', () {
    Money.zoneCurrency = 'TND';
    final preview = _preview(const Money(minorUnits: 12350, currency: 'TND'));
    expect(preview.fare, '12.350 DT');
    final offer = RideOffer.reservation(preview);
    _expectMoney(offer.fare, 12350, 'TND');
    _expectMoney(offer.driverEarnings, 12350, 'TND');
    expect(offer.fare.formatted, '12.350 DT');
  });

  test('TND booked ride with thousands opens (1 250.000 DT)', () {
    Money.zoneCurrency = 'TND';
    final offer = RideOffer.reservation(
      _preview(const Money(minorUnits: 1250000, currency: 'TND')),
    );
    _expectMoney(offer.fare, 1250000, 'TND');
  });

  test('EUR booked ride opens at Leave now with 12,50 €', () {
    Money.zoneCurrency = 'EUR';
    final preview = _preview(const Money(minorUnits: 1250, currency: 'EUR'));
    expect(preview.fare, '12,50 €');
    final offer = RideOffer.reservation(preview);
    _expectMoney(offer.fare, 1250, 'EUR');
    _expectMoney(offer.driverEarnings, 1250, 'EUR');
  });

  test('SEK booked ride still opens with 224,50 kr', () {
    final offer = RideOffer.reservation(
      _preview(const Money(minorUnits: 22450, currency: 'SEK')),
    );
    _expectMoney(offer.fare, 22450, 'SEK');
    _expectMoney(offer.driverEarnings, 22450, 'SEK');
  });

  test('EUR cash booked ride keeps its boost and cash to collect in €', () {
    Money.zoneCurrency = 'EUR';
    const preview = ReservationRequestPreview(
      category: 'Movera',
      fare: '30,00 €',
      earnings: '24,00 €',
      pickupLabel: 'Pickup 08:30',
      pickupAddress: 'A',
      dropoffAddress: 'B',
      pickupTime: '08:30',
      pickupDay: 'Today',
      tripMinutes: 16,
      tripKm: 8.2,
      pickup: GeoPoint(48.85, 2.35),
      dropoff: GeoPoint(48.86, 2.36),
      paidByCash: true,
      cashToCollect: '32,50 €',
      fareBoost: '+4,00 €',
    );
    final offer = RideOffer.reservation(preview);
    _expectMoney(offer.fare, 3000, 'EUR');
    _expectMoney(offer.fareBoost, 400, 'EUR');
    _expectMoney(offer.cashToCollect, 3250, 'EUR');
  });

  test('a label that is not an amount still fails loudly', () {
    const preview = ReservationRequestPreview(
      category: 'Movera',
      fare: 'abc',
      pickupLabel: 'Pickup 08:30',
      pickupAddress: 'A',
      dropoffAddress: 'B',
      pickupTime: '08:30',
      pickupDay: 'Today',
      tripMinutes: 16,
      tripKm: 8.2,
      pickup: GeoPoint(59.3, 18.0),
      dropoff: GeoPoint(59.31, 18.01),
    );
    expect(() => RideOffer.reservation(preview), throwsArgumentError);
  });
}
