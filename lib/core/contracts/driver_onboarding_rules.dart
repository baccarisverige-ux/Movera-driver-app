/// The rules of contract v0.5.3 §14 (`contract.json#driverOnboarding`), as
/// the app needs them before it has a server answer: the countries it can
/// sign up in with their cities, the minimum age, the fleet code's shape,
/// the upload limits and every document type's kind and name in the app's
/// languages. `test/contract/driver_onboarding_rules_test.dart` keeps them
/// equal to the contract copy; the server sends the required lists per
/// account (`Driver.requiredDocuments` …), never computed here.
library;

import 'package:movera/core/admin/trip_rules_admin_config.dart';

class OnboardingCity {
  const OnboardingCity(this.cityId, this.name, this.zoneId);
  final String cityId;
  final String name;
  final String zoneId;
}

class OnboardingCountry {
  const OnboardingCountry({required this.open, required this.cities});
  final bool open;
  final List<OnboardingCity> cities;
}

/// `file` is uploaded, `acceptance` is the terms tick, `admin_check` is
/// approved by an admin without a file.
enum DocumentKind { file, acceptance, adminCheck }

class DocumentTypeInfo {
  const DocumentTypeInfo({
    required this.owner,
    required this.kind,
    required this.en,
    required this.sv,
    required this.fr,
    this.byCountry = const {},
  });

  /// `driver` or `vehicle`.
  final String owner;
  final DocumentKind kind;
  final String en;
  final String sv;
  final String fr;

  /// Contract v0.18.3 (R5 "Name per country"): `nameByCountry[country]`
  /// as `{ en, sv, fr }`; the country's name wins over the general one.
  final Map<String, Map<String, String>> byCountry;

  String nameIn(String language, {String? country}) {
    final local = byCountry[country]?[language];
    if (local != null) return local;
    return switch (language) {
      'sv' => sv,
      'fr' => fr,
      _ => en,
    };
  }
}

abstract final class DriverOnboardingRules {
  static const List<String> accountTypes = ['driver', 'fleet'];
  static const int minAge = 21;

  /// In the order the details screen shows them.
  static const Map<String, OnboardingCountry> countries = {
    'SE': OnboardingCountry(
      open: true,
      cities: [OnboardingCity('stockholm_lan', 'Stockholm län', 'Z001')],
    ),
    'FR': OnboardingCountry(
      open: true,
      cities: [OnboardingCity('paris', 'Paris', 'FR-PC')],
    ),
    'TN': OnboardingCountry(open: false, cities: []),
  };

  /// [country]'s cities a driver can sign up in now: the contract's, less
  /// a city whose zone the server's list (v0.11.0 §21) does not have open.
  static List<OnboardingCity> citiesOf(String country) => [
    for (final city in countries[country]?.cities ?? const <OnboardingCity>[])
      if (DriverZones.offers(city.zoneId)) city,
  ];

  /// True when [country] is open and has a city open now.
  static bool isOpen(String country) =>
      (countries[country]?.open ?? false) && citiesOf(country).isNotEmpty;

  static const String fleetCodePrefix = 'MV-';
  static const int fleetCodeLength = 5;
  static const String fleetCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int joinAttemptsPerHour = 10;

  static const int uploadMaxBytes = 10485760;
  static const List<String> uploadMediaTypes = [
    'image/jpeg',
    'image/png',
    'image/heic',
    'application/pdf',
  ];

  static const Map<String, DocumentTypeInfo> documentTypes = {
    'terms': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.acceptance,
      en: 'Terms and conditions',
      sv: 'Villkor',
      fr: 'Conditions générales',
    ),
    'info_session': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.adminCheck,
      en: 'Virtual information session',
      sv: 'Digitalt informationsmöte',
      fr: 'Session d’information en ligne',
    ),
    'driving_license': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Driving licence',
      sv: 'Körkort',
      fr: 'Permis de conduire',
    ),
    'profile_photo': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Profile photo',
      sv: 'Profilbild',
      fr: 'Photo de profil',
    ),
    'national_id': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'ID card or passport',
      sv: 'ID-kort eller pass',
      fr: 'Pièce d’identité ou passeport',
    ),
    'taxi_driver_license': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Taxi driver licence',
      sv: 'Taxiförarlegitimation',
      fr: 'Carte de chauffeur de taxi',
      byCountry: {
        'SE': {
          'en': 'Taxi driver licence (Transportstyrelsen)',
          'sv': 'Taxiförarlegitimation',
          'fr': 'Carte de conducteur de taxi (Transportstyrelsen)',
        },
      },
    ),
    'vtc_card': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'VTC professional card',
      sv: 'VTC-yrkeskort',
      fr: 'Carte professionnelle VTC',
    ),
    'company_registration': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Company registration',
      sv: 'Registreringsbevis (Bolagsverket)',
      fr: 'Extrait Kbis ou avis SIRENE (moins de 3 mois)',
      byCountry: {
        'SE': {
          'en': 'Company registration certificate (Bolagsverket)',
          'sv': 'Registreringsbevis (Bolagsverket)',
          'fr': 'Certificat d’enregistrement de la société (Bolagsverket)',
        },
        'FR': {
          'en': 'Kbis extract or SIRENE notice (under 3 months)',
          'sv': 'Kbis-utdrag eller SIRENE-intyg (högst 3 månader)',
          'fr': 'Extrait Kbis ou avis SIRENE (moins de 3 mois)',
        },
      },
    ),
    'taxi_traffic_permit': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Taxi traffic permit',
      sv: 'Taxitrafiktillstånd (Transportstyrelsen)',
      fr: 'Licence de taxi',
      byCountry: {
        'SE': {
          'en': 'Taxi traffic permit (Transportstyrelsen)',
          'sv': 'Taxitrafiktillstånd (Transportstyrelsen)',
          'fr': 'Autorisation de trafic taxi (Transportstyrelsen)',
        },
      },
    ),
    'tax_settings': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Tax settings (F-skatt)',
      sv: 'F-skattsedel',
      fr: 'Attestation fiscale',
      byCountry: {
        'SE': {
          'en': 'F-tax certificate (Skatteverket)',
          'sv': 'F-skattsedel',
          'fr': 'Attestation F-skatt (Skatteverket)',
        },
      },
    ),
    'bank_statement': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Bank details',
      sv: 'Kontobevis',
      fr: 'RIB de la société',
      byCountry: {
        'SE': {
          'en': 'Company bank account statement',
          'sv': 'Kontobevis',
          'fr': 'Relevé bancaire de l’entreprise',
        },
        'FR': {
          'en': 'Company bank details (RIB)',
          'sv': 'Företagets bankuppgifter (RIB)',
          'fr': 'RIB de la société',
        },
      },
    ),
    'vtc_register_certificate': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'VTC operators register certificate',
      sv: 'Intyg från VTC-registret',
      fr: 'Certificat d’inscription au registre des exploitants VTC',
    ),
    'rc_pro_insurance': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Professional liability insurance (RC pro)',
      sv: 'Ansvarsförsäkring (RC pro)',
      fr: 'Attestation RC professionnelle',
    ),
    'urssaf_certificate': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'URSSAF certificate',
      sv: 'URSSAF-intyg',
      fr: 'Attestation de vigilance URSSAF',
    ),
    'vehicle_registration': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Registration certificate',
      sv: 'Registreringsbevis',
      fr: 'Certificat d’immatriculation (carte grise)',
      byCountry: {
        'SE': {
          'en': 'Registration certificate (Transportstyrelsen)',
          'sv': 'Registreringsbevis',
          'fr': 'Certificat d’immatriculation (Transportstyrelsen)',
        },
        'FR': {
          'en': 'Registration certificate (carte grise)',
          'sv': 'Registreringsbevis (carte grise)',
          'fr': 'Certificat d’immatriculation (carte grise)',
        },
      },
    ),
    'insurance': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Vehicle insurance',
      sv: 'Försäkringsbrev',
      fr: 'Assurance transport de personnes',
      byCountry: {
        'SE': {
          'en': 'Vehicle insurance (taxi)',
          'sv': 'Försäkringsbrev',
          'fr': 'Assurance du véhicule (taxi)',
        },
        'FR': {
          'en': 'Passenger transport insurance',
          'sv': 'Försäkring för persontransport',
          'fr': 'Assurance transport de personnes',
        },
      },
    ),
    'vtc_sticker': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'VTC sticker (macaron)',
      sv: 'VTC-dekal',
      fr: 'Macaron VTC',
    ),
    'vehicle_photo_front': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Photo: front with plate',
      sv: 'Foto: framifrån med registreringsskylt',
      fr: 'Photo : avant avec plaque',
    ),
    'vehicle_photo_back': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Photo: back with plate',
      sv: 'Foto: bakifrån med registreringsskylt',
      fr: 'Photo : arrière avec plaque',
    ),
    'vehicle_photo_side': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Photo: side',
      sv: 'Foto: från sidan',
      fr: 'Photo : côté',
    ),
    'vehicle_photo_inside': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Photo: inside',
      sv: 'Foto: insidan',
      fr: 'Photo : intérieur',
    ),
  };

  /// The document's name in [language]; the raw type for one the contract
  /// copy does not know yet.
  static String documentName(String type, String language, {String? country}) =>
      documentTypes[type]?.nameIn(language, country: country) ?? type;

  static DocumentKind kindOf(String type) =>
      documentTypes[type]?.kind ?? DocumentKind.file;

  /// What a driver typed as a code, in the stored form: upper case, no
  /// spaces or dashes, the prefix added when missing (as the server does).
  static String normalizeFleetCode(String typed) {
    final flat = typed.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '');
    final body = flat.startsWith('MV') && flat.length > fleetCodeLength
        ? flat.substring(2)
        : flat;
    return '$fleetCodePrefix$body';
  }

  /// Whole years between [dateOfBirth] and [now].
  static int ageAt(DateTime dateOfBirth, DateTime now) {
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age -= 1;
    }
    return age;
  }
}
