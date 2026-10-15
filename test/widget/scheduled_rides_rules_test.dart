import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

// Scheduled rides, Round 3: clashing rides leave the list (Q9), the cancel
// rules (Q11), the pause and admin's off switch (Q11), the fare boost
// (Q13) and rides Movera assigned (Q29). The demo day starts at 07:00.

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
  await tester.pumpAndSettle();
}

Future<void> _openRide(WidgetTester tester, String pickup) async {
  await tester.ensureVisible(find.text(pickup).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(pickup).first);
  await tester.pumpAndSettle();
}

/// From an accepted ride's details: Cancel reservation → [reason] →
/// Continue. Leaves the confirmation open. "Personal emergency" counts.
Future<void> _toConfirmation(
  WidgetTester tester, {
  String reason = 'Personal emergency',
}) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(reason));
  await tester.tap(find.text(reason));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _confirmCancel(WidgetTester tester) async {
  final confirm = find.widgetWithText(FilledButton, 'Cancel reservation');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

const _clashNote = ValueKey<String>('scheduled-clash-note');
const _blockNotice = ValueKey<String>('scheduled-block-notice');

void main() {
  setUp(ScheduledRideStore.reset);

  testWidgets('taking a ride removes the clashing one, with a short note', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Högsätravägen, Lidingö'), findsOneWidget);
    await _openRide(tester, 'Gamla vägen, Stockholm');
    await tester.tap(find.text('Accept  •  126.75 kr'));
    await tester.pumpAndSettle();
    expect(find.text('Reservation accepted'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    // 07:40 + 19 min ride + the drive to Lidingö + 15 spare is after 08:05.
    expect(find.text('Högsätravägen, Lidingö'), findsNothing);
    final note = find.byKey(_clashNote);
    expect(note, findsOneWidget);
    expect(
      find.descendant(of: note, matching: find.text('1 ride hidden')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: note,
        matching: find.textContaining('your 07:40 pickup'),
      ),
      findsOneWidget,
    );
    expect(ScheduledRideStore.openRequests.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the taken ride brings the clashing one back', (
    tester,
  ) async {
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
    await _open(tester);
    expect(find.text('Högsätravägen, Lidingö'), findsNothing);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await _openRide(tester, 'Gamla vägen, Stockholm');
    await _toConfirmation(tester);
    await _confirmCancel(tester);
    expect(find.text('Reservation cancelled'), findsOneWidget);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Högsätravägen, Lidingö'), findsOneWidget);
    expect(find.byKey(_clashNote), findsNothing);
  });

  testWidgets('the cancel sheet says until when it is free; drivers never pay', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    // The sample ride is tomorrow 08:15: free until 07:15 tomorrow.
    await _openRide(tester, 'Södermalm, Stockholm');
    expect(find.textContaining('Free cancel until tomorrow 07:15.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
    await tester.pumpAndSettle();
    final rules = find.byKey(const ValueKey<String>('scheduled-cancel-rules'));
    expect(
      find.descendant(
        of: rules,
        matching: find.text('Free cancel until tomorrow 07:15'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rules,
        matching: find.textContaining('You never pay to cancel'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Vehicle issue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Not late: no late-cancel warning, and no late cancel counted.
    expect(find.byKey(const ValueKey<String>('scheduled-late-cancel')),
        findsNothing);
    await _confirmCancel(tester);
    expect(ScheduledRideStore.lateCancelsInPeriod(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('under 1 h to pickup a cancel is late and counts', (
    tester,
  ) async {
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
    await _open(tester);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await _openRide(tester, 'Gamla vägen, Stockholm');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
    await tester.pumpAndSettle();
    expect(find.text('Late cancel: under 1 h to pickup'), findsOneWidget);
    expect(
      find.text('You never pay to cancel, but this late cancel counts.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Personal emergency'));
    await tester.tap(find.text('Personal emergency'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('This is a late cancel and it counts. You never pay.'),
        findsOneWidget);
    await _confirmCancel(tester);
    expect(ScheduledRideStore.lateCancelsInPeriod(), 1);
    // One late cancel does not pause anything.
    expect(ScheduledRideStore.block(), isNull);
  });

  testWidgets('a reason that doesn\'t count says so and is not a late cancel', (
    tester,
  ) async {
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
    await _open(tester);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await _openRide(tester, 'Gamla vägen, Stockholm');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
    await tester.pumpAndSettle();
    // Q21: the admin list marks a car breakdown as not counting.
    expect(find.text('Doesn’t count'), findsOneWidget);
    await tester.tap(find.text('Vehicle issue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('scheduled-cancel-not-counted')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('scheduled-late-cancel')),
        findsNothing);
    await _confirmCancel(tester);
    expect(ScheduledRideStore.lateCancelsInPeriod(), 0);
  });

  testWidgets('too many late cancels pause Scheduled rides until a date', (
    tester,
  ) async {
    final now = ScheduledClock.instance.now();
    ScheduledRideStore.addLateCancel(now.subtract(const Duration(days: 2)));
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
    await _open(tester);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await _openRide(tester, 'Gamla vägen, Stockholm');
    await _toConfirmation(tester);
    final until = now.add(const Duration(days: 7));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final date = '${until.day} ${months[until.month - 1]}';
    expect(
      find.text(
        'This is a late cancel (2 in 7 days). Scheduled rides pause until '
        '$date.',
      ),
      findsOneWidget,
    );
    await _confirmCancel(tester);

    final block = ScheduledRideStore.block();
    expect(block, isNotNull);
    expect(block!.byAdmin, isFalse);
    // The list is hidden, with the notice; the dot is off.
    expect(ScheduledRideStore.openRequests.value, 0);
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.byKey(_blockNotice), findsOneWidget);
    expect(find.text('Scheduled rides paused until $date'), findsOneWidget);
    expect(find.text('Gamla vägen, Stockholm'), findsNothing);
    expect(find.text('Högsätravägen, Lidingö'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin turned Scheduled rides off for this driver', (
    tester,
  ) async {
    ScheduledRideStore.driverAccess = const ScheduledRidesDriverAccess(
      enabled: false,
    );
    await _open(tester);
    expect(find.byKey(_blockNotice), findsOneWidget);
    expect(find.text('Scheduled rides are off'), findsOneWidget);
    expect(find.text('Gamla vägen, Stockholm'), findsNothing);
    expect(ScheduledRideStore.openRequests.value, 0);
    // Accepted rides stay.
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    expect(find.text('Södermalm, Stockholm'), findsOneWidget);

    // Off until a date: back on after it.
    final now = ScheduledClock.instance.now();
    ScheduledRideStore.driverAccess = ScheduledRidesDriverAccess(
      enabled: false,
      offUntil: now.subtract(const Duration(minutes: 1)),
    );
    expect(ScheduledRideStore.block(), isNull);
    expect(ScheduledRideStore.openRequests.value, 2);
  });

  testWidgets('a raised fare shows as a "+40 kr" boost badge (Q13)', (
    tester,
  ) async {
    await _open(tester);
    final badge = find.byKey(
      const ValueKey<String>('scheduled-boost-Högsätravägen, Lidingö'),
    );
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('+40 kr')),
        findsOneWidget);
    // Only the new fare: no old price next to it.
    expect(find.text('249.25 kr'), findsOneWidget);
    expect(find.text('209.25 kr'), findsNothing);
    await _openRide(tester, 'Högsätravägen, Lidingö');
    expect(find.text('+40 kr'), findsOneWidget);
    expect(find.text('Accept  •  249.25 kr'), findsOneWidget);
  });

  testWidgets('a ride Movera assigned is in Accepted, marked so (Q29)', (
    tester,
  ) async {
    ScheduledRideStore.acceptAssigned(demoAssignedReservation);
    await _open(tester);
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    expect(find.text('Kungsholmstorg, Stockholm'), findsOneWidget);
    expect(find.text('Assigned by Movera'), findsOneWidget);
    expect(ScheduledRideStore.upcoming.first, same(demoAssignedReservation));
  });
}
