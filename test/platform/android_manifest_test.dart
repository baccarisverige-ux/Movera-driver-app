import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/location/driver_location_service.dart';

/// Android manifest checks (ported from rider D3).
void main() {
  String manifest() =>
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  Set<String> permissions() => {
    for (final match in RegExp(
      r'<uses-permission\s+android:name="android\.permission\.([A-Z_]+)"',
    ).allMatches(manifest()))
      match.group(1)!,
  };

  test('a push tap opens the app', () {
    // movera-server src/push/fcm.ts sends every Android notification with
    // click_action FLUTTER_NOTIFICATION_CLICK; Android opens only an
    // activity with that action in an intent filter, else the tap does
    // nothing.
    final xml = manifest();
    final filter = RegExp(
      r'<intent-filter>\s*<action\s+android:name="FLUTTER_NOTIFICATION_CLICK"\s*/>\s*'
      r'<category\s+android:name="android.intent.category.DEFAULT"\s*/>\s*'
      r'</intent-filter>',
    );
    expect(filter.hasMatch(xml), isTrue);
  });

  // G24 (Pixel 8, BrowserStack logcat 2026-11-12): going online threw
  // SecurityException "Neither user … nor current process has
  // android.permission.WAKE_LOCK", so the position stream never started.
  // Every permission the online location settings need must be declared.
  for (final navigation in [false, true]) {
    test('G24: the manifest declares what the online location service '
        'needs (navigation: $navigation)', () {
      final settings =
          DriverLocationService.onlineSettings(
                platform: TargetPlatform.android,
                notificationTitle: 'Movera is online',
                notificationText: 'Sharing your location',
                navigation: navigation,
              )
              as AndroidSettings;
      final needed = <String>{'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'};
      final service = settings.foregroundNotificationConfig;
      if (service != null) {
        // Android 14: a location foreground service with its notification.
        needed.addAll({
          'FOREGROUND_SERVICE',
          'FOREGROUND_SERVICE_LOCATION',
          'POST_NOTIFICATIONS',
        });
        // geolocator_android GeolocatorLocationService: a partial wake lock
        // (and a Wi-Fi lock) need WAKE_LOCK.
        if (service.enableWakeLock || service.enableWifiLock) {
          needed.add('WAKE_LOCK');
        }
      }
      expect(needed, contains('WAKE_LOCK'));
      final declared = permissions();
      expect(
        needed.difference(declared),
        isEmpty,
        reason: 'missing from AndroidManifest.xml',
      );
      // Owner decision 1 (contract v0.18.4): the service starts while the
      // app is on screen, so no ACCESS_BACKGROUND_LOCATION is asked.
      expect(declared, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });
  }
}
