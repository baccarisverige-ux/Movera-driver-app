// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Movera Chauffeur';

  @override
  String get hideReservationRequest => 'Masquer la demande de réservation';

  @override
  String tripMinutesMinTrip(Object tripMinutes) {
    return 'Course de $tripMinutes min';
  }

  @override
  String get n1Stop => '1 arrêt';

  @override
  String pickupWhenLabel(Object whenLabel) {
    return 'Prise en charge $whenLabel';
  }

  @override
  String get reservation => 'Réservation';

  @override
  String get exclusive => 'Exclusive';

  @override
  String pickupMinutesMin(Object minutes) {
    return ' · Prise en charge $minutes min';
  }

  @override
  String get findingTrips => 'Recherche de courses';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get ridePreferences => 'Préférences de course';

  @override
  String get wallet => 'Portefeuille';

  @override
  String get inbox => 'Messages';

  @override
  String get scheduled => 'Planifiées';

  @override
  String get exclusiveForYou => 'Exclusive pour vous';

  @override
  String get destinationSet => 'Destination définie';

  @override
  String get recommendations => 'Recommandations';

  @override
  String get destination => 'Destination';

  @override
  String get driverStatus => 'STATUT DU CHAUFFEUR';

  @override
  String get accountAccessPaused => 'Accès au compte suspendu';

  @override
  String get yourDriverStatusIsCurrentlySuspended =>
      'Votre statut de chauffeur est suspendu : vous ne pouvez pas accepter de nouvelles demandes ni démarrer le Radar.';

  @override
  String get moveraWillUseAuthoritativeAccountStatus =>
      'Movera utilisera le statut officiel de votre compte. Cet écran ne devine ni la raison ni la date de déblocage.';

  @override
  String get gotIt => 'Compris';

  @override
  String get pickup => 'Prise en charge';

  @override
  String stopNumber(Object number) {
    return 'Arrêt $number';
  }

  @override
  String get arrive => 'Arrivée';

  @override
  String get backToRequest => 'Retour à la demande';

  @override
  String tripMinutesMinDistance(Object tripMinutes, Object distance) {
    return '$tripMinutes min · $distance';
  }

  @override
  String get dropOff => 'Dépose';

  @override
  String destinationModeUntilUntil(Object until) {
    return 'Mode destination jusqu’à $until';
  }

  @override
  String get showRoute => 'Voir l’itinéraire';

  @override
  String get turnOffDestination => 'Désactiver la destination';

  @override
  String versionLatestVersion(Object latestVersion) {
    return 'Version $latestVersion';
  }

  @override
  String get openingUpdateEllipsis => 'Ouverture de la mise à jour…';

  @override
  String get couldNotOpenUpdatePleaseTry =>
      'Impossible d’ouvrir la mise à jour. Veuillez réessayer.';

  @override
  String get updating => 'MISE À JOUR';

  @override
  String get slideToOpen => 'GLISSER POUR OUVRIR';

  @override
  String get rideHistory => 'Historique des courses';

  @override
  String get goOfflineQuestion => 'Passer hors ligne ?';

  @override
  String get youStopGettingTripOffersUntil =>
      'Vous ne recevrez plus d’offres de course jusqu’à votre retour en ligne.';

  @override
  String get stayOnline => 'Rester en ligne';

  @override
  String get goOffline => 'Passer hors ligne';

  @override
  String restUntilTime(Object time) {
    return 'Repos jusqu’à $time';
  }

  @override
  String timeLeftToDrive(Object time) {
    return 'Encore $time de conduite';
  }

  @override
  String get paused => 'En pause';

  @override
  String get findingYourLocation => 'Recherche de votre position';

  @override
  String untilTime(Object time) {
    return 'Jusqu’à $time';
  }

  @override
  String get documentExpired => 'Document expiré';

  @override
  String get skipExclusiveOffer => 'Passer l’offre exclusive';

  @override
  String get pleaseWait => 'Patientez';

  @override
  String get tapToAccept => 'Touchez pour accepter';

  @override
  String headToYourPickupTimePickup(Object pickupTime, Object pickupAddress) {
    return 'Partez maintenant pour votre prise en charge de $pickupTime : $pickupAddress.';
  }

  @override
  String headToYourPickupTimePickup2(Object pickupTime) {
    return 'Partez pour votre prise en charge de $pickupTime';
  }

  @override
  String leaveNowForPickupTimePickup(Object pickupTime) {
    return 'Partez maintenant pour la prise en charge de $pickupTime';
  }

  @override
  String get scheduledRide => 'Course planifiée';

  @override
  String pickupAtPickupTimeInLeft(
    Object pickupTime,
    Object left,
    Object pickupAddress,
  ) {
    return 'Prise en charge à $pickupTime dans $left : $pickupAddress.';
  }

  @override
  String pickupTimePickupInLeft(Object pickupTime, Object left) {
    return 'Prise en charge de $pickupTime dans $left';
  }

  @override
  String goOnlineNowForYourPickup(Object pickupTime) {
    return 'Passez en ligne maintenant pour votre prise en charge de $pickupTime.';
  }

  @override
  String goOnlineForPickupTimePickup(Object pickupTime) {
    return 'Passez en ligne pour la prise en charge de $pickupTime';
  }

  @override
  String get matching => 'Attribution';

  @override
  String get accept => 'Accepter';

  @override
  String get recenter => 'Recentrer';

  @override
  String get contactSupport => 'Contacter l’assistance';

  @override
  String get skipDemo => 'Passer la démo';

  @override
  String get retry => 'Réessayer';

  @override
  String get safetyToolkit => 'Outils de sécurité';

  @override
  String get menu => 'Menu';

  @override
  String get searchDestination => 'Rechercher une destination';

  @override
  String get lastTrip => 'DERNIÈRE COURSE';

  @override
  String get hold => 'Maintenir';

  @override
  String get rightNow => 'En ce moment';

  @override
  String get cashRides => 'Courses en espèces';

  @override
  String get performance => 'Performance';

  @override
  String get latestWaybill => 'Dernier bon de commande';

  @override
  String get noneYet => 'Aucun pour l’instant';

  @override
  String get rating => 'Note';

  @override
  String get acceptance => 'Acceptation';

  @override
  String get cancellation => 'Annulation';

  @override
  String get drivingTime => 'Temps de conduite';

  @override
  String get worked => 'Travaillé';

  @override
  String get leftBeforeRest => 'Restant avant le repos';

  @override
  String get restUntil => 'Repos jusqu’à';

  @override
  String get workLimit => 'Limite de travail';

  @override
  String get restAfterIt => 'Repos ensuite';

  @override
  String countsWhileRadarIsOnAfter(Object workHours, Object restHours) {
    return 'Compte tant que le Radar est actif. Après $workHours h, vous vous reposez $restHours h avant de repasser en ligne. Une pause de $restHours h le remet à zéro.';
  }

  @override
  String get closeSheet => 'Fermer le panneau';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get exclusiveReservation => 'Réservation exclusive';

  @override
  String get exclusiveOffer => 'Offre exclusive';

  @override
  String get moveraRadar => 'Movera Radar';

  @override
  String get rider => 'Passager';

  @override
  String get cash => 'Espèces';

  @override
  String get allOffers => 'TOUTES LES OFFRES';

  @override
  String get savedTripCouldNotBeOpened =>
      'Impossible d’ouvrir la course enregistrée.';

  @override
  String get unresolvedTrip => 'Course non clôturée';

  @override
  String get thisSavedTripIsOlderThan =>
      'Cette course enregistrée date de plus de six heures. Reprenez-la ou clôturez-la vous-même.';

  @override
  String get savedRouteCoordinatesAreUnavailableClose =>
      'Les coordonnées de l’itinéraire enregistré sont indisponibles. Clôturez cette course avant d’en accepter une autre.';

  @override
  String get closeTrip => 'Clôturer la course';

  @override
  String get resumeTrip => 'Reprendre la course';

  @override
  String get savedTripCouldNotBeClosed =>
      'Impossible de clôturer la course enregistrée.';

  @override
  String get savedTripCannotBeRead => 'Course enregistrée illisible';

  @override
  String get tripSavedOnThisDeviceIs =>
      'La course enregistrée sur cet appareil est endommagée ou provient d’une autre version de l’app. Clôturez-la pour continuer. Une copie est conservée sur cet appareil pour l’assistance.';

  @override
  String get closeUnreadableTrip => 'Clôturer la course illisible';

  @override
  String get savedTripCouldNotBeRead =>
      'Une course enregistrée est illisible. Clôturez-la pour passer en ligne.';

  @override
  String get review => 'Voir';

  @override
  String get unreadableTripCouldNotBeClosed =>
      'Impossible de clôturer la course illisible.';

  @override
  String get riderDataUnavailable => 'Données du passager indisponibles';

  @override
  String get finishOrCloseSavedTripBefore =>
      'Terminez ou clôturez la course enregistrée avant de passer en ligne.';

  @override
  String get openSavedTrip => 'Ouvrir la course enregistrée';

  @override
  String get account => 'Compte';

  @override
  String get radar => 'Radar';

  @override
  String get tapForDetails => 'Touchez pour les détails';

  @override
  String get notActive => 'Inactif';

  @override
  String get tapToScan => 'Touchez pour scanner';

  @override
  String get connecting => 'Connexion';

  @override
  String get tripFound => 'Course trouvée';

  @override
  String get tapForAll => 'Touchez pour tout voir';

  @override
  String get scanning => 'Recherche';

  @override
  String get currentTrip => 'Course en cours';

  @override
  String get nextTripSecured => 'Prochaine course assurée';

  @override
  String riderNameIsOnWay(Object riderName) {
    return '$riderName arrive';
  }

  @override
  String get tripUpdatesCouldNotBeRefreshed =>
      'Impossible d’actualiser la course.';

  @override
  String get tripUpdateCouldNotBeSaved =>
      'Impossible d’enregistrer la mise à jour de la course. Nouvel essai automatique.';

  @override
  String get retryNow => 'Réessayer maintenant';

  @override
  String get couldNotSaveRiderCancellationRetry =>
      'Impossible d’enregistrer l’annulation du passager. Réessayez.';

  @override
  String get tripProgressCouldNotBeSaved =>
      'Impossible d’enregistrer la progression de la course. Gardez cet écran ouvert et réessayez.';

  @override
  String get thisStopNeedsVerifiedMapLocation =>
      'Cet arrêt doit avoir une position vérifiée sur la carte avant l’arrivée.';

  @override
  String get locationUnavailableEnableLocationToConfirm =>
      'Position indisponible. Activez la localisation pour confirmer l’arrivée.';

  @override
  String moveWithin100MOfWhere(Object where) {
    return 'Approchez-vous à moins de 100 m ($where) pour confirmer l’arrivée.';
  }

  @override
  String get yourDriverHasArrivedAtPickup =>
      'Votre chauffeur est arrivé au point de prise en charge.';

  @override
  String get locationUpdatingEllipsis => 'Mise à jour de la position…';

  @override
  String get stopLocationUnavailable => 'Position de l’arrêt indisponible';

  @override
  String get couldNotFinishSavingThisTrip =>
      'Impossible de terminer l’enregistrement de cette course. Relancez la clôture ; le reçu ne sera pas dupliqué.';

  @override
  String get alongYourDestination => 'Vers votre destination';

  @override
  String get cancelNextTripQuestion => 'Annuler la prochaine course ?';

  @override
  String get endThisTripEarlyQuestion => 'Terminer cette course plus tôt ?';

  @override
  String get cancelThisTripQuestion => 'Annuler cette course ?';

  @override
  String reasonTitle(Object title) {
    return 'Motif : $title';
  }

  @override
  String get yourCurrentTripContinuesNextTrip =>
      'Votre course actuelle continue. La prochaine course est proposée à un autre chauffeur.';

  @override
  String get onlyEndTripAfterYouHave =>
      'Ne terminez la course qu’une fois arrêté en lieu sûr, quand le passager peut descendre en sécurité.';

  @override
  String get cancelNextTrip => 'Annuler la prochaine course';

  @override
  String get endTripEarly => 'Terminer plus tôt';

  @override
  String get cancelTrip => 'Annuler la course';

  @override
  String get keepTrip => 'Garder la course';

  @override
  String get thisTripCannotBeCancelledRight =>
      'Cette course ne peut pas être annulée pour l’instant.';

  @override
  String get couldNotSaveCancellationRetry =>
      'Impossible d’enregistrer l’annulation. Réessayez.';

  @override
  String get firstTripEndedStartingNextOne =>
      'Première course terminée · début de la suivante';

  @override
  String tripEndedEarlyTitle(Object title) {
    return 'Course terminée plus tôt · $title';
  }

  @override
  String tripCancelledTitle(Object title) {
    return 'Course annulée · $title';
  }

  @override
  String get tripRouteAndOptions => 'Itinéraire et options';

  @override
  String get now => 'Maintenant';

  @override
  String get arrival => 'Arrivée';

  @override
  String get arriving => 'Arrivée proche';

  @override
  String get turnExclusiveOffersOff => 'Désactiver les offres exclusives';

  @override
  String get turnExclusiveOffersOn => 'Activer les offres exclusives';

  @override
  String get cashCollectInCar => 'Espèces : à encaisser dans la voiture';

  @override
  String get paidByCard => 'Payé par carte';

  @override
  String get rideCheckDemo => 'Démo de vérification de course';

  @override
  String demoValue(Object value) {
    return 'Démo : $value';
  }

  @override
  String get routeProgress => 'Progression de l’itinéraire';

  @override
  String get unavailable => 'Indisponible';

  @override
  String get addressUnavailable => 'Adresse indisponible';

  @override
  String get doesnTCount => 'Ne compte pas';

  @override
  String get tripUpdatesDisconnectedReconnectingIsRequired =>
      'Mises à jour de la course déconnectées. Reconnexion nécessaire.';

  @override
  String pickingUpRiderName(Object riderName) {
    return 'Prise en charge de $riderName';
  }

  @override
  String waitingForRiderName(Object riderName) {
    return 'En attente de $riderName';
  }

  @override
  String waitingAtStopNumber(Object number) {
    return 'Attente à l’arrêt $number';
  }

  @override
  String headingToStopNumber(Object number) {
    return 'En route vers l’arrêt $number';
  }

  @override
  String droppingOffRiderName(Object riderName) {
    return 'Dépose de $riderName';
  }

  @override
  String pickUpRiderName(Object riderName) {
    return 'Prendre en charge $riderName';
  }

  @override
  String driveToStopNumber(Object number) {
    return 'Aller à l’arrêt $number';
  }

  @override
  String dropOffRiderName(Object riderName) {
    return 'Déposer $riderName';
  }

  @override
  String get enRoute => 'En route';

  @override
  String paidWaitAtStopNumber(Object number) {
    return 'Attente payante à l’arrêt $number';
  }

  @override
  String get includedWaitThenPaid => 'Attente incluse · puis payante';

  @override
  String get paidWaitRunning => 'Attente payante en cours';

  @override
  String get paidWaitNoShowAvailable => 'Attente payante · absence possible';

  @override
  String get nextStop => 'Prochain arrêt';

  @override
  String get toDropOff => 'Vers la dépose';

  @override
  String get waiting => 'Attente';

  @override
  String get tripStarted => 'Course démarrée';

  @override
  String get tripCompleted => 'Course terminée';

  @override
  String holdForRiderName(Object riderName) {
    return 'Attendre $riderName';
  }

  @override
  String get thenDropOff => 'Puis dépose';

  @override
  String stop1OfStopAddressesLength(Object stopAddressesLength) {
    return 'Arrêt 1 sur $stopAddressesLength';
  }

  @override
  String get actionCouldNotBeCompletedPlease =>
      'L’action n’a pas pu aboutir. Veuillez réessayer.';

  @override
  String get confirmThisTripActionQuestion => 'Confirmer cette action ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get finishSoSoonQuestion => 'Terminer si tôt ?';

  @override
  String youPickedUpRiderMinutesMin(Object minutes) {
    return 'Vous avez pris en charge le passager il y a $minutes min. Ne terminez que si la course est vraiment finie.';
  }

  @override
  String get backToRide => 'Retour à la course';

  @override
  String get finishTrip => 'Terminer la course';

  @override
  String get isEverythingOkQuestion => 'Tout va bien ?';

  @override
  String rideCheckTitle(Object title) {
    return 'Vérification de course. $title';
  }

  @override
  String get rideCheck => 'Vérification de course';

  @override
  String get call112 => 'Appeler le 112';

  @override
  String get iMOk => 'Tout va bien';

  @override
  String get orTellUsWhatSHappening => 'Ou dites-nous ce qui se passe';

  @override
  String get yourAnswerIsSavedToThis =>
      'Votre réponse est enregistrée dans cette course.';

  @override
  String rideCheckShort(Object short) {
    return 'Vérification · $short';
  }

  @override
  String get whatIsHappeningQuestion => 'Que se passe-t-il ?';

  @override
  String get thanksThisIsSavedToTrip =>
      'Merci, c’est enregistré dans la course.';

  @override
  String get done => 'Terminé';

  @override
  String get yourAnswersAreSavedToThis =>
      'Vos réponses sont enregistrées dans cette course.';

  @override
  String get rideCheck112 => 'Vérification · 112';

  @override
  String get call112OnYourPhone => 'Appelez le 112 depuis votre téléphone';

  @override
  String get couldNotOpenDialerDial112 =>
      'Impossible d’ouvrir le clavier d’appel. Composez le 112 vous-même.';

  @override
  String get yourDialerOpensWith112Movera =>
      'Le clavier d’appel s’ouvre avec le 112. Movera n’appelle jamais à votre place.';

  @override
  String get moveraCouldNotBeAlerted => 'Impossible d’alerter Movera';

  @override
  String get moveraSafetyTeamAlerted => 'Équipe sécurité de Movera alertée';

  @override
  String get call112IfYouNeedHelp =>
      '\nAppelez le 112 si vous avez besoin d’aide maintenant.';

  @override
  String get tripDriverAndRiderDetailsWere =>
      '\nLes détails de la course, du chauffeur et du passager ont été envoyés.';

  @override
  String get call112Now => 'Appelez le 112 maintenant';

  @override
  String get ifSomeoneIsHurtOrIn =>
      'Si quelqu’un est blessé ou en danger, appelez les secours.';

  @override
  String get tellUsInFewWords => 'Dites-le-nous en quelques mots';

  @override
  String recordingTime(Object time) {
    return 'Enregistrement $time';
  }

  @override
  String get savedOnlyOnThisPhone => 'enregistré uniquement sur ce téléphone';

  @override
  String get recordAudio => 'Enregistrer l’audio';

  @override
  String audioSavedTime(Object time) {
    return 'Audio enregistré · $time';
  }

  @override
  String get onlyOnThisPhone => 'uniquement sur ce téléphone';

  @override
  String get notAvailableOnThisDevice => 'indisponible sur cet appareil';

  @override
  String get allowMicrophoneFirst => 'autorisez d’abord le micro';

  @override
  String get couldNotRecordTryAgain => 'échec de l’enregistrement, réessayez';

  @override
  String get stop => 'Arrêter';

  @override
  String get moveraRecordedThisTripAsCompleted =>
      'Movera a enregistré cette course comme terminée.';

  @override
  String get tripCancelledByMovera => 'Course annulée par Movera';

  @override
  String get moveraCancelledThisTripStopIn =>
      'Movera a annulé cette course. Arrêtez-vous en lieu sûr avant de quitter cet écran.';

  @override
  String get moveraClosedThisTripStopIn =>
      'Movera a clôturé cette course. Arrêtez-vous en lieu sûr avant de quitter cet écran.';

  @override
  String get tripCancelled => 'Course annulée';

  @override
  String get thisTripWasCancelledFromYour =>
      'Cette course a été annulée depuis votre compte.';

  @override
  String get riderCancelled => 'Le passager a annulé';

  @override
  String get riderCancelledThisTrip => 'Le passager a annulé cette course.';

  @override
  String get riderNoShowRecorded => 'Absence du passager enregistrée';

  @override
  String get thisPickupWasClosedBecauseRider =>
      'Cette prise en charge a été clôturée car le passager ne s’est pas présenté.';

  @override
  String get tripExpired => 'Course expirée';

  @override
  String get thisTripIsNoLongerActive => 'Cette course n’est plus active.';

  @override
  String get tripCouldNotContinue => 'La course n’a pas pu continuer';

  @override
  String get tripWasClosedBecauseOfSystem =>
      'La course a été clôturée à cause d’un problème système. Contactez l’assistance si le passager est toujours avec vous.';

  @override
  String get tripRemovedByMovera => 'Course retirée par Movera';

  @override
  String get moveraGaveThisTripBackTo =>
      'Movera a remis cette course en attribution. Arrêtez-vous en lieu sûr avant de quitter cet écran.';

  @override
  String get tripEnded => 'Course terminée';

  @override
  String bodyYourNextTripStartsNow(Object body) {
    return '$body Votre prochaine course commence maintenant.';
  }

  @override
  String get goToNextTrip => 'Aller à la prochaine course';

  @override
  String get holdToStopNextTrips =>
      'Maintenez pour arrêter les courses suivantes';

  @override
  String get holdToStartNextTrips =>
      'Maintenez pour lancer les courses suivantes';

  @override
  String get stopRadar => 'Arrêter le radar';

  @override
  String get startRadar => 'Lancer le radar';

  @override
  String get headingToPickup => 'En route vers la prise en charge';

  @override
  String waitingForFirst(Object first) {
    return 'En attente de $first';
  }

  @override
  String get toNextStop => 'Vers le prochain arrêt';

  @override
  String get onYourWay => 'Sur votre trajet';

  @override
  String get afterThisDropOff => 'Après cette dépose';

  @override
  String get availableAfterYourCurrentDropOff =>
      'Disponible après votre dépose actuelle';

  @override
  String exclusiveSecondsS(Object seconds) {
    return 'Exclusive · $seconds s';
  }

  @override
  String get onThisRide => 'Pendant cette course';

  @override
  String pickupMinutesMinAway(Object pickupMinutes) {
    return 'À $pickupMinutes min';
  }

  @override
  String get deny => 'Refuser';

  @override
  String get demoOffers => 'Offres de démo';

  @override
  String get demoOffersLiveLocationUnavailableStale =>
      'Offres de démo — position en direct indisponible ou ancienne';

  @override
  String get navigateWithGoogleMaps => 'Naviguer avec Google Maps';

  @override
  String get googleMapsIsUnavailable => 'Google Maps est indisponible.';

  @override
  String get callRider => 'Appeler le passager';

  @override
  String get messageRider => 'Écrire au passager';

  @override
  String get riderDetailsFromBookingWillAppear =>
      'Les détails du passager issus de la réservation s’afficheront ici quand le profil sera connecté au serveur.';

  @override
  String get retryRoute => 'Recalculer l’itinéraire';

  @override
  String get routeUnavailableYourTripRemainsActive =>
      'Itinéraire indisponible. Votre course reste active.';

  @override
  String get currentWaybill => 'Bon de commande actuel';

  @override
  String get currentTripWaybill => 'Bon de commande de la course';

  @override
  String get nextTripWaybill => 'Bon de commande de la prochaine course';

  @override
  String get nextTripsOnYourWay => 'Prochaines courses sur votre trajet';

  @override
  String get shareTripRecordAudioGetHelp =>
      'Partager la course, enregistrer l’audio, obtenir de l’aide';

  @override
  String get stopSafelyFirstReasonRequired =>
      'Arrêtez-vous d’abord en sécurité · motif requis';

  @override
  String get whyAreYouCancellingNextTripQuestion =>
      'Pourquoi annulez-vous la prochaine course ?';

  @override
  String get whyAreYouEndingTripQuestion =>
      'Pourquoi terminez-vous la course ?';

  @override
  String get whyAreYouCancellingQuestion => 'Pourquoi annulez-vous ?';

  @override
  String get yourCurrentTripContinues => 'Votre course actuelle continue.';

  @override
  String get stopInSafePlaceFirst => 'Arrêtez-vous d’abord en lieu sûr.';

  @override
  String get pickReasonThatFitsBest => 'Choisissez le motif le plus adapté.';

  @override
  String get riderEndedTrip => 'Le passager a terminé la course';

  @override
  String riderNameCancelledWhileTripWas(Object riderName) {
    return '$riderName a annulé pendant la course. Arrêtez-vous en lieu sûr avant de quitter cet écran.';
  }

  @override
  String riderNameCancelledThisRequestCurrent(Object riderName) {
    return '$riderName a annulé cette demande. La prise en charge en cours n’est plus active.';
  }

  @override
  String get activeTripCancelledByRider =>
      'Course en cours annulée par le passager';

  @override
  String get pickupCancelledByRider =>
      'Prise en charge annulée par le passager';

  @override
  String get tripUpdate => 'MISE À JOUR DE LA COURSE';

  @override
  String get keepControlOfVehicleAndStop =>
      'Gardez le contrôle du véhicule et arrêtez-vous en sécurité avant de continuer.';

  @override
  String get iHaveStoppedSafely => 'Je suis arrêté en sécurité';

  @override
  String get returnToRequests => 'Retour aux demandes';

  @override
  String get waitingInProgress => 'Attente en cours';

  @override
  String get takeCashBeforeYouFinish =>
      'Encaissez les espèces avant de terminer.';

  @override
  String takeCashFromFirstBeforeYou(Object first) {
    return 'Encaissez les espèces de $first avant de terminer.';
  }

  @override
  String get notYet => 'Pas encore';

  @override
  String collectAmountInCash(Object amount) {
    return 'Encaisser $amount en espèces';
  }

  @override
  String get collect => 'Encaisser';

  @override
  String get inCash => 'en espèces';

  @override
  String get yourFare => 'Votre tarif';

  @override
  String get cashFromRider => 'Espèces du passager';

  @override
  String get riderPaidMoreThanYourFare =>
      'Le passager a payé plus que votre tarif (promotion). La différence est réglée lors de votre prochain versement.';

  @override
  String get riderPaidLessThanYourFare =>
      'Le passager a payé moins que votre tarif (promotion). Movera ajoute la différence à votre prochain versement.';

  @override
  String get to => 'VERS';

  @override
  String get pickupArrived => 'Prise en charge · arrivé';

  @override
  String get pickupPickedUp => 'Prise en charge · passager à bord';

  @override
  String stopNumberDone(Object number) {
    return 'Arrêt $number · fait';
  }

  @override
  String get yourTrip => 'Votre course';

  @override
  String pickupPickupMinutesMin(Object pickupMinutes) {
    return 'Prise en charge · $pickupMinutes min';
  }

  @override
  String dropOffTripMinutesMinTrip(Object tripMinutes) {
    return 'Dépose · course de $tripMinutes min';
  }

  @override
  String get nextTripOptions => 'Options de la prochaine course';

  @override
  String get openWaybill => 'Ouvrir le bon de commande';

  @override
  String get contactRider => 'Contacter le passager';

  @override
  String get yourCurrentTripContinuesReasonRequired =>
      'Votre course actuelle continue · motif requis';

  @override
  String nextTripCancelledTitle(Object title) {
    return 'Prochaine course annulée · $title';
  }

  @override
  String get waybill => 'Bon de commande';

  @override
  String get stopWait => 'Attente à l’arrêt';

  @override
  String get pickupWait => 'Attente à la prise en charge';

  @override
  String get everyMinuteIsPaid => 'Chaque minute est payée';

  @override
  String get thisStopHasNoFreeMinutes =>
      'Cet arrêt n’a pas de minutes gratuites. Toute l’attente est ajoutée au tarif.';

  @override
  String ruleForThisPickupRule(Object rule) {
    return 'Règle pour cette prise en charge : $rule';
  }

  @override
  String get includedTime => 'Temps inclus';

  @override
  String get openingMinutesStayInsideFare =>
      'Les premières minutes sont comprises dans le tarif.';

  @override
  String get waitTime => 'Temps d’attente';

  @override
  String get addedFromFirstSecondAtThis =>
      'Ajouté dès la première seconde à cet arrêt.';

  @override
  String get addedToFareWhenThisTrip =>
      'Ajouté au tarif à la fin de la course.';

  @override
  String perMinuteFormattedMin(Object perMinuteFormatted) {
    return '$perMinuteFormatted / min';
  }

  @override
  String get noShow => 'Absence';

  @override
  String canBeAppliedAfterNoShow(Object noShowAfterMinutes) {
    return 'Applicable après $noShowAfterMinutes min si le passager n’est pas arrivé.';
  }

  @override
  String get riderDidnTShow => 'Passager absent';

  @override
  String youGetDriverShareWaitPercent(Object driverShareWaitPercent) {
    return 'Vous recevez $driverShareWaitPercent % du temps d’attente.';
  }

  @override
  String youGetDriverShareWaitPercent2(
    Object driverShareWaitPercent,
    Object driverShareNoShowPercent,
    Object driverNoShowFeeFormatted,
  ) {
    return 'Vous recevez $driverShareWaitPercent % du temps d’attente et $driverShareNoShowPercent % des frais d’absence ($driverNoShowFeeFormatted).';
  }

  @override
  String get amountsCanChangeWithTaxesAnd =>
      'Les montants peuvent varier selon les taxes et frais.';

  @override
  String get close => 'Fermer';

  @override
  String waitingFeePerMinuteFormattedMin(Object perMinuteFormatted) {
    return 'frais d’attente · $perMinuteFormatted / min';
  }

  @override
  String get later => 'Plus tard';

  @override
  String get includedMinutes => 'Minutes incluses';

  @override
  String get theseFirstMinutesAreAlreadyPart =>
      'Ces premières minutes sont déjà comprises dans le tarif.';

  @override
  String get waitTimeIsRunning => 'Le temps d’attente court';

  @override
  String get eachMinuteAfterIncludedTimeIs =>
      'Chaque minute après le temps inclus est ajoutée à la fin de la course.';

  @override
  String get noShowCanBeApplied => 'L’absence peut être appliquée';

  @override
  String get riderIsStillNotHereNo =>
      'Le passager n’est toujours pas là. Le montant d’absence est maintenant disponible.';

  @override
  String get tripDetails => 'Détails de la course';

  @override
  String get justNow => 'À l’instant';

  @override
  String get rideCompleted => 'Course terminée';

  @override
  String includesFeeWaitingFee(Object fee) {
    return 'Dont $fee de frais d’attente';
  }

  @override
  String get payment => 'Paiement';

  @override
  String get lastWaybill => 'Dernier bon de commande';

  @override
  String get open => 'Ouvrir';

  @override
  String get tripId => 'N° de course';

  @override
  String get completed => 'Terminée';

  @override
  String get ratingNotSentDemo => 'Note non envoyée (démo)';

  @override
  String rateRider(Object rider) {
    return 'Noter $rider';
  }

  @override
  String get trip => 'Course n°';

  @override
  String get time => 'Heure';

  @override
  String get fare => 'Tarif';

  @override
  String get passenger => 'Passager';

  @override
  String get via => 'Via';

  @override
  String get from => 'De';

  @override
  String get to2 => 'À';

  @override
  String get driver => 'Chauffeur';

  @override
  String get licensePlate => 'Plaque d’immatriculation';

  @override
  String get passengerCapacity => 'Nombre de places';

  @override
  String get paidByPassenger => 'Payé par le passager';

  @override
  String get inApp => 'Dans l’app';

  @override
  String basePriceService(Object service) {
    return 'Prix de base · $service';
  }

  @override
  String get moveraFee => 'Frais Movera';

  @override
  String get moveraBonus => 'Bonus Movera';

  @override
  String get yourEarnings => 'Vos gains';

  @override
  String get roundToNearestWholeKronaIn =>
      '* Arrondir à la couronne entière la plus proche au taximètre.';

  @override
  String get feature => 'Option';

  @override
  String get samplePeriod => 'Période d’exemple';

  @override
  String get clear => 'Effacer';

  @override
  String get back => 'Retour';

  @override
  String get earningsPreview => 'Aperçu des gains';

  @override
  String get demoRider => 'Passager de démo';

  @override
  String get sampleDistance => 'Distance d’exemple';

  @override
  String get sample => 'Exemple';

  @override
  String get pickupFrom => 'Prise en charge à';

  @override
  String get samplePickupStockholm => 'Prise en charge d’exemple, Stockholm';

  @override
  String get dropOffLocation => 'Lieu de dépose';

  @override
  String get sampleDropOffStockholm => 'Dépose d’exemple, Stockholm';

  @override
  String get noAnswer => 'Pas de réponse';

  @override
  String answerAnswer(Object answer) {
    return 'Réponse : $answer';
  }

  @override
  String audioSavedOnlyOnThisPhone(Object time) {
    return 'Audio enregistré uniquement sur ce téléphone · $time';
  }

  @override
  String get illustrativeMapArchivedRouteUnavailable =>
      'Carte indicative · itinéraire archivé indisponible';

  @override
  String get rideCost => 'Prix de la course';

  @override
  String get tip => 'Pourboire';

  @override
  String get paymentMethod => 'Moyen de paiement';

  @override
  String get rideType => 'Type de course';

  @override
  String get cashCollected => 'Espèces encaissées';

  @override
  String get cashMatchedYourFare => 'Les espèces correspondent à votre tarif';

  @override
  String get settledInYourNextPayout =>
      'Réglé lors de votre prochain versement';

  @override
  String get rideCompletedOn => 'Course terminée le';

  @override
  String get cancelledByRider => 'Annulée par le passager';

  @override
  String get cancelledByDriver => 'Annulée par le chauffeur';

  @override
  String get cancelledBySupport => 'Annulée par l’assistance';

  @override
  String get cancelledByMovera => 'Annulée par Movera';

  @override
  String get riderDidNotArrive => 'Passager absent';

  @override
  String get tripFailed => 'Course en échec';

  @override
  String get previous => 'Précédentes';

  @override
  String get last7Days => '7 derniers jours';

  @override
  String get loadingRideHistoryEllipsis => 'Chargement de l’historique…';

  @override
  String get couldNotLoadRideHistory =>
      'Impossible de charger l’historique des courses.';

  @override
  String get earningsHistory => 'Gains et historique';

  @override
  String get allRides => 'Toutes les courses';

  @override
  String get yourMoveraActivity => 'Votre activité Movera';

  @override
  String get online => 'En ligne';

  @override
  String get rides => 'Courses';

  @override
  String get earningsBreakdown => 'Détail des gains';

  @override
  String get latestRides => 'Dernières courses';

  @override
  String get noCompletedRidesInThisPeriod =>
      'Aucune course terminée sur cette période.';

  @override
  String viewAllVisibleRideCountRides(Object visibleRideCount) {
    return 'Voir les $visibleRideCount courses';
  }

  @override
  String periodRidesRidesInPeriodLabel(Object periodRides, Object periodLabel) {
    return '$periodRides courses · $periodLabel';
  }

  @override
  String get week => 'Semaine';

  @override
  String get month => 'Mois';

  @override
  String get recordedFares => 'Tarifs enregistrés';

  @override
  String get tipsAndFees => 'Pourboires et frais';

  @override
  String get notAvailable => 'Indisponible';

  @override
  String get otherEarnings => 'Autres gains';

  @override
  String otherEarningsTripsLengthCash(Object tripsLength) {
    return 'Autres gains · $tripsLength en espèces';
  }

  @override
  String get cashTripsYourFareMinusCash =>
      'Courses en espèces : votre tarif moins les espèces encaissées.';

  @override
  String get noCashTripsInThisPeriod =>
      'Aucune course en espèces sur cette période.';

  @override
  String get totalYouOweMovera => 'Total dû à Movera';

  @override
  String get totalMoveraOwesYou => 'Total que Movera vous doit';

  @override
  String get totalBalance => 'Solde total';

  @override
  String get settledInYourNextPayout2 =>
      'Réglé lors de votre prochain versement.';

  @override
  String fareFareFormattedCashCashCollected(
    Object fareFormatted,
    Object cashCollectedFormatted,
  ) {
    return 'Tarif $fareFormatted · Espèces $cashCollectedFormatted';
  }

  @override
  String get driver2 => 'CHAUFFEUR';

  @override
  String get profile => 'Profil';

  @override
  String get accountVehicleAndDocuments => 'Compte, véhicule et documents';

  @override
  String get earningsAndWeeklyPayouts => 'Gains et versements hebdomadaires';

  @override
  String get completedAndPreviousRides => 'Courses terminées et passées';

  @override
  String get notifications => 'Notifications';

  @override
  String get rideAlertsDemandAndAccount =>
      'Alertes de course, demande et compte';

  @override
  String get work => 'TRAVAIL';

  @override
  String get scheduledRides => 'Courses planifiées';

  @override
  String get reservationsAndAcceptedTrips =>
      'Réservations et courses acceptées';

  @override
  String get chooseCategoriesYouWantToReceive =>
      'Choisissez les catégories que vous voulez recevoir';

  @override
  String get promotions => 'Promotions';

  @override
  String get bonusesAndCampaignOffers => 'Bonus et offres en cours';

  @override
  String get drivingLogs => 'Journal de conduite';

  @override
  String get hoursOnlineAndRestRules => 'Heures en ligne et règles de repos';

  @override
  String get supportApp => 'ASSISTANCE ET APP';

  @override
  String get support => 'Assistance';

  @override
  String get messagesAndSupportTickets => 'Messages et demandes d’assistance';

  @override
  String get settings => 'Réglages';

  @override
  String get appAndDriverSettings => 'Réglages de l’app et du chauffeur';

  @override
  String sampleRating(Object rating) {
    return 'Note d’exemple $rating';
  }

  @override
  String get active => 'Actif';

  @override
  String get pending => 'En attente';

  @override
  String get soundVoice => 'Son et voix';

  @override
  String get savingPreferencesEllipsis => 'Enregistrement des préférences…';

  @override
  String get changesNotSavedRetry =>
      'Modifications non enregistrées — Réessayer';

  @override
  String get couldNotLoadSavedPreferencesRetry =>
      'Impossible de charger les préférences — Réessayer';

  @override
  String get localDemoPreferencesSavedOnThis =>
      'Préférences de démo locales — enregistrées sur cet appareil ; les effets sont des aperçus.';

  @override
  String get volume => 'Volume';

  @override
  String get generalVolume => 'Volume général';

  @override
  String get alwaysPlayTripRequests => 'Toujours jouer les demandes de course';

  @override
  String get playsEvenWhenPhoneIsSilent =>
      'Même quand le téléphone est en silencieux';

  @override
  String get voice => 'Voix';

  @override
  String get voiceNavigation => 'Navigation vocale';

  @override
  String get spokenTurnsWhileYouDrive =>
      'Indications vocales pendant la conduite';

  @override
  String get readRiderMessages => 'Lire les messages du passager';

  @override
  String get readsNewChatMessagesAloud =>
      'Lit à voix haute les nouveaux messages';

  @override
  String get testAlerts => 'Tester les alertes';

  @override
  String get testVoice => 'Tester la voix';

  @override
  String get playingAlertSoundMock => 'Lecture du son d’alerte (simulation)';

  @override
  String get playingVoiceSoundMock => 'Lecture de la voix (simulation)';

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get hearing => 'Audition';

  @override
  String get tellRidersIfYouAreDeaf =>
      'Indiquez aux passagers si vous êtes sourd ou malentendant.';

  @override
  String get demoPreviewNoInformationIsShared =>
      'Aperçu de démo — aucune information n’est partagée avec les passagers.';

  @override
  String get closePreview => 'Fermer l’aperçu';

  @override
  String get flashForRequests => 'Flash pour les demandes';

  @override
  String get screenFlashesWhenRequestArrives =>
      'L’écran clignote à l’arrivée d’une demande.';

  @override
  String get vibrationForRequests => 'Vibration pour les demandes';

  @override
  String get phoneVibratesWhenRequestArrives =>
      'Le téléphone vibre à l’arrivée d’une demande.';

  @override
  String get appSettings => 'Réglages de l’app';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get unavailableInDemo => 'Indisponible en démo';

  @override
  String get language => 'Langue';

  @override
  String get pinVerification => 'Vérification par code';

  @override
  String get emergencyContacts => 'Contacts d’urgence';

  @override
  String get safety => 'Sécurité';

  @override
  String get showTrafficOnMap => 'Afficher le trafic sur la carte';

  @override
  String get trafficColoursOnTripMap =>
      'Couleurs du trafic sur la carte de course';

  @override
  String get trustedContact => 'Contact de confiance';

  @override
  String get dialerIsUnavailable => 'Le clavier d’appel est indisponible.';

  @override
  String get addTrustedContact => 'Ajouter un contact de confiance';

  @override
  String get couldNotLoadTrustedContactsRetry =>
      'Impossible de charger les contacts de confiance — Réessayer';

  @override
  String get trustedContactsStayOnThisDevice =>
      'Les contacts de confiance restent sur cet appareil. Appeler ouvre votre clavier d’appel.';

  @override
  String callName(Object name) {
    return 'Appeler $name';
  }

  @override
  String get contactCouldNotBeSavedRetry =>
      'Impossible d’enregistrer le contact. Réessayez.';

  @override
  String get name => 'Nom';

  @override
  String get enterName => 'Saisissez un nom';

  @override
  String get phone => 'Téléphone';

  @override
  String get enterValidPhoneNumber => 'Saisissez un numéro de téléphone valide';

  @override
  String get relation => 'Lien';

  @override
  String get savingContactEllipsis => 'Enregistrement du contact…';

  @override
  String get saveContact => 'Enregistrer le contact';

  @override
  String get recentPayouts => 'Versements récents';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get previewOnly => 'Aperçu uniquement';

  @override
  String get noPayoutBalanceUntilPaymentService =>
      'Aucun solde à verser tant qu’aucun service de paiement n’est connecté.';

  @override
  String get noAutomaticPayout => 'Pas de versement automatique';

  @override
  String get payoutDateIsNotAvailable => 'Date de versement indisponible';

  @override
  String get notSet => 'Non défini';

  @override
  String get noPayoutsYetLocalPreviewCannot =>
      'Aucun versement pour l’instant. L’aperçu local n’invente pas de gains.';

  @override
  String get payoutAccount => 'Compte de versement';

  @override
  String get noPayoutAccountConnected => 'Aucun compte de versement connecté';

  @override
  String ratingRiderTripsTrips(Object rating, Object riderTrips) {
    return '$rating · $riderTrips courses';
  }

  @override
  String get closeOffer => 'Fermer l’offre';

  @override
  String reservationTime(Object time) {
    return 'Réservation · $time';
  }

  @override
  String get priority => 'Prioritaire';

  @override
  String get demoModeNoAccount => 'Mode démo — sans compte';

  @override
  String labelUnavailableInDemo(Object label) {
    return '$label — indisponible en démo';
  }

  @override
  String get routeUpdated => 'Itinéraire mis à jour';

  @override
  String get gpsRestored => 'GPS rétabli';

  @override
  String get waitingAtStop => 'Attente à l’arrêt';

  @override
  String get paidWaiting => 'Attente payante';

  @override
  String get waitingTime => 'Temps d’attente';

  @override
  String nearValue(Object value) {
    return 'Proche : $value';
  }

  @override
  String get arrivingSoon => 'Arrivée imminente';

  @override
  String trafficAheadValueMin(Object value) {
    return 'Trafic devant · +$value min';
  }

  @override
  String arrivingInEtaMinTimeTime2(Object eta, Object time, Object time2) {
    return 'Arrivée dans $eta min · $time:$time2';
  }

  @override
  String nextTripSecuredNextTripFare(Object nextTripFare) {
    return 'Prochaine course assurée · $nextTripFare';
  }

  @override
  String pickupOnPickupSideSide(Object pickupSide) {
    return 'Prise en charge côté $pickupSide';
  }

  @override
  String get tollAhead => 'Péage devant';

  @override
  String pickupOverKmKm(Object km) {
    return 'Prise en charge à plus de $km km';
  }

  @override
  String get assignedByMovera => 'Attribuée par Movera';

  @override
  String inclBonusMoveraBonus(Object bonus) {
    return 'dont +$bonus de bonus Movera';
  }

  @override
  String get islandOnline => 'Radar en ligne';

  @override
  String get islandOffline => 'Radar hors ligne';

  @override
  String get islandRiderCancelled => 'Le passager a annulé';

  @override
  String get islandRiderEndedTrip => 'Le passager a terminé';

  @override
  String get islandTripRemoved => 'Course retirée par Movera';

  @override
  String islandCancelFee(Object amount) {
    return '+$amount';
  }

  @override
  String get islandCancelNoFee => 'sans frais';

  @override
  String islandReservationCancelled(Object time) {
    return '$time annulée';
  }

  @override
  String get islandMatching => 'Attribution…';

  @override
  String get islandMatched => 'Course attribuée';

  @override
  String get islandTakenByOther => 'Prise par un autre chauffeur';

  @override
  String get islandTripUnavailable => 'Course indisponible';

  @override
  String get islandNoConnection => 'Pas de connexion';

  @override
  String get islandContactSupport => 'Contacter l’assistance';

  @override
  String get islandAccountOnHold => 'Compte suspendu · Contacter l’assistance';

  @override
  String get islandAccountNotActive => 'Compte inactif · Finir l’inscription';

  @override
  String get islandNewReservation => 'Nouvelle réservation';

  @override
  String get islandExclusiveRide => 'Course exclusive';

  @override
  String get islandExclusiveReservation => 'Réservation exclusive';

  @override
  String get islandReservationAccepted => 'Réservation acceptée';

  @override
  String islandReservationAcceptedAt(Object time) {
    return 'Acceptée · prise en charge $time';
  }

  @override
  String get islandNoLongerAvailable => 'Plus disponible';

  @override
  String get islandAssignedByMovera => 'Attribuée par Movera';

  @override
  String get islandAssignmentAccepted => 'Course planifiée acceptée';

  @override
  String get islandAssignmentNotAccepted => 'Attribution non acceptée';

  @override
  String islandPickupIn(Object time, Object left) {
    return 'Prise en charge $time dans $left';
  }

  @override
  String islandGoOnlineFor(Object time) {
    return 'Passez en ligne pour $time';
  }

  @override
  String islandLeaveNow(Object time) {
    return 'Partez pour la prise en charge de $time';
  }

  @override
  String islandHeadToPickup(Object time) {
    return 'En route pour $time';
  }

  @override
  String get islandGivenToBackup => 'Confiée à un chauffeur de secours';

  @override
  String get islandCashOn => 'Courses en espèces activées';

  @override
  String get islandCashOff => 'Courses en espèces désactivées';

  @override
  String get islandLastMissed => 'Prochaine offre manquée : hors ligne';

  @override
  String islandOfflineMissed(Object count) {
    return 'Hors ligne : $count offres manquées';
  }

  @override
  String islandDrivingLeft(Object minutes) {
    return 'Encore $minutes min de conduite';
  }

  @override
  String islandRestUntil(Object time) {
    return 'Repos jusqu’à $time';
  }

  @override
  String get islandRestOver => 'Repos terminé';

  @override
  String islandDocumentExpires(Object document, Object when) {
    return '$document expire $when';
  }

  @override
  String islandDocumentExpired(Object document) {
    return '$document expiré';
  }

  @override
  String get islandDocumentInReview => 'Nouveau document en vérification';

  @override
  String get islandDocumentApproved => 'Document approuvé';

  @override
  String islandHighDemand(Object area) {
    return 'Forte demande · $area';
  }

  @override
  String get islandScheduledPaused => 'Courses planifiées en pause';

  @override
  String get islandSavedTripOpen => 'Course enregistrée ouverte';

  @override
  String get islandNewerTripKept => 'Course plus récente conservée';

  @override
  String get islandRecordSetAside => 'Course mise de côté';

  @override
  String get islandRecoveryFailed => 'Échec de la récupération';

  @override
  String get islandTripNotClosed => 'Course non clôturée';

  @override
  String get islandCloseSavedTrip => 'Clôturer la course enregistrée';

  @override
  String get islandSeeEarnings => 'Touchez pour voir vos gains';

  @override
  String get islandDestinationsUsed => 'Destinations du jour épuisées';

  @override
  String get islandDestinationOff => 'Mode destination indisponible ici';

  @override
  String get islandDestinationEnded => 'Mode destination terminé';

  @override
  String get offerYourShare => 'Votre part';

  @override
  String get offerFare => 'Tarif';

  @override
  String get offerPickup => 'Prise en charge';

  @override
  String get offerDropoff => 'Dépose';

  @override
  String get offerPickupNearby => 'Prise en charge proche';

  @override
  String offerKmAway(Object km) {
    return 'À $km km';
  }

  @override
  String offerTripLength(Object minutes, Object km) {
    return 'Course de $minutes min · $km km';
  }

  @override
  String get offerMatch => 'Prendre';

  @override
  String get offerMatching => 'Attribution…';

  @override
  String get offerAccept => 'Accepter';

  @override
  String get offerOnYourWay => 'Sur votre trajet';

  @override
  String get offerHide => 'Masquer l’offre';

  @override
  String get offerReservationRequest => 'Demande de réservation';

  @override
  String get offerYourNextRide => 'Votre prochaine course';

  @override
  String get offerViewRoute => 'Voir l’itinéraire';

  @override
  String get offerNewReservation => 'Nouvelle réservation';

  @override
  String get offerViewDetails => 'Voir les détails';

  @override
  String get tripArrived => 'Je suis arrivé';

  @override
  String get tripStart => 'Démarrer la course';

  @override
  String get tripStartFirstStop => 'Vers le premier arrêt';

  @override
  String get tripArriveAtStop => 'Arrivé à l’arrêt';

  @override
  String get tripComplete => 'Terminer la course';

  @override
  String tripGoToStop(Object stop) {
    return 'Aller au $stop arrêt';
  }

  @override
  String get tripGoToDropoff => 'Aller à la dépose';

  @override
  String get tripCollectCash => 'Encaisser les espèces';

  @override
  String get tripCompleteRide => 'Terminer la course';

  @override
  String tripFinishCategory(Object category) {
    return 'Terminer $category';
  }

  @override
  String get tripFinishRide => 'Terminer la course';

  @override
  String get cancelReasonRiderNoShow => 'Le passager ne s’est pas présenté';

  @override
  String get cancelReasonRiderNoShowDetail =>
      'Le délai d’attente est écoulé et le passager n’est pas là';

  @override
  String get cancelReasonRiderRequestedCancel =>
      'Le passager a demandé l’annulation';

  @override
  String get cancelReasonRiderRequestedCancelDetail =>
      'Le passager ne veut pas continuer';

  @override
  String get cancelReasonRiderNotAtPickup =>
      'Passager absent au point de prise en charge';

  @override
  String get cancelReasonRiderNotAtPickupDetail =>
      'Vous êtes arrivé mais n’avez pas trouvé le passager';

  @override
  String get cancelReasonUnsafePickup => 'Prise en charge dangereuse';

  @override
  String get cancelReasonUnsafePickupDetail =>
      'Vous ne pouvez pas vous y arrêter en sécurité';

  @override
  String get cancelReasonVehicleIssueBeforeStart => 'Problème de véhicule';

  @override
  String get cancelReasonVehicleIssueBeforeStartDetail =>
      'Votre voiture ne peut pas faire la course';

  @override
  String get cancelReasonDriverEmergencyBeforeStart => 'Urgence personnelle';

  @override
  String get cancelReasonDriverEmergencyBeforeStartDetail =>
      'Un imprévu urgent est survenu';

  @override
  String get cancelReasonOtherBeforeStart => 'Autre motif';

  @override
  String get cancelReasonOtherBeforeStartDetail =>
      'Autre chose empêche cette prise en charge';

  @override
  String get cancelReasonRiderRequestedEarlyEnd =>
      'Le passager veut arrêter la course';

  @override
  String get cancelReasonRiderRequestedEarlyEndDetail =>
      'Le passager veut descendre avant la destination';

  @override
  String get cancelReasonSafetyConcernOnTrip => 'Problème de sécurité';

  @override
  String get cancelReasonSafetyConcernOnTripDetail =>
      'Continuer la course pourrait être dangereux';

  @override
  String get cancelReasonVehicleIssueOnTrip => 'Problème de véhicule';

  @override
  String get cancelReasonVehicleIssueOnTripDetail =>
      'Un problème de véhicule rend la suite dangereuse';

  @override
  String get cancelReasonAccidentOrRoadEmergency =>
      'Accident ou urgence routière';

  @override
  String get cancelReasonAccidentOrRoadEmergencyDetail =>
      'Un incident ou une urgence empêche de continuer';

  @override
  String get cancelReasonRiderBehavior => 'Comportement du passager';

  @override
  String get cancelReasonRiderBehaviorDetail =>
      'Le comportement du passager impose d’arrêter la course';

  @override
  String get cancelReasonTripOrDestinationIssue =>
      'Problème de course ou de destination';

  @override
  String get cancelReasonTripOrDestinationIssueDetail =>
      'Un détail de la course ou de la destination empêche de continuer';

  @override
  String get cancelReasonOtherOnTrip => 'Autre motif';

  @override
  String get cancelReasonOtherOnTripDetail =>
      'Un autre problème impose de terminer la course plus tôt';

  @override
  String get cancelReasonScheduledCannotMakeTime =>
      'Je ne peux plus être là à l’heure';

  @override
  String get cancelReasonScheduledVehicleIssue => 'Problème de véhicule';

  @override
  String get cancelReasonScheduledPersonalEmergency => 'Urgence personnelle';

  @override
  String get cancelReasonScheduledPickupTooFar =>
      'La prise en charge est trop loin';

  @override
  String get cancelReasonScheduledTripDetails =>
      'Les détails de la course ne me conviennent plus';

  @override
  String get cancelReasonScheduledOther => 'Autre motif';

  @override
  String get cancelReasonNextTripCurrentRunningLate =>
      'La course actuelle prend plus de temps';

  @override
  String get cancelReasonNextTripCurrentRunningLateDetail =>
      'Vous ne pouvez pas arriver à temps à la prochaine prise en charge';

  @override
  String get cancelReasonNextTripPickupTooFar =>
      'Trop loin de la prise en charge';

  @override
  String get cancelReasonNextTripPickupTooFarDetail =>
      'La prochaine prise en charge est plus loin que prévu';

  @override
  String get cancelReasonNextTripRiderRequested =>
      'Le passager m’a demandé d’annuler';

  @override
  String get cancelReasonNextTripRiderRequestedDetail =>
      'Le prochain passager ne veut plus la course';

  @override
  String get cancelReasonNextTripVehicleIssue => 'Problème avec la voiture';

  @override
  String get cancelReasonNextTripVehicleIssueDetail =>
      'Votre voiture ne peut pas faire la prochaine course';

  @override
  String get cancelReasonNextTripDriverEmergency => 'Urgence personnelle';

  @override
  String get cancelReasonNextTripDriverEmergencyDetail =>
      'Un imprévu urgent est survenu';

  @override
  String get cancelReasonNextTripOther => 'Autre motif';

  @override
  String get cancelReasonNextTripOtherDetail =>
      'Autre chose empêche la prochaine course';

  @override
  String get cancelReasonPickupIncorrect =>
      'Le point de prise en charge est incorrect';

  @override
  String get cancelReasonWrongRideOption =>
      'J’ai choisi le mauvais type de course';

  @override
  String get cancelReasonRequestedByMistake =>
      'J’ai commandé la course par erreur';

  @override
  String get cancelReasonWaitTooLong => 'L’attente est trop longue';

  @override
  String get cancelReasonDestinationChange =>
      'La destination doit être modifiée';

  @override
  String get cancelReasonDriverNotSuitable =>
      'Le chauffeur ou la course ne conviennent pas';

  @override
  String get cancelReasonPlansChanged => 'Changement de programme';

  @override
  String get cancelReasonSomethingElse => 'Autre chose';

  @override
  String get exclusiveReasonBestMatch => 'Meilleur choix';

  @override
  String get exclusiveReasonFavourite => 'Favori du passager';

  @override
  String get exclusiveReasonFinishingNearby => 'Vous terminez à proximité';

  @override
  String get exclusiveReasonAirportQueue => 'File de l’aéroport';

  @override
  String get exclusiveReasonPickupSoon => 'Prise en charge imminente';

  @override
  String get exclusiveReasonNearby => 'Rien que pour vous · à proximité';

  @override
  String get waitingRulePickupFarAway => 'Prise en charge éloignée';

  @override
  String get waitingRuleScheduledRide => 'Course planifiée';

  @override
  String get waitingRuleAirportPickup => 'Prise en charge à l’aéroport';

  @override
  String get waitingRuleEventPickup => 'Prise en charge lors d’un événement';

  @override
  String riderBags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le passager a $count bagages',
      one: 'Le passager a 1 bagage',
    );
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageZoneDefault => 'Langue par défaut de votre zone';

  @override
  String get languageSaveFailed => 'Langue non enregistrée. Réessayez.';

  @override
  String get tomorrow => 'Demain';

  @override
  String get todayCaps => 'AUJOURD’HUI';

  @override
  String get statusRest => 'REPOS';

  @override
  String get statusHold => 'BLOQUÉ';

  @override
  String whenInMinutes(Object minutes) {
    return 'Dans $minutes min';
  }

  @override
  String whenInHours(Object hours) {
    return 'Dans $hours h';
  }

  @override
  String whenToday(Object time) {
    return 'Aujourd’hui $time';
  }

  @override
  String whenTomorrow(Object time) {
    return 'Demain $time';
  }

  @override
  String get stopOrdinal1 => 'premier';

  @override
  String get stopOrdinal2 => 'deuxième';

  @override
  String get stopOrdinal3 => 'troisième';

  @override
  String get stopOrdinal4 => 'quatrième';

  @override
  String get stopOrdinal5 => 'cinquième';

  @override
  String stopOrdinalN(Object number) {
    return '${number}e';
  }

  @override
  String get hideRequest => 'Masquer la demande';

  @override
  String get holdToGoOffline => 'Maintenez pour passer hors ligne';

  @override
  String get tripOptions => 'Options de la course';

  @override
  String get orbMatch => 'PRENDRE';

  @override
  String get orbWait => 'ATTENTE';

  @override
  String get orbOff => 'ARRÊT';

  @override
  String get orbOn => 'MARCHE';

  @override
  String get orbNew => 'NOUVEAU';

  @override
  String get orbLive => 'ACTIF';

  @override
  String get orbPaused => 'PAUSE';

  @override
  String get orbStarting => 'DÉMARRAGE';

  @override
  String get navArrived => 'ARRIVÉ';

  @override
  String get navNear => 'PROCHE';

  @override
  String get navNow => 'ICI';

  @override
  String get menuOnline => 'EN LIGNE';

  @override
  String get menuOffline => 'HORS LIGNE';

  @override
  String get menuReady => 'PRÊT';

  @override
  String get menuPending => 'EN ATTENTE';

  @override
  String get ok => 'OK';

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String stopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts',
      one: '1 arrêt',
    );
    return '$_temp0';
  }
}
