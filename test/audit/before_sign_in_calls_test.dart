import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phase5/live_fixture.dart';

/// Contract v0.18.2 `auth.beforeSignIn` (owner 2026-10-30, "Yes, stop it
/// (Recommended)"): measured on live, the sign-in screen with no session
/// asked `GET /driver/config` about 22 times a minute and
/// `/driver/config/stream` 11 times, plus `/driver/zones` and
/// `/driver/content`, all answered 401. Without a stored session the app
/// may only call what needs no bearer token; the signed-in calls start
/// right after sign-in, and a 401 is never retried in a loop.
void main() {
  late List<http.BaseRequest> requests;

  http.Client server() => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/auth/test-accounts')) {
      return http.Response(
        jsonEncode({'accounts': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({'code': 'unauthorized', 'message': 'no session'}),
      401,
      headers: {'content-type': 'application/json'},
    );
  });

  /// `contract.json#auth.beforeSignIn.allowed`, as request paths.
  const allowed = <String>{
    '/api/v1/auth/otp/request',
    '/api/v1/auth/otp/verify',
    '/api/v1/auth/provider',
    '/api/v1/auth/waitlist',
    '/api/v1/auth/test-accounts',
    '/api/v1/telemetry/logs',
    '/api/v1/telemetry/analytics',
    '/api/v1/telemetry/crashes',
  };

  setUp(() {
    requests = [];
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a live build on the sign-in screen with no session makes '
      'no signed-in calls for a whole minute', (tester) async {
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      authRequired: true,
      apiBaseUrl: 'https://api.test.movera.se',
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = server();
    await tester.pumpWidget(
      MoveraApp(
        tokenStore: MemoryTokenStore(),
        httpClient: client,
        locationRepository: FixedGps(),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(DriverSignIn), findsOneWidget);
    final signedIn = [
      for (final request in requests)
        if (!allowed.contains(request.url.path))
          '${request.method} ${request.url.path}',
    ];
    expect(signedIn, isEmpty);
    expect(
      requests.where((r) => r.headers.containsKey('Authorization')),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    LiveDriverServices.instance = null;
  });

  test('a 401 on the settings stream is not retried in a loop', () async {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final calls = <String>[];
    final client = MockClient.streaming((request, _) async {
      calls.add(request.url.path);
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 401);
    });
    final config = LiveDriverConfig(
      client: client,
      apiBase: Uri.parse('https://api.test.movera.se/api/v1'),
      accessToken: tokens.readAccess,
      renewSession: () async {},
      cache: MemoryDriverConfigCache(),
      retryAfter: const Duration(milliseconds: 10),
    );
    addTearDown(config.dispose);
    await config.start();
    await config.watch();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // One read and one stream (each with its one renewal retry at most);
    // nothing every 10 ms after that.
    expect(calls.length, lessThanOrEqualTo(4));
  });

  test('no access token: the settings are not asked for at all', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(request.url.path);
      return http.Response('{}', 401);
    });
    final config = LiveDriverConfig(
      client: client,
      apiBase: Uri.parse('https://api.test.movera.se/api/v1'),
      accessToken: () async => null,
      cache: MemoryDriverConfigCache(),
      retryAfter: const Duration(milliseconds: 10),
    );
    addTearDown(config.dispose);
    await config.start();
    unawaited(config.watch());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(calls, isEmpty);
  });

  test(
    'a 401 is not sent as an error report; other errors still are',
    () async {
      final sent = <String>[];
      final sink = CrashReportSink(
        baseUri: Uri.parse('https://api.test.movera.se'),
        client: MockClient((request) async {
          sent.add(request.body);
          return http.Response('', 202);
        }),
      );
      addTearDown(sink.dispose);
      DriverLogRecord record(Object error) => DriverLogRecord(
        level: DriverLogLevel.error,
        name: 'live',
        message: 'refused',
        error: error,
        stack: StackTrace.empty,
      );
      sink(
        record(
          const ApiError(
            code: 'unauthorized',
            message: 'no session',
            statusCode: 401,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sent, isEmpty);
      sink(record(StateError('a real fault')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sent, hasLength(1));
    },
  );

  test(
    'the signed-in calls start right after the sign-in, not before',
    () async {
      final tokens = MemoryTokenStore();
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({'code': 'unavailable', 'message': 'x'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      });
      final origin = Uri.parse('https://api.test.movera.se');
      final live = LiveDriverServices(
        client: client,
        origin: origin,
        tokens: tokens,
        api: ApiClient(client: client, baseUri: origin, tokens: tokens),
        location: FixedGps(),
        locationEvery: const Duration(hours: 1),
      );
      final session = DriverSessionController(
        repository: MemoryDriverSessionRepository(),
      );
      addTearDown(() async {
        await live.dispose();
        session.dispose();
      });
      live.attach(session);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(paths, isEmpty);

      await tokens.save(access: 'a', refresh: 'r');
      live.signedIn();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(paths, contains('/api/v1/driver/zones'));
      expect(paths, contains('/api/v1/driver/config'));
      live.signedOut();
    },
  );
}
