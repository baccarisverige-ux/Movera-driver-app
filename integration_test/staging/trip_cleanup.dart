part of 'trip_run.dart';

/// The clean-up every run reaches: each trip the run booked is closed
/// (rider cancel up to the arrival, else driver cancel), and the phone is
/// brought back to Home.
extension _TripCleanup on TripRun {
  /// [until]: the clean-up's own time box (the run's hard limit has
  /// passed or the steps are over); each server call is cut at it.
  Future<void> _cleanup({required DateTime until}) async {
    const title = 'no open test trip is left';
    Future<ApiAnswer> boxed(Future<ApiAnswer> call) {
      var left = until.difference(DateTime.now());
      if (left < const Duration(seconds: 5)) left = const Duration(seconds: 5);
      return call.timeout(
        left,
        onTimeout: () => const ApiAnswer(0, null, error: 'TimeoutException'),
      );
    }

    if (bookAnswerLost && rider.signedIn) {
      // A trip made by a booking whose answer was lost may show up late.
      final found = await _findLostBooking().timeout(
        const Duration(seconds: 30),
        onTimeout: () => const <String>[],
      );
      CheckLog.say('STEP lost booking re-check: ${found.length} new trip(s)');
    }
    if (booked.isEmpty) {
      log.skip('CLEANUP', title, 'no trip was booked');
    }
    final lines = <String>[];
    var allClosed = true;
    for (final id in booked) {
      try {
        var answer = await boxed(rider.trip(id));
        var status = answer.map?['status'] as String?;
        var how = 'nothing to do';
        if (status != null && !terminalStatuses.contains(status)) {
          final version = (answer.map!['version'] as num).toInt();
          final byRider =
              riderCancellable.contains(status) || status == 'requested';
          final done = await boxed(
            byRider
                ? rider.cancel(id, version, 'plans_changed')
                : driverApi.cancel(id, version, 'other_on_trip'),
          );
          how = '${byRider ? 'rider' : 'driver'} cancel ${done.short}';
          answer = await boxed(rider.trip(id));
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
    final left = until.difference(DateTime.now());
    await pumpUntil(
      tester,
      () => shows(find.byType(DriverHome)),
      timeout: left < const Duration(seconds: 15)
          ? const Duration(seconds: 3)
          : const Duration(seconds: 15),
    );
  }
}
