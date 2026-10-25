import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';

/// Round 4 sign-in: the driver app's API client sends the contract's
/// headers, maps error answers to [ApiError], and renews the session once
/// on a 401.
void main() {
  final base = Uri.parse('https://api.test.movera.se');

  http.Response json(
    int status,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...?headers},
  );

  test('every request carries the bearer token, the API version and a '
      'request id; POST and PATCH an Idempotency-Key', () async {
    final seen = <http.Request>[];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final api = ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        return json(200, {'ok': true});
      }),
      baseUri: base,
      tokens: tokens,
      requestId: () => 'req-1',
      idempotencyKey: () => 'idem-1',
    );
    await api.get('/api/v1/driver/me');
    await api.post('/api/v1/driver/online', body: {'on': true});
    await api.patch('/api/v1/driver/me', body: {'name': 'x'});
    expect(seen.map((r) => r.url.toString()), [
      'https://api.test.movera.se/api/v1/driver/me',
      'https://api.test.movera.se/api/v1/driver/online',
      'https://api.test.movera.se/api/v1/driver/me',
    ]);
    for (final request in seen) {
      expect(request.headers['Authorization'], 'Bearer a1');
      expect(request.headers['X-Api-Version'], '0.5');
      expect(request.headers['X-Request-Id'], 'req-1');
      expect(request.headers['Accept'], 'application/json');
    }
    expect(seen[0].headers.containsKey('Idempotency-Key'), isFalse);
    expect(seen[1].headers['Idempotency-Key'], 'idem-1');
    expect(seen[2].headers['Idempotency-Key'], 'idem-1');
    expect(jsonDecode(seen[1].body), {'on': true});
  });

  test('an unauthenticated call sends no bearer token', () async {
    http.Request? seen;
    final tokens = MemoryTokenStore()..save(access: 'stale', refresh: 'r1');
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return json(200, {'sessionId': 's'});
      }),
      baseUri: base,
      tokens: tokens,
    );
    await api.post(
      '/api/v1/auth/otp/request',
      body: {'phone': '+46701234567', 'app': 'driver'},
      authenticated: false,
    );
    expect(seen!.headers.containsKey('Authorization'), isFalse);
    expect(seen!.headers['Idempotency-Key'], hasLength(32));
  });

  group('error mapping', () {
    ApiClient client(http.Response response) => ApiClient(
      client: MockClient((_) async => response),
      baseUri: base,
      tokens: MemoryTokenStore(),
      requestId: () => 'req-9',
    );

    test('400 invalid_request with reason invalid_otp_code', () async {
      final api = client(
        json(400, {
          'code': 'invalid_request',
          'message': 'Wrong code',
          'reason': 'invalid_otp_code',
        }),
      );
      final error = await api
          .post('/api/v1/auth/otp/verify', authenticated: false)
          .then<Object>((_) => 'no error', onError: (Object e) => e);
      expect(error, isA<ApiError>());
      final apiError = error as ApiError;
      expect(apiError.code, 'invalid_request');
      expect(apiError.reason, 'invalid_otp_code');
      expect(apiError.detail, 'invalid_otp_code');
      expect(apiError.message, 'Wrong code');
      expect(apiError.statusCode, 400);
      expect(apiError.requestId, 'req-9');
    });

    test('410 otp_expired and 403 sign_in_restricted', () async {
      final expired =
          await client(json(410, {'code': 'otp_expired', 'message': 'Expired'}))
                  .post('/x', authenticated: false)
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(expired.statusCode, 410);
      expect(expired.detail, 'otp_expired');
      final restricted =
          await client(
                    json(403, {
                      'code': 'forbidden',
                      'message': 'Not on the list',
                      'reason': 'sign_in_restricted',
                    }),
                  )
                  .post('/x', authenticated: false)
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(restricted.isForbidden, isTrue);
      expect(restricted.detail, 'sign_in_restricted');
    });

    test('429 keeps the Retry-After wait', () async {
      final error =
          await client(
                    json(
                      429,
                      {'code': 'rate_limited', 'message': 'Slow down'},
                      headers: {'retry-after': '45'},
                    ),
                  )
                  .post('/x', authenticated: false)
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(error.statusCode, 429);
      expect(error.retryAfter, const Duration(seconds: 45));
      expect(error.isRetryable, isTrue);
    });

    test('a non-JSON error body keeps the status', () async {
      final error =
          await client(http.Response('<html>bad gateway</html>', 502))
                  .get('/x')
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(error.statusCode, 502);
      expect(error.code, 'http_502');
      expect(error.requestId, 'req-9');
    });

    test('no connection is a NETWORK error', () async {
      final api = ApiClient(
        client: MockClient((_) async => throw http.ClientException('down')),
        baseUri: base,
        tokens: MemoryTokenStore(),
      );
      final error =
          await api
                  .get('/x')
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(error.code, ApiError.network);
      expect(error.neverReachedServer, isTrue);
    });

    test('an answer that never comes is a TIMEOUT error', () async {
      final api = ApiClient(
        client: MockClient(
          (_) =>
              Future.delayed(const Duration(seconds: 5), () => json(200, {})),
        ),
        baseUri: base,
        tokens: MemoryTokenStore(),
        timeout: const Duration(milliseconds: 50),
      );
      final error =
          await api
                  .get('/x')
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(error.code, ApiError.timeout);
    });
  });

  group('refresh on 401', () {
    test(
      'a 401 renews the session once and retries with the new token',
      () async {
        final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'r1');
        final calls = <String>[];
        final api = ApiClient(
          client: MockClient((request) async {
            calls.add(
              '${request.method} ${request.url.path} '
              '${request.headers['Authorization']}',
            );
            if (request.url.path == ApiClient.refreshPath) {
              expect(jsonDecode(request.body), {'refreshToken': 'r1'});
              return json(200, {'accessToken': 'new', 'refreshToken': 'r2'});
            }
            if (request.headers['Authorization'] == 'Bearer old') {
              return json(401, {'code': 'unauthenticated', 'message': 'x'});
            }
            return json(200, {'me': true});
          }),
          baseUri: base,
          tokens: tokens,
        );
        final result = await api.get('/api/v1/driver/me');
        expect(result, {'me': true});
        expect(calls, [
          'GET /api/v1/driver/me Bearer old',
          'POST /api/v1/auth/refresh null',
          'GET /api/v1/driver/me Bearer new',
        ]);
        expect(await tokens.readAccess(), 'new');
        expect(await tokens.readRefresh(), 'r2');
      },
    );

    for (final status in [400, 401, 403]) {
      test('a $status from the refresh ends the session', () async {
        final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'r1');
        var expired = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            if (request.url.path == ApiClient.refreshPath) {
              return json(status, {'code': 'unauthenticated', 'message': 'x'});
            }
            return json(401, {'code': 'unauthenticated', 'message': 'x'});
          }),
          baseUri: base,
          tokens: tokens,
          onSessionExpired: () async => expired++,
        );
        final error = await api
            .get('/api/v1/driver/me')
            .then<Object>((_) => 'no error', onError: (Object e) => e);
        expect(error, isA<ApiError>());
        expect((error as ApiError).statusCode, 401);
        expect(expired, 1);
        expect(await tokens.readAccess(), isNull);
        expect(await tokens.readRefresh(), isNull);
      });
    }

    test('a refresh that cannot answer keeps the tokens and reports a '
        'network error', () async {
      final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'r1');
      var expired = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == ApiClient.refreshPath) {
            return http.Response('', 503);
          }
          return json(401, {'code': 'unauthenticated', 'message': 'x'});
        }),
        baseUri: base,
        tokens: tokens,
        onSessionExpired: () async => expired++,
      );
      final error =
          await api
                  .get('/api/v1/driver/me')
                  .then<Object>((_) => 'no error', onError: (Object e) => e)
              as ApiError;
      expect(error.code, ApiError.network);
      expect(expired, 0);
      expect(await tokens.readAccess(), 'old');
      expect(await tokens.readRefresh(), 'r1');
    });

    test(
      'a 401 on an unauthenticated sign-in call is a plain refusal',
      () async {
        final tokens = MemoryTokenStore()..save(access: 'stale', refresh: 'r1');
        var refreshes = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            if (request.url.path == ApiClient.refreshPath) refreshes++;
            return json(401, {'code': 'unauthenticated', 'message': 'wrong'});
          }),
          baseUri: base,
          tokens: tokens,
        );
        final error =
            await api
                    .post('/api/v1/auth/otp/verify', authenticated: false)
                    .then<Object>((_) => 'no error', onError: (Object e) => e)
                as ApiError;
        expect(error.statusCode, 401);
        expect(refreshes, 0);
        expect(await tokens.readRefresh(), 'r1');
      },
    );

    test('concurrent 401s share one refresh', () async {
      final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'r1');
      var refreshes = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == ApiClient.refreshPath) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return json(200, {'accessToken': 'new', 'refreshToken': 'r2'});
          }
          if (request.headers['Authorization'] == 'Bearer old') {
            return json(401, {'code': 'unauthenticated', 'message': 'x'});
          }
          return json(200, {'ok': true});
        }),
        baseUri: base,
        tokens: tokens,
      );
      final results = await Future.wait([api.get('/a'), api.get('/b')]);
      expect(results, [
        {'ok': true},
        {'ok': true},
      ]);
      expect(refreshes, 1);
    });
  });
}
