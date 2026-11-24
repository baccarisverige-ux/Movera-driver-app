import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/logging/crash_breadcrumbs.dart';
import 'package:movera/core/logging/crash_catcher.dart';
import 'package:movera/core/logging/crash_files.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Owner 2026-11-24 "Add to admin all kind of crash" (contract v0.18.157
/// `contract.json#crashCatcher`), driver app. Rule 36: fails on main — no
/// crash catcher, no native_crash / freeze / dart_error kind, no
/// breadcrumbs, no outbox file and no crashReports.on switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 11, 24, 10);
    CrashReports.reportingEnabled = true;
    CrashReports.context = null;
    CrashReports.currentScreen = null;
    CrashCatcher.instance = null;
    CrashBreadcrumbs.instance = CrashBreadcrumbs(clock: () => now);
  });

  CrashCatcher catcherWith(MemoryCrashFiles files, List<CrashEvent> events) =>
      CrashCatcher(
        files: files,
        send: events.add,
        clock: () => now,
        appVersion: '1.0.0',
        build: '10',
      );

  CrashReportSink sinkWith(
    Future<http.Response> Function(http.Request) handler,
  ) => CrashReportSink(
    baseUri: Uri.parse('https://api.movera.example'),
    client: MockClient(handler),
    appVersion: '1.0.0',
    build: '10',
    platform: 'android',
    retryDelay: const Duration(milliseconds: 20),
    maxAttempts: 2,
  );

  test(
    'an Android exception file + the marker of the last run = one native_crash at the next launch',
    () {
      final files = MemoryCrashFiles();
      final first = catcherWith(files, [])..start();
      first.crumbs.route('/home');
      first.stop();
      files.write(
        CrashFileNames.native,
        jsonEncode({
          'name': 'java.lang.IllegalStateException',
          'reason': 'Reply already submitted',
          'stack': 'at io.flutter.plugin.common.MethodChannel',
        }),
      );
      final events = <CrashEvent>[];
      CrashBreadcrumbs.instance = CrashBreadcrumbs(clock: () => now);
      catcherWith(files, events).start();
      expect(events.single.kind, 'native_crash');
      expect(
        events.single.message,
        'java.lang.IllegalStateException: Reply already submitted',
      );
      expect(events.single.screen, '/home');
      expect(events.single.breadcrumbs!.single['message'], '/home');
      expect(files.read(CrashFileNames.native), isNull);
    },
  );

  test('an ANR named by ApplicationExitInfo (no stack) is reported too', () {
    final files = MemoryCrashFiles()
      ..write(CrashFileNames.running, '{}')
      ..write(
        CrashFileNames.native,
        '{"name":"REASON_ANR","reason":"Input dispatching timed out","stack":""}',
      );
    final events = <CrashEvent>[];
    catcherWith(files, events).start();
    expect(events.single.message, 'REASON_ANR: Input dispatching timed out');
    expect(events.single.nativeReason, {
      'name': 'REASON_ANR',
      'reason': 'Input dispatching timed out',
    });
  });

  test('a clean pause leaves no marker: no report at the next launch', () {
    final files = MemoryCrashFiles();
    final first = catcherWith(files, [])..start();
    first.lifecycle(AppLifecycleState.paused);
    first.stop();
    final events = <CrashEvent>[];
    catcherWith(files, events).start();
    expect(events, isEmpty);
  });

  test('a freeze of 6 s in front is one freeze report', () {
    final events = <CrashEvent>[];
    final c = catcherWith(MemoryCrashFiles(), events)..start();
    CrashReports.currentScreen = '/trip';
    now = now.add(const Duration(seconds: 7));
    c.checkFreeze();
    expect(events.single.kind, 'freeze');
    expect(events.single.freezeMs, 6000);
    expect(events.single.message, 'The screen froze for 6 s (screen /trip)');
    c.stop();
  });

  test(
    'a warning log line and a failed API call become breadcrumbs, ids out',
    () {
      DriverLog.warn('offer 123 expired for rider +46 70 174 06 08');
      CrashBreadcrumbs.instance.network(
        'GET',
        '/driver/trips/trp_01JB2Z3Y4X5W6V7T8S9R0QPNMK',
        503,
      );
      final lines = CrashBreadcrumbs.instance.items
          .map((c) => '${c.type} ${c.message}')
          .toList();
      expect(lines.first, startsWith('log movera: offer :id expired'));
      expect(lines.first, isNot(contains('174 06 08')));
      expect(lines.last, 'network GET /driver/trips/:id 503');
    },
  );

  test(
    'an uncaught Dart error is sent as dart_error with device, OS and breadcrumbs',
    () async {
      final sent = <Map<String, Object?>>[];
      final sink = sinkWith((r) async {
        sent.add(jsonDecode(r.body) as Map<String, Object?>);
        return http.Response('', 202);
      });
      CrashBreadcrumbs.instance.route('/home');
      CrashReports.context = () => {
        'deviceModel': 'samsung SM-S911B',
        'osVersion': 'Android 14 (API 34)',
        'breadcrumbs': CrashBreadcrumbs.instance.toJson(),
      };
      sink(
        const DriverLogRecord(
          level: DriverLogLevel.error,
          name: 'movera',
          message: 'Flutter framework error',
          error: 'Null check',
          fatal: true,
        ),
      );
      await settle();
      expect(sent.single['kind'], 'dart_error');
      expect(sent.single['deviceModel'], 'samsung SM-S911B');
      expect(sent.single['osVersion'], 'Android 14 (API 34)');
      expect(
        (sent.single['breadcrumbs']! as List).single,
        containsPair('message', '/home'),
      );
      sink.dispose();
    },
  );

  test('native reason and freeze time go in their own fields', () async {
    final sent = <Map<String, Object?>>[];
    final sink = sinkWith((r) async {
      sent.add(jsonDecode(r.body) as Map<String, Object?>);
      return http.Response('', 202);
    });
    sink.report(
      'SIGSEGV: signal 11',
      StackTrace.empty,
      kind: 'native_crash',
      nativeReason: {'name': 'SIGSEGV', 'reason': 'signal 11'},
    );
    sink.report(
      'The screen froze for 6 s',
      StackTrace.empty,
      kind: 'freeze',
      freezeMs: 6000,
    );
    await settle();
    expect(sent[0]['nativeReason'], {'name': 'SIGSEGV', 'reason': 'signal 11'});
    expect(sent[1]['freezeMs'], 6000);
    expect(sent[1]['kind'], 'freeze');
    sink.dispose();
  });

  test(
    'the zone switch off sends nothing; the document in use turns it on again',
    () async {
      final sent = <http.Request>[];
      final sink = sinkWith((r) async {
        sent.add(r);
        return http.Response('', 202);
      });
      CrashCatcher.acceptSwitch({'on': false}, zoneId: 'Z001');
      expect(CrashReports.currentZoneId, 'Z001');
      sink.report(StateError('off'), StackTrace.empty, kind: 'dart_error');
      await settle();
      expect(sent, isEmpty);
      CrashCatcher.acceptSwitch(null);
      sink.report(StateError('on'), StackTrace.empty, kind: 'dart_error');
      await settle();
      expect(sent, hasLength(1));
      expect(jsonDecode(sent.single.body)['zoneId'], 'Z001');
      sink.dispose();
    },
  );

  test(
    'offline: kept in the outbox file, sent once at the next launch',
    () async {
      final files = MemoryCrashFiles();
      final offline = sinkWith(
        (r) async => throw http.ClientException('offline'),
      )..outbox = CrashOutbox(files);
      offline.report(StateError('kept'), StackTrace.empty, kind: 'dart_error');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      offline.dispose();
      expect(CrashOutbox(files).pending(), hasLength(1));
      final sent = <Map<String, Object?>>[];
      final online = sinkWith((r) async {
        sent.add(jsonDecode(r.body) as Map<String, Object?>);
        return http.Response('', 202);
      })..outbox = CrashOutbox(files);
      online.resendOutbox();
      await settle();
      expect(sent.single['error'], contains('kept'));
      expect(CrashOutbox(files).pending(), isEmpty);
      online.dispose();
    },
  );
}
