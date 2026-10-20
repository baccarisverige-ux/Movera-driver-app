import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';

/// One ride category of the zone (`catalog.categories[]`).
class DriverAppCategory {
  const DriverAppCategory({
    required this.id,
    required this.label,
    this.seats,
    this.sort,
  });

  final String id;
  final String label;
  final int? seats;
  final int? sort;
}

/// `DriverAppConfig` (contract §6), the per-zone document the admin app
/// exports for the driver app.
///
/// [DriverAppConfig.fromJson] never throws: unknown keys are ignored, and a
/// missing or broken value falls back to the app's seed. Money must be in
/// the document's currency; a seed amount in another currency is never
/// mixed in (that value becomes zero in the document's currency).
class DriverAppConfig {
  const DriverAppConfig({
    this.version = 0,
    this.publishedAt,
    this.zoneId = DriverZones.defaultId,
    this.currency = 'SEK',
    this.timeZone = 'Europe/Stockholm',
    this.categories = const <DriverAppCategory>[],
    this.features = const <String, bool>{},
    this.waiting = const WaitingRules(),
    this.destinationMode = const DestinationModeRules(),
    this.nextTrips = const NextTripRules(),
    this.cancelReasons = const <String, List<String>>{},
    this.minimumVersion = '1.0.0',
    this.latestVersion = '1.0.0',
    this.country = 'SE',
    this.languages = const AppLanguages(
      rider: 'sv',
      driver: 'sv',
      admin: 'sv',
    ),
    this.paymentMethods = ZoneDefaults.paymentMethods,
    this.maxStops = ZoneDefaults.maxStops,
    this.maxPickupMoveMeters = ZoneDefaults.maxPickupMoveMeters,
    this.autoOffline = true,
    this.missedExclusiveBeforeOffline =
        ZoneDefaults.missedExclusiveBeforeOffline,
    this.driverBonus,
  });

  final int version;
  final DateTime? publishedAt;
  final String zoneId;
  final String currency;
  final String timeZone;
  final List<DriverAppCategory> categories;
  final Map<String, bool> features;
  final WaitingRules waiting;
  final DestinationModeRules destinationMode;
  final NextTripRules nextTrips;

  /// Codes per group (`driverBeforeTrip`, `noShow`, …); titles come from
  /// the texts. Empty = the app's own lists.
  final Map<String, List<String>> cancelReasons;
  final String minimumVersion;
  final String latestVersion;

  /// ISO 3166 country of the zone (`SE`, `FR`, `TN`), contract v0.4.0.
  final String country;

  /// App languages and the country's default per app (Q48/Q49).
  final AppLanguages languages;

  /// Zone payment methods (`cash`, `card`, `apple_pay`, `google_pay`; Q7).
  final List<String> paymentMethods;

  /// `booking.maxStops` (Q39).
  final int maxStops;

  /// `booking.maxPickupMoveMeters`: how far the rider may move the pickup
  /// after accept; the driver is notified (Q40).
  final int maxPickupMoveMeters;

  /// `offers.autoOffline`: offline after this many missed or declined
  /// Exclusive offers in a row (Q46).
  final bool autoOffline;
  final int missedExclusiveBeforeOffline;

  /// `driverBonus` limits in the zone's currency (Q17); null = the
  /// country defaults ([driverBonusLimits]).
  final DriverBonusLimits? driverBonus;

  /// The bonus limits of the zone, the defaults when the document has none.
  DriverBonusLimits get driverBonusLimits =>
      driverBonus ?? DriverBonusLimits.defaultsIn(currency);

  bool feature(String key, {bool fallback = false}) =>
      features[key] ?? fallback;

  factory DriverAppConfig.fromJson(Object? json) {
    const seed = DriverAppConfig();
    if (json is! Map) return seed;
    final currencyRaw = json['currency'];
    final currency =
        currencyRaw is String && Money.exponents.containsKey(currencyRaw)
            ? currencyRaw
            : seed.currency;
    final zone = json['zoneId'];
    final time = json['timeZone'];
    final published = json['publishedAt'];
    final update = _map(json['appUpdate']);
    final countryRaw = json['country'];
    final country =
        countryRaw is String && RegExp(r'^[A-Z]{2}$').hasMatch(countryRaw)
        ? countryRaw
        : ZoneDefaults.countryOf(currency);
    final booking = _map(json['booking']);
    final autoOffline = _map(_map(json['offers'])?['autoOffline']);
    final missed = _int(autoOffline?['missedExclusive']);
    return DriverAppConfig(
      version: _int(json['version']) ?? seed.version,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      zoneId: zone is String && zone.trim().isNotEmpty
          ? DriverZones.canonical(zone.trim())
          : seed.zoneId,
      currency: currency,
      timeZone: time is String && time.isNotEmpty ? time : seed.timeZone,
      categories: _categories(_map(json['catalog'])?['categories']),
      features: {
        for (final entry in (_map(json['features']) ?? const {}).entries)
          if (entry.key is String && entry.value is bool)
            entry.key as String: entry.value as bool,
      },
      waiting: _waiting(_map(json['waiting']), currency),
      destinationMode: DestinationModeRules.fromJson(json['destinationMode']),
      nextTrips: NextTripRules.fromJson(json['nextTrips']),
      cancelReasons: {
        for (final entry in (_map(json['cancelReasons']) ?? const {}).entries)
          if (entry.key is String && entry.value is List)
            entry.key as String: [
              for (final code in entry.value as List)
                if (code is String && _code.hasMatch(code)) code,
            ],
      },
      minimumVersion: _string(update?['minimumVersion']) ?? seed.minimumVersion,
      latestVersion: _string(update?['latestVersion']) ?? seed.latestVersion,
      country: country,
      languages: AppLanguages.fromJson(json['languages'], country),
      paymentMethods: ZoneDefaults.readPaymentMethods(json['paymentMethods']),
      maxStops: _bounded(booking?['maxStops'], 10) ?? seed.maxStops,
      maxPickupMoveMeters: _bounded(booking?['maxPickupMoveMeters'], 100000) ??
          seed.maxPickupMoveMeters,
      autoOffline: autoOffline?['on'] is bool
          ? autoOffline!['on'] as bool
          : seed.autoOffline,
      missedExclusiveBeforeOffline: missed != null && missed >= 1 && missed <= 99
          ? missed
          : seed.missedExclusiveBeforeOffline,
      driverBonus: _bonus(_map(json['driverBonus']), currency),
    );
  }

  /// Puts this zone's rules in use where the app reads them.
  void apply() {
    WaitingRules.current = waiting;
    DestinationModeRules.current = destinationMode;
    NextTripRules.current = nextTrips;
  }

  /// The ids of [categories], or the seed ids when the document has none.
  List<String> get categoryIds => categories.isEmpty
      ? CategoryCatalog.seed
      : [for (final category in categories) category.id];

  static final RegExp _code = RegExp(r'^[a-z][a-z0-9_]{1,63}$');
}

List<DriverAppCategory> _categories(Object? json) {
  if (json is! List) return const <DriverAppCategory>[];
  final seen = <String>{};
  return [
    for (final item in json)
      if (item is Map &&
          item['id'] is String &&
          CategoryCatalog.canonicalId(item['id'] as String) != null &&
          seen.add(CategoryCatalog.canonicalId(item['id'] as String)!))
        DriverAppCategory(
          id: CategoryCatalog.canonicalId(item['id'] as String)!,
          label: _string(item['label']) ??
              CategoryCatalog.labelOf(item['id'] as String),
          seats: _int(item['seats']),
          sort: _int(item['sort']),
        ),
  ];
}

WaitingRules _waiting(Map<dynamic, dynamic>? json, String currency) {
  const seed = WaitingRules();
  final base = seed.base;
  if (json == null) {
    return WaitingRules(
      base: _rebaseTerms(base, currency),
      farPickupKm: seed.farPickupKm,
      farPickup: _rebase(seed.farPickup, currency),
      rideTypes: {
        for (final entry in seed.rideTypes.entries)
          entry.key: _rebase(entry.value, currency),
      },
      categories: {
        for (final entry in seed.categories.entries)
          entry.key: _rebase(entry.value, currency),
      },
    );
  }
  final terms = WaitingTerms(
    freeMinutes: _int(json['freeWaitMin']) ?? base.freeMinutes,
    perMinute: _money(json['perMin'], currency) ??
        _sameCurrency(base.perMinute, currency),
    noShowAfterMinutes: _int(json['noShowAfterMin']) ?? base.noShowAfterMinutes,
    noShowFee: _money(json['noShowFee'], currency) ??
        _sameCurrency(base.noShowFee, currency),
    driverShareWaitPercent:
        _percent(json['driverShareWaitPct']) ?? base.driverShareWaitPercent,
    driverShareNoShowPercent:
        _percent(json['driverSharePct']) ?? base.driverShareNoShowPercent,
  );

  final far = _map(json['farPickup']);
  final farOn = far?['on'] is bool ? far!['on'] as bool : true;
  final farKm = far?['km'];

  final types = _map(json['rideTypes']);
  final rideTypes = <WaitingRideType, WaitingRule>{};
  for (final entry in seed.rideTypes.entries) {
    final raw = _map(types?[entry.key.name]);
    if (raw == null) {
      rideTypes[entry.key] = _rebase(entry.value, currency);
    } else if (raw['on'] != false) {
      rideTypes[entry.key] = _rule(raw, entry.value.label, currency);
    }
  }

  final byCategory = _map(json['byCategory']);
  final categories = <String, WaitingRule>{};
  if (byCategory == null) {
    for (final entry in seed.categories.entries) {
      categories[entry.key] = _rebase(entry.value, currency);
    }
  } else {
    for (final entry in byCategory.entries) {
      final id = entry.key is String
          ? CategoryCatalog.canonicalId(entry.key as String)
          : null;
      final raw = _map(entry.value);
      if (id == null || raw == null) continue;
      // Only what differs from the zone's terms is a rule for this category.
      final rule = _rule(raw, CategoryCatalog.labelOf(id), currency);
      final changed = WaitingRule(
        label: rule.label,
        freeMinutes:
            rule.freeMinutes == terms.freeMinutes ? null : rule.freeMinutes,
        perMinute: rule.perMinute == terms.perMinute ? null : rule.perMinute,
        noShowAfterMinutes: rule.noShowAfterMinutes == terms.noShowAfterMinutes
            ? null
            : rule.noShowAfterMinutes,
        noShowFee: rule.noShowFee == terms.noShowFee ? null : rule.noShowFee,
      );
      if (changed.freeMinutes != null ||
          changed.perMinute != null ||
          changed.noShowAfterMinutes != null ||
          changed.noShowFee != null) {
        categories[id] = changed;
      }
    }
  }

  return WaitingRules(
    base: terms,
    farPickupKm: !farOn
        ? double.infinity
        : farKm is num && farKm.isFinite && farKm > 0
            ? farKm.toDouble()
            : seed.farPickupKm,
    farPickup: far == null
        ? _rebase(seed.farPickup, currency)
        : _rule(far, seed.farPickup.label, currency),
    rideTypes: rideTypes,
    categories: categories,
  );
}

/// A rule from `{freeWaitMin, perMin, noShowAfterMin, noShowFee}`; a
/// missing or null value leaves that part unchanged.
WaitingRule _rule(Map<dynamic, dynamic> json, String label, String currency) =>
    WaitingRule(
      label: label,
      freeMinutes: _int(json['freeWaitMin']),
      perMinute: _money(json['perMin'], currency),
      noShowAfterMinutes: _int(json['noShowAfterMin']),
      noShowFee: _money(json['noShowFee'], currency),
    );

/// A seed rule without amounts in another currency.
WaitingRule _rebase(WaitingRule rule, String currency) => WaitingRule(
  label: rule.label,
  freeMinutes: rule.freeMinutes,
  perMinute: rule.perMinute?.currency == currency ? rule.perMinute : null,
  noShowAfterMinutes: rule.noShowAfterMinutes,
  noShowFee: rule.noShowFee?.currency == currency ? rule.noShowFee : null,
);

WaitingTerms _rebaseTerms(WaitingTerms terms, String currency) => WaitingTerms(
  freeMinutes: terms.freeMinutes,
  perMinute: _sameCurrency(terms.perMinute, currency),
  noShowAfterMinutes: terms.noShowAfterMinutes,
  noShowFee: _sameCurrency(terms.noShowFee, currency),
  driverShareWaitPercent: terms.driverShareWaitPercent,
  driverShareNoShowPercent: terms.driverShareNoShowPercent,
);

Money _sameCurrency(Money seed, String currency) =>
    seed.currency == currency ? seed : Money(minorUnits: 0, currency: currency);

/// Contract Money in [currency]; null for anything else.
Money? _money(Object? json, String currency) {
  if (json is! Map) return null;
  try {
    final money = Money.fromJson(Map<String, dynamic>.from(json));
    return money.currency == currency && money.minorUnits >= 0 ? money : null;
  } on Object {
    return null;
  }
}

Map<dynamic, dynamic>? _map(Object? json) => json is Map ? json : null;

/// A whole number from 0 to [max]; null for anything else (a fraction too).
int? _bounded(Object? json, int max) =>
    json is int && json >= 0 && json <= max ? json : null;

/// Both limits in [currency], positive, the limit not above the hard max;
/// else null (the country defaults apply).
DriverBonusLimits? _bonus(Map<dynamic, dynamic>? json, String currency) {
  if (json == null) return null;
  final limit = _money(json['defaultLimit'], currency);
  final max = _money(json['hardMax'], currency);
  if (limit == null ||
      max == null ||
      limit.minorUnits <= 0 ||
      limit.minorUnits > max.minorUnits) {
    return null;
  }
  return DriverBonusLimits(defaultLimit: limit, hardMax: max);
}

String? _string(Object? json) =>
    json is String && json.trim().isNotEmpty ? json.trim() : null;

int? _int(Object? json) =>
    json is num && json.isFinite && json >= 0 ? json.round() : null;

int? _percent(Object? json) {
  final value = _int(json);
  return value != null && value <= 100 ? value : null;
}
