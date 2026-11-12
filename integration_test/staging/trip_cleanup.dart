part of 'trip_run.dart';

/// The clean-up every run reaches: each trip the run booked is closed
/// (rider cancel up to the arrival, else driver cancel), and the phone is
/// brought back to Home.
extension _TripCleanup on TripRun {
  Future<void> _cleanup() async {
    const title = 'no open test trip is left';
    if (booked.isEmpty) {
      log.skip('CLEANUP', title, 'no trip was booked');
    }
    final lines = <String>[];
    var allClosed = true;
    for (final id in booked) {
      try {
        var answer = await rider.trip(id);
        var status = answer.map?['status'] as String?;
        var how = 'nothing to do';
        if (status != null && !terminalStatuses.contains(status)) {
          final version = (answer.map!['version'] as num).toInt();
          final byRider =
              riderCancellable.contains(status) || status == 'requested';
          final done = byRider
              ? await rider.cancel(id, version, 'plans_changed')
              : await driverApi.cancel(id, version, 'other_on_trip');
          how = '${byRider ? 'rider' : 'driver'} cancel ${done.short}';
          answer = await rider.trip(id);
          status = answer.map?['status'] as String?;
        }
        final closed = status != null && terminalStatuses.contains(status);
        allClosed &= closed;
        lines.add('$id $status ($how)');
      } catch (error) {
        allClosed = false;
        lines.add('$id stopped by ${error.runtimeType}');
      }
    }
    if (booked.isNotEmpty) {
      allClosed
          ? log.pass('CLEANUP', title, lines.join('; '))
          : log.fail('CLEANUP', title, lines.join('; '));
    }
    // Back to Home through whatever the trip left on screen.
    for (final key in const [
      'trip-outcome-acknowledge',
      'call-close',
      'ride-completed-done',
    ]) {
      if (shows(byKey(key))) {
        await tester.tap(byKey(key).first, warnIfMissed: false);
        await wait(tester, const Duration(seconds: 2));
      }
    }
    await pumpUntil(
      tester,
      () => shows(find.byType(DriverHome)),
      timeout: const Duration(seconds: 15),
    );
  }
}
