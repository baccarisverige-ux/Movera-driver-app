import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release metadata is Movera Driver, not the Flutter template', () {
    final files = <String>[
      'pubspec.yaml',
      'web/index.html',
      'web/manifest.json',
      'README.md',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('A new Flutter project')), reason: path);
    }
    expect(File('web/index.html').readAsStringSync(), contains('Movera Driver'));
    expect(File('web/manifest.json').readAsStringSync(), contains('Movera Driver'));
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="Movera Driver"'),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<string>Movera Driver</string>'),
    );
    expect(
      File('android/app/build.gradle.kts').readAsStringSync(),
      contains('se.movera.driver'),
    );
  });

  // driver-u4: the iOS bundle id matches Android and the README, not the
  // Flutter template com.example.movera.
  test('iOS bundle identifier is se.movera.driver in every configuration', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);').allMatches(project).map((m) => m.group(1)).toList();
    expect(ids.where((id) => id == 'se.movera.driver'), hasLength(3), reason: 'Runner Debug, Release, Profile');
    expect(ids.where((id) => id == 'se.movera.driver.RunnerTests'), hasLength(3), reason: 'RunnerTests');
    expect(ids, hasLength(6));
    expect(project, isNot(contains('com.example')));
  });
}
