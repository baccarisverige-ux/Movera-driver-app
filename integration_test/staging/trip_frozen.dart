part of 'trip_run.dart';

/// T7 on Test Lab (owner 2026-11-19 "You test with Firebase"; steps in
/// Rules audits/impact/longstop-frozen-fix-supervisor.md "T7"): the
/// server's long-stop ride check when the phone's position freezes.
///
/// One live cash trip, rider on board, then three cases along the
/// pickup -> drop-off line (all > 300 m from the drop-off):
/// * T7-C no network: moving, network (airplane + Wi-Fi + data) off for
///   3 min, on again -> NO long_stop check (silent time is not counted).
/// * T7-B "tunnel": moving (fixes say ~8 m/s), Location off for 3 min with
///   the network on -> the app re-sends its last fix, which said "moving"
///   -> NO long_stop check (owner: "Skip if car was moving").
/// * T7-A frozen while standing: standing 30 s, Location off for 4 min ->
///   the long_stop check MUST come (card on the phone, server rideCheck
///   trigger long_stop); answered OK on both sides.
///
/// A real road tunnel (GPS lost underground while the car drives, then a
/// different first fix when it comes back) cannot be made on a phone in a
/// rack: T7-B is its closest copy (the switch, not the sky, takes the GPS).
extension _TripFrozen on TripRun {
  static const String _locationPath = '/api/v1/driver/location';

  Future<void> _frozenScenario() async {
    await step('BOOK', 'rider books a cash trip', () => _book('BOOK'));
    if (tripId == null) return;
    await step('OFFER', 'offer shows on the driver phone', _offerAndAccept);
    if (!accepted) return;
    await step('ARRIVE', 'driver taps Arrived', _arrive);
    await step('START', 'driver starts the trip', _start);
    if (!started) return;
    final switches = PhoneSwitches();
    if (!switches.usable || !mock.movable) {
      for (final id in ['T7-C', 'T7-B', 'T7-A']) {
        log.skip(id, 'frozen GPS case', 'NOT CHECKED: no control/mock file');
      }
      return;
    }
    final config = rec.lastAnswer['/api/v1/driver/config'];
    final rc = config is Map ? config['rideCheck'] : null;
    final on = rc is Map ? rc['on'] != false : true;
    final stopMin = rc is Map && rc['stopMinutes'] is num
        ? (rc['stopMinutes'] as num).toDouble()
        : 2.0;
    CheckLog.say('STEP rideCheck on=$on stopMinutes=$stopMin');
    if (!on) {
      for (final id in ['T7-C', 'T7-B', 'T7-A']) {
        log.skip(id, 'frozen GPS case', 'NOT CHECKED: rideCheck.on is false');
      }
      return;
    }
    // The line pickup -> drop-off (~700 m east): C uses 0-100 m, B
    // 100-200 m, A stands at 240 m (~460 m before the drop-off).
    (double, double) at(double meters) => (
      pickup.$1 + (dropoff.$1 - pickup.$1) * meters / 700,
      pickup.$2 + (dropoff.$2 - pickup.$2) * meters / 700,
    );
    try {
      await step('T7-C', 'no network 3 min while moving: not asked', () async {
        await _drive(at(40), 4);
        final mark = rec.length;
        final before = await _checkIds();
        final off = await switches.send(tester, 'net-off');
        await _hold(const Duration(minutes: 3), moveTo: at(100));
        final back = await switches.send(tester, 'net-on');
        await _drive(at(100), 4);
        final asked = await _watchNoCheck(before, const Duration(seconds: 75));
        _noCheck('T7-C', 'no network 3 min while moving: not asked', asked, [
          'switch off=$off',
          'on=$back',
          'location POSTs=${_posts(mark)}',
        ]);
      });
      await step(
        'T7-B',
        'Location off 3 min while moving (tunnel copy): not asked',
        () async {
          await _drive(at(140), 8, sayMoving: true);
          mock.hold(speed: 8);
          final mark = rec.length;
          final before = await _checkIds();
          final off = await switches.send(tester, 'location-off');
          final offAt = rec.length;
          await _hold(const Duration(minutes: 3));
          final during = _posts(offAt);
          final back = await switches.send(tester, 'location-on');
          await _drive(at(200), 8, sayMoving: true);
          final asked = await _watchNoCheck(
            before,
            const Duration(seconds: 60),
          );
          _noCheck(
            'T7-B',
            'Location off 3 min while moving (tunnel copy): not asked',
            asked,
            [
              'switch off=$off',
              'on=$back',
              'location POSTs while off=$during',
              'all=${_posts(mark)}',
            ],
          );
        },
      );
      await step(
        'T7-A',
        'Location off 4 min while standing: asked once',
        () async {
          const title = 'Location off 4 min while standing: asked once';
          await _drive(at(240), 6);
          mock.hold();
          final before = await _checkIds();
          rideCheckSeenAt = null;
          await _hold(const Duration(seconds: 30));
          final off = await switches.send(tester, 'location-off');
          final offAt = rec.length;
          final since = DateTime.now();
          await _hold(const Duration(minutes: 4));
          final during = _posts(offAt);
          final ids = await _checkIds();
          final view = lastRiderView;
          final check = view?['rideCheck'];
          final back = await switches.send(tester, 'location-on');
          final fresh = ids.difference(before);
          if (check is Map && check['checkId'] is String) {
            await rider.post('/api/v1/rider/trips/$tripId/ride-check', {
              'checkId': check['checkId'],
              'trigger': check['trigger'],
              'at': DateTime.now().toUtc().toIso8601String(),
              'answer': 'ok',
            });
          }
          final trigger = check is Map ? check['trigger'] : null;
          final detail =
              'card seen=${rideCheckSeenAt != null} after '
              '${rideCheckSeenAt?.difference(since).inSeconds ?? '-'} s with '
              'Location off (stopMinutes=$stopMin); server checks new='
              '${fresh.length} trigger=$trigger; location POSTs while off='
              '$during; switch off=$off on=$back; app screen on top: '
              'trip=${onTripTop()}';
          rideCheckSeenAt != null && trigger == 'long_stop'
              ? log.pass('T7-A', title, detail)
              : log.fail('T7-A', title, detail);
        },
      );
    } finally {
      // Never leave the phone without Location or network for the
      // clean-up (the Java side also puts the network back after 5 min).
      await switches.send(tester, 'net-on');
      await switches.send(tester, 'location-on');
    }
  }

  Future<void> _drive(
    (double, double) to,
    double speed, {
    bool sayMoving = false,
  }) => mock.driveTo(
    tester,
    to.$1,
    to.$2,
    metersPerSecond: speed,
    settle: const Duration(seconds: 2),
    sayMoving: sayMoving,
  );

  /// Waits [time] pumping (the ride check card is noted and answered);
  /// [moveTo]: the mock keeps moving there meanwhile (the car drives on).
  Future<void> _hold(Duration time, {(double, double)? moveTo}) async {
    final end = DateTime.now().add(time);
    final from = (mock.lat, mock.lng);
    final start = DateTime.now();
    while (DateTime.now().isBefore(end) && !stopped) {
      await rideCheckGate();
      if (moveTo != null) {
        final t =
            DateTime.now().difference(start).inMilliseconds /
            time.inMilliseconds;
        mock.lat = from.$1 + (moveTo.$1 - from.$1) * t.clamp(0.0, 1.0);
        mock.lng = from.$2 + (moveTo.$2 - from.$2) * t.clamp(0.0, 1.0);
        mock.hold(speed: 5);
      }
      await wait(tester, const Duration(seconds: 2));
    }
  }

  /// The ride check ids the server shows the rider now (the newest one).
  Future<Set<String>> _checkIds() async {
    final view = await riderView();
    final check = view?['rideCheck'];
    return {
      if (check is Map && check['checkId'] is String)
        '${check['checkId']}:${check['trigger']}',
    };
  }

  /// Watches [time] for a NEW long_stop check (card or server); returns
  /// what was seen (empty = not asked).
  Future<List<String>> _watchNoCheck(Set<String> before, Duration time) async {
    rideCheckSeenAt = null;
    final seen = <String>{};
    final end = DateTime.now().add(time);
    while (DateTime.now().isBefore(end) && !stopped) {
      await rideCheckGate();
      seen.addAll((await _checkIds()).difference(before));
      await wait(tester, const Duration(seconds: 5));
    }
    return [...seen, if (rideCheckSeenAt != null) 'card on the phone'];
  }

  void _noCheck(String id, String title, List<String> asked, List<String> d) {
    final longStop = asked.where(
      (a) => a.endsWith(':long_stop') || a == 'card on the phone',
    );
    final detail = 'new checks=$asked; ${d.join('; ')}';
    longStop.isEmpty
        ? log.pass(id, title, detail)
        : log.fail(id, title, detail);
  }

  String _posts(int from) {
    final list = calls(_locationPath, method: 'POST', from: from).toList();
    final ok = list.where((c) => !c.failed).length;
    return '${list.length} (ok $ok)';
  }
}
