import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:pinput/pinput.dart';

/// Driver group 1 re-check (owner 2026-10-30, contract v0.18.2 §24): the
/// start country, the code that checks itself and the wrong code that
/// empties the boxes.

http.Response _json(int status, Map<String, Object?> map) => http.Response(
  jsonEncode(map),
  status,
  headers: {'content-type': 'application/json'},
);

class _Server {
  _Server(this.answer);
  final FutureOr<http.Response> Function(http.Request request) answer;
  final List<http.Request> requests = [];
  http.Client get client => MockClient((request) async {
    requests.add(request);
    return answer(request);
  });
  int get verifies =>
      requests.where((r) => r.url.path == AuthRepository.verifyPath).length;
}

AuthController _controller(_Server server) {
  final store = MemoryTokenStore();
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

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _pinText(WidgetTester tester) =>
    tester.widget<Pinput>(find.byType(Pinput)).controller!.text;

void main() {
  tearDown(() => DriverPhoneVerification.debugWeb = null);

  group('start country (auth.startCountry, owner "France or sweden")', () {
    Future<String> dialShown(WidgetTester tester, Locale device) async {
      tester.platformDispatcher.localeTestValue = device;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      _phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: DriverSignIn(
            controller: _controller(_Server((_) => _json(404, {}))),
            showTestAccounts: false,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      final dial = tester
          .widget<Text>(find.byKey(const ValueKey('auth-phone-dial')))
          .data!;
      await tester.pumpWidget(const SizedBox.shrink());
      return dial;
    }

    testWidgets('a French phone starts with France +33', (tester) async {
      expect(await dialShown(tester, const Locale('fr', 'FR')), '+33');
    });

    testWidgets('a US phone starts with Sweden +46, not +1', (tester) async {
      expect(await dialShown(tester, const Locale('en', 'US')), '+46');
    });

    testWidgets('a Swedish phone starts with Sweden +46', (tester) async {
      expect(await dialShown(tester, const Locale('sv', 'SE')), '+46');
    });
  });

  group('the code checks itself (auth.codeAutoSubmit, owner "Check by '
      'itself")', () {
    testWidgets('the 4th digit sends the code at once, without Verify', (
      tester,
    ) async {
      final server = _Server((request) {
        if (request.url.path == AuthRepository.verifyPath) {
          return _json(400, {
            'code': 'invalid_request',
            'message': 'x',
            'reason': 'invalid_otp_code',
          });
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpVerify(tester, _controller(server));
      await tester.enterText(find.byType(EditableText), '123');
      await _settle(tester);
      expect(server.verifies, 0);
      await tester.enterText(find.byType(EditableText), '1234');
      await _settle(tester);
      expect(server.verifies, 1);
      expect(jsonDecode(server.requests.last.body)['code'], '1234');
      // Verify is still on the screen for slow connections.
      expect(find.byKey(const ValueKey('auth-verify')), findsOneWidget);
    });

    testWidgets('tapping Verify while the code is already being checked '
        'sends no second call', (tester) async {
      final answer = Completer<http.Response>();
      final server = _Server((request) {
        if (request.url.path == AuthRepository.verifyPath) {
          return answer.future;
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpVerify(tester, _controller(server));
      await tester.enterText(find.byType(EditableText), '1234');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('auth-verify')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('auth-verify')),
        warnIfMissed: false,
      );
      await tester.pump();
      answer.complete(
        _json(400, {
          'code': 'invalid_request',
          'message': 'x',
          'reason': 'invalid_otp_code',
        }),
      );
      await _settle(tester);
      expect(server.verifies, 1);
    });
  });

  group('a wrong code empties the boxes (auth.codeClearOnWrong, owner '
      '"Clear boxes")', () {
    testWidgets('the boxes are empty, the error line stays and the field '
        'keeps its focus for the next code', (tester) async {
      final server = _Server((request) {
        if (request.url.path == AuthRepository.verifyPath) {
          return _json(400, {
            'code': 'invalid_request',
            'message': 'x',
            'reason': 'invalid_otp_code',
          });
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpVerify(tester, _controller(server));
      await tester.tap(find.byType(Pinput));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '9999');
      await tester.pump();
      // Also the old way (Verify by hand): the result must be the same.
      await tester.tap(
        find.byKey(const ValueKey('auth-verify')),
        warnIfMissed: false,
      );
      await _settle(tester);
      expect(_pinText(tester), isEmpty);
      expect(find.text(tr.authErrWrongCode), findsOneWidget);
      expect(
        tester.widget<Pinput>(find.byType(Pinput)).focusNode!.hasFocus,
        isTrue,
      );
      // The next code can be typed at once and is checked by itself.
      final before = server.verifies;
      await tester.enterText(find.byType(EditableText), '1235');
      await _settle(tester);
      expect(server.verifies, before + 1);
    });

    testWidgets('a code that could not be checked (no connection) is kept, '
        'so Verify can send it again', (tester) async {
      final server = _Server((request) {
        if (request.url.path == AuthRepository.verifyPath) {
          throw http.ClientException('offline');
        }
        return _json(404, {'code': 'not_found', 'message': 'x'});
      });
      await _pumpVerify(tester, _controller(server));
      await tester.enterText(find.byType(EditableText), '1234');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('auth-verify')),
        warnIfMissed: false,
      );
      await _settle(tester);
      expect(_pinText(tester), '1234');
      expect(find.text(tr.authErrOffline), findsOneWidget);
    });
  });
}
