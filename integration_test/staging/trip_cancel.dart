part of 'trip_run.dart';

/// Sensitive buttons 2026-11-20 (owner: "make Firebase test for sensitive
/// buttons", Rules audits/impact/device-proof-2026-11-20.md): the one
/// sensitive driver button the trip-lifecycle run did not press yet,
/// Cancel trip. After the full trip, the rider (over HTTP) books a second
/// cash ride, the driver accepts it on the phone, then taps the trip
/// card's "more" button -> Cancel trip -> the first reason -> Confirm.
/// PASS only when the server says `cancelled_by_driver` and the phone has
/// left the trip screen. Staging test accounts only; no fee is involved
/// (driver cancel before the pickup).
extension _TripCancel on TripRun {
  Future<void> _driverCancel() async {
    const id = 'DRIVER-CANCEL';
    const title = 'driver cancels an accepted ride in the app';
    if (late) return log.skip(id, title, 'not run: time limit near');
    if (!completed) {
      return log.skip(id, title, 'not run: the first trip did not complete');
    }
    await backToHome(tester);
    await _book('CANCEL-BOOK');
    final trip = tripId;
    if (trip == null) {
      return log.skip(id, title, 'not run: second booking failed');
    }
    String? control;
    await pumpUntil(
      tester,
      () => (control = offerControl()) != null,
      timeout: const Duration(seconds: 90),
    );
    if (control == null) {
      final view = await riderView();
      return log.fail(
        id,
        title,
        'no offer for the second ride in 90 s (server ${view?['status']})',
      );
    }
    final onTrip = await acceptOffer(tester, control!);
    final took = await waitStatus({
      'accepted',
      'driver_to_pickup',
    }, const Duration(seconds: 30));
    if (!onTrip || (took != 'accepted' && took != 'driver_to_pickup')) {
      return log.fail(
        id,
        title,
        'accept: trip screen=$onTrip server=$took (want accepted)',
      );
    }
    final more = await tapTripControl(tester, 'current-trip-more');
    await pumpUntil(
      tester,
      () => shows(byKey('active-ride-cancel-option')),
      timeout: const Duration(seconds: 8),
    );
    final option =
        shows(byKey('active-ride-cancel-option')) &&
        await tapHit(tester, byKey('active-ride-cancel-option'), 'Cancel trip');
    await pumpUntil(
      tester,
      () => shows(byKey('trip-cancellation-reasons-sheet')),
      timeout: const Duration(seconds: 8),
    );
    final reasons = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('trip-cancel-reason-'),
    );
    var reason = 'none';
    if (shows(reasons)) {
      final key = reasons.evaluate().first.widget.key! as ValueKey<String>;
      reason = key.value.substring('trip-cancel-reason-'.length);
      await tapHit(tester, find.byKey(key), 'cancel reason $reason');
    }
    await pumpUntil(
      tester,
      () => shows(byKey('confirm-trip-cancellation')),
      timeout: const Duration(seconds: 8),
    );
    final confirm =
        shows(byKey('confirm-trip-cancellation')) &&
        await tapHit(tester, byKey('confirm-trip-cancellation'), 'Confirm');
    final status = await waitStatus({
      'cancelled_by_driver',
    }, const Duration(seconds: 30));
    await pumpUntil(
      tester,
      () => tripScreen()?.tripId != trip,
      timeout: const Duration(seconds: 20),
    );
    final left = tripScreen()?.tripId != trip;
    await log.screenshot(tester, 'trip-driver-cancelled');
    final detail =
        'more=$more cancel option=$option reason=$reason confirm=$confirm '
        'server=$status trip screen left=$left';
    status == 'cancelled_by_driver' && left
        ? log.pass(id, title, detail)
        : log.fail(
            id,
            title,
            '$detail (want cancelled_by_driver, off the trip)',
          );
  }
}
