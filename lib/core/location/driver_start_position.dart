import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where Home's map opens: the driver's last known position, so the app
/// never starts on a city fallback and then jumps.
///
/// Saved from live fixes; read back on the next start. When nothing was
/// saved, the phone's own last known fix is used (not on web).
class DriverStartPosition {
  DriverStartPosition._();

  static const String key = 'driver_last_position_v1';

  /// Not written more often than this while driving.
  static const Duration saveEvery = Duration(seconds: 30);

  static GeoPoint? _memory;
  static DateTime? _lastSave;

  /// The position already known in this run, without waiting.
  static GeoPoint? get cached => _memory;

  /// Saved position first, then the platform's last known fix.
  static Future<GeoPoint?> load({
    Future<SharedPreferences> Function()? prefs,
    Future<GeoPoint?> Function()? platformLastKnown,
  }) async {
    final memory = _memory;
    if (memory != null) return memory;
    try {
      final raw = (await (prefs ?? SharedPreferences.getInstance)())
          .getString(key);
      final saved = _decode(raw);
      if (saved != null) return _memory = saved;
    } catch (_) {
      // Unreadable storage: fall through to the platform fix.
    }
    try {
      final platform = await (platformLastKnown ?? _platformLastKnown)();
      if (platform != null && platform.isValid) return _memory = platform;
    } catch (_) {
      // No platform fix; Home waits for live GPS.
    }
    return null;
  }

  /// Remembers [point]; writes to storage at most every [saveEvery].
  static Future<void> save(
    GeoPoint point, {
    DateTime? now,
    Future<SharedPreferences> Function()? prefs,
  }) async {
    if (!point.isValid) return;
    _memory = point;
    final at = now ?? DateTime.now();
    final last = _lastSave;
    if (last != null && at.difference(last) < saveEvery) return;
    _lastSave = at;
    try {
      await (await (prefs ?? SharedPreferences.getInstance)()).setString(
        key,
        jsonEncode(<String, double>{
          'lat': point.latitude,
          'lng': point.longitude,
        }),
      );
    } catch (_) {
      // Best effort: the next start just waits for GPS.
    }
  }

  /// Forgets the in-memory position (logout, tests).
  static void clearMemory() {
    _memory = null;
    _lastSave = null;
  }

  static GeoPoint? _decode(String? raw) {
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final lat = value['lat'], lng = value['lng'];
    if (lat is! num || lng is! num) return null;
    final point = GeoPoint(lat.toDouble(), lng.toDouble());
    return point.isValid ? point : null;
  }

  static Future<GeoPoint?> _platformLastKnown() async {
    // getLastKnownPosition is not supported on web.
    if (kIsWeb) return null;
    // No timeout: a late answer is ignored once GPS placed the map.
    final last = await Geolocator.getLastKnownPosition();
    return last == null ? null : GeoPoint(last.latitude, last.longitude);
  }
}
