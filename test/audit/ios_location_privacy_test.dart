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
    expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(
      plist,
      isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')),
    );
    expect(
      plist,
      matches(
        RegExp(
          r'<key>UIBackgroundModes</key>\s*<array>\s*<string>location</string>\s*</array>',
        ),
      ),
    );
  });
}
