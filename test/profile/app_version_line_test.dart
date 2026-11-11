// Owner 2026-11-11 (set 2: "Yes, both apps"; contract v0.18.66 §87, app
// only): the driver Account screen ends with the app version and build
// number, e.g. "Version 1.0.0 (583)", read from the build
// (MOVERA_APP_VERSION, the pubspec `version` with its build number).
// Fail-before: no version line on the Account (Profile) screen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/profile/app_version_line.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Account screen ends with the version line', (tester) async {
    final session = DriverSessionController(initialOnline: false);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRuntimeScope(
          session: session,
          homeBuilder: () => const Scaffold(body: Text('HOME')),
          logout: () async {},
          child: const DriverProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final line = find.byKey(const ValueKey<String>('account-app-version'));
    await tester.scrollUntilVisible(line, 200);
    // A local / check build has no MOVERA_APP_VERSION: "dev".
    expect(
      tester.widget<Text>(line).data,
      matches(RegExp(r'^Version \S+( \(\S+\))?$')),
    );
    // It is the last thing on the screen, under Log out.
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(tester.getTopLeft(find.text('Log out')).dy),
    );
  });

  test('a live build reads "Version 1.0.0 (583)"; no build number → '
      '"Version 1.0.0"', () {
    expect(AppVersionLine.text('1.0.0+583'), 'Version 1.0.0 (583)');
    expect(AppVersionLine.text('1.0.0'), 'Version 1.0.0');
    expect(AppVersionLine.text('dev'), 'Version dev');
  });

  test('the texts exist in sv / fr / en', () {
    for (final lang in ['sv', 'fr', 'en']) {
      final arb =
          jsonDecode(
                File('lib/l10n/parts/account.$lang.arb').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(arb['appVersionLine'], contains('{version}'), reason: lang);
      expect(arb['appVersionLine'], contains('({build})'), reason: lang);
      expect(arb['appVersionOnly'], contains('{version}'), reason: lang);
    }
  });
}
