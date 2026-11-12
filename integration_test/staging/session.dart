import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/main.dart';

import 'check_log.dart';
import 'driver_steps.dart';
import 'movera_api.dart';
import 'recording_client.dart';

/// Central Stockholm (zone Z001) unless the run names another point; the
/// same default as MainActivityTest's mock position.
const double defaultLat = 59.3326;
const double defaultLng = 18.0649;

String? tlEnv(String name) {
  final value = Platform.environment[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// The driver app on the phone, signed in with one test driver, and the
/// steps both device tests share: start, sign in, go online, ask the
/// server with the app's own session, go offline at the end.
///
/// (Moved out of staging_device_test.dart unchanged, so the trip
/// lifecycle test reuses it; the only addition is the API fallback in
/// [goOfflineAtEnd].)
class StagingSession {
  StagingSession(this.tester, this.log)
    : base = DriverRuntimeConfig.current.apiBaseUri,
      rec = RecordingClient(
        http.Client(),
        apiHost: DriverRuntimeConfig.current.apiBaseUri.host,
      ) {
    driverApi = MoveraApi(
      Uri(scheme: base.scheme, host: base.host, port: base.port),
      contractVersion: ApiClient.contractVersion,
      authorization: () => rec.authorization,
    );
  }

  final WidgetTester tester;
  final CheckLog log;
  final Uri base;
  final RecordingClient rec;

  /// The test's own calls with the app's session (never recorded).
  late final MoveraApi driverApi;

  final double lat =
      double.tryParse(tlEnv('MOVERA_TL_LAT') ?? '') ?? defaultLat;
  final double lng =
      double.tryParse(tlEnv('MOVERA_TL_LNG') ?? '') ?? defaultLng;

  bool online = false;

  /// The same start as lib/main.dart (language and phone country), with
  /// the recording client injected; the device's own GPS stack and token
  /// store are used.
  Future<void> start() async {
    try {
      await StartCountryHints.load().timeout(const Duration(seconds: 2));
    } catch (_) {}
    DriverLanguage.applyDevice(
      phoneLanguage: deviceLanguage(),
      startCountry: defaultPhoneCountry().iso,
    );
    DriverLanguage.followDevice(deviceLanguage);
    try {
      await DriverLanguage.restore().timeout(const Duration(seconds: 2));
    } catch (_) {}
    await tester.pumpWidget(MoveraApp(httpClient: rec));
    await tester.pump();
  }

  /// Runs [body]; an exception is a failure text, not a crash of the run.
  Future<String?> guard(Future<String?> Function() body) async {
    try {
      return await body();
    } catch (error) {
      return 'stopped by ${error.runtimeType}: $error';
    }
  }

  Iterable<RecordedCall> calls(String path, {String? method, int from = 0}) =>
      rec
          .since(from)
          .where(
            (c) => c.path == path && (method == null || c.method == method),
          );

  /// GET [path] with the app's own session, asked by the test itself.
  Future<(int, Object?)> ask(String path, [Map<String, String>? query]) async {
    if (rec.authorization == null) return (0, null);
    final answer = await driverApi.get(
      path,
      query: query,
      timeout: const Duration(seconds: 60),
    );
    return (answer.status, answer.body);
  }

  static String? statusOf(Object? answer) =>
      answer is Map ? answer['onlineStatus'] as String? : null;

  Future<void> goOnline() async {
    log.step('go online');
    final mark = rec.length;
    if (!await tapGoOnline(tester)) {
      log.fail('ONLINE', 'Go online is taken', 'no go-online control on Home');
      return;
    }
    bool taken() =>
        calls('/api/v1/driver/availability', method: 'POST', from: mark).any(
          (c) =>
              statusOf(c.answer) == 'online' || statusOf(c.answer) == 'on_trip',
        );
    bool refused() =>
        calls(
          '/api/v1/driver/availability',
          method: 'POST',
          from: mark,
        ).any((c) => c.failed) ||
        homeReasons().isNotEmpty;
    await pumpUntil(
      tester,
      () => taken() || refused(),
      timeout: const Duration(seconds: 120),
    );
    // A profile read that already says online also counts (no POST sent).
    final profileOnline = calls(
      '/api/v1/driver/profile',
      method: 'GET',
      from: mark,
    ).any((c) => statusOf(c.answer) == 'online');
    if (taken() || profileOnline) {
      online = true;
      log.pass('ONLINE', 'Go online is taken', 'server answered online');
      await wait(tester, const Duration(seconds: 2));
      await log.screenshot(tester, 'home-online');
      return;
    }
    final posts = calls(
      '/api/v1/driver/availability',
      method: 'POST',
      from: mark,
    ).toList();
    log.fail(
      'ONLINE',
      'Go online is taken',
      'availability calls=${posts.map((c) => c.status ?? c.error).toList()} '
          'home reasons=${homeReasons()} '
          '(no POST at all = the app had no fresh position: G24)',
    );
  }

  Future<void> goOfflineAtEnd() async {
    if (!online) {
      // Go online may have thrown or timed out after the tap while the
      // server did go online: ask the server, so the shared test driver is
      // never left online on staging.
      String? before;
      try {
        final (_, profile) = await ask('/api/v1/driver/profile');
        before = statusOf(profile);
      } catch (_) {
        before = null;
      }
      if (before != 'online' && before != 'on_trip') {
        log.skip(
          'OFFLINE',
          'Go offline is taken',
          'not online (server says ${before ?? 'unknown'})',
        );
        driverApi.close();
        return;
      }
    }
    log.step('go offline');
    await backToHome(tester);
    final mark = rec.length;
    final held = await goOffline(tester);
    await pumpUntil(
      tester,
      () => calls(
        '/api/v1/driver/availability',
        method: 'POST',
        from: mark,
      ).any((c) => c.status != null || c.error != null),
      timeout: const Duration(seconds: 60),
    );
    final (status, profile) = await ask('/api/v1/driver/profile');
    final now = statusOf(profile);
    if (held && status == 200 && now == 'offline') {
      log.pass('OFFLINE', 'Go offline is taken', 'server says offline');
      await log.screenshot(tester, 'home-offline-end');
    } else {
      // Never leave the shared test driver online: the API, then a FAIL
      // that says the app's own way did not work.
      final api = await _offlineByApi(profile);
      log.fail(
        'OFFLINE',
        'Go offline is taken',
        'hold+confirm=$held profile=$status onlineStatus=$now; '
            'offline through the API: $api',
      );
    }
    driverApi.close();
  }

  Future<String> _offlineByApi(Object? profile) async {
    if (statusOf(profile) == 'offline') return 'not needed';
    final version = profile is Map ? profile['version'] : null;
    if (version is! num) return 'no profile version';
    final answer = await driverApi.post('/api/v1/driver/availability', {
      'expectedVersion': version.toInt(),
      'onlineStatus': 'offline',
    });
    return answer.short;
  }
}
