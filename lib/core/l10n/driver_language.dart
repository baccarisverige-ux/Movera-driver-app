import 'package:flutter/widgets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// The driver app's language (Round 4, owner Q48/Q49).
///
/// Until a language is picked the app speaks the phone's language
/// ([applyDevice], owner 2026-11-10: French phone → fr, Swedish → sv,
/// anything else → en). The driver can pick another one (sign-in globe, Settings,
/// details step); that choice is saved on this phone and wins.
abstract final class DriverLanguage {
  static const String section = 'language';
  static const String key = 'code';

  /// The app's languages, in the order every list shows them (owner G1-B5
  /// "Same in both": Svenska, Français, English, as the rider app).
  static const List<String> supported = <String>['sv', 'fr', 'en'];

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
  static String? _firstOpen;
  static List<String> _available = supported;

  /// Contract v0.18.2 `auth.firstLanguage.fallback`.
  static const String fallback = 'en';

  /// The language before any pick (owner 2026-11-10): the phone's
  /// language when it is sv, fr or en; anything else is English. The start
  /// country no longer decides (a French phone in Tunis opened in Swedish).
  static String firstLanguage({String? phoneLanguage, String? startCountry}) =>
      _usable(phoneLanguage ?? '') ?? fallback;

  /// The app opens in the phone's language ([firstLanguage]) until the
  /// person picks one (the globe button, Settings, the details step). The
  /// picked language is kept and wins.
  static void applyDevice({String? phoneLanguage, String? startCountry}) {
    _firstOpen = firstLanguage(phoneLanguage: phoneLanguage);
    _apply();
  }

  static _DeviceLocaleObserver? _observer;

  /// Follows the phone's language: on Android the engine can report the
  /// locales only after `main` has read them, so a later report (or a
  /// change in the phone's settings) is applied too. A pick still wins.
  static void followDevice([String? Function()? read]) {
    final reader =
        read ??
        () => WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final old = _observer;
    if (old != null) WidgetsBinding.instance.removeObserver(old);
    final observer = _DeviceLocaleObserver((locales) {
      String? code = locales == null || locales.isEmpty
          ? null
          : locales.first.languageCode;
      if (code == null) {
        try {
          code = reader();
        } catch (_) {
          code = null;
        }
      }
      applyDevice(phoneLanguage: code);
    });
    _observer = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

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

  /// A live build: saves a pick to the account too (contract v0.18.12,
  /// `PATCH /driver/profile { language }`); null in the demo and tests.
  static Future<void> Function(String code)? saveToAccount;

  /// The driver picks [code] in Settings: used now and saved.
  static Future<void> choose(String code, [SettingsRepository? repository]) {
    final usable = _usable(code);
    if (usable == null) {
      return Future<void>.error(ArgumentError.value(code, 'code'));
    }
    _choice = usable;
    _apply();
    saveToAccount?.call(usable).ignore();
    return (repository ?? SettingsRepository()).save(section, {key: usable});
  }

  /// The account's language (`Driver.language`): used when nothing was
  /// picked on this phone (contract v0.18.2 `auth.firstLanguage`: the
  /// phone's language only until a pick or the account has one). Not
  /// saved; a pick here still wins.
  static void useAccount(String? code) {
    if (_choice != null || code == null) return;
    final usable = _usable(code);
    if (usable == null) return;
    _choice = usable;
    _apply();
  }

  /// Tests: no zone, no choice, English.
  @visibleForTesting
  static void resetForTest() {
    _zoneDefault = 'en';
    _available = supported;
    _choice = null;
    _firstOpen = null;
    final old = _observer;
    if (old != null) WidgetsBinding.instance.removeObserver(old);
    _observer = null;
    _apply();
  }

  static String? _usable(String code) {
    final lower = code.trim().toLowerCase();
    return supported.contains(lower) ? lower : null;
  }

  static void _apply() {
    final code = _choice ?? _firstOpen ?? _zoneDefault;
    DriverAppTexts.language = code;
    current.value = code;
  }
}

class _DeviceLocaleObserver with WidgetsBindingObserver {
  _DeviceLocaleObserver(this._onChange);

  final void Function(List<Locale>? locales) _onChange;

  @override
  void didChangeLocales(List<Locale>? locales) => _onChange(locales);
}
