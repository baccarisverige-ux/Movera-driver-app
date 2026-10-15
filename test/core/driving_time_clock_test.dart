import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/session/driving_time_clock.dart';

void main() {
  test('counts only while online, against the 12 h work rule', () {
    var now = DateTime(2026, 10, 14, 8);
    final clock = DrivingTimeClock(now: () => now);
    expect(clock.worked, Duration.zero);

    clock.sync(online: true);
    now = now.add(const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(clock.worked, const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(DrivingTimeClock.hoursMinutes(clock.left), '7 h 47 min');
    expect(DrivingTimeClock.clock(clock.worked), '4:12:36');

    clock.sync(online: false);
    now = now.add(const Duration(hours: 2));
    expect(clock.worked, const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(clock.running, isFalse);
    expect(clock.restUntil, isNull);
  });

  test('at the limit the driver rests 6 h, then starts from zero', () {
    var now = DateTime(2026, 10, 14, 10, 30);
    final clock = DrivingTimeClock(now: () => now)..start();
    now = now.add(const Duration(hours: 12));
    expect(clock.left, Duration.zero);
    expect(clock.usedFraction, 1);

    clock.stop();
    expect(clock.restUntil, DateTime(2026, 10, 15, 4, 30));
    now = now.add(const Duration(hours: 5, minutes: 59));
    expect(clock.restUntil, isNotNull);
    now = now.add(const Duration(minutes: 1));
    expect(clock.restUntil, isNull);
    expect(clock.worked, Duration.zero);
  });

  test('online past the limit, the rest starts when the driver stops', () {
    var now = DateTime(2026, 10, 14, 6);
    final clock = DrivingTimeClock(now: () => now)
      ..load(worked: const Duration(hours: 11, minutes: 50))
      ..start();
    now = now.add(const Duration(minutes: 25));
    expect(clock.restUntil, DateTime(2026, 10, 14, 12, 25));
    clock.stop();
    now = now.add(const Duration(minutes: 10));
    expect(clock.restUntil, DateTime(2026, 10, 14, 12, 25));
  });

  test('a short break keeps the count; the rule can be off', () {
    var now = DateTime(2026, 10, 14, 6);
    final clock = DrivingTimeClock(now: () => now)..start();
    now = now.add(const Duration(hours: 3));
    clock.stop();
    now = now.add(const Duration(hours: 2));
    clock.start();
    now = now.add(const Duration(hours: 1));
    expect(clock.worked, const Duration(hours: 4));

    final free = DrivingTimeClock(
      now: () => now,
      rule: const DrivingRestRule(on: false),
    )..load(worked: const Duration(hours: 13));
    expect(free.restUntil, isNull);
  });
}
