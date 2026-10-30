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

/// driver-r5-51: the driver did not allow location. [forever]: the
/// device blocks the prompt (Settings is the only way back); otherwise
/// the app asks again only when the driver says so
/// ([DriverLocationService.allowPrompt]).
class LocationPermissionDeniedException extends DriverLocationException {
  const LocationPermissionDeniedException({this.forever = false})
    : super(
        forever
            ? 'Location permission is blocked in device settings.'
            : 'Location permission was denied.',
      );

  final bool forever;
}

class DriverLocationService implements DriverLocationRepository {
  const DriverLocationService();

  /// driver-r5-51: the system prompt now on screen; every caller waits
  /// for its answer instead of asking again (Android has no guard and
  /// would lose the earlier answers).
  static Future<LocationPermission>? _prompt;

  /// The driver answered "Don't allow" this session: no prompt comes
  /// back by itself (on Android a second decline blocks it for good).
  static bool _declined = false;

  /// The driver asked to allow location (a tap, not a resume): the next
  /// check may show the system prompt again.
  static void allowPrompt() => _declined = false;

  @visibleForTesting
  static void resetForTesting() {
    _prompt = null;
    _declined = false;
    _online = null;
  }

  static const Duration _oneShotLimit = Duration(seconds: 8);

  /// Driver group 3 (live test 2026-10-30, "position sent only once"): a
  /// browser one-shot with `maximumAge: 0` waits for a *new* position, and
  /// a laptop's network location gives a new one only when it moves, so
  /// every read after the first timed out. The browser may answer from
  /// its own fix of the last [webMaximumAge].
  static const Duration webMaximumAge = Duration(seconds: 30);

  LocationSettings get _settings => kIsWeb
      ? WebSettings(
          accuracy: LocationAccuracy.high,
          maximumAge: webMaximumAge,
          timeLimit: _oneShotLimit,
        )
      : LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
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
      final last = await _lastKnown();
      final fallback = vetCachedFix(
        last == null ? null : _toDriverLocation(last),
        DateTime.now(),
      );
      if (fallback != null) {
        return fallback;
      }
      // No signal, a timeout, location off or not allowed: the phone's
      // normal life, not an app fault, so no crash report (driver group 3:
      // one report a minute while online indoors).
      if (isNormalGpsFailure(error)) {
        DriverLog.warn('No recent accurate GPS fix: ${error.runtimeType}');
      } else {
        DriverLog.error('No recent accurate GPS fix available', error, stack);
      }
      rethrow;
    }
  }

  /// A GPS read that failed the way phones do (timeout, no signal,
  /// location off, not allowed), not through an app fault.
  @visibleForTesting
  static bool isNormalGpsFailure(Object error) =>
      error is TimeoutException ||
      error is PositionUpdateException ||
      error is LocationServiceDisabledException ||
      error is PermissionDeniedException ||
      error is PermissionRequestInProgressException ||
      error is DriverLocationException;

  /// The platform's cached fix, or null where it has none to give: web
  /// (geolocator_web throws UnsupportedError) must not replace the real
  /// GPS error with that one (driver-r4-22).
  static Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (error) {
      DriverLog.warn('No last known GPS fix: $error');
      return null;
    }
  }

  /// Do not navigate from a stale or inaccurate cached fix when live GPS
  /// times out. Callers handle the original GPS error as unavailable location.
  @visibleForTesting
  static DriverLocation? vetCachedFix(DriverLocation? fix, DateTime now) =>
      fix != null && fix.isUsableAt(now) ? fix : null;

  LocationSettings _streamSettings(int distanceFilterMeters) {
    final navigation = distanceFilterMeters == 0;
    final online = _online;
    if (online != null && !kIsWeb) {
      return onlineSettings(
        platform: defaultTargetPlatform,
        notificationTitle: online.title,
        notificationText: online.text,
        navigation: navigation,
      );
    }
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

  /// The open position streams. Android and iOS share ONE native stream
  /// between all listeners, made with the first listener's settings, so
  /// switching to the online (background) settings must close every
  /// listener before the first opens again ([setOnlineBackground]).
  static final Set<_PositionWatch> _watches = <_PositionWatch>{};

  /// The "Movera is online" notification while online; null offline.
  static ({String title, String text})? _online;

  /// Decision 1: while online every position stream keeps running with
  /// the phone locked (Android foreground service with [notification],
  /// iOS background location); null goes back to foreground only. The web
  /// has no background location; nothing changes there.
  static Future<void> setOnlineBackground(
    ({String title, String text})? notification,
  ) async {
    if (notification == _online) return;
    _online = notification;
    if (kIsWeb) return;
    final open = _watches.toList();
    for (final watch in open) {
      await watch.pause();
    }
    for (final watch in open) {
      if (_watches.contains(watch)) watch.resume();
    }
  }

  @visibleForTesting
  static bool get onlineBackground => _online != null;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) async* {
    await _ensurePermission();
    final watch = _PositionWatch(
      () => _streamSettings(distanceFilterMeters),
      _toDriverLocation,
    );
    _watches.add(watch);
    watch.output.onCancel = () {
      _watches.remove(watch);
      return watch.pause();
    };
    watch.resume();
    yield* watch.output.stream;
  }

  /// Owner decision 1 (driver group 3): the stream settings while online
  /// for [platform] (null: the web). Android runs geolocator's location
  /// foreground service with the persistent [notificationTitle]
  /// notification ("Movera is online"); iOS keeps the when-in-use session
  /// running in the background (`UIBackgroundModes location`, blue
  /// indicator). A browser cannot: a hidden tab stops sending, and the
  /// server sets the driver offline after `autoOffline.noFixMinutes`.
  @visibleForTesting
  static LocationSettings onlineSettings({
    required TargetPlatform? platform,
    required String notificationTitle,
    required String notificationText,
    bool navigation = false,
  }) {
    if (platform == null) {
      return WebSettings(
        accuracy: LocationAccuracy.high,
        maximumAge: webMaximumAge,
      );
    }
    if (platform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: navigation
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: navigation ? 1 : 5),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          notificationChannelName: notificationTitle,
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    }
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: navigation
            ? LocationAccuracy.bestForNavigation
            : LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
  }

  /// Decision 2: whether the phone's location is off or not allowed, read
  /// without asking (Go online is blocked then). Null: allowed and on.
  static Future<DriverLocationException?> locationBlock() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DriverLocationException(
          'Location services are turned off.',
        );
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        return const LocationPermissionDeniedException(forever: true);
      }
      if (permission == LocationPermission.denied && _declined) {
        return const LocationPermissionDeniedException();
      }
    } catch (error) {
      DriverLog.warn('Location state unknown: ${error.runtimeType}');
    }
    return null;
  }

  /// The phone's location settings (Android, iOS: the app's page when
  /// that is all the platform opens).
  static Future<bool> openLocationSettings() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return await Geolocator.openAppSettings();
      }
      return await Geolocator.openLocationSettings();
    } catch (error) {
      DriverLog.warn('Could not open location settings: $error');
      return false;
    }
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
      if (_declined) {
        throw const LocationPermissionDeniedException();
      }
      final prompt = _prompt ??= Geolocator.requestPermission().whenComplete(
        () => _prompt = null,
      );
      permission = await prompt;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _declined = true;
      }
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(forever: true);
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

/// One listener of [DriverLocationService.watchPosition]: its own output,
/// fed by the platform stream, which [pause] closes and [resume] opens
/// again with the settings of that moment.
class _PositionWatch {
  _PositionWatch(this._settings, this._map);

  final LocationSettings Function() _settings;
  final DriverLocation Function(Position) _map;
  final StreamController<DriverLocation> output =
      StreamController<DriverLocation>();
  StreamSubscription<Position>? _inner;

  void resume() {
    if (_inner != null || output.isClosed) return;
    _inner = Geolocator.getPositionStream(locationSettings: _settings()).listen(
      (position) => output.add(_map(position)),
      onError: output.addError,
    );
  }

  Future<void> pause() async {
    final inner = _inner;
    _inner = null;
    await inner?.cancel();
  }
}
