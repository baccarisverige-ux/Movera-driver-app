import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/auth/driver_sign_out.dart';

/// S8 (2026-11-07): server #112 (owner Q8 "Server refuses too") answers
/// POST /auth/sign-out with 409 sign_out_on_trip while the driver has a
/// current trip, and keeps the session, push devices and trip. The driver
/// app still clears its tokens whatever the answer, so the phone is signed
/// out while the server says it is not (pushes still go to this device).
void main() {
  test(
    'a 409 sign_out_on_trip keeps the driver signed in on the phone',
    () async {
      final tokens = MemoryTokenStore()..save(access: 'acc', refresh: 'ref');
      final api = ApiClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': 'conflict',
              'reason': 'sign_out_on_trip',
              'message': 'Finish the trip first.',
            }),
            409,
            headers: {'content-type': 'application/json'},
          ),
        ),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      Object? thrown;
      try {
        await AuthRepository(api: api, tokens: tokens).signOut();
      } catch (error) {
        thrown = error;
      }
      expect(
        await tokens.readRefresh(),
        'ref',
        reason: 'tokens cleared after the server refused (thrown: $thrown)',
      );
    },
  );

  ApiClient api409(TokenStore tokens) => ApiClient(
    client: MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error': 'conflict',
          'reason': 'sign_out_on_trip',
          'message': 'Terminez d’abord la course.',
        }),
        409,
        headers: {'content-type': 'application/json'},
      ),
    ),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );

  test(
    'the refusal is thrown as SignOutOnTrip (the app can say why)',
    () async {
      final tokens = MemoryTokenStore()..save(access: 'acc', refresh: 'ref');
      await expectLater(
        AuthRepository(api: api409(tokens), tokens: tokens).signOut(),
        throwsA(isA<SignOutOnTrip>()),
      );
    },
  );

  test('any other answer still signs this phone out', () async {
    final tokens = MemoryTokenStore()..save(access: 'acc', refresh: 'ref');
    final api = ApiClient(
      client: MockClient((request) async => http.Response('', 503)),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    await AuthRepository(api: api, tokens: tokens).signOut();
    expect(await tokens.readRefresh(), isNull);
  });

  testWidgets('Log out refused for a current trip: « Terminez d’abord la '
      'course. », still signed in, back on Home', (tester) async {
    final session = DriverSessionController();
    var signInShown = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DriverRuntimeScope(
          session: session,
          homeBuilder: () => const Text('home'),
          signInBuilder: () {
            signInShown = true;
            return const Text('sign in');
          },
          logout: () async =>
              throw const SignOutOnTrip('Finish the trip first.'),
          child: child!,
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );
    final home = tester.element(find.text('home'));
    Navigator.of(home).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => signOutDriver(context),
            child: const Text('Log out'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text(tr.fleetOnTrip), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(signInShown, isFalse);
    session.dispose();
  });
}
