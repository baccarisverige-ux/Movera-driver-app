import 'package:movera/core/api/api_client.dart';

/// v0.18.155 (contract.json#driverProfile; owner 2026-11-20 "Now build
/// all"): the six compliment chips, in the contract's order, with the
/// phone's own emoji drawn as text (no image file).
const complimentEmoji = <String, String>{
  'great_service': '⭐',
  'knew_the_way': '\u{1F9ED}',
  'friendly': '\u{1F4AC}',
  'clean_car': '✨',
  'safe_driving': '\u{1F6E1}',
  'good_music': '\u{1F3B5}',
};

/// contract.json#driverProfile.languages.codes with each language's own
/// name (endonyms are the same in every app language).
const profileLanguageNames = <String, String>{
  'sv': 'Svenska',
  'en': 'English',
  'ar': 'العربية',
  'fr': 'Français',
  'fi': 'Suomi',
  'es': 'Español',
  'de': 'Deutsch',
  'fa': 'فارسی',
  'so': 'Soomaali',
  'ti': 'ትግርኛ',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'ru': 'Русский',
  'ku': 'Kurdî',
  'bs': 'Bosanski',
  'uk': 'Українська',
};
const maxProfileLanguages = 6;

class ProfileCompliment {
  const ProfileCompliment(this.code, this.count);
  final String code;
  final int count;
}

class ProfileReview {
  const ProfileReview({
    required this.text,
    this.name,
    required this.month,
    this.status = 'approved',
  });
  final String text;
  final String? name;
  final String month;
  final String status;
}

/// `DriverPublicProfile`: what a rider sees.
class PublicProfilePreview {
  const PublicProfilePreview({
    required this.firstName,
    this.verified = false,
    this.languages = const [],
    this.city,
    this.sinceMonth,
    this.years,
    this.tripCount = 0,
    this.rating,
    this.compliments = const [],
    this.milestones = const [],
    this.latestReview,
  });

  final String firstName;
  final bool verified;
  final List<String> languages;
  final String? city;
  final String? sinceMonth;
  final int? years;
  final int tripCount;
  final double? rating;
  final List<ProfileCompliment> compliments;
  final List<String> milestones;
  final ProfileReview? latestReview;

  factory PublicProfilePreview.fromJson(Map<String, dynamic> j) {
    final review = j['latestReview'];
    return PublicProfilePreview(
      firstName: (j['firstName'] as String?) ?? '',
      verified: j['verified'] == true,
      languages: [
        for (final l in (j['languages'] as List? ?? const []))
          if (l is String) l,
      ],
      city: j['city'] as String?,
      sinceMonth: j['sinceMonth'] as String?,
      years: (j['years'] as num?)?.toInt(),
      tripCount: (j['tripCount'] as num?)?.toInt() ?? 0,
      rating: (j['rating'] as num?)?.toDouble(),
      compliments: complimentsOf(j['compliments']),
      milestones: [
        for (final m in (j['milestones'] as List? ?? const []))
          if (m is Map && m['code'] is String) m['code'] as String,
      ],
      latestReview: review is Map<String, dynamic>
          ? ProfileReview(
              text: (review['text'] as String?) ?? '',
              name: review['name'] as String?,
              month: (review['month'] as String?) ?? '',
            )
          : null,
    );
  }
}

List<ProfileCompliment> complimentsOf(Object? raw) => [
  for (final c in (raw as List? ?? const []))
    if (c is Map && complimentEmoji.containsKey(c['code']) && c['count'] is num)
      ProfileCompliment(c['code'] as String, (c['count'] as num).toInt()),
];

/// `DriverOwnPublicProfile`: Min profil.
class OwnPublicProfile {
  const OwnPublicProfile({
    required this.languages,
    required this.showCity,
    required this.showYears,
    required this.profileOn,
    required this.reviewsOn,
    required this.preview,
    required this.compliments,
    required this.reviews,
  });

  final List<String> languages;
  final bool showCity;
  final bool showYears;
  final bool profileOn;
  final bool reviewsOn;
  final PublicProfilePreview preview;
  final List<ProfileCompliment> compliments;
  final List<ProfileReview> reviews;

  factory OwnPublicProfile.fromJson(Map<String, dynamic> j) => OwnPublicProfile(
    languages: [
      for (final l in (j['languages'] as List? ?? const []))
        if (l is String) l,
    ],
    showCity: j['showCity'] != false,
    showYears: j['showYears'] != false,
    profileOn: j['profileOn'] != false,
    reviewsOn: j['reviewsOn'] == true,
    preview: PublicProfilePreview.fromJson(
      (j['preview'] as Map<String, dynamic>?) ?? const {},
    ),
    compliments: complimentsOf(j['compliments']),
    reviews: [
      for (final r in (j['reviews'] as List? ?? const []))
        if (r is Map<String, dynamic>)
          ProfileReview(
            text: (r['text'] as String?) ?? '',
            name: r['name'] as String?,
            month: (r['month'] as String?) ?? '',
            status: (r['status'] as String?) ?? 'pending',
          ),
    ],
  );
}

/// Read when Min profil opens, saved on each change (no polling: the
/// owner's LOAD RULE).
abstract class PublicProfileApi {
  Future<OwnPublicProfile> read();
  Future<OwnPublicProfile> save({
    List<String>? languages,
    bool? showCity,
    bool? showYears,
  });
}

class LivePublicProfile implements PublicProfileApi {
  LivePublicProfile({required ApiClient api}) : _api = api;
  final ApiClient _api;
  static const path = '/api/v1/driver/public-profile';

  @override
  Future<OwnPublicProfile> read() async =>
      OwnPublicProfile.fromJson(await _api.get(path));

  @override
  Future<OwnPublicProfile> save({
    List<String>? languages,
    bool? showCity,
    bool? showYears,
  }) async => OwnPublicProfile.fromJson(
    await _api.patch(
      path,
      body: {
        'languages': ?languages,
        'showCity': ?showCity,
        'showYears': ?showYears,
      },
    ),
  );
}
