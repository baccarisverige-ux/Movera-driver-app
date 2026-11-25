// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations_profile.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ProfileLocalizationsFr extends ProfileLocalizations {
  ProfileLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get mppTitle => 'Mon profil';

  @override
  String get mppIntro =>
      'C\'est ce que voient les passagers quand ils touchent votre carte.';

  @override
  String get mppLanguages => 'Langues que je parle';

  @override
  String get mppLanguagesHint => 'Jusqu\'à 6.';

  @override
  String get mppShowCity => 'Afficher ma ville';

  @override
  String get mppShowYears => 'Afficher depuis quand je conduis avec Movera';

  @override
  String get mppCompliments => 'Ce que disent les passagers';

  @override
  String get mppNoCompliments => 'Pas encore de compliments.';

  @override
  String get mppReviews => 'Avis';

  @override
  String get mppNoReviews => 'Pas encore d\'avis.';

  @override
  String get mppReviewPending => 'En attente d\'approbation';

  @override
  String get mppReviewApproved => 'Visible par les passagers';

  @override
  String get mppReviewHidden => 'Masqué';

  @override
  String get mppAnonymous => 'Anonyme';

  @override
  String get mppViewAsRider => 'Voir comme un passager';

  @override
  String get mppProfileOff =>
      'Le profil chauffeur est désactivé dans votre zone. Les passagers voient seulement votre nom, votre voiture et votre note.';

  @override
  String get mppReviewsOff =>
      'Les avis écrits sont désactivés dans votre zone.';

  @override
  String get mppLoadError => 'Impossible de charger votre profil.';

  @override
  String get mppSaveError => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get mppRetry => 'Réessayer';

  @override
  String get mppTrips => 'Courses';

  @override
  String get mppRating => 'Note';

  @override
  String get mppYears => 'Ans';

  @override
  String get mppLatestReview => 'Dernier avis';

  @override
  String get mppMilestones => 'Étapes';

  @override
  String get mppMilestoneTrips1000 => '1 000 courses';

  @override
  String get mppMilestoneTopRating => 'Note excellente';

  @override
  String get complimentGreatService => 'Service excellent';

  @override
  String get complimentKnewTheWay => 'Bon itinéraire';

  @override
  String get complimentFriendly => 'Conversation agréable';

  @override
  String get complimentCleanCar => 'Voiture propre';

  @override
  String get complimentSafeDriving => 'Conduite sûre';

  @override
  String get complimentGoodMusic => 'Bonne musique';

  @override
  String mppSince(String month) {
    return 'Chauffeur Movera depuis $month';
  }

  @override
  String get mppLanguagesMax =>
      'Vous en avez choisi 6. Retirez-en une pour en choisir une autre.';

  @override
  String get acctDeleteTitle => 'Supprimer mon compte';

  @override
  String get acctDeleteBody =>
      'Votre compte est fermé tout de suite : vous êtes déconnecté et ne pouvez plus vous connecter ni conduire avec. Après 30 jours, vos données personnelles sont effacées.';

  @override
  String get acctDeleteKept =>
      'Conservés : vos courses, gains et virements pour la loi comptable et, si vous devez de l’argent à Movera, votre nom, numéro et le montant jusqu’au paiement.';

  @override
  String get acctDeleteConfirmQ => 'Supprimer votre compte ?';

  @override
  String get acctDeleteConfirmBody =>
      'Action irréversible. Votre compte est fermé maintenant.';

  @override
  String get acctDeleteConfirm => 'Supprimer le compte';

  @override
  String get acctDeleteOpenTrip =>
      'Terminez ou annulez d’abord votre course, puis supprimez votre compte.';

  @override
  String get acctDeleteFailed =>
      'Impossible de supprimer le compte. Réessayez.';

  @override
  String get profLogOutClears =>
      'Les données d’aperçu de cet appareil seront effacées, y compris l’historique des courses, les contacts et les brouillons. Vous reviendrez à l’écran de connexion hors ligne.';

  @override
  String get profCouldNotClear =>
      'Impossible d’effacer les données locales. Vous êtes toujours connecté. Réessayez.';

  @override
  String get profLiveNoNameYet =>
      'Vos informations ne sont pas encore envoyées';

  @override
  String get acctDetailsSaved =>
      'Vos informations sont enregistrées. Movera les vérifie.';

  @override
  String get acctDetailsTitle => 'Vos informations';

  @override
  String get profSampleDriver => 'Profil de chauffeur d’exemple';

  @override
  String get logOutQ => 'Se déconnecter ?';

  @override
  String get helpCenter => 'Centre d’aide';

  @override
  String get profDemoNoVerified => 'Démo — aucun compte vérifié';

  @override
  String contactEmailVerified(String email) {
    return '$email · Vérifié';
  }

  @override
  String contactEmailNotVerified(String email) {
    return '$email · Non vérifié';
  }

  @override
  String get contactEmailNone => 'Aucun e-mail';
}
