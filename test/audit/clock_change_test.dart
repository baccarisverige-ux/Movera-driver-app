import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// Times across a clock change (Europe: 29 Mar 2026 02:00 → 03:00, 25 Oct
/// 2026 03:00 → 02:00). Run with TZ=Europe/Stockholm to see the change;
/// elsewhere the expectations hold too.
void main() {
  const ride = ReservationRequestPreview(
    category: 'Comfort',
    fare: '126,75 kr',
    pickupLabel: 'Pickup today 01:50',
    pickupAddress: 'Gamla vägen',
    dropoffAddress: 'Solna centrum',
    pickupTime: '01:50',
    pickupDay: 'Today',
    tripMinutes: 20,
    tripKm: 9,
    pickup: GeoPoint(59.33, 18.06),
    dropoff: GeoPoint(59.36, 18.0),
  );

  test('a reservation arrives trip minutes after its pickup instant '
      '(driver-r4-13)', () {
    final pickup = DateTime(2026, 3, 29, 1, 50);
    expect(
      ride.scheduledFor(pickup).arrivalTime,
      clockLabel(pickup.add(const Duration(minutes: 20))),
    );
    // "Today 07:40" on the spring-forward day is 07:40, not 08:40.
    const morning = ReservationRequestPreview(
      category: 'Comfort',
      fare: '126,75 kr',
      pickupLabel: 'Pickup today 07:40',
      pickupAddress: 'Gamla vägen',
      dropoffAddress: 'Solna centrum',
      pickupTime: '07:40',
      pickupDay: 'Today',
      tripMinutes: 19,
      tripKm: 9,
      pickup: GeoPoint(59.33, 18.06),
      dropoff: GeoPoint(59.36, 18.0),
    );
    final at = morning.pickupAt(DateTime(2026, 3, 29, 0, 30))!;
    expect([at.day, at.hour, at.minute], [29, 7, 40]);
  });
}
