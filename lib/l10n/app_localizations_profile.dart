import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_profile_en.dart';
import 'app_localizations_profile_fr.dart';
import 'app_localizations_profile_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ProfileLocalizations
/// returned by `ProfileLocalizations.of(context)`.
///
/// Applications need to include `ProfileLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations_profile.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ProfileLocalizations.localizationsDelegates,
///   supportedLocales: ProfileLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ProfileLocalizations.supportedLocales
/// property.
abstract class ProfileLocalizations {
  ProfileLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ProfileLocalizations of(BuildContext context) {
    return Localizations.of<ProfileLocalizations>(
      context,
      ProfileLocalizations,
    )!;
  }

  static const LocalizationsDelegate<ProfileLocalizations> delegate =
      _ProfileLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('sv'),
  ];

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get mppTitle;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'This is what riders see when they tap your card.'**
  String get mppIntro;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Languages I speak'**
  String get mppLanguages;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Pick up to 6.'**
  String get mppLanguagesHint;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Show my city'**
  String get mppShowCity;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Show how long I have driven with Movera'**
  String get mppShowYears;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'What riders say'**
  String get mppCompliments;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'No compliments yet.'**
  String get mppNoCompliments;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get mppReviews;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get mppNoReviews;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get mppReviewPending;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Shown to riders'**
  String get mppReviewApproved;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get mppReviewHidden;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get mppAnonymous;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'View as rider'**
  String get mppViewAsRider;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'The driver profile is off in your zone. Riders see only your name, car and rating.'**
  String get mppProfileOff;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Written reviews are off in your zone.'**
  String get mppReviewsOff;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get mppLoadError;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Try again.'**
  String get mppSaveError;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get mppRetry;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get mppTrips;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get mppRating;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get mppYears;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Latest review'**
  String get mppLatestReview;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get mppMilestones;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'1,000 trips'**
  String get mppMilestoneTrips1000;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Top rating'**
  String get mppMilestoneTopRating;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Excellent service'**
  String get complimentGreatService;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Good route'**
  String get complimentKnewTheWay;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Nice conversation'**
  String get complimentFriendly;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Clean car'**
  String get complimentCleanCar;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Safe driving'**
  String get complimentSafeDriving;

  /// v0.18.155 driver profile (owner 2026-11-20 "Now build all"): Profile › My profile.
  ///
  /// In en, this message translates to:
  /// **'Good music'**
  String get complimentGoodMusic;

  /// v0.18.155 View as rider: the since month (years 0 shows only this).
  ///
  /// In en, this message translates to:
  /// **'Movera driver since {month}'**
  String mppSince(String month);

  /// v0.18.155 Min profil: shown when 6 languages are picked.
  ///
  /// In en, this message translates to:
  /// **'You picked 6. Remove one to pick another.'**
  String get mppLanguagesMax;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. row and screen title.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get acctDeleteTitle;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. what happens.
  ///
  /// In en, this message translates to:
  /// **'Your account closes at once: you are signed out and cannot sign in or drive with it again. After 30 days your personal data is erased.'**
  String get acctDeleteBody;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. what is kept.
  ///
  /// In en, this message translates to:
  /// **'Kept: your trips, earnings and payouts for the bookkeeping law, and, if you owe Movera, your name, number and the amount until it is paid.'**
  String get acctDeleteKept;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. confirm dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get acctDeleteConfirmQ;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. confirm dialog text.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Your account closes now.'**
  String get acctDeleteConfirmBody;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. confirm button.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get acctDeleteConfirm;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. 409 deletion_open_trip.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel your ride first, then delete your account.'**
  String get acctDeleteOpenTrip;

  /// v0.18.134 (contract.json#accountDeletion.driver, owner button 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. other error.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account. Try again.'**
  String get acctDeleteFailed;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Local preview data on this device will be cleared, including trip history, contacts, and drafts. You will return to the sign-in screen offline.'**
  String get profLogOutClears;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Could not clear local data. You are still signed in. Please retry.'**
  String get profCouldNotClear;

  /// Profile header (live): profLiveNoNameYet
  ///
  /// In en, this message translates to:
  /// **'Your details are not sent yet'**
  String get profLiveNoNameYet;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Your details are saved. Movera checks them.'**
  String get acctDetailsSaved;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get acctDetailsTitle;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Sample driver profile'**
  String get profSampleDriver;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQ;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get helpCenter;

  /// Moved from AppLocalizations (fleet #679 web budget, text unchanged): read only by the deferred Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Demo — no verified account'**
  String get profDemoNoVerified;

  /// G30 (contract v0.18.76 emailVerified, owner 2026-11-12): the Account e-mail row, a verified address (texts.verified).
  ///
  /// In en, this message translates to:
  /// **'{email} · Verified'**
  String contactEmailVerified(String email);

  /// G30 (contract v0.18.76 emailVerified, owner 2026-11-12): the Account e-mail row, an address without a code check (texts.notVerified).
  ///
  /// In en, this message translates to:
  /// **'{email} · Not verified'**
  String contactEmailNotVerified(String email);

  /// G30 (contract v0.18.76 emailVerified, owner 2026-11-12): the Account e-mail row without an address.
  ///
  /// In en, this message translates to:
  /// **'No e-mail'**
  String get contactEmailNone;
}

class _ProfileLocalizationsDelegate
    extends LocalizationsDelegate<ProfileLocalizations> {
  const _ProfileLocalizationsDelegate();

  @override
  Future<ProfileLocalizations> load(Locale locale) {
    return SynchronousFuture<ProfileLocalizations>(
      lookupProfileLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_ProfileLocalizationsDelegate old) => false;
}

ProfileLocalizations lookupProfileLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ProfileLocalizationsEn();
    case 'fr':
      return ProfileLocalizationsFr();
    case 'sv':
      return ProfileLocalizationsSv();
  }

  throw FlutterError(
    'ProfileLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
