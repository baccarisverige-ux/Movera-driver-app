import 'package:flutter/foundation.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// Driver setting "Show traffic on map" (R13-17). ON by default.
///
/// Only the trip map reads it: when on, Google's traffic colours draw on top
/// of the Movera map style. Every other map keeps traffic off.
abstract final class MapTrafficSetting {
  static const String section = 'map';
  static const String key = 'showTraffic';
  static const bool defaultValue = true;

  /// Current value; the trip map and the Settings switch read this.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(defaultValue);

  /// Loads the saved choice. A missing or unreadable value keeps the default.
  static Future<bool> restore([SettingsRepository? repository]) async {
    try {
      final saved = (await (repository ?? SettingsRepository()).read(
        section,
      ))[key];
      enabled.value = saved is bool ? saved : defaultValue;
    } catch (_) {
      enabled.value = defaultValue;
    }
    return enabled.value;
  }

  /// Applies [value] now and saves it.
  static Future<void> set(bool value, [SettingsRepository? repository]) {
    enabled.value = value;
    return (repository ?? SettingsRepository()).save(section, {key: value});
  }

  /// Back to the default, e.g. after local data is cleared on sign-out.
  static void reset() => enabled.value = defaultValue;
}
