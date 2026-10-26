import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/reservation_when.dart';

void main() {
  // Sunday 18 October 2026, 11:00.
  final now = DateTime(2026, 10, 18, 11);
  String when(DateTime at) => ReservationWhen.of(at, now).label;

  test('under 3 hours: "In 2 h", under 1 h: "In 45 min"', () {
    expect(when(DateTime(2026, 10, 18, 13)), 'In 2 h');
    expect(when(DateTime(2026, 10, 18, 13, 20)), 'In 2 h');
    expect(when(DateTime(2026, 10, 18, 11, 45)), 'In 45 min');
    expect(when(DateTime(2026, 10, 18, 13, 59)), 'In 3 h');
    // The island adds the time.
    expect(
      ReservationWhen.of(DateTime(2026, 10, 18, 13, 5), now).island,
      'In 2 h · 13:05',
    );
  });

  test('later today, tomorrow, this week, further', () {
    expect(when(DateTime(2026, 10, 18, 14)), 'Today 14:00');
    expect(when(DateTime(2026, 10, 18, 23, 5)), 'Today 23:05');
    expect(when(DateTime(2026, 10, 19, 11, 55)), 'Tomorrow 11:55');
    expect(when(DateTime(2026, 10, 24, 14, 33)), 'Saturday 14:33');
    expect(when(DateTime(2026, 10, 20, 8)), 'Tuesday 08:00');
    expect(when(DateTime(2026, 10, 25, 11, 44)), '25-10 11:44');
    expect(when(DateTime(2026, 11, 3, 9, 5)), '03-11 09:05');
    // Not soon: the island says the same.
    expect(
      ReservationWhen.of(DateTime(2026, 10, 19, 6), now).island,
      'Tomorrow 06:00',
    );
  });

  test('reads the request\'s day', () {
    ReservationRequestPreview on(String day, String time) =>
        ReservationRequestPreview(
          category: 'Comfort',
          fare: '1 kr',
          pickupLabel: '',
          pickupAddress: '',
          dropoffAddress: '',
          pickupTime: time,
          pickupDay: day,
          tripMinutes: 42,
          tripKm: 38,
          pickup: const GeoPoint(0, 0),
          dropoff: const GeoPoint(0, 0),
        );
    String label(String day, String time) =>
        ReservationWhen.ofRequest(on(day, time), now).label;
    expect(label('Today', '13:00'), 'In 2 h');
    expect(label('Today', '18:30'), 'Today 18:30');
    expect(label('Tomorrow', '06:35'), 'Tomorrow 06:35');
    expect(label('Sat 24 Oct', '14:33'), 'Saturday 14:33');
    expect(label('19 Nov', '11:44'), '19-11 11:44');
    expect(label('2026-10-21', '07:00'), 'Wednesday 07:00');
    // Unreadable: its own words.
    expect(label('Someday', '06:35'), 'Someday 06:35');
  });
}
