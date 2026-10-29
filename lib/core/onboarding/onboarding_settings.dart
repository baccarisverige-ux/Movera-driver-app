/// Contract v0.17.0 §25 (`contract.json#driverOnboarding.settings`), owner
/// decisions of 2026-10-29, driver group 2 items 1, 10, 11 and 14: the
/// admin's Drivers › Onboarding and Vehicles › Rules settings of the
/// driver's country, as `GET /driver/onboarding/settings` sends them. The
/// app follows them: the documents each account needs (with the admin's
/// own types and texts), which of them expire and when the warnings come,
/// and the car categories a car fits.
library;

import 'package:flutter/foundation.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];

int _whole(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// `LocalText { sv, fr, en }`.
@immutable
class LocalText {
  const LocalText({this.sv, this.fr, this.en});

  static LocalText? fromJson(Object? json) {
    final map = _map(json);
    final text = LocalText(
      sv: _text(map['sv']),
      fr: _text(map['fr']),
      en: _text(map['en']),
    );
    return text.isEmpty ? null : text;
  }

  final String? sv;
  final String? fr;
  final String? en;

  bool get isEmpty => sv == null && fr == null && en == null;

  /// The text in [language], else English, else any.
  String? inLanguage(String language) =>
      switch (language) {
        'sv' => sv,
        'fr' => fr,
        _ => en,
      } ??
      en ??
      sv ??
      fr;
}

/// `DocumentTypeInfo`: one type of the country's lists, a contract type
/// with the admin's texts or a type the admin made (`custom_…`).
@immutable
class OnboardingDocumentType {
  const OnboardingDocumentType({
    required this.type,
    required this.owner,
    required this.kind,
    required this.expires,
    this.custom = false,
    this.name,
    this.help,
  });

  factory OnboardingDocumentType.fromJson(
    String type,
    Map<String, dynamic> json,
  ) => OnboardingDocumentType(
    type: type,
    owner: _text(json['owner']) ?? 'driver',
    kind: switch (json['kind']) {
      'acceptance' => DocumentKind.acceptance,
      'admin_check' => DocumentKind.adminCheck,
      _ => DocumentKind.file,
    },
    expires: json['expires'] == true,
    custom: json['custom'] == true || type.startsWith('custom_'),
    name: LocalText.fromJson(json['name']),
    help: LocalText.fromJson(json['help']),
  );

  final String type;

  /// `driver`, `fleet` or `vehicle`.
  final String owner;
  final DocumentKind kind;
  final bool expires;
  final bool custom;
  final LocalText? name;

  /// The admin's help / checklist text, one point per line.
  final LocalText? help;
}

/// `VehicleCategoryRule`: what a car needs for one category.
@immutable
class VehicleCategoryRule {
  const VehicleCategoryRule({
    required this.category,
    required this.on,
    required this.minYear,
    required this.minSeats,
    required this.fuels,
  });

  factory VehicleCategoryRule.fromJson(Map<String, dynamic> json) =>
      VehicleCategoryRule(
        category: _text(json['category']) ?? '',
        on: json['on'] != false,
        minYear: _whole(json['minYear'], 1990),
        minSeats: _whole(json['minSeats'], 1),
        fuels: _strings(json['fuels']),
      );

  final String category;
  final bool on;
  final int minYear;
  final int minSeats;
  final List<String> fuels;

  /// The contract's problem for a car (`vehicleRules.problems`), or null
  /// when it fits. [fuel] null: not chosen yet.
  String? problemFor({required int year, required int seats, String? fuel}) {
    if (!on) return 'category_off';
    if (year < minYear) return 'year_too_old';
    if (seats < minSeats) return 'too_few_seats';
    final allFuels = OnboardingSettings.fuels.every(fuels.contains);
    if (fuel == null) return allFuels ? null : 'fuel_required';
    if (!fuels.contains(fuel)) return 'fuel_not_allowed';
    return null;
  }
}

/// `OnboardingSettings` of one country.
@immutable
class OnboardingSettings {
  const OnboardingSettings({
    required this.country,
    this.version = 0,
    this.driverDocuments = const [],
    this.fleetDocuments = const [],
    this.vehicleDocuments = const [],
    this.expiringTypes = const [],
    this.warnDays = const [30, 7, 1],
    this.blockAtExpiry = true,
    this.categories = const [],
    this.vehicleWarnDays = 30,
    this.autoHold = true,
    this.photosNeeded = true,
    this.documentTypes = const {},
  });

  factory OnboardingSettings.fromJson(Map<String, dynamic> json) {
    final documents = _map(json['documents']);
    final expiry = _map(json['expiry']);
    final vehicles = _map(json['vehicles']);
    final types = _map(json['documentTypes']);
    return OnboardingSettings(
      country: _text(json['country']) ?? '',
      version: _whole(json['version'], 0),
      driverDocuments: _strings(documents['driver']),
      fleetDocuments: _strings(documents['fleet']),
      vehicleDocuments: _strings(documents['vehicle']),
      expiringTypes: _strings(json['expiringTypes']),
      warnDays: [
        if (expiry['warnDays'] is List)
          for (final day in expiry['warnDays'] as List)
            if (day is num) day.toInt(),
      ],
      blockAtExpiry: expiry['blockAtExpiry'] != false,
      categories: [
        if (vehicles['categories'] is List)
          for (final row in vehicles['categories'] as List)
            if (row is Map)
              VehicleCategoryRule.fromJson(Map<String, dynamic>.from(row)),
      ],
      vehicleWarnDays: _whole(vehicles['warnDays'], 30),
      autoHold: vehicles['autoHold'] != false,
      photosNeeded: vehicles['photosNeeded'] != false,
      documentTypes: {
        for (final entry in types.entries)
          if (entry.value is Map)
            entry.key: OnboardingDocumentType.fromJson(
              entry.key,
              Map<String, dynamic>.from(entry.value as Map),
            ),
      },
    );
  }

  /// `contract.json#driverOnboarding.settings.fuels`.
  static const List<String> fuels = ['petrol', 'diesel', 'hybrid', 'electric'];

  /// `settings.photoTypes`: the four car photos.
  static const List<String> photoTypes = [
    'vehicle_photo_front',
    'vehicle_photo_back',
    'vehicle_photo_side',
    'vehicle_photo_inside',
  ];

  final String country;

  /// 0 = the admin's defaults (nothing published yet).
  final int version;
  final List<String> driverDocuments;
  final List<String> fleetDocuments;
  final List<String> vehicleDocuments;
  final List<String> expiringTypes;
  final List<int> warnDays;
  final bool blockAtExpiry;
  final List<VehicleCategoryRule> categories;
  final int vehicleWarnDays;
  final bool autoHold;
  final bool photosNeeded;
  final Map<String, OnboardingDocumentType> documentTypes;

  /// The car photos a new car must have.
  List<String> get carPhotos => photosNeeded ? photoTypes : const [];

  OnboardingDocumentType? typeOf(String type) => documentTypes[type];

  /// The document's name in [language]: the admin's text, else the
  /// contract's, else the raw type.
  String nameOf(String type, String language) =>
      documentTypes[type]?.name?.inLanguage(language) ??
      DriverOnboardingRules.documentName(type, language);

  /// The admin's help text, one point per line; empty when none.
  List<String> helpOf(String type, String language) => [
    for (final line
        in (documentTypes[type]?.help?.inLanguage(language) ?? '').split('\n'))
      if (line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), '').isNotEmpty)
        line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''),
  ];

  DocumentKind kindOf(String type) =>
      documentTypes[type]?.kind ?? DriverOnboardingRules.kindOf(type);

  bool expires(String type) =>
      documentTypes[type]?.expires ?? expiringTypes.contains(type);

  VehicleCategoryRule? ruleFor(String category) {
    for (final rule in categories) {
      if (rule.category == category) return rule;
    }
    return null;
  }

  /// Why [category] does not fit the car, or null when it does. A category
  /// with no rule (e.g. child_seat) is not checked.
  String? categoryProblem(
    String category, {
    required int year,
    required int seats,
    String? fuel,
  }) => ruleFor(category)?.problemFor(year: year, seats: seats, fuel: fuel);

  /// The categories of [catalog] the car fits, in catalog order.
  List<String> fittingCategories(
    Iterable<String> catalog, {
    required int year,
    required int seats,
    String? fuel,
  }) => [
    for (final category in catalog)
      if (categoryProblem(category, year: year, seats: seats, fuel: fuel) ==
          null)
        category,
  ];
}

/// The settings of the signed-in driver's country for the session: read
/// when Documents, Add car or Home open; the last answer stays when a
/// read fails.
class OnboardingSettingsStore extends ChangeNotifier {
  OnboardingSettingsStore();

  static OnboardingSettingsStore instance = OnboardingSettingsStore();

  OnboardingSettings? _settings;
  Future<OnboardingSettings>? _loading;

  OnboardingSettings? get settings => _settings;

  /// One read at a time; [load] answers or throws.
  Future<OnboardingSettings> refresh(
    Future<OnboardingSettings> Function() load,
  ) {
    final active = _loading;
    if (active != null) return active;
    final pending = load().then((settings) {
      _settings = settings;
      notifyListeners();
      return settings;
    });
    _loading = pending;
    pending.whenComplete(() {
      if (identical(_loading, pending)) _loading = null;
    }).ignore();
    return pending;
  }

  /// The document's name with the published texts when read, else the
  /// contract's.
  String nameOf(String type, String language) =>
      _settings?.nameOf(type, language) ??
      DriverOnboardingRules.documentName(type, language);

  DocumentKind kindOf(String type) =>
      _settings?.kindOf(type) ?? DriverOnboardingRules.kindOf(type);

  /// Takes settings read elsewhere (or a test's).
  void use(OnboardingSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  void clear() {
    _settings = null;
    notifyListeners();
  }
}
