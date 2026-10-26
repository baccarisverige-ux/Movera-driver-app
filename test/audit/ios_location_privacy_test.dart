import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS location privacy matches when-in-use behavior', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, contains('while the app is open'));
    expect(plist, contains('Background location is not used'));
    expect(plist, contains('NSCameraUsageDescription'));
    expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(
      plist,
      isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')),
    );
    expect(plist, isNot(contains('UIBackgroundModes')));
  });
}
