/// Owner decision of 2026-10-29, driver group 2 item 4: an upload guide
/// page per document and country, from the published settings
/// (contract v0.17.0 `documentTypes`): a Movera-drawn example, a
/// checklist of what must be visible, "Tips for a good photo" and one
/// Upload button. The admin's help text, when there is one, is the
/// checklist (types the admin made included); otherwise the app's own
/// list for the type and country, and a general list for a type it does
/// not know. Texts in sv, fr and en.
library;

import 'package:flutter/foundation.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';

/// What the drawn example shows.
enum GuideExample {
  /// A card: licence, ID, professional cards.
  card,

  /// A paper or a screen print: certificates, insurance, bank details.
  paper,

  /// A face photo.
  portrait,
  carFront,
  carBack,
  carSide,
  carInside,

  /// A sticker on the windscreen.
  sticker,
}

@immutable
class UploadGuide {
  const UploadGuide({
    required this.type,
    required this.title,
    required this.example,
    required this.checklist,
    required this.tips,
    required this.fromAdmin,
    required this.expires,
    this.warnDays = 30,
  });

  final String type;
  final String title;
  final GuideExample example;

  /// What must be visible, one line each.
  final List<String> checklist;

  /// "Tips for a good photo".
  final List<String> tips;

  /// The checklist is the admin's help text.
  final bool fromAdmin;

  /// The document has an end date the admin types when approving.
  final bool expires;

  /// The admin's first warning day before that date (30 by default).
  final int warnDays;
}

abstract final class UploadGuides {
  static GuideExample exampleOf(String type) => switch (type) {
    'driving_license' ||
    'national_id' ||
    'taxi_driver_license' ||
    'vtc_card' => GuideExample.card,
    'profile_photo' => GuideExample.portrait,
    'vehicle_photo_front' => GuideExample.carFront,
    'vehicle_photo_back' => GuideExample.carBack,
    'vehicle_photo_side' => GuideExample.carSide,
    'vehicle_photo_inside' => GuideExample.carInside,
    'vtc_sticker' => GuideExample.sticker,
    _ => GuideExample.paper,
  };

  /// The guide for [type] in [country] ("SE", "FR"), in the app's
  /// language. [settings] null: the contract's names, the app's lists.
  static UploadGuide forType(
    String type, {
    required String country,
    OnboardingSettings? settings,
  }) {
    final language = tr.localeName;
    final info = settings?.typeOf(type);
    // Contract v0.18.3 (R8): the admin's guide lines of this country
    // first, then the older help text, then the app's own text.
    final guideChecklist = _inLanguage(info?.checklist, language);
    final admin = guideChecklist.isNotEmpty
        ? guideChecklist
        : settings?.helpOf(type, language) ?? const <String>[];
    final adminTips = _inLanguage(info?.tips, language);
    final example = exampleOf(type);
    return UploadGuide(
      type: type,
      title:
          settings?.nameOf(type, language) ??
          DriverOnboardingRules.documentName(type, language),
      example: example,
      checklist: admin.isNotEmpty ? admin : _checklist(type, country),
      tips: adminTips.isNotEmpty ? adminTips : _tips(example),
      fromAdmin: admin.isNotEmpty,
      expires: settings?.expires(type) ?? false,
      warnDays: _firstWarning(type, settings),
    );
  }

  static List<String> _inLanguage(List<LocalText>? lines, String language) => [
    for (final line in lines ?? const <LocalText>[])
      if (line.inLanguage(language)?.trim() case final text?
          when text.isNotEmpty)
        text,
  ];

  static int _firstWarning(String type, OnboardingSettings? settings) {
    if (settings == null) return 30;
    final car = settings.typeOf(type)?.owner == 'vehicle';
    final days = car ? settings.vehicleWarnDays : settings.warnDays.firstOrNull;
    return days ?? 30;
  }

  static List<String> _checklist(String type, String country) {
    final france = country == 'FR';
    return switch (type) {
      'driving_license' => [
        tr.guideLicenceBothSides,
        tr.guideNameAndPhoto,
        tr.guideValidUntil,
        france ? tr.guideLicenceCategoryB3Years : tr.guideLicenceCategoryB,
      ],
      'national_id' => [
        tr.guideIdWholeCard,
        tr.guideNameAndPhoto,
        tr.guideValidUntil,
      ],
      'profile_photo' => [
        tr.guidePhotoFaceFront,
        tr.guidePhotoPlainBackground,
        tr.guidePhotoNoSunglasses,
      ],
      'taxi_driver_license' => [
        tr.guideCardBothSides,
        tr.guideNameAndPhoto,
        tr.guideValidUntil,
      ],
      'vtc_card' => [
        tr.guideCardBothSides,
        tr.guideNameAndPhoto,
        tr.guideCardNumber,
        tr.guideValidUntil,
      ],
      'company_registration' => [
        france ? tr.guideKbisRecent : tr.guideSeRegistrationBolagsverket,
        tr.guideCompanyNameAndNumber,
        tr.guideAllPages,
      ],
      'taxi_traffic_permit' => [
        tr.guideSeTrafficPermit,
        tr.guideCompanyNameAndNumber,
        tr.guideValidUntil,
      ],
      'tax_settings' => [tr.guideSeFTax, tr.guideCompanyNameAndNumber],
      'bank_statement' => [
        france ? tr.guideFrRib : tr.guideSeBankAccount,
        tr.guideAccountHolderName,
      ],
      'vtc_register_certificate' => [
        tr.guideFrVtcRegister,
        tr.guideCompanyNameAndNumber,
        tr.guideValidUntil,
      ],
      'rc_pro_insurance' => [
        tr.guideFrRcPro,
        tr.guideCompanyNameAndNumber,
        tr.guideValidUntil,
      ],
      'urssaf_certificate' => [
        tr.guideFrUrssafRecent,
        tr.guideCompanyNameAndNumber,
      ],
      'vehicle_registration' => [
        france ? tr.guideFrCarteGrise : tr.guideSeRegistrationFront,
        tr.guidePlateVisible,
        tr.guideOwnerName,
      ],
      'insurance' => [
        france ? tr.guideFrPassengerInsurance : tr.guideSeInsuranceLetter,
        tr.guidePlateVisible,
        tr.guideValidUntil,
      ],
      'vtc_sticker' => [
        tr.guideFrStickerOnCar,
        tr.guidePlateVisible,
        tr.guideValidUntil,
      ],
      'vehicle_photo_front' => [tr.guideCarFront, tr.guidePlateReadable],
      'vehicle_photo_back' => [tr.guideCarBack, tr.guidePlateReadable],
      'vehicle_photo_side' => [tr.guideCarSide],
      'vehicle_photo_inside' => [tr.guideCarInside],
      // A type the app does not know (e.g. one the admin made).
      _ => [
        tr.guideWholeDocument,
        tr.guideNameAndPhotoIfAny,
        tr.guideValidUntil,
      ],
    };
  }

  static List<String> _tips(GuideExample example) => switch (example) {
    GuideExample.portrait => [
      tr.tipPhotoDaylight,
      tr.tipPhotoHoldStill,
      tr.tipPhotoNoFilter,
    ],
    GuideExample.carFront ||
    GuideExample.carBack ||
    GuideExample.carSide ||
    GuideExample.carInside ||
    GuideExample.sticker => [
      tr.tipCarWholeInFrame,
      tr.tipPhotoDaylight,
      tr.tipPhotoHoldStill,
    ],
    _ => [
      tr.tipFlatDarkSurface,
      tr.tipNoGlare,
      tr.tipFourCorners,
      tr.tipPhotoHoldStill,
    ],
  };
}
