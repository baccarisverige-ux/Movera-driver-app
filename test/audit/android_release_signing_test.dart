import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Android release does not fall back to debug signing', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains('Production Android release refuses debug signing'),
    );
    expect(gradle, contains('MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW'));
    expect(gradle, contains('MOVERA_REQUIRE_MAPS_KEY'));
    expect(
      gradle,
      isNot(contains('signingConfigs.getByName("debug")\n            }')),
    );
    expect(
      gradle.contains(
        'else {\n                signingConfigs.getByName("debug")',
      ),
      isFalse,
    );
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();
    expect(wrapper, contains('gradle-8.14.3-all.zip'));
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    expect(settings, contains('com.android.application") version "8.11.1"'));
    expect(
      settings,
      contains('org.jetbrains.kotlin.android") version "2.2.20"'),
    );
  });
}
