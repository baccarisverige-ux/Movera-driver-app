import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Owner decision 1 (driver group 3, contract v0.18.4): while online the
  // position keeps going out with the phone locked. iOS keeps a when-in-use
  // location session started in the app running in the background
  // (UIBackgroundModes location, blue indicator); "Always" is never asked.
  test('iOS location privacy: when-in-use, background only while online', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, contains('while the app is open'));
    expect(plist, contains('while you are online, also with the phone locked'));
    expect(plist, contains('NSCameraUsageDescription'));
    // 2026-11-23 ITMS-90683: Apple refuses the upload without the Always
    // keys because a bundled plugin references always-location. The app
    // still asks only when-in-use; the Always texts say online only.
    for (final key in [
      'NSLocationAlwaysUsageDescription',
      'NSLocationAlwaysAndWhenInUseUsageDescription',
    ]) {
      expect(
        RegExp(
          '<key>$key</key>\\s*<string>[^<]*while you are online[^<]*'
          'When you go offline, location is no longer used',
        ).hasMatch(plist),
        isTrue,
        reason: key,
      );
    }
    expect(
      plist,
      matches(
        RegExp(
          // v0.18.160: plus remote-notification (push), no other mode.
          r'<key>UIBackgroundModes</key>\s*<array>\s*<string>location</string>'
          r'\s*<string>remote-notification</string>\s*</array>',
        ),
      ),
    );
  });
}
