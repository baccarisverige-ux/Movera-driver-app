import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';

import 'd51_translations_test.dart' show languages, show, speak, words;

/// Wave 5 D5.1 (parts c, d and e): texts that stayed in English, or in
/// the language they were made in, now follow the driver's language.
void main() {
  testWidgets('driver-57: the English code prompt is grammatical',
      (tester) async {
    await show(tester, 'en', const DriverPhoneVerification());
    expect(words('Didn’t get the code?'), findsOneWidget);
    expect(words('Did you don’t'), findsNothing);
  });
}
