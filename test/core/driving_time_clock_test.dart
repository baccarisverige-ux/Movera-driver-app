import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driving_time_clock.dart';

void main() {
  test('counts only while online, against a 10 h day', () {
    var now = DateTime(2026, 10, 14, 8);
    final clock = DrivingTimeClock(now: () => now);
    expect(clock.drivenToday, Duration.zero);

    clock.sync(online: true);
    now = now.add(const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(clock.drivenToday, const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(DrivingTimeClock.hoursMinutes(clock.leftToday), '5 h 47 min');
    expect(DrivingTimeClock.clock(clock.drivenToday), '4:12:36');

    clock.sync(online: false);
    now = now.add(const Duration(hours: 2));
    expect(clock.drivenToday, const Duration(hours: 4, minutes: 12, seconds: 36));
    expect(clock.running, isFalse);
  });

  test('a new day starts from zero and the limit never goes negative', () {
    var now = DateTime(2026, 10, 14, 6);
    final clock = DrivingTimeClock(now: () => now)..start();
    now = now.add(const Duration(hours: 11));
    expect(clock.leftToday, Duration.zero);
    expect(clock.usedFraction, 1);

    clock.stop();
    now = DateTime(2026, 10, 15, 7);
    expect(clock.drivenToday, Duration.zero);
  });
}
