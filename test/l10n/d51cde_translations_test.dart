import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc_phone.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign%20in%20phone/sign_in_phone.dart';
import 'package:movera/presentation/driver/auth/sign%20in/sign_in.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_confirm.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';

import 'd51_translations_test.dart' as d51 show show;
import 'd51_translations_test.dart' show languages, speak, words;

/// [d51.show], after clearing the screen: a const screen pumped again in
/// another language is built anew, as the app root does on a switch.
Future<void> show(WidgetTester tester, String code, Widget home) async {
  await tester.pumpWidget(const SizedBox());
  await d51.show(tester, code, home);
}

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

  testWidgets('driver-58: the sign-in divider word is translated',
      (tester) async {
    for (final (code, or) in [('fr', 'ou'), ('sv', 'eller')]) {
      await show(tester, code, const DriverSignIn());
      expect(find.text(or), findsOneWidget, reason: code);
      expect(find.text('or'), findsNothing);
    }
  });

  test('driver-u107: the destination summary uses the decimal comma', () {
    for (final code in languages) {
      speak(code);
      expect(destinationDistanceTimeLabel(38100, 2040), '38,1 km · 34 min');
    }
    speak('en');
    expect(destinationDistanceTimeLabel(38100, 2040), '38.1 km · 34 min');
  });

  testWidgets('driver-60: the destination search count is translated',
      (tester) async {
    for (final (code, query, count) in [
      ('fr', 'airport', '2 trouvés'),
      ('sv', 'kista', '1 träff'),
    ]) {
      await show(tester, code, const DriverDestinationPicker());
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text(count), findsOneWidget, reason: code);
      expect(words('found'), findsNothing);
    }
  });
}
