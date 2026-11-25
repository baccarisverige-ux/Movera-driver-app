// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_profile.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class ProfileLocalizationsSv extends ProfileLocalizations {
  ProfileLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get mppTitle => 'Min profil';

  @override
  String get mppIntro =>
      'Så här ser resenärer dig när de trycker på ditt kort.';

  @override
  String get mppLanguages => 'Språk jag talar';

  @override
  String get mppLanguagesHint => 'Välj upp till 6.';

  @override
  String get mppShowCity => 'Visa min stad';

  @override
  String get mppShowYears => 'Visa hur länge jag kört med Movera';

  @override
  String get mppCompliments => 'Vad resenärer säger';

  @override
  String get mppNoCompliments => 'Inga komplimanger än.';

  @override
  String get mppReviews => 'Omdömen';

  @override
  String get mppNoReviews => 'Inga omdömen än.';

  @override
  String get mppReviewPending => 'Väntar på godkännande';

  @override
  String get mppReviewApproved => 'Visas för resenärer';

  @override
  String get mppReviewHidden => 'Dolt';

  @override
  String get mppAnonymous => 'Anonym';

  @override
  String get mppViewAsRider => 'Visa som resenär';

  @override
  String get mppProfileOff =>
      'Förarprofilen är avstängd i din zon. Resenärer ser bara ditt namn, din bil och ditt betyg.';

  @override
  String get mppReviewsOff => 'Skrivna omdömen är avstängda i din zon.';

  @override
  String get mppLoadError => 'Det gick inte att läsa in din profil.';

  @override
  String get mppSaveError => 'Det gick inte att spara. Försök igen.';

  @override
  String get mppRetry => 'Försök igen';

  @override
  String get mppTrips => 'Resor';

  @override
  String get mppRating => 'Betyg';

  @override
  String get mppYears => 'År';

  @override
  String get mppLatestReview => 'Senaste omdöme';

  @override
  String get mppMilestones => 'Milstolpar';

  @override
  String get mppMilestoneTrips1000 => '1 000 resor';

  @override
  String get mppMilestoneTopRating => 'Toppbetyg';

  @override
  String get complimentGreatService => 'Utmärkt service';

  @override
  String get complimentKnewTheWay => 'Bra vägval';

  @override
  String get complimentFriendly => 'Trevligt samtal';

  @override
  String get complimentCleanCar => 'Ren bil';

  @override
  String get complimentSafeDriving => 'Säker körning';

  @override
  String get complimentGoodMusic => 'Bra musik';

  @override
  String mppSince(String month) {
    return 'Movera-förare sedan $month';
  }

  @override
  String get mppLanguagesMax =>
      'Du har valt 6. Ta bort ett för att välja ett annat.';

  @override
  String get acctDeleteTitle => 'Radera mitt konto';

  @override
  String get acctDeleteBody =>
      'Ditt konto stängs direkt: du loggas ut och kan inte logga in eller köra med det igen. Efter 30 dagar raderas dina personuppgifter.';

  @override
  String get acctDeleteKept =>
      'Sparas: dina resor, intäkter och utbetalningar enligt bokföringslagen, och om du är skyldig Movera ditt namn, nummer och beloppet tills det är betalt.';

  @override
  String get acctDeleteConfirmQ => 'Radera ditt konto?';

  @override
  String get acctDeleteConfirmBody =>
      'Det går inte att ångra. Ditt konto stängs nu.';

  @override
  String get acctDeleteConfirm => 'Radera konto';

  @override
  String get acctDeleteOpenTrip =>
      'Avsluta eller avbryt din resa först och radera sedan kontot.';

  @override
  String get acctDeleteFailed => 'Kontot kunde inte raderas. Försök igen.';

  @override
  String get profLogOutClears =>
      'Förhandsdata på enheten rensas, även resehistorik, kontakter och utkast. Du kommer tillbaka till inloggningen offline.';

  @override
  String get profCouldNotClear =>
      'Det gick inte att rensa lokal data. Du är fortfarande inloggad. Försök igen.';

  @override
  String get profLiveNoNameYet => 'Dina uppgifter är inte skickade än';

  @override
  String get acctDetailsSaved =>
      'Dina uppgifter är sparade. Movera kontrollerar dem.';

  @override
  String get acctDetailsTitle => 'Dina uppgifter';

  @override
  String get profSampleDriver => 'Exempelprofil för förare';

  @override
  String get logOutQ => 'Logga ut?';

  @override
  String get helpCenter => 'Hjälpcenter';

  @override
  String get profDemoNoVerified => 'Demo – inget verifierat konto';

  @override
  String contactEmailVerified(String email) {
    return '$email · Verifierad';
  }

  @override
  String contactEmailNotVerified(String email) {
    return '$email · Inte verifierad';
  }

  @override
  String get contactEmailNone => 'Ingen e-post';
}
