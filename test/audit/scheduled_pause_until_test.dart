import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

// driver-u163: the late-cancel pause ends at the date the driver was told
// (the cancel that reached the limit + pauseDays), not as soon as the first
// counted cancel leaves the lateCancelPeriodDays window.

void main() {
  setUp(ScheduledRideStore.reset);
  tearDown(ScheduledRideStore.reset);

  test('the pause holds until the announced date', () {
    final rules = ScheduledRideRules.current;
    expect(rules.lateCancelLimit, 2);
    expect(rules.lateCancelPeriodDays, 7);
    expect(rules.pauseDays, 7);
    final first = DateTime(2026, 10, 20, 9);
    final second = DateTime(2026, 10, 27, 8);
    ScheduledRideStore.addLateCancel(first);
    ScheduledRideStore.addLateCancel(second);
    final announced = DateTime(2026, 11, 3, 8);
    expect(ScheduledRideStore.pausedUntil(second), announced);

    // 61 minutes later the first cancel has left the 7-day period.
    final later = second.add(const Duration(minutes: 61));
    expect(ScheduledRideStore.pausedUntil(later), announced);
    expect(
      ScheduledRideStore.pausedUntil(
        announced.subtract(const Duration(minutes: 1)),
      ),
      announced,
    );
    expect(ScheduledRideStore.pausedUntil(announced), isNull);
  });

  test('one late cancel alone never pauses', () {
    ScheduledRideStore.addLateCancel(DateTime(2026, 10, 20, 9));
    ScheduledRideStore.addLateCancel(DateTime(2026, 10, 28, 9));
    expect(ScheduledRideStore.pausedUntil(DateTime(2026, 10, 28, 10)), isNull);
  });
}
