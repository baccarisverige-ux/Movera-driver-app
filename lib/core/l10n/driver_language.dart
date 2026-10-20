import 'package:flutter/foundation.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// The driver app's language (Round 4, owner Q48/Q49).
///
/// The zone's `languages.default.driver` is the default (`sv` in Sweden,
/// `fr` in France and Tunisia). The driver can pick another one in
/// Settings; that choice is saved on this phone and wins over the default.
abstract final class DriverLanguage {
  static const String section = 'language';
  static const String key = 'code';

  /// The app's languages, in the order Settings lists them.
  static const List<String> supported = <String>['fr', 'sv', 'en'];

  /// Each language in its own words, for the Settings list.
  static const Map<String, String> names = <String, String>{
    'en': 'English',
    'fr': 'Français',
    'sv': 'Svenska',
  };

  /// "FR · Français".
  static String label(String code) =>
      '${code.toUpperCase()} · ${names[code] ?? code}';

  /// The language in use. The app root listens and rebuilds on a change.
  static final ValueNotifier<String> current = ValueNotifier<String>(
    DriverAppTexts.language,
  );

  static String _zoneDefault = 'en';
  static String? _choice;
  static List<String> _available = supported;

  /// The zone's default for the driver app.
  static String get zoneDefault => _zoneDefault;

  /// The driver's saved choice, or null when they never picked one.
  static String? get choice => _choice;

  /// What Settings offers: the zone's languages (all three by default).
  static List<String> get available => [
    for (final code in supported)
      if (_available.contains(code)) code,
  ];

  /// Takes the zone's languages. The driver's choice still wins.
  static void applyZone(AppLanguages languages) {
    final usable = languages.available.where(supported.contains).toList();
    _available = usable.isEmpty ? supported : usable;
    _zoneDefault = _usable(languages.driver) ?? _available.first;
    _apply();
  }

  /// Loads the saved choice. A missing, unknown or unreadable value
  /// leaves the zone default.
  static Future<String> restore([SettingsRepository? repository]) async {
    try {
      final saved = (await (repository ?? SettingsRepository()).read(
        section,
      ))[key];
      _choice = saved is String ? _usable(saved) : null;
    } catch (_) {
      _choice = null;
    }
    _apply();
    return current.value;
  }

  /// The driver picks [code] in Settings: used now and saved.
  static Future<void> choose(String code, [SettingsRepository? repository]) {
    final usable = _usable(code);
    if (usable == null) {
      return Future<void>.error(ArgumentError.value(code, 'code'));
    }
    _choice = usable;
    _apply();
    return (repository ?? SettingsRepository()).save(section, {key: usable});
  }

  /// Back to the zone default, e.g. after local data is cleared on
  /// sign-out (the saved choice is cleared with the other settings).
  static void reset() {
    _choice = null;
    _apply();
  }

  /// Tests: no zone, no choice, English.
  @visibleForTesting
  static void resetForTest() {
    _zoneDefault = 'en';
    _available = supported;
    _choice = null;
    _apply();
  }

  static String? _usable(String code) {
    final lower = code.trim().toLowerCase();
    return supported.contains(lower) ? lower : null;
  }

  static void _apply() {
    final code = _choice ?? _zoneDefault;
    DriverAppTexts.language = code;
    current.value = code;
  }
}
