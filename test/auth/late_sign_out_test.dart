import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
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
}
