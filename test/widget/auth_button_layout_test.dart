import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';

/// The sign-in screens at 200 % text on a small phone, portrait and
/// landscape: the page scrolls, so the primary button can always be
/// brought on screen, and nothing overflows.
void main() {
  final screens = <String, Widget>{
    'sign in': const DriverSignIn(),
    'verification': DriverPhoneVerification(
      challenge: OtpChallenge(
        phone: '+46701234567',
        sessionId: 'otp-1',
        expiresAt: DateTime.utc(2030),
        retryAfter: const Duration(seconds: 30),
      ),
    ),
  };
  for (final entry in screens.entries) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
        '${entry.key} keeps its growing button reachable at 200% in $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (_, _) => MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 6));
          final button = find.byType(AuthPrimaryButton);
          expect(button, findsOneWidget);
          await tester.ensureVisible(button);
          await tester.pump();
          expect(button.hitTestable(), findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
