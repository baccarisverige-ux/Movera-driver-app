import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';

/// Round 4: the driver sign-in against a fake server, from the phone to
/// Home.
class _FakeAuthServer {
  _FakeAuthServer({this.retryAfterSeconds = 30});

  /// The one code the server accepts.
  static const acceptedCode = '1234';
  final int retryAfterSeconds;
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

Future<AuthController> _pumpSignIn(
  WidgetTester tester,
  _FakeAuthServer server,
  MemoryTokenStore tokens,
) async {
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

/// Phone typed, consent ticked, Continue: on the code screen.
Future<void> _toCodeScreen(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('auth-phone-field')),
    '070 123 45 67',
  );
  await _tickConsent(tester);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('auth-continue')));
  await _settle(tester);
  expect(find.byType(DriverPhoneVerification), findsOneWidget);
}

void main() {
  testWidgets('the Driver word sits under the wordmark and there are no '
      'Apple or Google buttons', (tester) async {
    await _pumpSignIn(tester, _FakeAuthServer(), MemoryTokenStore());
    expect(find.byKey(const ValueKey('auth-driver-word')), findsOneWidget);
    expect(find.text(tr.authDriverWord.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.text(tr.authEnterPhone), findsOneWidget);
    // Two steps: phone, code.
    expect(find.text('1 / 2'), findsOneWidget);
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
    expect(find.text('2 / 2'), findsOneWidget);
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
