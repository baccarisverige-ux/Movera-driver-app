// BQ-V46 (G6, REMINDERS 42). Owner 2026-11-11 (set 2, "App version + build
// number inside both apps": "Yes, both apps (Rec.)",
// Rules decisions/session-2026-11-06.md:961): the app shows its real
// version and build number. The update prompt compared the admin's
// "latest version" with a hard-coded '1.0.0' (home.dart _currentAppVersion)
// and never said which version is on the phone. Now it reads the build
// (MOVERA_APP_VERSION, the same source as the Account "Version x (build)"
// line) and shows "Installed: 1.4.0 (583)" under the latest version.
// Fail-before: an installed 1.4.0 was still offered 1.2.0, a local build
// was offered any update, and the sheet had no installed line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/home/components/app_update_sheet.dart';
import 'package:movera/presentation/driver/profile/app_version_line.dart';

AppUpdateAdminConfig _config({bool enabled = true, String latest = '1.2.0'}) =>
    AppUpdateAdminConfig(
      enabled: enabled,
      latestVersion: latest,
      minimumVersion: '1.0.0',
      title: 'Update available',
      message: 'Install the latest version.',
      actionLabel: 'Update now',
      dismissLabel: 'Later',
      mandatory: false,
      updateUrl: 'https://example.com/update',
    );

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  test('the prompt compares with the installed build, not 1.0.0', () {
    // Installed 1.4.0 (build 583): an older or equal "latest" is no update.
    expect(
      appUpdateOffered(_config(latest: '1.2.0'), installed: '1.4.0+583'),
      isFalse,
    );
    expect(
      appUpdateOffered(_config(latest: '1.4.0'), installed: '1.4.0+583'),
      isFalse,
    );
    expect(
      appUpdateOffered(_config(latest: '1.10.0'), installed: '1.4.0+583'),
      isTrue,
    );
    expect(
      appUpdateOffered(_config(latest: '1.4.1'), installed: '1.4.0'),
      isTrue,
    );
    expect(
      appUpdateOffered(
        _config(enabled: false, latest: '9.0.0'),
        installed: '1.4.0+583',
      ),
      isFalse,
    );
  });

  test('a local build ("dev", no version) is never offered an update', () {
    expect(
      appUpdateOffered(_config(latest: '9.0.0'), installed: 'dev'),
      isFalse,
    );
  });

  test('the short version reads "1.4.0 (583)", "1.4.0", "dev"', () {
    expect(AppVersionLine.short('1.4.0+583'), '1.4.0 (583)');
    expect(AppVersionLine.short('1.4.0'), '1.4.0');
    expect(AppVersionLine.short('dev'), 'dev');
  });

  testWidgets('the sheet shows the installed version and build number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUpdateSheet(
            update: _config(latest: '1.5.0'),
            installed: '1.4.0+583',
          ),
        ),
      ),
    );
    expect(find.text('Version 1.5.0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('app-update-installed')),
      findsOneWidget,
    );
    expect(find.text('Installed: 1.4.0 (583)'), findsOneWidget);
  });

  test('the installed text exists in sv / fr / en', () {
    final expected = {
      'en': 'Installed: 1.4.0 (583)',
      'sv': 'Installerad: 1.4.0 (583)',
      'fr': 'Installée : 1.4.0 (583)',
    };
    for (final MapEntry(key: lang, value: text) in expected.entries) {
      DriverAppTexts.language = lang;
      expect(AppUpdateSheet.installedText('1.4.0+583'), text, reason: lang);
    }
  });
}
