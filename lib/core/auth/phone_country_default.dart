import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/zones/driver_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone field's starting country (contract v0.18.2
/// `auth.startCountry`, owner 2026-10-30 "France or sweden"): Sweden (+46)
/// or France (+33) only, from the last good fix, else the last zone, else
/// the device's region; else Sweden. No location prompt for it.
PhoneCountry defaultPhoneCountry({
  String? lastFix,
  String? lastZone,
  String? localeRegion,
}) => PhoneCountries.startFor(
  lastFix: lastFix ?? StartCountryHints.fixCountry,
  lastZone: lastZone ?? StartCountryHints.zoneCountry,
  deviceRegion: localeRegion ?? deviceRegion(),
);

/// The country of the device's locale ("SE" in sv-SE or en-SE), or null.
String? deviceRegion() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  } catch (_) {
    return null;
  }
}

/// The language of the device's locale ("fr" in fr-SE), or null.
String? deviceLanguage() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  } catch (_) {
    return null;
  }
}

/// What this phone already knows about where the driver works, read once
/// at start from what earlier sessions kept: the country of the zone
/// holding the last saved position, and the country of the last settings
/// document (its zone). Nothing is asked from the server or the GPS.
abstract final class StartCountryHints {
  static String? _fix;
  static String? _zone;

  /// The country (ISO) of the zone around the last good fix, or null.
  static String? get fixCountry => _fix;

  /// The country (ISO) of the last zone the driver worked in, or null.
  static String? get zoneCountry => _zone;

  /// Reads the kept position, zones and settings. Never throws.
  static Future<void> load({
    Future<SharedPreferences> Function()? prefs,
  }) async {
    try {
      final store = await (prefs ?? SharedPreferences.getInstance)();
      final zones = _zones(store.getString(PrefsDriverZonesCache.key));
      _fix = _fixCountry(store.getString(DriverStartPosition.key), zones);
      _zone = _zoneCountry(store.getString(PrefsDriverConfigCache.key), zones);
    } catch (_) {
      _fix = null;
      _zone = null;
    }
  }

  /// Tests: nothing known.
  @visibleForTesting
  static void reset() {
    _fix = null;
    _zone = null;
  }

  static List<DriverZone> _zones(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return LiveDriverZones.parse(jsonDecode(raw)) ?? const [];
    } on FormatException {
      return const [];
    }
  }

  static String? _fixCountry(String? raw, List<DriverZone> zones) {
    if (raw == null || raw.isEmpty) return null;
    final point = jsonDecode(raw);
    if (point is! Map) return null;
    final lat = point['lat'], lng = point['lng'];
    if (lat is! num || lng is! num) return null;
    DriverZone? best;
    for (final zone in zones) {
      if (!zone.contains(lat.toDouble(), lng.toDouble())) continue;
      if (best == null || zone.area < best.area) best = zone;
    }
    return best?.country;
  }

  static String? _zoneCountry(String? raw, List<DriverZone> zones) {
    if (raw == null || raw.isEmpty) return null;
    final document = jsonDecode(raw);
    if (document is! Map) return null;
    final country = document['country'];
    if (country is String && country.trim().isNotEmpty) return country;
    final zoneId = document['zoneId'];
    for (final zone in zones) {
      if (zone.id == zoneId) return zone.country;
    }
    return null;
  }
}
