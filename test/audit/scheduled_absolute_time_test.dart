import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

// Wave 3 (D3.2, part b): scheduled rides across midnight.
// - driver-u141: a reservation booked as "Tomorrow 01:00" before midnight
//   is still 01:00 that night after midnight, not a day later.
// - driver-u142: an accepted "Tomorrow 08:15" ride seen after midnight is
//   that morning: planned, late-cancel and listed as "Today, 08:15".

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
    ScheduledRideStore.reset();
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

  group('driver-u142: an accepted ride after midnight', () {
    test('"Tomorrow 08:15" accepted at 23:00 is this morning at 07:30', () {
      clockAt(23);
      DemoReservations.reset();
      ScheduledRideStore.reset();
      final ride = ScheduledRideStore.upcoming.single;
      expect(ride.pickupTime, '08:15');
      final booked = ride.pickupAt(ScheduledClock.instance.now())!;
      expect(
        booked.difference(ScheduledClock.instance.now()),
        const Duration(hours: 9, minutes: 15),
      );
      pass(const Duration(hours: 8, minutes: 30));
      final now = ScheduledClock.instance.now();
      expect(
        ScheduledRideStore.upcoming.single.pickupAt(now),
        booked,
        reason: 'the same morning, not +24 h',
      );
      // 45 min before pickup: a cancel now is late (the admin's 1 h).
      expect(ScheduledRideStore.isLateCancel(ride), isTrue);
    });

    testWidgets('Scheduled rides lists it as "Today, 08:15"', (tester) async {
      clockAt(23);
      DemoReservations.reset();
      ScheduledRideStore.reset();
      pass(const Duration(hours: 8, minutes: 30));
      await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Accepted').first);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Tomorrow, 08:15'), findsNothing);
      expect(find.text('Today, 08:15'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
