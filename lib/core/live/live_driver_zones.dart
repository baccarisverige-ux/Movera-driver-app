import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// Zones from the server (contract v0.11.0 §20): `GET /driver/zones` on
/// start and on `config_published` with doc `zones` ([LiveDriverConfig]
/// hears it); the last answer is kept on the device and used until the
/// server answers ([DriverZones.useServer]). Live builds only: the demo
/// keeps its own zone. Never throws to its callers.
class LiveDriverZones extends ChangeNotifier {
  LiveDriverZones({required ApiClient api, DriverZonesCache? cache})
    : _api = api,
      _cache = cache ?? const PrefsDriverZonesCache();

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

  /// Asks the server; concurrent calls share one request. True when read.
  Future<bool> refresh() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<bool> _fetch() async {
    try {
      final zones = parse(await _api.get(path));
      if (zones == null) throw const FormatException('not a zones answer');
      _use(zones);
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
      return false;
    }
  }

  void _use(List<DriverZone> zones) {
    DriverZones.useServer(zones);
    notifyListeners();
  }
}
