import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/logging/driver_log.dart';

class DriverLocationException implements Exception {
  const DriverLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// driver-u24: location is allowed but only approximately (Android 12+
/// "Approximate", iOS 14+ "Precise Location" off). Every such fix is
/// kilometres wide and fails the 50 m gate, so the driver must be asked to
/// turn precise location on instead of waiting for a fix that never comes.
class PreciseLocationRequiredException extends DriverLocationException {
  const PreciseLocationRequiredException()
    : super('Precise location is turned off.');
}

class DriverLocationService implements DriverLocationRepository {
  const DriverLocationService();

  static const Duration _oneShotLimit = Duration(seconds: 8);

  LocationSettings get _settings => LocationSettings(
    accuracy: kIsWeb
        ? LocationAccuracy.high
        : LocationAccuracy.bestForNavigation,
    timeLimit: _oneShotLimit,
  );

  /// The app's page in the device settings, where precise location is
  /// turned on.
  static Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (error) {
      DriverLog.warn('Could not open app settings: $error');
      return false;
    }
  }

  @override
  Future<DriverLocation> getCurrentPosition() async {
    await _ensurePermission();

    try {
      // driver-18: the plugin's timeLimit alone is not enough. On web,
      // geolocator_web passes it to the browser in the wrong unit (8 s
      // becomes 8,000 s) and adds no timeout of its own, so a browser that
      // never answers would block Home and the trip. Enforce it here too.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      ).timeout(_oneShotLimit);
      return _toDriverLocation(position);
    } catch (error, stack) {
      DriverLog.warn('Current GPS failed, trying last known: $error');
      final last = await Geolocator.getLastKnownPosition();
      final fallback = vetCachedFix(
        last == null ? null : _toDriverLocation(last),
        DateTime.now(),
      );
      if (fallback != null) {
        return fallback;
      }
      DriverLog.error('No recent accurate GPS fix available', error, stack);
      rethrow;
    }
  }

  /// Do not navigate from a stale or inaccurate cached fix when live GPS
  /// times out. Callers handle the original GPS error as unavailable location.
  @visibleForTesting
  static DriverLocation? vetCachedFix(DriverLocation? fix, DateTime now) =>
      fix != null && fix.isUsableAt(now) ? fix : null;

  LocationSettings _streamSettings(int distanceFilterMeters) {
    final navigation = distanceFilterMeters == 0;
    if (kIsWeb || !navigation) {
      return LocationSettings(
        accuracy: kIsWeb
            ? LocationAccuracy.high
            : LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) async* {
    await _ensurePermission();

    yield* Geolocator.getPositionStream(
      locationSettings: _streamSettings(distanceFilterMeters),
    ).map(_toDriverLocation);
  }

  DriverLocation _toDriverLocation(Position position) {
    return DriverLocation(
      point: GeoPoint(position.latitude, position.longitude),
      headingDegrees: position.heading,
      speedMetersPerSecond: position.speed,
      measuredAt: position.timestamp,
      accuracyMeters: position.accuracy,
    );
  }

  Future<void> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const DriverLocationException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const DriverLocationException('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const DriverLocationException(
        'Location permission is blocked in device settings.',
      );
    }

    // Browsers have no approximate mode and the web plugin cannot tell.
    if (kIsWeb) return;
    LocationAccuracyStatus accuracy;
    try {
      accuracy = await Geolocator.getLocationAccuracy();
    } catch (error) {
      DriverLog.warn('Location accuracy status unknown: $error');
      return;
    }
    if (accuracy == LocationAccuracyStatus.reduced) {
      throw const PreciseLocationRequiredException();
    }
  }
}
