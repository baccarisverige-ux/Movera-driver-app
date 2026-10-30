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
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/widgets/keep_above_keyboard.dart';

/// Owner 2026-10-30 (screen video, sign-in on iPhone): "When clic on any box
/// to fill, why the botton continue doesnt show up with keyboard!?"
/// (decisions/driver-g1.md, last section). With the keyboard up, the field,
/// the terms tick and the main button stay visible just above it.

const _screen = Size(390, 844);

/// An iPhone keyboard with its bar above it, in logical pixels.
const _keyboard = 336.0;

AuthController _auth() {
  final store = MemoryTokenStore();
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 404)),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: store,
  );
  return AuthController(
    repository: AuthRepository(api: api, tokens: store),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

/// The keyboard opens the way a phone (or the browser's visualViewport)
/// reports it: the view's bottom inset grows over a few frames.
Future<void> _openKeyboard(WidgetTester tester) async {
  for (final step in [0.3, 0.7, 1.0]) {
    tester.view.viewInsets = FakeViewPadding(bottom: _keyboard * step);
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

double get _keyboardTop => _screen.height - _keyboard;

void _visibleAboveKeyboard(WidgetTester tester, Finder finder, String what) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$what top on screen');
  expect(
    rect.bottom,
    lessThanOrEqualTo(_keyboardTop + 0.5),
    reason: '$what must be above the keyboard (bottom ${rect.bottom})',
  );
}

void main() {
  testWidgets('sign-in: phone field, terms tick and Continue stay above the '
      'keyboard', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverSignIn(controller: _auth(), showTestAccounts: false),
      ),
    );
    await tester.pump(const Duration(seconds: 6));

    await tester.tap(find.byKey(const ValueKey('auth-phone-field')));
    await tester.pump();
    await _openKeyboard(tester);

    _visibleAboveKeyboard(
      tester,
      find.byKey(const ValueKey('auth-phone-field')),
      'phone field',
    );
    _visibleAboveKeyboard(
      tester,
      find.byKey(const ValueKey('auth-consent')),
      'terms tick',
    );
    _visibleAboveKeyboard(
      tester,
      find.byKey(const ValueKey('auth-continue')),
      'Continue',
    );
  });

  testWidgets(
    'code screen: the code boxes and Verify stay above the keyboard',
    (tester) async {
      _phone(tester);
      DriverPhoneVerification.debugWeb = true;
      addTearDown(() => DriverPhoneVerification.debugWeb = null);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: DriverPhoneVerification(
              controller: _auth(),
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
      await tester.tap(find.byKey(const ValueKey('auth-code')));
      await tester.pump();
      await _openKeyboard(tester);

      _visibleAboveKeyboard(
        tester,
        find.byKey(const ValueKey('auth-code')),
        'code boxes',
      );
      _visibleAboveKeyboard(
        tester,
        find.byKey(const ValueKey('auth-verify')),
        'Verify',
      );
    },
  );

  testWidgets('any form: moving to another field with the keyboard up keeps '
      'the field visible and brings the button up when both fit', (
    tester,
  ) async {
    _phone(tester);
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 500),
              TextField(key: const ValueKey('f1'), focusNode: first),
              TextField(key: const ValueKey('f2'), focusNode: second),
              const SizedBox(height: 120),
              KeepAboveKeyboard(
                child: FilledButton(
                  key: const ValueKey('save'),
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('f1')));
    await tester.pump();
    await _openKeyboard(tester);
    _visibleAboveKeyboard(tester, find.byKey(const ValueKey('f1')), 'field 1');
    _visibleAboveKeyboard(tester, find.byKey(const ValueKey('save')), 'Save');

    second.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _visibleAboveKeyboard(tester, find.byKey(const ValueKey('f2')), 'field 2');
    _visibleAboveKeyboard(tester, find.byKey(const ValueKey('save')), 'Save');
  });
}
