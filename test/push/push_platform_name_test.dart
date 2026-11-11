import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/push/push_platform_io.dart';

/// D14-23: the contract's push `platform` is `ios` or `android`.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('D14-23: iOS says ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(const UnsupportedPushPlatform().platformName, 'ios');
  });

  test('D14-23: Android says android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(const UnsupportedPushPlatform().platformName, 'android');
  });
}
