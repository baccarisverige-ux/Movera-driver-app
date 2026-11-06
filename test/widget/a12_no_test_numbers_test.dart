import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';

/// Job A12 (owner 2026-11-05, "Remove everywhere"): the sign-in screen has
/// no "Test numbers" link, button or list in any build, and no build bakes
/// MOVERA_TEST_NUMBERS into the app.

const _words = ['Test numbers', 'Numéros de test', 'Testnummer'];

Iterable<File> _files(String dir, bool Function(String) keep) => Directory(
  dir,
).listSync(recursive: true).whereType<File>().where((f) => keep(f.path));

void main() {
  test('no app code or build reads MOVERA_TEST_NUMBERS', () {
    final hits = <String>[
      for (final f in [
        ..._files('lib', (p) => p.endsWith('.dart') || p.endsWith('.arb')),
        ..._files('.github/workflows', (p) => p.endsWith('.yml')),
      ])
        if (f.readAsStringSync().contains('MOVERA_TEST_NUMBERS=') ||
            f.readAsStringSync().contains(
              "fromEnvironment('MOVERA_TEST_NUMBERS')",
            ))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  test('no sign-in test-numbers text in any language', () {
    final hits = <String>[
      for (final f in _files(
        'lib',
        (p) => p.endsWith('.arb') || p.endsWith('.dart'),
      ))
        for (final w in [..._words, 'authTestNumbers', 'auth-test-numbers'])
          if (f.readAsStringSync().contains(w)) '${f.path}: $w',
    ];
    expect(hits, isEmpty);
  });

  testWidgets('the sign-in screen shows no test-numbers widget even when '
      'the server would list test accounts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryTokenStore();
    final api = ApiClient(
      client: MockClient(
        (request) async => request.url.path == '/api/v1/auth/test-accounts'
            ? http.Response(
                '{"accounts":[{"phone":"+46700000001","app":"driver",'
                '"status":"test"}]}',
                200,
                headers: {'content-type': 'application/json'},
              )
            : http.Response('{"code":"not_found"}', 404),
      ),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: store,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DriverSignIn(
          controller: AuthController(
            repository: AuthRepository(api: api, tokens: store),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    for (final w in _words) {
      expect(find.textContaining(w), findsNothing);
    }
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('auth-test-'),
      ),
      findsNothing,
    );
  });
}
