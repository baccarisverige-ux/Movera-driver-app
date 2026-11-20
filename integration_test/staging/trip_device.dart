part of 'trip_run.dart';

/// Device proof 2026-11-20 (Rules audits/impact/device-proof-2026-11-20.md):
/// the two trip-lifecycle gaps a real Test Lab phone must close.
///
/// M1: the app is really put in the background (Android HOME through
/// MainActivityTest), the rider books over HTTP against the same staging
/// server the run already uses, and the offer notice (channel
/// `movera_offers*`, MainActivity.kt) must be in the phone's notification
/// list; then the app comes back to the front for OFFER / ACCEPT.
///
/// M4: SOS is pressed and sent: the phone's top screen must be a dialer
/// opened by a `tel:` intent (a dial screen, never a call: the app only
/// launches `tel:`, no CALL_PHONE), and the server's SosReceipt
/// (`incidentId`) proves the Movera alert, the case the admin's alert
/// list shows. The test has no admin account, so the admin list itself
/// is not read.
///
/// While the app is really in the background frames are off: nothing is
/// pumped then (run 6), only plain time passes.
extension _TripDevice on TripRun {
  static const String _pkg = 'se.movera.driver';

  static int _offers(String? ack) =>
      int.tryParse(RegExp(r'offers=(\d+)').firstMatch(ack ?? '')?[1] ?? '') ??
      -1;

  static String _field(String? ack, String name) =>
      RegExp('$name=(\\S+)').firstMatch(ack ?? '')?[1] ?? '?';

  /// Brings the app back and pumps only once Android says it is resumed.
  Future<String?> _toFront(PhoneSwitches phone) async {
    final ack = await phone.send(tester, 'front', pump: false);
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await wait(tester, const Duration(seconds: 2));
    return ack;
  }

  Future<void> _bookInBackground() async {
    const id = 'OFFER-PUSH';
    const title = 'offer push shows while the app is in the background';
    final phone = PhoneSwitches();
    if (!phone.usable) {
      log.skip(id, title, 'not run: no phone control file (not Test Lab)');
      return _book('BOOK');
    }
    final before = _offers(await phone.send(tester, 'notif'));
    final home = await phone.send(tester, 'home', pump: false);
    final away = !_field(home, 'top').startsWith(_pkg);
    await _book('BOOK');
    var now = before;
    final sent = DateTime.now();
    if (tripId != null) {
      final end = sent.add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(end)) {
        now = _offers(await phone.send(tester, 'notif', pump: false));
        if (now > before && before >= 0) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    final seconds = DateTime.now().difference(sent).inSeconds;
    final front = await _toFront(phone);
    final back = _field(front, 'top').startsWith(_pkg);
    final detail =
        'app in background=$away offer notices before=$before after=$now '
        'in ${seconds}s; trip=${tripId ?? 'none'}; back in front=$back';
    if (tripId == null) {
      log.skip(id, title, 'not run: booking failed; $detail');
    } else if (away && before >= 0 && now > before && back) {
      log.pass(id, title, detail);
    } else {
      log.fail(id, title, detail);
    }
  }

  Future<void> _sosPress() async {
    const id = 'SOS-PRESS';
    const title = 'SOS opens the 112 dialer and alerts Movera';
    if (late) return log.skip(id, title, 'not run: time limit near');
    final phone = PhoneSwitches();
    if (!phone.usable) {
      return log.skip(id, title, 'not run: no phone control file');
    }
    final trip = tripId;
    await tapTripControl(tester, 'active-ride-safety-button');
    await pumpUntil(
      tester,
      () => shows(find.byKey(const ValueKey('safety-sos'))),
      timeout: const Duration(seconds: 10),
    );
    await tester.tap(find.byKey(const ValueKey('safety-sos')));
    await pumpUntil(
      tester,
      () => shows(find.byKey(const ValueKey('safety-sos-send'))),
      timeout: const Duration(seconds: 5),
    );
    // The tap hands off to the dialer: from here the app may be paused.
    await tester.tap(find.byKey(const ValueKey('safety-sos-send')));
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(seconds: 3));
    final top = await phone.send(tester, 'top', pump: false);
    final topActivity = _field(top, 'top');
    final dialAct = _field(top, 'telact');
    final dialerOnTop = !topActivity.startsWith(_pkg) && topActivity != '?';
    final dialIntent = dialAct.endsWith('.DIAL') || dialAct.endsWith('.VIEW');
    final front = await _toFront(phone);
    await pumpUntil(
      tester,
      () => shows(find.textContaining(tr.safetySosSent)),
      timeout: const Duration(seconds: 20),
    );
    final sentShown = shows(find.textContaining(tr.safetySosSent));
    final receipt = trip == null
        ? null
        : rec.lastAnswer['/api/v1/driver/trips/${Uri.encodeComponent(trip)}/sos'];
    final incident = receipt is Map && receipt['incidentId'] is String;
    await log.screenshot(tester, 'trip-sos-sent');
    await backToTrip(tester);
    final detail =
        'top after SOS=$topActivity tel intent=$dialAct '
        'back=${_field(front, 'top')}; "SOS sent" shown=$sentShown; '
        'server incident=$incident; trip screen on top=${onTripTop()}';
    dialerOnTop && dialIntent && sentShown && incident && onTripTop()
        ? log.pass(id, title, detail)
        : log.fail(id, title, detail);
  }
}
