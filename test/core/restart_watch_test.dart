import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/restart_watch.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/session/driver_route_observer.dart';

class _FakeStore implements RestartMarkerStore {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String value) => this.value = value;

  Map<String, Object?> get marker =>
      (jsonDecode(value!) as Map).cast<String, Object?>();
}

String _marker({
  required DateTime start,
  required DateTime beat,
  String? screen = '/active-ride',
  String? stage = 'driverAssigned',
  bool visible = true,
  bool clean = false,
}) => jsonEncode({
  'v': 1,
  'id': 'abcd0123',
  'start': start.millisecondsSinceEpoch,
  'beat': beat.millisecondsSinceEpoch,
  'screen': screen,
  'stage': stage,
  'visible': visible,
  'clean': clean,
});

void main() {
  final start = DateTime.utc(2026, 11, 7, 12);
  final lastBeat = start.add(const Duration(seconds: 95));
  final now = lastBeat.add(const Duration(seconds: 3));

  late _FakeStore store;
  late List<String> reports;
  late String? screen;

  RestartWatch watch({DateTime? at}) => RestartWatch(
    store: store,
    report: reports.add,
    screen: () => screen,
    clock: () => at ?? now,
  );

  setUp(() {
    store = _FakeStore();
    reports = [];
    screen = '/home';
    RestartWatch.instance = null;
    RestartWatch.tripStage = null;
  });

  tearDown(() {
    RestartWatch.instance?.stop();
    RestartWatch.instance = null;
    RestartWatch.tripStage = null;
  });

  test('previous session unclean, visible and recent: one report with the '
      'last screen', () {
    store.value = _marker(start: start, beat: lastBeat);

    watch().start(visible: true, periodic: false);

    expect(reports, [
      'unexpected restart (on screen): last screen /active-ride (trip '
          'stage driverAssigned), 3 s after last beat, uptime 95 s',
    ]);
  });

  // Q5 (owner 2026-11-07, "Report background too"): a hidden page that
  // died is reported too, marked background (restart_watch_background_test).
  test('clean, old or missing previous marker: no report', () {
    for (final previous in <String?>[
      _marker(start: start, beat: lastBeat, clean: true),
      _marker(start: start, beat: lastBeat, visible: false, clean: true),
      _marker(start: start, beat: now.subtract(const Duration(minutes: 11))),
      _marker(
        start: start,
        beat: now.subtract(const Duration(minutes: 121)),
        visible: false,
      ),
      null,
      'not json',
    ]) {
      store.value = previous;
      watch().start(visible: true, periodic: false);
    }

    expect(reports, isEmpty);
  });

  test('previous session unclean and hidden at its last beat: one report '
      'marked background, also after 11 min (background limit 2 h)', () {
    store.value = _marker(start: start, beat: lastBeat, visible: false);

    watch().start(visible: true, periodic: false);

    expect(reports, [
      'unexpected restart (background): last screen /active-ride (trip '
          'stage driverAssigned), away 3 s, 3 s after last beat, uptime 95 s',
    ]);
  });

  test('the new marker is written at start and pagehide marks it clean', () {
    watch().start(visible: true, periodic: false);
    expect(store.marker['clean'], false);
    expect(store.marker['visible'], true);
    expect(store.marker['screen'], '/home');

    final w = watch()..start(visible: true, periodic: false);
    w.pageHide();
    expect(store.marker['clean'], true);
    expect(RestartWatch.unexpectedRestart(store.value, now), isNull);
  });

  test('the marker is updated on a screen change and a trip stage change', () {
    RestartWatch.instance = watch()..start(visible: true, periodic: false);
    expect(store.marker['screen'], '/home');

    screen = '/active-ride';
    RestartWatch.touch();
    expect(store.marker['screen'], '/active-ride');

    final ride = ActiveRideController(tripId: 'trp_1');
    expect(store.marker['stage'], 'driverToPickup');
    ride.dispose();
    expect(store.marker['stage'], isNull);
  });

  test('the route observer updates the marker on a push', () {
    RestartWatch.instance = RestartWatch(
      store: store,
      report: reports.add,
      clock: () => now,
    )..start(visible: true, periodic: false);
    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/earnings'),
      pageBuilder: (_, _, _) => const SizedBox(),
    );

    DriverRouteObserver().didPush(route, null);

    expect(CrashReports.currentScreen, '/earnings');
    expect(store.marker['screen'], '/earnings');
  });

  test('a lost WebGL context is reported once', () {
    final w = watch()..start(visible: true, periodic: false);
    w.contextLost();
    w.contextLost();
    expect(reports, ['webgl context lost: last screen /home, uptime 0 s']);
  });

  test('a report goes out as one error on the crash report channel', () async {
    final sent = <Map<String, Object?>>[];
    final sink = CrashReportSink(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        sent.add((jsonDecode(request.body) as Map).cast<String, Object?>());
        return http.Response('', 202);
      }),
      platform: 'web',
    );
    store.value = _marker(start: start, beat: lastBeat, stage: null);

    RestartWatch(
      store: store,
      report: (message) =>
          sink.report(message, StackTrace.empty, kind: CrashReports.kindError),
      clock: () => now,
    ).start(visible: true, periodic: false);
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(1));
    expect(sent.single['kind'], 'error');
    expect(sent.single['app'], 'driver');
    expect(
      sent.single['error'],
      'unexpected restart (on screen): last screen /active-ride, 3 s after '
      'last beat, uptime 95 s',
    );
    sink.dispose();
  });
}
