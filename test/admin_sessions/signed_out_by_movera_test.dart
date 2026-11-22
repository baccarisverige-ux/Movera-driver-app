import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/signed_out_notice.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';

/// Contract v0.18.149 `adminSessions.apps` (owner Rules decisions/driver-g12.md
/// Q6): an admin signed this phone out. The next call is 401 reason
/// `signed_out_by_movera`, so is the refresh; the app signs out through the
/// one existing path (tokens cleared, onSessionExpired) and Sign in shows
/// "You were signed out by Movera" once. A normal 401 / expired session
/// does not show it.

final _origin = Uri.parse('https://api.test.movera.se');

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

/// A call answered 401 (with [callReason]) whose refresh answers 401 with
/// [refreshReason]; returns how often the app was told the session ended.
Future<({int expired, MemoryTokenStore store})> _refused({
  String? callReason,
  String? refreshReason,
}) async {
  final store = MemoryTokenStore();
  await store.save(access: 'old', refresh: 'r1');
  var expired = 0;
  final api = ApiClient(
    client: MockClient((request) async {
      if (request.url.path == ApiClient.refreshPath) {
        return _json(401, {
          'code': 'unauthenticated',
          'message': 'Please sign in again.',
          if (refreshReason != null) 'reason': refreshReason,
        });
      }
      return _json(401, {
        'code': 'unauthenticated',
        'message': 'Please sign in again.',
        if (callReason != null) 'reason': callReason,
      });
    }),
    baseUri: _origin,
    tokens: store,
    onSessionExpired: () async => expired++,
  );
  await expectLater(
    api.get('/api/v1/driver/profile'),
    throwsA(isA<ApiError>()),
  );
  return (expired: expired, store: store);
}

void main() {
  setUp(() {
    DriverAppTexts.language = 'en';
    SignedOutNotice.clear();
  });

  test('a call and refresh refused signed_out_by_movera sign out once and '
      'say "by Movera"', () async {
    final result = await _refused(
      callReason: 'signed_out_by_movera',
      refreshReason: 'signed_out_by_movera',
    );
    expect(result.expired, 1);
    expect(await result.store.readAccess(), isNull);
    expect(await result.store.readRefresh(), isNull);
    expect(SignedOutNotice.kind.value, SignedOutNotice.byMovera);
    final signedOut = (_contract['auth'] as Map)['signedOut'] as Map;
    expect(signedOut['reasons']['signed_out_by_movera'], 'revoked');
    expect(SignedOutNotice.reasons, signedOut['reasons']);
  });

  test('a normal 401 or an expired session never says "by Movera"', () async {
    for (final reason in [null, 'session_expired', 'session_ended']) {
      SignedOutNotice.clear();
      final result = await _refused(refreshReason: reason);
      expect(result.expired, 1, reason: '$reason');
      expect(
        SignedOutNotice.kind.value,
        isNot(SignedOutNotice.byMovera),
        reason: '$reason',
      );
    }
    SignedOutNotice.clear();
    await _refused(refreshReason: 'session_expired');
    expect(SignedOutNotice.kind.value, SignedOutNotice.expired);
  });

  test('the words are the contract\'s byMoveraTexts in sv, fr, en', () {
    final texts =
        (_contract['auth'] as Map)['signedOut']['byMoveraTexts'] as Map;
    for (final lang in ['en', 'sv', 'fr']) {
      DriverAppTexts.language = lang;
      expect(tr.authSignedOutByMovera, texts[lang], reason: lang);
    }
    DriverAppTexts.language = 'en';
  });

  testWidgets('Sign in shows it once, with the revoked title; own Sign out '
      'and the next sign-in clear it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryTokenStore();
    final auth = AuthController(
      repository: AuthRepository(
        api: ApiClient(
          client: MockClient((_) async => _json(404, {})),
          baseUri: _origin,
          tokens: store,
        ),
        tokens: store,
      ),
    );
    SignedOutNotice.sessionRefused('signed_out_by_movera');
    await tester.pumpWidget(MaterialApp(home: DriverSignIn(controller: auth)));
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const ValueKey('auth-signed-out')), findsOneWidget);
    expect(find.text(tr.authSignedOutRevoked), findsOneWidget);
    expect(find.text('You were signed out by Movera'), findsOneWidget);
    expect(find.text(tr.authSignedOutDetailRevoked), findsNothing);
    await auth.signOut();
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-signed-out')), findsNothing);
    expect(find.text('You were signed out by Movera'), findsNothing);
  });
}
