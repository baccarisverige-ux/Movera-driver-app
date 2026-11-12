import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/zones/driver_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last `GET /driver/zones` answer, kept on the device.
abstract class DriverZonesCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> answer);
}

class PrefsDriverZonesCache implements DriverZonesCache {
  const PrefsDriverZonesCache();

  static const key = 'movera_driver_zones_v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<void> write(Map<String, dynamic> answer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(answer));
  }
}

class MemoryDriverZonesCache implements DriverZonesCache {
  Map<String, dynamic>? answer;

  @override
  Future<Map<String, dynamic>?> read() async => answer;

  @override
  Future<void> write(Map<String, dynamic> answer) async {
    this.answer = answer;
  }
}

/// Zones from the server (contract v0.11.0 §21): `GET /driver/zones` on
/// start and on `config_published` with doc `zones` ([LiveDriverConfig]
/// hears it); the last answer is kept on the device and used until the
/// server answers ([DriverZones.useServer]). Live builds only: the demo
/// keeps its own zone. Never throws to its callers.
class LiveDriverZones extends ChangeNotifier {
  LiveDriverZones({
    required ApiClient api,
    DriverZonesCache? cache,
    List<Duration>? retryDelays,
    DateTime Function()? now,
  }) : _api = api,
       _cache = cache ?? const PrefsDriverZonesCache(),
       retryDelays = retryDelays ?? defaultRetryDelays,
       _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Owner 2026-11-10: a failed read while a kept list is in use is tried
  /// again after each of these delays (bounded: 3 more tries).
  static const defaultRetryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final List<Duration> retryDelays;

  /// Owner 2026-11-10 (§21): reads the list again when the app comes back
  /// (G27: [refreshIfStale]). Called once per session (after [start]);
  /// [dispose] stops it.
  void watchResume() {
    if (_resume != null) return;
    try {
      _resume = AppLifecycleListener(
        onResume: () => unawaited(refreshIfStale()),
      );
    } on FlutterError catch (error) {
      // No Flutter binding (a pure Dart harness): nothing comes back.
      DriverLog.warn('driver_zones.resume_watch_skipped: $error');
    }
  }

  AppLifecycleListener? _resume;
  Timer? _retryTimer;
  int _retries = 0;

  static const path = '/api/v1/driver/zones';

  final ApiClient _api;
  final DriverZonesCache _cache;
  Future<bool>? _inFlight;

  /// The open zones of an answer `{ zones: Zone[] }`; null when it is not
  /// one. A zone that does not parse is left out.
  static List<DriverZone>? parse(Object? answer) {
    if (answer is! Map) return null;
    final raw = answer['zones'];
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map && item['open'] != false) ?DriverZone.fromJson(item),
    ];
  }

  /// The kept answer, then the server's.
  Future<void> start() async {
    try {
      final zones = parse(await _cache.read());
      if (zones != null) _use(zones);
    } catch (error) {
      DriverLog.warn('driver_zones.cache_read_failed: $error');
    }
    await refresh();
  }

  /// G27: a resume reads the list again only after this long (a `zones`
  /// publish on the settings stream still reads at once).
  static const resumeAfter = Duration(seconds: 60);

  /// The last answered read.
  DateTime? _readAt;

  /// G27: [refresh] unless the list was read in the last [resumeAfter] (a
  /// failed read does not count); true when it is current.
  Future<bool> refreshIfStale() {
    final read = _readAt;
    if (read != null && _now().difference(read) < resumeAfter) {
      return Future<bool>.value(true);
    }
    return refresh();
  }

  /// Asks the server; concurrent calls share one request. True when read.
  Future<bool> refresh() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<bool> _fetch({bool retry = false}) async {
    try {
      final zones = parse(await _api.get(path));
      if (zones == null) throw const FormatException('not a zones answer');
      _readAt = _now();
      _use(zones);
      _retryTimer?.cancel();
      _retryTimer = null;
      _retries = 0;
      try {
        await _cache.write({
          'zones': [for (final zone in zones) zone.toJson()],
        });
      } catch (error) {
        DriverLog.warn('driver_zones.cache_write_failed: $error');
      }
      return true;
    } catch (error) {
      DriverLog.warn('driver_zones.fetch_failed: $error');
      if (!retry) _retries = 0;
      _scheduleRetry();
      return false;
    }
  }

  /// Owner 2026-11-10: the kept list stays in use when a read fails, so it
  /// is read again after a short delay (bounded by [retryDelays]) instead
  /// of keeping an old list silently.
  void _scheduleRetry() {
    if (DriverZones.server == null || _retryTimer != null) return;
    if (_retries >= retryDelays.length) return;
    _retryTimer = Timer(retryDelays[_retries++], () {
      _retryTimer = null;
      unawaited(
        _inFlight ??= _fetch(retry: true).whenComplete(() => _inFlight = null),
      );
    });
  }

  @override
  void dispose() {
    _resume?.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _use(List<DriverZone> zones) {
    DriverZones.useServer(zones);
    notifyListeners();
  }
}
