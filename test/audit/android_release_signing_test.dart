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

  // flutter_stripe 11.5.0 README "Requirements > Android" (Pay Movera by
  // card, #644). The release build (R8) failed on "Missing classes" without
  // step 7; each step that can be read from the files is held here.
  test('the Android build meets the Stripe SDK requirements', () {
    final rules = File('android/app/proguard-rules.pro').readAsLinesSync();
    for (final name in const [
      r'PushProvisioningActivity$g',
      r'PushProvisioningActivityStarter$Args',
      r'PushProvisioningActivityStarter$Error',
      'PushProvisioningActivityStarter',
      'PushProvisioningEphemeralKeyProvider',
    ]) {
      expect(
        rules,
        contains('-dontwarn com.stripe.android.pushProvisioning.$name'),
        reason: name,
      );
    }
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final release = gradle.substring(
      gradle.indexOf('buildTypes {'),
      gradle.indexOf('gradle.taskGraph.whenReady'),
    );
    expect(release, contains('proguardFiles("proguard-rules.pro")'));
    // Minify / R8 is never switched off to get around a missing rule.
    expect(gradle, isNot(contains('isMinifyEnabled = false')));
    expect(gradle, isNot(contains('isShrinkResources = false')));
    final properties = File('android/gradle.properties').readAsLinesSync();
    expect(properties, contains('android.enableR8.fullMode=false'));
    // Step 6: the Payment Sheet needs a FragmentActivity.
    final activity = File(
      'android/app/src/main/kotlin/se/movera/driver/MainActivity.kt',
    ).readAsStringSync();
    expect(
      activity,
      contains('class MainActivity : FlutterFragmentActivity()'),
    );
    // Step 4: the activity's theme (NormalTheme, set by the manifest) is a
    // descendant of Theme.AppCompat, in the light and the night styles.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:resource="@style/NormalTheme"'));
    for (final folder in const ['values', 'values-night']) {
      final styles = File(
        'android/app/src/main/res/$folder/styles.xml',
      ).readAsStringSync();
      expect(
        RegExp(
          r'<style name="NormalTheme" parent="Theme\.(AppCompat|MaterialComponents)[.\w]*">',
        ).hasMatch(styles),
        isTrue,
        reason: folder,
      );
    }
  });
}
