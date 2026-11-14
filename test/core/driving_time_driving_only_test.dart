import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';

/// SV follow-up (coordinator ruling 2026-11-14, open point 2; owner
/// decisions/driving-time-limits.md:2 "It's 12 hours driving (mean driving
/// to pickup or on trip) not online time !!"): the phone counts only while
/// the driver drives to the pickup or is on the trip — never while he is
/// just online, nor while he waits at the pickup — and every server read
/// still corrects it.
void main() {
  test('online without a trip: the clock does not count', () {
    var now = DateTime(2026, 11, 14, 8);
    final clock = DrivingTimeClock(now: () => now)..sync(online: true);
    now = now.add(const Duration(hours: 3));
    expect(clock.worked, Duration.zero);
    expect(clock.running, isFalse);
  });

  test('counts to the pickup and on the trip, not while waiting', () {
    var now = DateTime(2026, 11, 14, 8);
    final clock = DrivingTimeClock(now: () => now)..sync(online: true);
    clock.syncDriving(true); // accepted, driving to the pickup
    now = now.add(const Duration(minutes: 12));
    clock.syncDriving(false); // arrived, waiting for the rider
    now = now.add(const Duration(minutes: 7));
    clock.syncDriving(true); // rider on board
    now = now.add(const Duration(minutes: 30));
    clock.syncDriving(false); // trip ended, online again
    now = now.add(const Duration(hours: 1));
    expect(clock.worked, const Duration(minutes: 42));
    // Waiting online is not "offline": no rest is counted.
    expect(clock.restUntil, isNull);
  });

  test('a server read still corrects the phone', () {
    var now = DateTime(2026, 11, 14, 8);
    final clock = DrivingTimeClock(now: () => now)
      ..sync(online: true)
      ..syncDriving(true);
    now = now.add(const Duration(minutes: 50));
    clock.loadServer(drivenMinutes: 40, maxMinutes: 720);
    expect(clock.worked, const Duration(minutes: 40));
    now = now.add(const Duration(minutes: 5));
    expect(clock.worked, const Duration(minutes: 45), reason: 'still driving');
  });

  test('the ride stage drives the app clock', () {
    final clock = DrivingTimeClock.instance
      ..reset()
      ..sync(online: true);
    final ride = ActiveRideController(tripId: 'trp_1');
    expect(clock.running, isTrue, reason: 'heading to the pickup');
    ride.dispose();
    expect(clock.running, isFalse, reason: 'no ride any more');
    final waiting = ActiveRideController(
      tripId: 'trp_2',
      initialStage: ActiveRideStage.waitingForRider,
    );
    expect(clock.running, isFalse, reason: 'waiting at the pickup');
    waiting.dispose();
    clock.reset();
  });
}
