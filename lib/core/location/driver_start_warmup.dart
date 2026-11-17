import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';

/// Owner REMINDERS 144/145 (fast start behind the intro): the driver's
/// position is read while the intro shows, not after Home is built.
///
/// Only for a signed-in driver whose location is already allowed: the
/// check never shows a prompt (the first-time "Allow location?" flow stays
/// on Home). Home takes this one read instead of asking the GPS again, so
/// a start makes one position request, not two.
class DriverStartWarmup {
  DriverStartWarmup._();

  static Future<DriverLocation>? _pending;

  /// Starts the read when [signedIn] and [allowedWithoutAsking] are true.
  /// Never throws; a failed read fails only the future Home takes.
  static Future<void> start({
    required Future<bool> Function() signedIn,
    required Future<bool> Function() allowedWithoutAsking,
    required Future<DriverLocation> Function() read,
    void Function()? warmMap,
  }) async {
    try {
      if (!await signedIn()) return;
      // The map's script loads during the intro too (web: Maps JavaScript;
      // the sign-in screen still never waits for it, owner LT-4). Home's
      // one map uses it; no second map is made.
      try {
        warmMap?.call();
      } catch (_) {
        // The map asks again when it is on screen.
      }
      if (!await allowedWithoutAsking()) return;
      final pending = read();
      _pending = pending;
      unawaited(
        pending.then(
          (fix) => DriverStartPosition.save(fix.point),
          onError: (Object _) {},
        ),
      );
    } catch (_) {
      // No warm read: Home asks the GPS itself, as before.
    }
  }

  /// The warm read, once; null when none was started or it was taken.
  static Future<DriverLocation>? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  /// Location on and allowed, read without asking (on web through the
  /// browser's Permissions API, so no prompt).
  static Future<bool> allowedNow() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @visibleForTesting
  static void resetForTesting() => _pending = null;
}
