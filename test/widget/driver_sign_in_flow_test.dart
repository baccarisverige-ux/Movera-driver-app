import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/provider_token_source.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';

/// Round 4: the driver sign-in against a fake server, from the phone to
/// Home.
class _FakeAuthServer {
  _FakeAuthServer({
    this.retryAfterSeconds = 30,
    this.provider = _Provider.linked,
  });

  /// The one code the server accepts.
  static const acceptedCode = '1234';
  final int retryAfterSeconds;

  /// How `POST /auth/provider` answers (round 4b).
  final _Provider provider;
  final List<http.Request> requests = [];
  int codesSent = 0;

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    http.Response json(int status, Map<String, Object?> map) => http.Response(
      jsonEncode(map),
      status,
      headers: {'content-type': 'application/json'},
    );
    switch (request.url.path) {
      case AuthRepository.requestPath:
        codesSent++;
        return json(200, {
          'sessionId': 'otp-$codesSent',
          'expiresAt': '2030-01-01T10:00:00Z',
          'retryAfterSeconds': retryAfterSeconds,
        });
      case AuthRepository.providerPath:
        return switch (provider) {
          _Provider.notConfigured => json(503, {
            'code': 'unavailable',
            'message': 'Sign-in with Google is coming soon.',
            'reason': 'provider_not_configured',
          }),
          _Provider.phoneRequired => json(200, {
            'code': 'PHONE_REQUIRED',
            'linkToken': 'lt_abc',
            'firstName': 'Lina',
            'lastName': 'Berg',
            'email': 'lina.berg@gmail.com',
          }),
          _Provider.linked => json(200, {
            'accessToken': 'acc-p',
            'refreshToken': 'ref-p',
            'expiresIn': 900,
            'actor': 'driver',
            'isNewDriver': false,
          }),
        };
      case AuthRepository.verifyPath:
        if (body['code'] != acceptedCode) {
          return json(400, {
            'code': 'invalid_request',
            'message': 'Wrong code',
            'reason': 'invalid_otp_code',
          });
        }
        return json(200, {
          'accessToken': 'acc-1',
          'refreshToken': 'ref-1',
          'expiresIn': 900,
          'actor': {'id': 'drv_1', 'role': 'driver'},
          'isNewDriver': false,
        });
    }
    return json(404, {'code': 'not_found', 'message': 'x'});
  });
}

enum _Provider { linked, phoneRequired, notConfigured }

/// The provider SDK, scripted: a token, or the sheet closed.
class _FakeTokens implements ProviderTokenSource {
  _FakeTokens({this.cancel = false});
  final bool cancel;
  final List<String> asked = [];

  @override
  Future<ProviderIdentityToken?> obtain(String provider) async {
    asked.add(provider);
    if (cancel) return null;
    return ProviderIdentityToken(
      provider: provider,
      idToken: 'id-token-$provider',
      name: provider == 'apple' ? 'Lina Berg' : null,
    );
  }
}

Future<AuthController> _pumpSignIn(
  WidgetTester tester,
  _FakeAuthServer server,
  MemoryTokenStore tokens, {
  ProviderTokenSource? providerTokens,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(
    client: server.client,
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );
  final auth = AuthController(
    repository: AuthRepository(api: api, tokens: tokens),
    providerTokens: providerTokens ?? _FakeTokens(),
  );
  await tester.pumpWidget(
    DriverRuntimeScope(
      session: DriverSessionController(),
      homeBuilder: () => const Scaffold(body: Text('Driver home')),
      auth: auth,
      signInBuilder: () => DriverSignIn(controller: auth),
      child: MaterialApp(home: DriverSignIn(controller: auth)),
    ),
  );
  // The brand intro plays for 5.2 s; the form is usable meanwhile.
  await tester.pump(const Duration(seconds: 6));
  return auth;
}

/// Taps the consent box itself (the line's words open the legal pages).
Future<void> _tickConsent(WidgetTester tester) async {
  final consent = find.byKey(const ValueKey('auth-consent'));
  await tester.tapAt(tester.getTopLeft(consent) + const Offset(12, 12));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Phone typed, consent ticked (unless already), Continue: on the code screen.
Future<void> _toCodeScreen(
  WidgetTester tester, {
  bool tickConsent = true,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('auth-phone-field')),
    '070 123 45 67',
  );
  if (tickConsent) await _tickConsent(tester);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('auth-continue')));
  await _settle(tester);
  expect(find.byType(DriverPhoneVerification), findsOneWidget);
}

void main() {
  testWidgets('the Driver word sits under the wordmark, Apple and Google '
      'under the phone form (round 4b)', (tester) async {
    await _pumpSignIn(tester, _FakeAuthServer(), MemoryTokenStore());
    expect(find.byKey(const ValueKey('auth-driver-word')), findsOneWidget);
    expect(find.text(tr.authDriverWord.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
    expect(find.text(tr.authOr), findsOneWidget);
    expect(find.text(tr.authEnterPhone), findsOneWidget);
    // Three steps: phone, code, details.
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google, a new identity: PHONE_REQUIRED keeps the link, the '
      'phone step sends the linkToken on both calls, the details are '
      'prefilled', (tester) async {
    final server = _FakeAuthServer(provider: _Provider.phoneRequired);
    final tokens = _FakeTokens();
    final auth = await _pumpSignIn(
      tester,
      server,
      MemoryTokenStore(),
      providerTokens: tokens,
    );
    await _tickConsent(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await _settle(tester);
    expect(tokens.asked, ['google']);
    final providerCall = server.requests.single;
    expect(providerCall.url.path, AuthRepository.providerPath);
    expect(jsonDecode(providerCall.body), {
      'provider': 'google',
      'idToken': 'id-token-google',
      'app': 'driver',
    });
    expect(auth.providerLink?.linkToken, 'lt_abc');
    expect(auth.providerLink?.firstName, 'Lina');
    expect(auth.providerLink?.email, 'lina.berg@gmail.com');
    // Still step 1, now asking for the phone once.
    expect(find.byKey(const ValueKey('auth-sub-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-apple')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('auth-phone-field')),
      '070 174 06 08',
    );
    await tester.tap(find.byKey(const ValueKey('auth-continue')));
    await _settle(tester);
    expect(find.byType(DriverPhoneVerification), findsOneWidget);
    expect(jsonDecode(server.requests[1].body), {
      'phone': '+46701740608',
      'app': 'driver',
      'linkToken': 'lt_abc',
    });
    await tester.enterText(find.byKey(const ValueKey('auth-code')), '1234');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-verify')));
    await _settle(tester);
    final verify = jsonDecode(server.requests[2].body) as Map;
    expect(verify['linkToken'], 'lt_abc');
    expect(auth.signedInPhone, '+46701740608');
    expect(auth.providerLink?.email, 'lina.berg@gmail.com');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Apple, an identity the server knows: signed in at once', (
    tester,
  ) async {
    final tokens = MemoryTokenStore();
    final auth = await _pumpSignIn(tester, _FakeAuthServer(), tokens);
    await _tickConsent(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-apple')));
    await _settle(tester);
    expect(await tokens.readAccess(), 'acc-p');
    expect(auth.providerLink, isNull);
    expect(find.text('Driver home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a provider without keys on the server (503): the button '
      'shows Coming soon and the phone keeps working', (tester) async {
    final server = _FakeAuthServer(provider: _Provider.notConfigured);
    await _pumpSignIn(tester, server, MemoryTokenStore());
    await _tickConsent(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('auth-provider-soon-Google')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-provider-soon-Apple')),
      findsNothing,
    );
    expect(find.text(tr.authProviderComingSoon), findsOneWidget);
    // Not tappable any more; no crash.
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await _settle(tester);
    expect(
      server.requests
          .where((r) => r.url.path == AuthRepository.providerPath)
          .length,
      1,
    );
    // The consent box is already ticked: the phone still works.
    await _toCodeScreen(tester, tickConsent: false);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the provider sheet closed: nothing happens; a platform '
      'without the SDK shows Coming soon', (tester) async {
    final server = _FakeAuthServer(provider: _Provider.phoneRequired);
    await _pumpSignIn(
      tester,
      server,
      MemoryTokenStore(),
      providerTokens: _FakeTokens(cancel: true),
    );
    await _tickConsent(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-apple')));
    await _settle(tester);
    expect(server.requests, isEmpty);
    expect(find.byKey(const ValueKey('auth-error')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    // The real source on this test host (Linux): unavailable → Coming soon.
    await _pumpSignIn(
      tester,
      server,
      MemoryTokenStore(),
      providerTokens: PlatformProviderTokenSource(),
    );
    await _tickConsent(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-google')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('auth-provider-soon-Google')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Continue waits for the consent tick and a valid number', (
    tester,
  ) async {
    await _pumpSignIn(tester, _FakeAuthServer(), MemoryTokenStore());
    await tester.enterText(
      find.byKey(const ValueKey('auth-phone-field')),
      '070 123 45 67',
    );
    await tester.tap(find.byKey(const ValueKey('auth-continue')));
    await tester.pump();
    expect(find.text(tr.authConsentTickFirst), findsOneWidget);
    expect(find.byType(DriverPhoneVerification), findsNothing);
    await _tickConsent(tester);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('auth-phone-field')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('auth-continue')));
    await tester.pump();
    expect(find.text(tr.authInvalidMobileNumber), findsOneWidget);
    expect(find.byType(DriverPhoneVerification), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('phone, code, tokens stored, Home', (tester) async {
    final server = _FakeAuthServer();
    final tokens = MemoryTokenStore();
    final auth = await _pumpSignIn(tester, server, tokens);
    await _toCodeScreen(tester);
    final request = server.requests.single;
    expect(request.url.path, AuthRepository.requestPath);
    expect(jsonDecode(request.body), {
      'phone': '+46701234567',
      'app': 'driver',
    });
    expect(request.headers['X-Api-Version'], '0.5');
    expect(request.headers['Idempotency-Key'], isNotNull);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(
      find.textContaining('+46 70 123 45 67', findRichText: true),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('auth-code')), '1234');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-verify')));
    await _settle(tester);
    expect(await tokens.readAccess(), 'acc-1');
    expect(await tokens.readRefresh(), 'ref-1');
    expect(auth.signInResult?.isNewDriver, isFalse);
    expect(find.text('Driver home'), findsOneWidget);
    expect(find.byType(DriverPhoneVerification), findsNothing);
    expect(find.byType(DriverSignIn), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wrong code says so and saves nothing', (tester) async {
    final tokens = MemoryTokenStore();
    await _pumpSignIn(tester, _FakeAuthServer(), tokens);
    await _toCodeScreen(tester);
    await tester.enterText(find.byKey(const ValueKey('auth-code')), '9999');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-verify')));
    await _settle(tester);
    expect(find.text(tr.authErrWrongCode), findsOneWidget);
    expect(find.text('Driver home'), findsNothing);
    expect(await tokens.readAccess(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resend counts the server\'s window down, then sends a new '
      'code', (tester) async {
    final server = _FakeAuthServer(retryAfterSeconds: 30);
    await _pumpSignIn(tester, server, MemoryTokenStore());
    await _toCodeScreen(tester);
    expect(find.byKey(const ValueKey('auth-resend-wait')), findsOneWidget);
    expect(find.textContaining('0:30', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-resend')), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('0:20', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-resend-wait')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('auth-resend')));
    await _settle(tester);
    expect(server.codesSent, 2);
    expect(find.text(tr.authNewCodeSent), findsOneWidget);
    expect(find.textContaining('0:30', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
