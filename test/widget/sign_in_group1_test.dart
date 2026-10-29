import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_error_message.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/session_gate.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:pinput/pinput.dart';

/// Owner decisions of 2026-10-29, driver app group 1 "Sign in, sign up,
/// language" (contract v0.15.0 §24). Each group names its decision.

http.Response _json(int status, Map<String, Object?> map, {String? retry}) =>
    http.Response(
      jsonEncode(map),
      status,
      headers: {
        'content-type': 'application/json',
        if (retry != null) 'retry-after': retry,
      },
    );

/// A scripted server: [answer] per path; every request is kept.
class _Server {
  _Server(this.answer);
  final FutureOr<http.Response> Function(http.Request request) answer;
  final List<http.Request> requests = [];
  http.Client get client => MockClient((request) async {
    requests.add(request);
    return answer(request);
  });
}

AuthController _controller(_Server server, [TokenStore? tokens]) {
  final store = tokens ?? MemoryTokenStore();
  final api = ApiClient(
    client: server.client,
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: store,
  );
  return AuthController(
    repository: AuthRepository(api: api, tokens: store),
  );
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpSignIn(
  WidgetTester tester,
  AuthController auth, {
  bool showTestAccounts = false,
}) async {
  _phoneSize(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: DriverSignIn(controller: auth, showTestAccounts: showTestAccounts),
    ),
  );
  await tester.pump(const Duration(seconds: 6));
}

Future<void> _continueWith(WidgetTester tester, String typed) async {
  await tester.enterText(find.byKey(const ValueKey('auth-phone-field')), typed);
  final consent = find.byKey(const ValueKey('auth-consent'));
  await tester.tapAt(tester.getTopLeft(consent) + const Offset(12, 12));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('auth-continue')));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpVerify(WidgetTester tester, AuthController auth) async {
  _phoneSize(tester);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: DriverPhoneVerification(
          controller: auth,
          challenge: OtpChallenge(
            phone: '+46701740605',
            sessionId: 'otp-1',
            expiresAt: DateTime.utc(2030),
            retryAfter: Duration.zero,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(() => DriverPhoneVerification.debugWeb = null);

  group('decision 4: a wait is shown in minutes', () {
    test('fixtures/sign_in.json#waitDisplay', () {
      final fixture =
          jsonDecode(File('contracts/fixtures/sign_in.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final raw in fixture['waitDisplay'] as List) {
        final c = raw as Map<String, dynamic>;
        final expect_ = c['expect'] as Map<String, dynamic>;
        final value = expect_['value'] as int;
        final want = expect_['unit'] == 'seconds'
            ? tr.authRetrySeconds(value)
            : tr.authRetryMinutes(value);
        expect(
          authWaitText(Duration(seconds: c['retryAfterSeconds'] as int)),
          want,
          reason: '$c',
        );
      }
      expect(authWaitText(const Duration(seconds: 2520)), '42 min');
    });

    test('429 otp_too_many says "Try again in 42 min"', () {
      const error = ApiError(
        code: 'rate_limited',
        reason: 'otp_too_many',
        message: 'x',
        statusCode: 429,
        retryAfter: Duration(seconds: 2501),
      );
      expect(
        authErrorMessage(error, AuthAction.sendCode),
        tr.authErrTooManyIn('42 min'),
      );
    });
  });

  group('decision 1: the sign-in calls wait up to 60 s', () {
    testWidgets('a slow server: no error after 20 s, "Starting the server…" '
        'after 5 s, the code screen when the answer comes', (tester) async {
      final answer = Completer<http.Response>();
      final server = _Server((request) {
        if (request.url.path == AuthRepository.requestPath) {
          return answer.future;
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpSignIn(tester, _controller(server));
      await _continueWith(tester, '70 174 06 05');
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('auth-slow-server')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('auth-slow-server')), findsOneWidget);
      expect(find.text(tr.authStartingServer), findsOneWidget);
      // The old 15 s limit gave up here.
      await tester.pump(const Duration(seconds: 14));
      expect(find.text(tr.authErrOffline), findsNothing);
      answer.complete(
        _json(200, {
          'sessionId': 'otp-1',
          'expiresAt': '2030-01-01T10:00:00Z',
          'retryAfterSeconds': 30,
        }),
      );
      await _settle(tester);
      expect(find.byType(DriverPhoneVerification), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-slow-server')), findsNothing);
    });

    test('every sign-in call is given 60 s', () {
      expect(ApiClient.signInTimeout, const Duration(seconds: 60));
      final contract =
          jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>;
      final slow =
          (contract['auth'] as Map<String, dynamic>)['slowStart']
              as Map<String, dynamic>;
      expect(ApiClient.signInTimeout.inSeconds, slow['waitSeconds']);
    });
  });

  group('decision 5: the waiting list', () {
    testWidgets('a restricted number gets "Join the waiting list"; it saves '
        'the number', (tester) async {
      final server = _Server((request) {
        switch (request.url.path) {
          case AuthRepository.requestPath:
            return _json(403, {
              'code': 'forbidden',
              'message': 'x',
              'reason': 'sign_in_restricted',
            });
          case AuthRepository.waitlistPath:
            return _json(200, {'status': 'saved', 'requestId': 'r1'});
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpSignIn(tester, _controller(server));
      await _continueWith(tester, '70 555 12 34');
      await _settle(tester);
      expect(find.text(tr.authSignInRestricted), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-join-waitlist')));
      await _settle(tester);
      final sent = server.requests.last;
      expect(sent.url.path, AuthRepository.waitlistPath);
      expect(jsonDecode(sent.body), {
        'phone': '+46705551234',
        'app': 'driver',
        'locale': 'en',
      });
      expect(find.byKey(const ValueKey('auth-waitlist-saved')), findsOneWidget);
      expect(find.text(tr.authWaitlistSaved), findsOneWidget);
    });
  });

  group('decision 6: test numbers only in test builds', () {
    final accounts = _Server((request) {
      if (request.url.path == AuthRepository.testAccountsPath) {
        return _json(200, {
          'accounts': [
            {'phone': '+46701740605', 'app': 'rider', 'status': 'test'},
            {
              'phone': '+46701740605',
              'app': 'driver',
              'status': 'active',
              'name': 'Test',
            },
            {'phone': '+46701740606', 'app': 'driver', 'status': 'test'},
          ],
        });
      }
      return _json(404, {'code': 'not_found', 'message': 'x'});
    });

    testWidgets('a test build lists the driver numbers with their status; a '
        'tap fills the phone field', (tester) async {
      await _pumpSignIn(tester, _controller(accounts), showTestAccounts: true);
      expect(find.byKey(const ValueKey('auth-test-accounts')), findsOneWidget);
      expect(find.text(tr.authTestStatusNew), findsOneWidget);
      expect(find.text(tr.swDriverAccountStatusActive), findsOneWidget);
      final row = find.byKey(const ValueKey('auth-test-+46701740606'));
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();
      final typed = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((field) => field.controller.text.replaceAll(' ', ''));
      expect(typed, contains('701740606'));
    });

    testWidgets('a store build never asks', (tester) async {
      final before = accounts.requests.length;
      await _pumpSignIn(tester, _controller(accounts));
      expect(find.byKey(const ValueKey('auth-test-accounts')), findsNothing);
      expect(accounts.requests.length, before);
    });
  });

  group('decision 3: 5 wrong codes', () {
    testWidgets('"Too many wrong tries – tap Resend code" and the resend '
        'button is highlighted until a new code is sent', (tester) async {
      final server = _Server((request) {
        switch (request.url.path) {
          case AuthRepository.verifyPath:
            return _json(429, {
              'code': 'rate_limited',
              'message': 'x',
              'reason': 'otp_too_many_attempts',
            }, retry: '30');
          case AuthRepository.requestPath:
            return _json(200, {
              'sessionId': 'otp-2',
              'expiresAt': '2030-01-01T10:00:00Z',
              'retryAfterSeconds': 0,
            });
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpVerify(tester, _controller(server));
      await tester.enterText(find.byType(EditableText), '9999');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('auth-verify')));
      await _settle(tester);
      expect(
        find.text(tr.authErrTooManyWrongCodes(tr.authResendCode)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auth-resend-highlight')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('auth-resend-highlight')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('auth-resend-highlight')), findsNothing);
      expect(find.byKey(const ValueKey('auth-resend')), findsOneWidget);
    });
  });

  group('decisions 7 and 9: the code field', () {
    testWidgets('it asks for one-time-code autofill', (tester) async {
      await _pumpVerify(tester, _controller(_Server((_) => _json(404, {}))));
      expect(tester.widget<Pinput>(find.byType(Pinput)).autofillHints, const [
        AutofillHints.oneTimeCode,
      ]);
    });

    testWidgets('in a browser, a tap on the field that already has focus '
        'closes and opens the text input again, so the browser opens the '
        'keyboard', (tester) async {
      DriverPhoneVerification.debugWeb = true;
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );
      await _pumpVerify(tester, _controller(_Server((_) => _json(404, {}))));
      final pin = find.byType(Pinput);
      // (a) nothing focuses the field by itself.
      expect(tester.widget<Pinput>(pin).focusNode!.hasFocus, isFalse);
      await tester.tap(pin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Pinput>(pin).focusNode!.hasFocus, isTrue);
      // Past the double-tap window: the next tap is a tap of its own.
      await tester.pump(const Duration(milliseconds: 500));
      calls.clear();
      // (b) the keyboard was closed (swipe, wrong code, resend) while the
      // field kept its focus: the next tap must reconnect.
      await tester.tap(pin);
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, contains('TextInput.clearClient'));
      expect(
        calls.lastIndexOf('TextInput.setClient'),
        greaterThan(calls.indexOf('TextInput.clearClient')),
      );
      expect(
        calls.last == 'TextInput.show' || calls.contains('TextInput.show'),
        isTrue,
      );
      expect(tester.widget<Pinput>(pin).focusNode!.hasFocus, isTrue);
    });
  });

  group('decision 2: the start screen', () {
    Future<void> pumpGate(
      WidgetTester tester, {
      required FutureOr<http.Response> Function() profile,
      Widget Function()? supportBuilder,
    }) async {
      _phoneSize(tester);
      final tokens = MemoryTokenStore();
      await tokens.save(access: 'a', refresh: 'r');
      final server = _Server((request) {
        if (request.url.path == DriverAccountRepository.profilePath) {
          return profile();
        }
        return http.Response('', 204);
      });
      final api = ApiClient(
        client: server.client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DriverSessionGate(
            auth: AuthController(
              repository: AuthRepository(api: api, tokens: tokens),
            ),
            homeBuilder: () => const Text('home'),
            signInBuilder: () => const Text('sign in'),
            account: DriverAccountSession(
              repository: DriverAccountRepository(api),
            ),
            supportBuilder: supportBuilder,
          ),
        ),
      );
    }

    testWidgets('a spinner only after 2 s', (tester) async {
      final never = Completer<http.Response>();
      await pumpGate(tester, profile: () => never.future);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byKey(const ValueKey('gate-spinner')), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('gate-spinner')), findsOneWidget);
      never.complete(http.Response('{}', 500));
      await tester.pump(const Duration(seconds: 20));
    });

    testWidgets('an error offers Try again, Sign out and Contact support', (
      tester,
    ) async {
      await pumpGate(
        tester,
        profile: () => _json(503, {'code': 'unavailable', 'message': 'x'}),
        supportBuilder: () => const Text('in-app support'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(tr.gateTryAgain), findsOneWidget);
      expect(find.text(tr.gateSignOut), findsOneWidget);
      expect(find.text(tr.contactSupport), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gate-support')));
      await _settle(tester);
      expect(find.text('in-app support'), findsOneWidget);
      Navigator.of(tester.element(find.text('in-app support'))).pop();
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('gate-sign-out')));
      await _settle(tester);
      expect(find.text('sign in'), findsOneWidget);
    });
  });
}
