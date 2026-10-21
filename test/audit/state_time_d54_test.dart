import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

// Wave 5 D5.4 (parts a + b): state and time. Time cases also run under
// TZ=Europe/Stockholm and TZ=America/New_York.

void main() {
  group('driver-8: a demo reservation after midnight on a clock-change day', () {
    final previousNow = ScheduledClock.realNow;
    final previousPlan = DemoReservations.plan;
    tearDown(() {
      ScheduledClock.realNow = previousNow;
      ScheduledClock.instance = ScheduledClock.fastDay();
      DemoReservations.plan = previousPlan;
      DemoReservations.reset();
    });

    // Spring forward: 29 Mar 2026 in Europe, 8 Mar 2026 in the US. Booked
    // at 22:30 on that day, a ride 2 h later is the next day.
    for (final day in [DateTime(2026, 3, 29, 22, 30), DateTime(2026, 3, 8, 22, 30)]) {
      test('booked ${day.month}/${day.day} 22:30, +2 h is "Tomorrow"', () {
        ScheduledClock.realNow = () => day;
        ScheduledClock.instance = ScheduledClock();
        DemoReservations.plan = const DemoReservationPlan(
          main: Duration(hours: 2),
          clashing: Duration(hours: 2, minutes: 25),
          assigned: Duration(hours: 8),
        );
        DemoReservations.reset();
        final main = DemoReservations.main;
        final at = day.add(const Duration(hours: 2));
        expect(main.pickupTime, '${at.hour.toString().padLeft(2, '0')}:30');
        expect(main.pickupDay, 'Tomorrow');
        expect(main.pickupDayAt(day), 'Tomorrow');
      });
    }
  });

  test('driver-u9: every text admin can change is shown by a screen', () {
    const source = 'lib/core/content/driver_app_texts.dart';
    final names = {
      for (final m in RegExp(r"static const (\w+) =\s*DriverTextKey\(\s*'([^']+)'")
          .allMatches(File(source).readAsStringSync()))
        m.group(2)!: m.group(1)!,
    };
    final used = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith(source))
        .map((f) => f.readAsStringSync())
        .join('\n');
    final dead = [
      for (final key in DriverTexts.all)
        if (!RegExp('DriverTexts\\.${names[key.id]}\\b').hasMatch(used)) key.id,
    ];
    expect(dead, isEmpty);
  });
}
