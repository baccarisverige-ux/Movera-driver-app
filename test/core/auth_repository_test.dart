import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';

/// Round 4 sign-in: the phone code endpoints, the saved session and the
/// local sign-out.
void main() {
  final base = Uri.parse('https://api.test.movera.se');

  http.Response json(int status, Map<String, Object?> body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('requestCode posts the phone for the driver app and reads the '
      'challenge', () async {
    http.Request? seen;
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return json(200, {
          'sessionId': 'otp-7',
          'expiresAt': '2030-01-01T10:00:00Z',
          'retryAfterSeconds': 30,
        });
      }),
      baseUri: base,
      tokens: MemoryTokenStore(),
    );
    final repo = AuthRepository(api: api, tokens: MemoryTokenStore());
    final challenge = await repo.requestCode('+46 70 123 45 67');
    expect(seen!.url.path, AuthRepository.requestPath);
    expect(jsonDecode(seen!.body), {'phone': '+46701234567', 'app': 'driver'});
    expect(seen!.headers.containsKey('Authorization'), isFalse);
    expect(challenge.phone, '+46701234567');
    expect(challenge.sessionId, 'otp-7');
    expect(challenge.retryAfter, const Duration(seconds: 30));
    expect(challenge.expiresAt, DateTime.utc(2030, 1, 1, 10));
  });

  test('verify saves both tokens only after the server accepts the code '
      'and reports a new driver', () async {
    final tokens = MemoryTokenStore();
    http.Request? seen;
    final api = ApiClient(
      client: MockClient((request) async {
        seen = request;
        return json(200, {
          'accessToken': 'acc',
          'refreshToken': 'ref',
          'expiresIn': 900,
          'actor': {'id': 'drv_1', 'role': 'driver'},
          'isNewDriver': true,
        });
      }),
      baseUri: base,
      tokens: tokens,
    );
    final controller = AuthController(
      repository: AuthRepository(api: api, tokens: tokens),
    );
    final challenge = await () async {
      final repoApi = ApiClient(
        client: MockClient(
          (_) async => json(200, {
            'sessionId': 'otp-7',
            'expiresAt': '2030-01-01T10:00:00Z',
            'retryAfterSeconds': 30,
          }),
        ),
        baseUri: base,
        tokens: tokens,
      );
      return AuthRepository(
        api: repoApi,
        tokens: tokens,
      ).requestCode('+46701234567');
    }();
    expect(await controller.hasSession(), isFalse);
    final result = await controller.verify(challenge: challenge, code: '1234');
    expect(jsonDecode(seen!.body), {
      'phone': '+46701234567',
      'sessionId': 'otp-7',
      'code': '1234',
    });
    expect(result.isNewDriver, isTrue);
    expect(result.actor, {'id': 'drv_1', 'role': 'driver'});
    expect(result.expiresIn, const Duration(minutes: 15));
    expect(controller.signInResult, same(result));
    expect(await tokens.readAccess(), 'acc');
    expect(await tokens.readRefresh(), 'ref');
    expect(await controller.hasSession(), isTrue);
  });

  test('a refused code saves nothing', () async {
    final tokens = MemoryTokenStore();
    final api = ApiClient(
      client: MockClient(
        (_) async => json(400, {
          'code': 'invalid_request',
          'message': 'x',
          'reason': 'invalid_otp_code',
        }),
      ),
      baseUri: base,
      tokens: tokens,
    );
    final repo = AuthRepository(api: api, tokens: tokens);
    await expectLater(
      repo.verify('+46701234567', 'otp-7', '0000'),
      throwsA(
        isA<ApiError>().having((e) => e.detail, 'detail', 'invalid_otp_code'),
      ),
    );
    expect(await tokens.readAccess(), isNull);
  });

  test('signOut posts while the token is there and clears the tokens even '
      'when the server cannot be reached', () async {
    final tokens = MemoryTokenStore()..save(access: 'acc', refresh: 'ref');
    final calls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        calls.add('${request.url.path} ${request.headers['Authorization']}');
        throw http.ClientException('offline');
      }),
      baseUri: base,
      tokens: tokens,
    );
    await AuthRepository(api: api, tokens: tokens).signOut();
    expect(calls, ['${AuthRepository.signOutPath} Bearer acc']);
    expect(await tokens.readAccess(), isNull);
    expect(await tokens.readRefresh(), isNull);
  });

  test('signOut without a session sends nothing (the demo logout)', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return json(200, {});
      }),
      baseUri: Uri.parse(''),
      tokens: MemoryTokenStore(),
    );
    await AuthRepository(api: api, tokens: MemoryTokenStore()).signOut();
    expect(calls, 0);
  });
}
