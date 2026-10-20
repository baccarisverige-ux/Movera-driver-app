import 'package:movera/core/money/money.dart';

/// App languages (`languages`, contract v0.4.0, owner Q48/Q49): what the
/// user may pick and the country's default per app.
class AppLanguages {
  const AppLanguages({
    this.available = ZoneDefaults.languages,
    required this.rider,
    required this.driver,
    required this.admin,
  });

  final List<String> available;
  final String rider;
  final String driver;
  final String admin;

  factory AppLanguages.forCountry(String country) {
    final lang = ZoneDefaults.languageOf(country);
    return AppLanguages(rider: lang, driver: lang, admin: lang);
  }

  /// `languages`; the country's defaults for anything missing or unknown.
  factory AppLanguages.fromJson(Object? json, String country) {
    final fallback = AppLanguages.forCountry(country);
    if (json is! Map) return fallback;
    final list = json['available'];
    final available = <String>[];
    for (final code in list is List ? list : const <Object?>[]) {
      if (code is String &&
          ZoneDefaults.languages.contains(code) &&
          !available.contains(code)) {
        available.add(code);
      }
    }
    final usable = available.isEmpty ? ZoneDefaults.languages : available;
    final defaults = json['default'];
    String pick(String app, String fallbackValue) {
      final value = defaults is Map ? defaults[app] : null;
      if (value is String && usable.contains(value)) return value;
      return usable.contains(fallbackValue) ? fallbackValue : usable.first;
    }

    return AppLanguages(
      available: List.unmodifiable(usable),
      rider: pick('rider', fallback.rider),
      driver: pick('driver', fallback.driver),
      admin: pick('admin', fallback.admin),
    );
  }
}

/// Movera-paid driver bonus limits per country (`driverBonus`, owner Q17).
class DriverBonusLimits {
  const DriverBonusLimits({required this.defaultLimit, required this.hardMax});

  /// Above this the admin is told to adjust the limit in Pricing.
  final Money defaultLimit;

  /// The limit can never be set above this.
  final Money hardMax;

  /// The country defaults in [currency] (contract.json#configDefaults).
  factory DriverBonusLimits.defaultsIn(String currency) {
    final (limit, max) = switch (currency) {
      'EUR' => (2000, 9500),
      'TND' => (60000, 300000),
      _ => (20000, 100000),
    };
    return DriverBonusLimits(
      defaultLimit: Money(minorUnits: limit, currency: currency),
      hardMax: Money(minorUnits: max, currency: currency),
    );
  }
}

/// `contract.json#configDefaults` (v0.4.0): what the app uses when the
/// document lacks a per-zone field or has a bad value. A contract test keeps
/// these equal to the contract.
abstract final class ZoneDefaults {
  static const languages = <String>['en', 'fr', 'sv'];

  /// `contract.json#zonePaymentMethods` (owner Q7). No Swish, no D17.
  static const paymentMethods = <String>[
    'cash',
    'card',
    'apple_pay',
    'google_pay',
  ];

  /// v0.3 ids read as their v0.4 names for one release.
  static const paymentMethodAliases = <String, String>{
    'apple': 'apple_pay',
    'google': 'google_pay',
  };

  static const maxStops = 3;
  static const maxPickupMoveMeters = 500;
  static const missedExclusiveBeforeOffline = 3;
  static const waitingDriverSharePct = 100;
  static const noShowDriverSharePct = 80;

  static String countryOf(String currency) => switch (currency) {
    'EUR' => 'FR',
    'TND' => 'TN',
    _ => 'SE',
  };

  static String languageOf(String country) => switch (country) {
    'SE' => 'sv',
    'FR' || 'TN' => 'fr',
    _ => 'en',
  };

  /// `paymentMethods` as zone methods (aliases resolved, `swish` and other
  /// unknown ids dropped); the defaults when nothing usable is listed.
  static List<String> readPaymentMethods(Object? json) {
    if (json is! List) return paymentMethods;
    final out = <String>[];
    for (final id in json) {
      if (id is! String) continue;
      final value = paymentMethodAliases[id.trim()] ?? id.trim();
      if (paymentMethods.contains(value) && !out.contains(value)) {
        out.add(value);
      }
    }
    return out.isEmpty ? paymentMethods : List.unmodifiable(out);
  }
}
