/// The rules of contract v0.5.3 §14 (`contract.json#driverOnboarding`), as
/// the app needs them before it has a server answer: the countries it can
/// sign up in with their cities, the minimum age, the fleet code's shape,
/// the upload limits and every document type's kind and name in the app's
/// languages. `test/contract/driver_onboarding_rules_test.dart` keeps them
/// equal to the contract copy; the server sends the required lists per
/// account (`Driver.requiredDocuments` …), never computed here.
library;

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
  });

  /// `driver` or `vehicle`.
  final String owner;
  final DocumentKind kind;
  final String en;
  final String sv;
  final String fr;

  String nameIn(String language) => switch (language) {
    'sv' => sv,
    'fr' => fr,
    _ => en,
  };
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
    ),
    'taxi_traffic_permit': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Taxi traffic permit',
      sv: 'Taxitrafiktillstånd (Transportstyrelsen)',
      fr: 'Licence de taxi',
    ),
    'tax_settings': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Tax settings (F-skatt)',
      sv: 'F-skattsedel',
      fr: 'Attestation fiscale',
    ),
    'bank_statement': DocumentTypeInfo(
      owner: 'driver',
      kind: DocumentKind.file,
      en: 'Bank details',
      sv: 'Kontobevis',
      fr: 'RIB de la société',
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
    ),
    'insurance': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'Vehicle insurance',
      sv: 'Försäkringsbrev',
      fr: 'Assurance transport de personnes',
    ),
    'vtc_sticker': DocumentTypeInfo(
      owner: 'vehicle',
      kind: DocumentKind.file,
      en: 'VTC sticker (macaron)',
      sv: 'VTC-dekal',
      fr: 'Macaron VTC',
    ),
  };

  /// The document's name in [language]; the raw type for one the contract
  /// copy does not know yet.
  static String documentName(String type, String language) =>
      documentTypes[type]?.nameIn(language) ?? type;

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
