import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

// Wave 3 (D3.2, part b): scheduled rides across midnight.
// - driver-u141: a reservation booked as "Tomorrow 01:00" before midnight
//   is still 01:00 that night after midnight, not a day later.

void main() {
  final previousNow = ScheduledClock.realNow;
  late DateTime real;

  /// The real clock at [hour] (the app's clock, speed 1).
  void clockAt(int hour, [int minute = 0]) {
    real = DateTime(2026, 10, 21, 12);
    ScheduledClock.realNow = () => real;
    ScheduledClock.instance = ScheduledClock(
      startTime: Duration(hours: hour, minutes: minute),
    );
  }

  void pass(Duration time) => real = real.add(time);

  tearDown(() {
    ScheduledClock.realNow = previousNow;
    ScheduledClock.instance = ScheduledClock.fastDay();
    DemoReservations.plan = DemoReservationPlan.testDay;
    DemoReservations.reset();
  });

  group('driver-u141: the demo reservations after midnight', () {
    test('"Tomorrow 01:00" booked at 23:00 is 20 min away at 00:40', () {
      clockAt(23);
      DemoReservations.plan = const DemoReservationPlan(
        main: Duration(hours: 2),
        clashing: Duration(hours: 2, minutes: 25),
        assigned: Duration(hours: 8),
      );
      DemoReservations.reset();
      final main = DemoReservations.main;
      expect(main.pickupDay, 'Tomorrow');
      expect(main.pickupTime, '01:00');
      final booked = main.pickupAt(ScheduledClock.instance.now());
      pass(const Duration(hours: 1, minutes: 40));
      final now = ScheduledClock.instance.now();
      expect(now.hour, 0);
      expect(main.pickupAt(now), booked, reason: 'the same night, not +24 h');
      expect(main.untilPickup(now), const Duration(minutes: 20));
      // Its Exclusive step (20 min before) is reached; the island says it.
      expect(ReservationWhen.ofRequest(main, now).label, 'In 20 min');
    });
  });
}
