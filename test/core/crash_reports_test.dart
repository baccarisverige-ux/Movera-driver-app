import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/logging/global_error_hooks.dart';

/// Contract v0.16.0 §11 (owner 2026-10-29: "Add automatic and add this in
/// term and condition"): a live driver app sends crashes and reported
/// errors to POST /telemetry/crashes on its own, scrubbed.
void main() {
  Future<void> settle([int ms = 20]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  CrashReportSink sinkWith(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
    DateTime Function()? clock,
    DriverLogSink? next,
  }) => CrashReportSink(
    baseUri: Uri.parse('https://api.movera.example'),
    client: MockClient(handler),
    accessToken: token,
    appVersion: '1.0.0',
    build: '1',
    platform: 'android',
    next: next,
    clock: clock,
    retryDelay: const Duration(milliseconds: 30),
  );

  tearDown(() => CrashReports.currentScreen = null);

  test(
    'an uncaught error goes out as a crash with the v0.16.0 fields',
    () async {
      final sent = <http.Request>[];
      final console = <DriverLogRecord>[];
      final sink = sinkWith(
        (r) async {
          sent.add(r);
          return http.Response('', 202);
        },
        token: () async => 'driver-access',
        next: console.add,
      );
      CrashReports.currentScreen = 'driver-home';
      sink(
        DriverLogRecord(
          level: DriverLogLevel.error,
          name: 'movera',
          message: 'Uncaught async error',
          error: StateError(
            'rider Anna +46 70 123 45 67 anna@example.com 59.334591,18.063240 '
            '{"riderName":"Anna","pickupAddress":"Storgatan 1"}',
          ),
          stack: StackTrace.current,
          fatal: true,
        ),
      );
      await settle();
      expect(console, hasLength(1), reason: 'the console still gets it');
      expect(
        sent.single.url.toString(),
        'https://api.movera.example/api/v1/telemetry/crashes',
      );
      expect(sent.single.headers['Authorization'], 'Bearer driver-access');
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body['app'], 'driver');
      expect(body['platform'], 'android');
      expect(body['appVersion'], '1.0.0');
      expect(body['build'], '1');
      expect(body['screen'], 'driver-home');
      expect(body['kind'], 'crash');
      expect(DateTime.parse(body['occurredAt'] as String).isUtc, isTrue);
      final error = body['error'] as String;
      for (final personal in [
        '123 45 67',
        'anna@example.com',
        '59.334591',
        '"Anna"',
        'Storgatan',
      ]) {
        expect(error, isNot(contains(personal)));
      }
      sink.dispose();
    },
  );

  test(
    'DriverLog.error with an error is kind error; info lines stay home',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final sink = sinkWith((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response('', 202);
      });
      final previous = DriverLog.sink;
      DriverLog.sink = sink.call;
      addTearDown(() => DriverLog.sink = previous);
      DriverLog.info('ride restored');
      DriverLog.warn('slow');
      DriverLog.error('no error object');
      DriverLog.error('Trip step failed', StateError('x'), StackTrace.empty);
      await settle();
      expect(bodies, hasLength(1));
      expect(bodies.single['kind'], 'error');
      expect(bodies.single['extra'], {'message': 'Trip step failed'});
      sink.dispose();
    },
  );

  test('the global hooks report a crash, not an error', () {
    final records = <DriverLogRecord>[];
    final previousSink = DriverLog.sink;
    final previousOnError = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    FlutterError.onError = (_) {};
    DriverLog.sink = records.add;
    addTearDown(() {
      DriverLog.sink = previousSink;
      FlutterError.onError = previousOnError;
      PlatformDispatcher.instance.onError = previousPlatform;
    });
    installGlobalErrorHooks();
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('f')));
    PlatformDispatcher.instance.onError!(StateError('p'), StackTrace.empty);
    expect(records.map((r) => r.fatal), [true, true]);
  });

  test(
    'signed out or a broken token store: sent without Authorization',
    () async {
      final sent = <http.Request>[];
      final sink = sinkWith((r) async {
        sent.add(r);
        return http.Response('', 202);
      }, token: () async => throw StateError('keystore'));
      sink.report(StateError('a'), StackTrace.empty);
      await settle();
      expect(sent.single.headers.containsKey('Authorization'), isFalse);
      sink.dispose();
    },
  );

  test('a burst of one crash is sent once', () async {
    var now = DateTime.utc(2026, 10, 29, 9);
    var calls = 0;
    final sink = sinkWith((r) async {
      calls += 1;
      return http.Response('', 202);
    }, clock: () => now);
    for (var i = 0; i < 30; i++) {
      sink.report(StateError('same'), StackTrace.empty);
    }
    await settle();
    expect(calls, 1);
    expect(sink.repeatedCount, 29);
    now = now.add(const Duration(minutes: 2));
    sink.report(StateError('same'), StackTrace.empty);
    await settle();
    expect(calls, 2);
    sink.dispose();
  });

  test('offline: kept, then sent in order when the network is back', () async {
    var online = false;
    final delivered = <String>[];
    final sink = sinkWith((r) async {
      if (!online) throw http.ClientException('offline');
      delivered.add((jsonDecode(r.body) as Map)['error'] as String);
      return http.Response('', 202);
    });
    sink.report(StateError('one'), StackTrace.empty);
    sink.report(StateError('two'), StackTrace.empty);
    await settle();
    expect(delivered, isEmpty);
    expect(sink.pendingCount, 2);
    online = true;
    await settle(150);
    expect(delivered, ['Bad state: one', 'Bad state: two']);
    sink.dispose();
  });

  test(
    '5xx and 429 are retried, 4xx is not; attempts and queue bounded',
    () async {
      final codes = [503, 429, 202, 400];
      var calls = 0;
      final sink = sinkWith((r) async {
        calls += 1;
        return http.Response('', codes.removeAt(0));
      });
      sink.report(StateError('a'), StackTrace.empty);
      await settle(250);
      expect(calls, 3);
      sink.report(StateError('b'), StackTrace.empty);
      await settle(100);
      expect(calls, 4);
      sink.dispose();

      var failing = 0;
      final bounded = CrashReportSink(
        baseUri: Uri.parse('https://api.movera.example'),
        client: MockClient((r) async {
          failing += 1;
          return http.Response('', 500);
        }),
        queueLimit: 3,
        retryDelay: const Duration(milliseconds: 1),
        maxRetryDelay: const Duration(milliseconds: 2),
        maxAttempts: 2,
      );
      for (var i = 0; i < 10; i++) {
        bounded.report(StateError('e$i'), StackTrace.empty);
      }
      await settle(200);
      expect(failing, lessThanOrEqualTo(8));
      expect(bounded.droppedCount, greaterThanOrEqualTo(7));
      expect(bounded.pendingCount, 0);
      bounded.dispose();
    },
  );

  test('the body stays under 16 KB and the field limits', () {
    final body = CrashReports.body(
      error: 'e' * 20000,
      stackTrace: StackTrace.fromString('#0 frame\n' * 5000),
      extra: {'message': 'm' * 2000, 'riderName': 'Anna'},
      app: 'driver',
      appVersion: 'v' * 100,
      occurredAt: DateTime.utc(2026),
    );
    expect(utf8.encode(jsonEncode(body)).length, lessThanOrEqualTo(16384));
    expect((body['error'] as String).length, lessThanOrEqualTo(4000));
    expect((body['stack'] as String).length, lessThanOrEqualTo(12000));
    expect((body['appVersion'] as String).length, 40);
    expect((body['extra'] as Map).containsKey('riderName'), isFalse);
    expect(((body['extra'] as Map)['message'] as String).length, 500);
  });

  test('never throws into the app, also after dispose', () async {
    final sink = sinkWith(
      (r) async => throw StateError('boom'),
      next: (_) => throw StateError('console'),
    );
    sink(
      DriverLogRecord(
        level: DriverLogLevel.error,
        name: 'movera',
        message: 'x',
        error: _Exploding(),
      ),
    );
    sink.report(StateError('ok'), StackTrace.empty);
    await settle();
    sink.dispose();
    sink.report(StateError('after'), StackTrace.empty);
    expect(sink.pendingCount, 0);
  });

  test('helpers: platform, version, screen without ids', () {
    expect(CrashReports.platformName(isWeb: true), 'web');
    expect(
      CrashReports.platformName(isWeb: false, platform: TargetPlatform.iOS),
      'ios',
    );
    expect(
      CrashReports.platformName(isWeb: false, platform: TargetPlatform.android),
      'android',
    );
    expect(
      CrashReports.platformName(isWeb: false, platform: TargetPlatform.macOS),
      isNull,
    );
    expect(CrashReports.splitVersion('1.0.0+1'), (
      version: '1.0.0',
      build: '1',
    ));
    expect(CrashReports.splitVersion('dev'), (version: 'dev', build: null));
    expect(CrashReports.splitVersion('2.0.0+'), (
      version: '2.0.0',
      build: null,
    ));
    expect(CrashReports.cleanScreen('trip/0b9f3c2e-77aa?x=1'), 'trip/:id');
    expect(CrashReports.cleanScreen('driver-home'), 'driver-home');
    expect(CrashReports.cleanScreen(null), isNull);
    expect(CrashReports.cleanScreen('???'), isNull);
    expect(CrashReports.cleanScreen('z' * 200)!.length, 80);
  });
}

class _Exploding {
  @override
  String toString() => throw StateError('toString failed');
}
