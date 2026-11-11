import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/location/driver_location_service.dart';

/// D12-9: the offline Home map no longer uses top (navigation) accuracy.
void main() {
  test('D12-9: Android offline: balanced, 20 s, 20 m', () {
    final s = DriverLocationService.offlineSettings(
      platform: TargetPlatform.android,
    );
    expect(s, isA<AndroidSettings>());
    s as AndroidSettings;
    expect(s.accuracy, LocationAccuracy.medium);
    expect(s.distanceFilter, 20);
    expect(s.intervalDuration, const Duration(seconds: 20));
  });

  test('D12-9: iOS offline: not BestForNavigation, 20 m', () {
    final s = DriverLocationService.offlineSettings(
      platform: TargetPlatform.iOS,
    );
    expect(s, isA<AppleSettings>());
    expect(s.accuracy, LocationAccuracy.medium);
    expect(s.distanceFilter, 20);
  });
}
