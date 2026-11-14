import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/home/components/driving_time_row.dart';

/// BQ-V21 (SAFETY; decisions/driving-time-limits.md:2-4, owner "It's 12 hours
/// driving … not online time !! And yes e force" + "6 hours offline so reset
/// all time"): the driving-time row shows the SERVER's numbers
/// (`Driver.drivingTime { drivenMinutes, maxMinutes, reached,
/// resetAfterOfflineHours, canDriveAt? }`), not the phone's own 12 h / 6 h.
void main() {
  test('the profile carries the admin offline reset', () {
    final time = DriverDrivingTime.fromJson(<String, dynamic>{
      'drivenMinutes': 65,
      'maxMinutes': 60,
      'reached': true,
      'resetAfterOfflineHours': 2,
      'canDriveAt': '2026-11-14T12:30:00Z',
    });
    expect(time.resetAfterOfflineHours, 2);
    expect(time.reached, isTrue);
    expect(time.canDriveAt, DateTime.utc(2026, 11, 14, 12, 30));
    final old = DriverDrivingTime.fromJson(<String, dynamic>{
      'drivenMinutes': 0,
      'maxMinutes': 720,
    });
    expect(old.resetAfterOfflineHours, isNull, reason: 'older server');
  });

  test('offline at the limit: "Rest until" is the server canDriveAt', () {
    var now = DateTime.utc(2026, 11, 14, 11);
    final clock = DrivingTimeClock(now: () => now)
      ..loadServer(
        drivenMinutes: 65,
        maxMinutes: 60,
        reached: true,
        resetAfterOfflineHours: 2,
        canDriveAt: DateTime.utc(2026, 11, 14, 12, 30),
      );
    expect(clock.restLength, const Duration(hours: 2));
    // The server sends UTC; the row shows it in the phone's time zone.
    expect(clock.restUntil?.isUtc, isFalse);
    expect(clock.restUntil?.toUtc(), DateTime.utc(2026, 11, 14, 12, 30));
    now = now.add(const Duration(minutes: 89));
    expect(clock.restUntil?.toUtc(), DateTime.utc(2026, 11, 14, 12, 30));
    now = now.add(const Duration(minutes: 1));
    expect(clock.restUntil, isNull);
  });

  test('the server rested count wins: not reached = no rest line', () {
    final now = DateTime.utc(2026, 11, 14, 13);
    final clock = DrivingTimeClock(now: () => now)
      ..loadServer(
        drivenMinutes: 0,
        maxMinutes: 60,
        reached: false,
        resetAfterOfflineHours: 2,
      );
    expect(clock.restUntil, isNull);
    expect(clock.left, const Duration(hours: 1));
  });

  testWidgets('the row shows the server time to drive again', (tester) async {
    final now = DateTime(2026, 11, 14, 11);
    final clock = DrivingTimeClock(now: () => now)
      ..loadServer(
        drivenMinutes: 65,
        maxMinutes: 60,
        reached: true,
        resetAfterOfflineHours: 2,
        canDriveAt: DateTime(2026, 11, 14, 12, 30),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrivingTimeRow(clock: clock, running: false, onTap: () {}),
        ),
      ),
    );
    expect(find.textContaining('12:30'), findsOneWidget);
  });
}
