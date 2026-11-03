import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:movera/presentation/driver/auth/widgets/phone_country_picker.dart';
import 'package:movera/widgets/country_flag.dart';

/// Owner 2026-11-03, decisions/servers-test-live.md "Load time":
/// LT-3 small flag pictures instead of emoji (no emoji font downloaded),
/// LT-2 the driver web page shows the Movera loading screen.
bool _hasFlagEmoji(String text) =>
    text.runes.any((r) => r >= 0x1F1E6 && r <= 0x1F1FF);

void main() {
  test('every country of the phone field has a flag picture', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(PhoneCountries.all.length, greaterThan(200));
    for (final country in PhoneCountries.all) {
      final data = await rootBundle.load(CountryFlag.assetOf(country.iso));
      expect(data.lengthInBytes, greaterThan(50), reason: country.iso);
    }
  });

  testWidgets('the sign-in phone field shows the flag picture, no emoji', (
    tester,
  ) async {
    for (final country in [
      PhoneCountries.sweden,
      PhoneCountries.france,
      PhoneCountries.tunisia,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthPhoneField(
              controller: TextEditingController(),
              focusNode: FocusNode(),
              country: country,
              onCountryChanged: (_) {},
            ),
          ),
        ),
      );
      final flag = find.byKey(ValueKey('country-flag-${country.iso}'));
      expect(flag, findsOneWidget);
      expect(
        (tester.widget<Image>(flag).image as AssetImage).assetName,
        'assets/flags/${country.iso.toLowerCase()}.png',
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(_hasFlagEmoji(text.data ?? ''), isFalse);
      }
    }
  });

  testWidgets('the country sheet lists flag pictures', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneCountrySheet(selected: PhoneCountries.sweden),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CountryFlag), findsWidgets);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(_hasFlagEmoji(text.data ?? ''), isFalse);
    }
  });

  testWidgets('a code without a picture shows its letters', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: CountryFlag('ZZ'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('ZZ'), findsOneWidget);
  });

  test('the web page has the Movera loading screen until the first frame', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('id="movera-boot"'));
    expect(html, contains('window.moveraAppReady = clear'));
    expect(html, contains('setTimeout(clear, 20000)'));
  });
}
