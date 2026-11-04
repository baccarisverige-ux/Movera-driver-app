import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/core/zones/zone_clock.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';

Map<String, dynamic> _offer() => {
  'offerId': 'o1',
  'tripId': 'trp_1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'fare': {'amountMinor': 8810, 'currency': 'EUR'},
  'source': 'system',
  'pickup': {'address': 'Rue de Rivoli', 'lat': 48.8606, 'lng': 2.3376},
  'dropoff': {'address': 'Gare de Lyon', 'lat': 48.8443, 'lng': 2.3744},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
  'reservation': true,
  'scheduledAt': '2026-11-05T09:00:00Z',
};

/// Job 3 (L13, L18): booked times on the zone's clock; the "Booked ride"
/// badge kept across a restore.
void main() {
  // The phone's time zone is not the zone's (a phone left on UTC).
  setUp(() => debugZoneTimeZone = 'Europe/Paris');
  tearDown(() => debugZoneTimeZone = null);

  test('L18: a Paris booked ride shows Paris time, not the phone time', () {
    // 09:00 UTC in November is 10:00 in Paris.
    expect(ServerReservation.clockOf(DateTime.utc(2026, 11, 5, 9)), '10:00');
    expect(OfferWire.parse(_offer()).bookedTime, '10:00');
    // Summer time: 09:00 UTC in July is 11:00 in Paris.
    expect(ServerReservation.clockOf(DateTime.utc(2026, 7, 5, 9)), '11:00');
  });

  test('L18: Tunis keeps UTC+1 all year', () {
    debugZoneTimeZone = 'Africa/Tunis';
    expect(ServerReservation.clockOf(DateTime.utc(2026, 7, 5, 9)), '10:00');
  });

  test('L13: the badge time is saved with the trip and comes back', () {
    const saved = PersistedActiveRide(
      tripId: 'trp_1',
      stage: ActiveRideStage.headingToPickup,
      bookedTime: '10:00',
      pickupLat: 48.8606,
      pickupLng: 2.3376,
      dropoffLat: 48.8443,
      dropoffLng: 2.3744,
    );
    final back = PersistedActiveRide.fromJson(saved.stamped().toJson())!;
    expect(back.bookedTime, '10:00');
    expect(AcceptRide.fromPersisted(back).restoredSnapshot?.badgeTime, '10:00');
  });

  test('L13: an older save with only the pickup instant still gets the '
      'badge, on the zone clock', () {
    final saved = PersistedActiveRide(
      tripId: 'trp_1',
      stage: ActiveRideStage.headingToPickup,
      scheduledPickupAt: DateTime.utc(2026, 11, 5, 9),
      pickupLat: 48.8606,
      pickupLng: 2.3376,
      dropoffLat: 48.8443,
      dropoffLng: 2.3744,
    );
    expect(
      AcceptRide.fromPersisted(saved).restoredSnapshot?.badgeTime,
      '10:00',
    );
  });
}
