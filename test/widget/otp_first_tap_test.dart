import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:pinput/pinput.dart';

/// Owner, live test 2026-10-26: on the web (iPhone Safari) the first tap on
/// the code boxes did nothing; only a tap elsewhere and a second tap opened
/// the keyboard. The field focused itself when the screen opened, which a
/// browser does without a keyboard, so the first tap met a field that was
/// already focused. In a browser it now waits for the tap.
void main() {
  tearDown(() => DriverPhoneVerification.debugWeb = null);

  Future<void> pumpVerify(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: DriverPhoneVerification(
            challenge: OtpChallenge(
              phone: '+46701234567',
              sessionId: 'otp-1',
              expiresAt: DateTime.utc(2030),
              retryAfter: const Duration(seconds: 30),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool codeFocused(WidgetTester tester) =>
      tester.widget<Pinput>(find.byType(Pinput)).focusNode!.hasFocus;

  testWidgets('in a browser the code field is not focused until the driver '
      'taps it, and one tap focuses it', (tester) async {
    DriverPhoneVerification.debugWeb = true;
    await pumpVerify(tester);
    expect(tester.widget<Pinput>(find.byType(Pinput)).autofocus, isFalse);
    expect(codeFocused(tester), isFalse);
    await tester.tap(find.byType(Pinput));
    await tester.pump(const Duration(milliseconds: 100));
    expect(codeFocused(tester), isTrue);
  });

  testWidgets('the installed app still opens the keyboard at once', (
    tester,
  ) async {
    DriverPhoneVerification.debugWeb = false;
    await pumpVerify(tester);
    expect(tester.widget<Pinput>(find.byType(Pinput)).autofocus, isTrue);
    expect(codeFocused(tester), isTrue);
  });
}
