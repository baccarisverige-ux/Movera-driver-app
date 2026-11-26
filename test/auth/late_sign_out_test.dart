import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';

/// Review #683 (SHOULD): the details screen stops waiting for a sign-out
/// after 8 s, but the sign-out keeps running. When the driver signs in
/// again meanwhile, the late sign-out must not clear the new session.
void main() {
  test(
    'a sign-out that ends after a newer sign-in keeps the new session',
    () async {
      final signOutAnswer = Completer<http.Response>();
      http.Response json(Map<String, Object?> map) => http.Response(
        jsonEncode(map),
        200,
        headers: {'content-type': 'application/json'},
      );
      final client = MockClient((request) async {
        switch (request.url.path) {
          case AuthRepository.signOutPath:
            return signOutAnswer.future;
          case AuthRepository.verifyPath:
            return json({
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
              'expiresIn': 900,
              'isNewDriver': false,
            });
        }
        return http.Response('{}', 404);
      });
      final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'old-r');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      final late = repository.signOut();
      await Future<void>.delayed(Duration.zero);
      await repository.verify('+46701234567', 'otp-1', '1234');
      expect(await tokens.readAccess(), 'new-access');
      signOutAnswer.complete(json({}));
      await late;
      expect(await tokens.readAccess(), 'new-access');
      expect(await tokens.readRefresh(), 'new-refresh');
    },
  );

  test('a normal sign-out still clears the tokens', () async {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final repository = AuthRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      tokens: tokens,
    );
    await repository.signOut();
    expect(await tokens.readAccess(), isNull);
  });

  test(
    'the controller leaves a newer sign-in alone (no signed-out hook)',
    () async {
      final signOutAnswer = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path == AuthRepository.signOutPath) {
          return signOutAnswer.future;
        }
        return http.Response(
          jsonEncode({'accessToken': 'n', 'refreshToken': 'nr'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final tokens = MemoryTokenStore()..save(access: 'o', refresh: 'or');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      var signedOut = 0;
      final controller = AuthController(
        repository: repository,
        onSignedOut: () => signedOut++,
      );
      final late = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      await repository.verify('+46701234567', 'otp-1', '1234');
      controller.signedInPhone = '+46701234567';
      signOutAnswer.complete(http.Response('{}', 200));
      await late;
      expect(signedOut, 0);
      expect(controller.signedInPhone, '+46701234567');
      expect(await tokens.readAccess(), 'n');
    },
  );

  test(
    'a late sign-out with an expired token never spends the new refresh token',
    () async {
      final signOutAnswer = Completer<http.Response>();
      final refreshTokensSent = <Object?>[];
      final client = MockClient((request) async {
        switch (request.url.path) {
          case AuthRepository.signOutPath:
            return signOutAnswer.future;
          case ApiClient.refreshPath:
            refreshTokensSent.add(
              (jsonDecode(request.body) as Map)['refreshToken'],
            );
            return http.Response(
              jsonEncode({'accessToken': 'x', 'refreshToken': 'xr'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          case AuthRepository.verifyPath:
            return http.Response(
              jsonEncode({'accessToken': 'n', 'refreshToken': 'nr'}),
              200,
              headers: {'content-type': 'application/json'},
            );
        }
        return http.Response('{}', 404);
      });
      final tokens = MemoryTokenStore()..save(access: 'o', refresh: 'or');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      final late = repository.signOut();
      await Future<void>.delayed(Duration.zero);
      await repository.verify('+46701234567', 'otp-1', '1234');
      signOutAnswer.complete(http.Response('{}', 401));
      await late;
      expect(refreshTokensSent, isNot(contains('nr')));
      expect(await tokens.readAccess(), 'n');
      expect(await tokens.readRefresh(), 'nr');
    },
  );

  test(
    'an expired token of the same session is renewed, then signed out',
    () async {
      final seen = <String?>[];
      final client = MockClient((request) async {
        if (request.url.path == ApiClient.refreshPath) {
          return http.Response(
            jsonEncode({'accessToken': 'fresh', 'refreshToken': 'fr'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        seen.add(request.headers['Authorization']);
        return request.headers['Authorization'] == 'Bearer fresh'
            ? http.Response('{}', 200)
            : http.Response('{}', 401);
      });
      final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'r');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      await repository.signOut();
      expect(seen.last, 'Bearer fresh');
      expect(await tokens.readAccess(), isNull);
    },
  );

  test(
    'a sign-in that lands during the renewal keeps its tokens and session',
    () async {
      final refreshAnswer = Completer<http.Response>();
      final signOutBearers = <String?>[];
      final client = MockClient((request) async {
        switch (request.url.path) {
          case AuthRepository.signOutPath:
            signOutBearers.add(request.headers['Authorization']);
            return request.headers['Authorization'] == 'Bearer o2'
                ? http.Response('{}', 200)
                : http.Response('{}', 401);
          case ApiClient.refreshPath:
            return refreshAnswer.future;
          case AuthRepository.verifyPath:
            return http.Response(
              jsonEncode({'accessToken': 'n', 'refreshToken': 'nr'}),
              200,
              headers: {'content-type': 'application/json'},
            );
        }
        return http.Response('{}', 404);
      });
      final tokens = MemoryTokenStore()..save(access: 'o', refresh: 'or');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      final late = repository.signOut();
      for (var i = 0; i < 20 && !refreshAnswer.isCompleted; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await repository.verify('+46701234567', 'otp-1', '1234');
      refreshAnswer.complete(
        http.Response(
          jsonEncode({'accessToken': 'o2', 'refreshToken': 'or2'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await late;
      expect(signOutBearers, isNot(contains('Bearer n')));
      expect(signOutBearers.last, 'Bearer o2');
      expect(await tokens.readAccess(), 'n');
      expect(await tokens.readRefresh(), 'nr');
    },
  );

  test(
    '401, renewal, then 409 on a trip: SignOutOnTrip and the renewed pair kept',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == ApiClient.refreshPath) {
          return http.Response(
            jsonEncode({'accessToken': 'o2', 'refreshToken': 'or2'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.headers['Authorization'] == 'Bearer o2') {
          return http.Response(
            jsonEncode({
              'error': 'conflict',
              'reason': 'sign_out_on_trip',
              'message': 'Finish the trip first.',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 401);
      });
      final tokens = MemoryTokenStore()..save(access: 'o', refresh: 'or');
      final repository = AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        tokens: tokens,
      );
      await expectLater(repository.signOut(), throwsA(isA<SignOutOnTrip>()));
      expect(await tokens.readAccess(), 'o2');
      expect(await tokens.readRefresh(), 'or2');
    },
  );
}
