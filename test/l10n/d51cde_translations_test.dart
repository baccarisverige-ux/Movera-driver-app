import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc_phone.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign%20in%20phone/sign_in_phone.dart';

import 'd51_translations_test.dart' show languages, show, speak, words;

/// The country flag the phone field starts with, by ISO code.
Finder flag(String iso) => find.byWidgetPredicate((widget) =>
    widget is Image &&
    widget.image is AssetImage &&
    (widget.image as AssetImage).assetName.endsWith('/$iso.png'));

/// Wave 5 D5.1 (parts c, d and e): texts that stayed in English, or in
/// the language they were made in, now follow the driver's language.
void main() {
  testWidgets('driver-57: the English code prompt is grammatical',
      (tester) async {
    await show(tester, 'en', const DriverPhoneVerification());
    expect(words('Didn’t get the code?'), findsOneWidget);
    expect(words('Did you don’t'), findsNothing);
  });

  testWidgets('driver-u105: phone screens start on Sweden, +46', (tester) async {
    final screens = <Widget>[
      const DriverSignInPhone(),
      const DriverCreateAccountPhone(),
    ];
    for (final screen in screens) {
      await show(tester, 'sv', screen);
      expect(flag('se'), findsOneWidget, reason: '${screen.runtimeType}');
      expect(flag('us'), findsNothing);
    }
  });
}
