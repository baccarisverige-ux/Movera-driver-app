import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:pinput/pinput.dart';

/// Contract v0.18.135 `smsSignIn.codeLength` (owner 2026-11-19 "6 digits
/// (Rec.)"): a code sent by SMS is 6 digits, the test code of a test number
/// stays 4. The server says which in the code request's answer
/// (`OtpChallenge.codeLength`, missing = 4), so the same app build works
/// with the test server (4) and a server that sends SMS (6).
class _Server {
  _Server({this.codeLength, this.resendCodeLength});

  /// What the first code request answers as `codeLength` (null: no field,
  /// as a server before v0.18.135).
  final Object? codeLength;

  /// What a resend answers (null: the same as the first).
  final Object? resendCodeLength;
  final List<Map<String, dynamic>> verified = [];
  int codesSent = 0;

  http.Client get client => MockClient((request) async {
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
        final length = codesSent > 1 && resendCodeLength != null
            ? resendCodeLength
            : codeLength;
        return json(200, {
          'sessionId': 'otp-$codesSent',
          'expiresAt': '2030-01-01T10:00:00Z',
          'retryAfterSeconds': 0,
          'codeLength': ?length,
        });
      case AuthRepository.verifyPath:
        verified.add(body);
        return json(400, {
          'code': 'invalid_request',
          'message': 'Wrong code',
          'reason': 'invalid_otp_code',
        });
    }
    return json(404, {'code': 'not_found', 'message': 'x'});
  });
}

AuthController _auth(_Server server) {
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

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Server> _pumpCodeScreen(
  WidgetTester tester, {
  Object? codeLength,
  Object? resendCodeLength,
  Size screen = const Size(390, 844),
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final server = _Server(
    codeLength: codeLength,
    resendCodeLength: resendCodeLength,
  );
  final auth = _auth(server);
  final challenge = await auth.requestCode('+46701740605');
  await tester.pumpWidget(
    MaterialApp(
      home: DriverPhoneVerification(controller: auth, challenge: challenge),
    ),
  );
  await _settle(tester);
  return server;
}

Pinput _pinput(WidgetTester tester) =>
    tester.widget<Pinput>(find.byKey(const ValueKey('auth-code')));

bool _verifyEnabled(WidgetTester tester) =>
    tester
        .widget<AuthPrimaryButton>(find.byKey(const ValueKey('auth-verify')))
        .onPressed !=
    null;

void main() {
  test(
    'the code request answer says how many digits: 6 for an SMS code, '
    '4 for a test number, and 4 when the field is missing or not 4 / 6',
    () async {
      Future<OtpChallenge> ask(Object? value) =>
          _auth(_Server(codeLength: value)).requestCode('+46701740605');
      expect((await ask(6)).codeLength, 6);
      expect((await ask(4)).codeLength, 4);
      // A server before v0.18.135 (the test server today) sends no field.
      expect((await ask(null)).codeLength, 4);
      for (final odd in <Object>[5, 8, 0, -6, 60, '6', 6.5, true]) {
        expect((await ask(odd)).codeLength, 4, reason: '$odd');
      }
    },
  );

  test('a code is complete only with exactly the challenge\'s digits', () {
    OtpChallenge challenge(int length) => OtpChallenge(
      phone: '+46701740605',
      sessionId: 'otp-1',
      expiresAt: DateTime.utc(2030),
      retryAfter: Duration.zero,
      codeLength: length,
    );
    expect(challenge(6).isCompleteCode('123456'), isTrue);
    expect(challenge(6).isCompleteCode('1234'), isFalse);
    expect(challenge(6).isCompleteCode('1234567'), isFalse);
    expect(challenge(6).isCompleteCode('12345a'), isFalse);
    expect(challenge(4).isCompleteCode('1234'), isTrue);
    expect(challenge(4).isCompleteCode('123456'), isFalse);
    // The default is the test code's 4 digits.
    expect(
      OtpChallenge(
        phone: '+46701740605',
        sessionId: 'otp-1',
        expiresAt: DateTime.utc(2030),
        retryAfter: Duration.zero,
      ).codeLength,
      4,
    );
  });

  testWidgets('an SMS code (codeLength 6): six boxes; four digits send '
      'nothing and leave Verify off; the sixth digit sends the code', (
    tester,
  ) async {
    final server = await _pumpCodeScreen(tester, codeLength: 6);
    expect(_pinput(tester).length, 6);
    // One-time-code autofill (iOS, Android autofill, the web) is kept.
    expect(_pinput(tester).autofillHints, contains(AutofillHints.oneTimeCode));

    await tester.enterText(find.byKey(const ValueKey('auth-code')), '1234');
    await _settle(tester);
    expect(server.verified, isEmpty);
    expect(_verifyEnabled(tester), isFalse);

    await tester.enterText(find.byKey(const ValueKey('auth-code')), '123456');
    await _settle(tester);
    expect(server.verified, hasLength(1));
    expect(server.verified.single['code'], '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a code filled in at once (autofill or paste) of 6 digits is '
      'taken whole and sent', (tester) async {
    final server = await _pumpCodeScreen(tester, codeLength: 6);
    await tester.tap(find.byKey(const ValueKey('auth-code')));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '654321',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await _settle(tester);
    expect(server.verified.single['code'], '654321');
  });

  testWidgets('a test number or an older server (no codeLength): four '
      'boxes and the fourth digit sends the code, as before', (tester) async {
    final server = await _pumpCodeScreen(tester);
    expect(_pinput(tester).length, 4);
    expect(_pinput(tester).defaultPinTheme?.width, 68);
    await tester.enterText(find.byKey(const ValueKey('auth-code')), '1234');
    await _settle(tester);
    expect(server.verified.single['code'], '1234');
  });

  testWidgets('six boxes fit a small phone (320 wide) and a normal one '
      'without overflow', (tester) async {
    for (final screen in const [Size(320, 568), Size(390, 844)]) {
      await _pumpCodeScreen(tester, codeLength: 6, screen: screen);
      expect(tester.takeException(), isNull, reason: '$screen');
      final field = tester.getRect(find.byKey(const ValueKey('auth-code')));
      expect(field.left, greaterThanOrEqualTo(0), reason: '$screen');
      expect(field.right, lessThanOrEqualTo(screen.width), reason: '$screen');
      expect(_pinput(tester).defaultPinTheme!.width, lessThan(68));
      expect(_pinput(tester).defaultPinTheme!.width, greaterThanOrEqualTo(36));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a new code with another length changes the boxes (resend)', (
    tester,
  ) async {
    await _pumpCodeScreen(tester, codeLength: 4, resendCodeLength: 6);
    expect(_pinput(tester).length, 4);
    await tester.tap(find.byKey(const ValueKey('auth-resend')));
    await _settle(tester);
    expect(_pinput(tester).length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen-reader name of the boxes says 6 digits for an '
      'SMS code and stays as it was for 4', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCodeScreen(tester, codeLength: 6);
    expect(tr.authCodeFieldLabelSix, contains('6'));
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(tr.authCodeFieldLabelSix))),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpCodeScreen(tester);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(tr.authCodeFieldLabel))),
      findsWidgets,
    );
    handle.dispose();
  });
}
