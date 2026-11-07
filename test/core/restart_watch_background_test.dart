// Q5 (owner 2026-11-07, "Report background too (Recommended)"): the restart
// diagnostic also reports a page that died while it was hidden (the owner
// switching between the driver and the rider app, server log 2026-11-06
// 04:59:14 UTC: driver cold start between resumes, no reload in the code).
// Finder D (D6, plan/finders-2026-11-07/D.md): the last beat of such a page
// says visible:false, and unexpectedRestart() dropped every marker that was
// not visible. This first test is finder D's fail-before test.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/logging/restart_watch.dart';

class _Store implements RestartMarkerStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String value) => this.value = value;
}

void main() {
  test('a page killed in the background during a trip is reported', () {
    final now = DateTime.utc(2026, 11, 6, 4, 59, 14);
    final marker = jsonEncode({
      'v': 1,
      'id': 'abcd1234',
      'start': now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
      'beat': now.subtract(const Duration(seconds: 8)).millisecondsSinceEpoch,
      'screen': '/trip',
      'stage': 'to_pickup',
      'visible': false, // the app was switched away 8 s ago
      'clean': false, // no pagehide: the page did not close on purpose
    });
    expect(
      RestartWatch.unexpectedRestart(marker, now),
      isNotNull,
      reason: 'restart_watch.dart: decoded["visible"] != true => null',
    );
  });

  test('the background report says background, the last screen and the time '
      'away (counted from when the page was hidden)', () {
    final start = DateTime.utc(2026, 11, 7, 12);
    final hiddenAt = start.add(const Duration(seconds: 60));
    final now = hiddenAt.add(const Duration(seconds: 42));
    final store = _Store();
    final reports = <String>[];
    var clock = start;
    RestartWatch.tripStage = 'driverToPickup';
    addTearDown(() => RestartWatch.tripStage = null);
    final first = RestartWatch(
      store: store,
      report: reports.add,
      screen: () => '/active-ride',
      clock: () => clock,
    )..start(visible: true, periodic: false);
    clock = hiddenAt;
    first.setVisible(false);
    // iOS may still run a beat while hidden; the time away stays counted
    // from the moment the page was hidden.
    clock = hiddenAt.add(const Duration(seconds: 2));
    first.beat();
    expect(jsonDecode(store.value!)['hidden'], hiddenAt.millisecondsSinceEpoch);

    // The page is killed in the background; the next start reads it.
    clock = now;
    RestartWatch(
      store: store,
      report: reports.add,
      screen: () => '/home',
      clock: () => clock,
    ).start(visible: true, periodic: false);

    expect(reports, [
      'restart after background: last screen /active-ride (trip stage '
          'driverToPickup), 42 s away, uptime 62 s',
    ]);
  });

  test('back on screen, the hidden time is cleared and a later on-screen '
      'death is an on-screen report', () {
    final start = DateTime.utc(2026, 11, 7, 12);
    final store = _Store();
    final reports = <String>[];
    var clock = start;
    final first = RestartWatch(
      store: store,
      report: reports.add,
      screen: () => '/home',
      clock: () => clock,
    )..start(visible: true, periodic: false);
    clock = start.add(const Duration(seconds: 10));
    first.setVisible(false);
    clock = start.add(const Duration(seconds: 20));
    first.setVisible(true);
    expect(jsonDecode(store.value!).containsKey('hidden'), isFalse);

    clock = start.add(const Duration(seconds: 23));
    RestartWatch(
      store: store,
      report: reports.add,
      clock: () => clock,
    ).start(visible: true, periodic: false);
    expect(reports, [
      'unexpected restart: last screen /home, 3 s after last beat, '
          'uptime 20 s',
    ]);
  });
}
