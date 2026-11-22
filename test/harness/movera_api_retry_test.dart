import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../integration_test/staging/movera_api.dart';

/// Run 47: `RIDER-SIGN-IN ... code request 0 _ClientSocketException`. The
/// helper's first HTTP call threw once and the whole device run failed.
/// The seam is the `http.Client? client` the helper already takes.
http.Response _json(int status, Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);

const _noWait = <Duration>[Duration.zero, Duration.zero];

void main() {
  test('sign-in survives one socket error on the first call', () async {
    final calls = <String>[];
    final keys = <String?>[];
    final retries = <String>[];
    final client = MockClient((request) async {
      calls.add(request.url.path);
      keys.add(request.headers['Idempotency-Key']);
      if (calls.length == 1) {
        throw const SocketException('Connection reset by peer');
      }
      if (request.url.path.endsWith('/otp/request')) {
        return _json(200, {'sessionId': 'ses_1'});
      }
      return _json(200, {'accessToken': 'tok'});
    });
    final api = MoveraApi(
      Uri.parse('https://staging.invalid'),
      client: client,
      retryDelays: _noWait,
      onRetry: retries.add,
    );

    final error = await api.signIn(phone: 'p', code: 'c', app: 'rider');

    // ignore: avoid_print
    print(
      'HELPER-RETRY sign-in result: ${error ?? 'signed in'}; calls: $calls',
    );
    expect(error, isNull);
    expect(api.signedIn, isTrue);
    expect(calls, [
      '/api/v1/auth/otp/request',
      '/api/v1/auth/otp/request',
      '/api/v1/auth/otp/verify',
    ]);
    // The repeated write carries the first try's Idempotency-Key.
    expect(keys[0], isNotNull);
    expect(keys[1], keys[0]);
    expect(keys[2], isNot(keys[0]));
    // One log line per retry; nothing secret in it.
    expect(retries, [
      'API-RETRY POST /api/v1/auth/otp/request: no answer (SocketException), '
          'try 2 of 3',
    ]);
  });

  test('the default client error (ClientException) is retried too', () async {
    var calls = 0;
    final api = MoveraApi(
      Uri.parse('https://staging.invalid'),
      client: MockClient((request) async {
        if (++calls == 1) throw http.ClientException('Connection failed');
        return _json(200, {'ok': true});
      }),
      retryDelays: _noWait,
      onRetry: (_) {},
    );
    expect((await api.get('/api/v1/rider/config')).status, 200);
    expect(calls, 2);
  });

  test('three socket errors: the step fails with the socket error', () async {
    var calls = 0;
    final retries = <String>[];
    final api = MoveraApi(
      Uri.parse('https://staging.invalid'),
      client: MockClient((request) async {
        calls++;
        throw const SocketException('Connection reset by peer');
      }),
      retryDelays: _noWait,
      onRetry: retries.add,
    );

    final error = await api.signIn(phone: 'p', code: 'c', app: 'rider');

    // ignore: avoid_print
    print('HELPER-RETRY 3 throws: $error; calls: $calls');
    expect(error, 'code request 0 SocketException');
    expect(calls, 3);
    expect(retries, hasLength(2));
    expect(api.signedIn, isFalse);
  });

  test('a real answer is never retried: 429, 500, 409', () async {
    for (final status in [429, 500, 409]) {
      var calls = 0;
      final retries = <String>[];
      final api = MoveraApi(
        Uri.parse('https://staging.invalid'),
        client: MockClient((request) async {
          calls++;
          return _json(status, {'reason': 'nope'});
        }),
        retryDelays: _noWait,
        onRetry: retries.add,
      );

      final error = await api.signIn(phone: 'p', code: 'c', app: 'rider');
      final read = await api.get('/api/v1/rider/config');

      // ignore: avoid_print
      print('HELPER-RETRY $status: $error; calls: $calls');
      expect(error, 'code request $status nope');
      expect(read.status, status);
      expect(calls, 2, reason: 'one POST and one GET, each sent once');
      expect(retries, isEmpty);
    }
  });

  test('a timeout is never retried', () async {
    var calls = 0;
    final retries = <String>[];
    final api = MoveraApi(
      Uri.parse('https://staging.invalid'),
      client: MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json(200, {});
      }),
      retryDelays: _noWait,
      onRetry: retries.add,
    );

    final answer = await api.post(
      '/api/v1/trips',
      null,
      const Duration(milliseconds: 20),
    );

    expect(answer.short, '0 TimeoutException');
    expect(calls, 1);
    expect(retries, isEmpty);
  });
}
