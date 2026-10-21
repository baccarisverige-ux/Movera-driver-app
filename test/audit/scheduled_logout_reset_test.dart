import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:shared_preferences/shared_preferences.dart';

// driver-u167: logout resets Scheduled rides. The previous driver's
// accepted rides, late cancels and pause, reminder and backup note do not
// carry over to the next session on the device.

/// The previous driver's Scheduled rides: an accepted request, a pause
/// from two late cancels, a reminder and a backup note.
void _useScheduledRides() {
  final now = ScheduledClock.instance.now();
  ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
  ScheduledRideStore.addLateCancel(now.subtract(const Duration(hours: 2)));
  ScheduledRideStore.addLateCancel(now.subtract(const Duration(hours: 1)));
  ScheduledRideStore.reminder.value = 'Head to your 07:40 pickup';
  ScheduledRideStore.backupNote.value = 'Given to a backup driver';
  expect(ScheduledRideStore.block(), isNotNull);
}

void _expectFresh() {
  final now = ScheduledClock.instance.now();
  expect(ScheduledRideStore.block(), isNull);
  expect(ScheduledRideStore.pausedUntil(now), isNull);
  expect(ScheduledRideStore.lateCancelsInPeriod(), 0);
  expect(ScheduledRideStore.reminder.value, isNull);
  expect(ScheduledRideStore.backupNote.value, isNull);
  expect(ScheduledRideStore.openRequests.value, 2);
  expect(
    ScheduledRideStore.upcoming.map((ride) => ride.pickupAddress),
    ['Södermalm, Stockholm'],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(ScheduledRideStore.reset);

  testWidgets('the app logout resets Scheduled rides', (tester) async {
    DriverStartPosition.clearMemory();
    await (await SharedPreferences.getInstance())
        .setString(DriverStartPosition.key, '{"lat":59.3326,"lng":18.0649}');
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MoveraApp());
    await tester.pump(const Duration(milliseconds: 120));
    _useScheduledRides();
    final scope = tester.widget<DriverRuntimeScope>(
      find.byType(DriverRuntimeScope).first,
    );
    var done = false;
    scope.logout!().then((_) => done = true);
    for (var i = 0; i < 20 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done, isTrue);
    _expectFresh();
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Profile logout without an app scope resets them too', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DriverProfile()));
    await tester.pumpAndSettle();
    _useScheduledRides();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    _expectFresh();
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });
}
