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
  String get tripStorageUnavailable =>
      'Le stockage des courses de cet appareil n’a pas pu être ouvert : aucune course enregistrée ne peut être restaurée pour l’instant. Vous pouvez quand même passer en ligne.';

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
  String get preciseLocationOff =>
      'La position exacte est désactivée. Activez-la dans les réglages pour afficher votre position et confirmer l’arrivée.';

  @override
  String get preciseLocationOffShort => 'Position exacte désactivée';

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
  String get safetyAlertKeptOnPhoneDemo =>
      'Démo : alerte gardée uniquement sur ce téléphone. Personne chez Movera n’a été prévenu.';

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
  String get audioStoppedWhenAppLeft => 'arrêté quand Movera a quitté l’écran';

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
  String islandLateReassigned(Object minutes) {
    return 'Confiée à un autre chauffeur : $minutes min de retard';
  }

  @override
  String get lateEtaReassignedTitle => 'Course confiée à un autre chauffeur';

  @override
  String lateEtaReassignedNote(String time, int minutes) {
    return 'Course confiée à un autre chauffeur — vous arriveriez à la prise en charge de $time avec environ $minutes min de retard.';
  }

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
      one: 'Le passager a $count bagage',
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
      one: '$count course',
    );
    return '$_temp0';
  }

  @override
  String stopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts',
      one: '$count arrêt',
    );
    return '$_temp0';
  }

  @override
  String get navArrive => 'Arrivée';

  @override
  String get navHeadOut => 'Partez';

  @override
  String get navKeepLeft => 'Serrez à gauche';

  @override
  String get navKeepRight => 'Serrez à droite';

  @override
  String get navTunnelAhead => 'Tunnel à venir';

  @override
  String get navTollRoadAhead => 'Route à péage à venir';

  @override
  String get navContinueStraight => 'Continuez tout droit';

  @override
  String get navContinue => 'Continuez';

  @override
  String get navRoundabout => 'Rond-point';

  @override
  String navRoundaboutExit(String exit) {
    return 'Rond-point, sortie $exit';
  }

  @override
  String get navRoundaboutUTurn => 'Rond-point, demi-tour';

  @override
  String navRoundaboutUTurnExit(String exit) {
    return 'Rond-point, demi-tour · sortie $exit';
  }

  @override
  String navSignedExit(String exit) {
    return 'Sortie $exit';
  }

  @override
  String navSignedExitTowards(String exit, String place) {
    return 'Sortie $exit · $place';
  }

  @override
  String get navExitLeft => 'Sortez à gauche';

  @override
  String get navExitRight => 'Sortez à droite';

  @override
  String get navTakeExit => 'Prenez la sortie';

  @override
  String get navRampOnto => 'Prenez la bretelle vers';

  @override
  String get navRampLeft => 'Prenez la bretelle à gauche';

  @override
  String get navRampRight => 'Prenez la bretelle à droite';

  @override
  String get navRamp => 'Prenez la bretelle';

  @override
  String get navMergeLeft => 'Insérez-vous à gauche';

  @override
  String get navMergeRight => 'Insérez-vous à droite';

  @override
  String get navMerge => 'Insérez-vous';

  @override
  String get navForkLeft => 'À l’embranchement, allez à gauche';

  @override
  String get navForkRight => 'À l’embranchement, allez à droite';

  @override
  String get navContinueAtFork => 'Continuez à l’embranchement';

  @override
  String get navTurnLeft => 'Tournez à gauche';

  @override
  String get navTurnRight => 'Tournez à droite';

  @override
  String get navEndOfRoad => 'Fin de la route';

  @override
  String get navUTurn => 'Demi-tour';

  @override
  String get navSharpLeft => 'Tournez franchement à gauche';

  @override
  String get navSharpRight => 'Tournez franchement à droite';

  @override
  String get navSlightLeft => 'Tournez légèrement à gauche';

  @override
  String get navSlightRight => 'Tournez légèrement à droite';

  @override
  String get navDistanceNow => 'maintenant';

  @override
  String navMeters(String meters) {
    return '$meters m';
  }

  @override
  String navKilometers(String km) {
    return '$km km';
  }

  @override
  String get navDecimalMark => ',';

  @override
  String navInDistance(String distance) {
    return 'dans $distance';
  }

  @override
  String navActionIn(String action, String distance) {
    return '$action dans $distance';
  }

  @override
  String navActionNow(String action) {
    return '$action maintenant';
  }

  @override
  String navActionFor(String action, String distance) {
    return '$action sur $distance';
  }

  @override
  String navOnto(String action, String road) {
    return '$action sur $road';
  }

  @override
  String get navArriveAtDestination => 'Vous êtes arrivé à destination';

  @override
  String navHeadOutOn(String road) {
    return 'Partez sur $road';
  }

  @override
  String navContinueOn(String road) {
    return 'Continuez sur $road';
  }

  @override
  String get navRoundaboutContinue => 'Au rond-point, continuez';

  @override
  String navRoundaboutTakeExit(String exit) {
    return 'Au rond-point, prenez la sortie $exit';
  }

  @override
  String get navExitOnLeft => 'Prenez la sortie à gauche';

  @override
  String get navExitOnRight => 'Prenez la sortie à droite';

  @override
  String get navEndTurnLeft => 'Au bout de la route, tournez à gauche';

  @override
  String get navEndTurnRight => 'Au bout de la route, tournez à droite';

  @override
  String get navAtEndOfRoad => 'Au bout de la route';

  @override
  String get navMakeUTurn => 'Faites demi-tour';

  @override
  String navUseLeftLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prenez les $count voies de gauche',
      one: 'Prenez la voie de gauche',
    );
    return '$_temp0';
  }

  @override
  String navUseRightLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prenez les $count voies de droite',
      one: 'Prenez la voie de droite',
    );
    return '$_temp0';
  }

  @override
  String navUseMiddleLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prenez les $count voies du milieu',
      one: 'Prenez la voie du milieu',
    );
    return '$_temp0';
  }

  @override
  String navTowards(String place) {
    return 'direction $place';
  }

  @override
  String get navToDestination => 'Vers la destination';

  @override
  String navExitSemantics(String cue, String exit) {
    return '$cue, sortie $exit';
  }

  @override
  String get navPickupAhead => 'Prise en charge juste devant';

  @override
  String get navDropOffAhead => 'Dépose juste devant';

  @override
  String navPointAhead(String point) {
    return '$point juste devant';
  }

  @override
  String get navToPickup => 'Naviguer vers la prise en charge';

  @override
  String navToPoint(String point) {
    return 'Naviguer vers $point';
  }

  @override
  String get navDropOffLower => 'la dépose';

  @override
  String get navWaitingForRider => 'En attente du passager';

  @override
  String get navRouteUpdating => 'Itinéraire en cours de mise à jour…';

  @override
  String get navRouteRecalculating => 'Recalcul de l’itinéraire…';

  @override
  String get navRouteUnavailableRetry => 'Itinéraire indisponible — réessayez';

  @override
  String get navRouteUnavailableLocation =>
      'Itinéraire indisponible — vérifiez la localisation';

  @override
  String get authAddVehicle => 'Ajouter un véhicule';

  @override
  String get authAddVehicleDetails =>
      'Ajoutez les détails du véhicule pour vérification';

  @override
  String get vehicleMake => 'Marque du véhicule';

  @override
  String get vehicleModel => 'Modèle du véhicule';

  @override
  String get vehicleYear => 'Année du véhicule';

  @override
  String get enterModelYear => 'Saisissez l’année du modèle';

  @override
  String get licensePlateNumber => 'Numéro d’immatriculation';

  @override
  String get vehicleType => 'Type de véhicule';

  @override
  String get vehicleColor => 'Couleur';

  @override
  String get selectColor => 'Choisissez une couleur';

  @override
  String get tapToUpload => 'Touchez pour importer';

  @override
  String get openingEllipsis => 'Ouverture…';

  @override
  String get openCamera => 'Ouvrir l’appareil photo';

  @override
  String get fileSelectedSuccessfully => 'Fichier sélectionné !';

  @override
  String get vehicleDocumentSelectionFailed =>
      'Échec de la sélection du document du véhicule';

  @override
  String get couldNotReadSelectedFile =>
      'Impossible de lire le fichier sélectionné. Veuillez réessayer.';

  @override
  String get photoCapturedSuccessfully => 'Photo prise !';

  @override
  String get couldNotReadCapturedPhoto =>
      'Impossible de lire la photo prise. Veuillez réessayer.';

  @override
  String get docPassport => 'Passeport';

  @override
  String get scanYourPassportPhoto => 'Scannez la photo de votre passeport';

  @override
  String get docDrivingLicense => 'Permis de conduire';

  @override
  String get scanYourDrivingLicense => 'Scannez votre permis de conduire';

  @override
  String get docNationalId => 'Carte d’identité';

  @override
  String get scanYourNationalId => 'Scannez votre carte d’identité';

  @override
  String get selectDocumentTypeToScan =>
      'Choisissez le type de document à scanner';

  @override
  String get weNeedToDetermineDocument =>
      'Nous devons vérifier que la pièce d’identité est authentique et vous appartient';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get enterValidPhoneForCode =>
      'Saisissez un numéro de téléphone valide auquel nous enverrons un code de vérification';

  @override
  String get fullName => 'Nom complet';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get acceptTermsAndPrivacy =>
      'Acceptez les conditions et la politique de confidentialité';

  @override
  String get byContinuingIAgreeTo => ' En continuant, j’accepte les ';

  @override
  String get termsOfUse => 'Conditions d’utilisation';

  @override
  String get andWord => ' et la ';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get phoneVerification => 'Vérification du téléphone';

  @override
  String get codeDeliveryUnavailableDemo =>
      'L’envoi de code n’est pas disponible dans cette démo';

  @override
  String get accountVerificationNeedsService =>
      ' La vérification du compte nécessite le service de compte.';

  @override
  String get didNotGetCode => 'Vous n’avez pas reçu de code ?';

  @override
  String get signInUnavailableInPreview => 'Connexion indisponible en aperçu';

  @override
  String get verificationUnavailableDemo =>
      'La vérification n’est pas disponible dans cette démo.';

  @override
  String get starterTagline =>
      'En route ! Acceptez des courses en temps réel et faites compter chaque minute';

  @override
  String get legacySignInPreview => 'Aperçu de l’ancienne connexion';

  @override
  String get signInUnavailableDemo => 'Connexion indisponible — démo';

  @override
  String get legacyRegistrationPreview => 'Aperçu de l’ancienne inscription';

  @override
  String get registrationUnavailableDemo => 'Inscription indisponible — démo';

  @override
  String get returnToDemo => 'Retour à la démo';

  @override
  String get signIn => 'Se connecter';

  @override
  String get welcomeBackRiding => 'Bon retour ! C’est parti';

  @override
  String get continueWithPhone => 'Continuer avec le téléphone';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get dontHaveAccount => 'Vous n’avez pas de compte ?';

  @override
  String get signUp => 'S’inscrire';

  @override
  String get signInWithPhone => 'Se connecter avec un numéro de téléphone';

  @override
  String get phoneSignInUnavailableDemo =>
      'La connexion par téléphone n’est pas disponible dans cette démo. Aucun code n’est envoyé.';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get phoneSignInNeedsService =>
      'La connexion par téléphone nécessite le service de compte.';

  @override
  String get socialSignInNeedsService =>
      'La connexion avec Apple ou Google nécessite le service de compte.';

  @override
  String get idPhotoPreview => 'Aperçu de la photo d’identité';

  @override
  String get idPhotoSampleOnly =>
      'Image d’exemple uniquement. La prise de vue et la vérification ne sont pas connectées. Aucune pièce d’identité n’est envoyée.';

  @override
  String get returnToHome => 'Retour à l’accueil';

  @override
  String get retakeUnavailablePreview => 'Reprise indisponible dans cet aperçu';

  @override
  String get enterValidPhoneWeWillSend =>
      'Saisissez un numéro de téléphone valide auquel nous enverrons';

  @override
  String get verifyAction => 'Vérifier';

  @override
  String stepOfTotal(String step, String total) {
    return '$step sur $total';
  }

  @override
  String get uploadId => 'Importer une pièce d’identité';

  @override
  String get weNeedToVerifyYourId => 'nous devons vérifier votre identité';

  @override
  String get approveAccountIdentityReason =>
      'Pour approuver votre compte, nous devons être sûrs à 100 % que vous êtes bien la personne que vous dites être, pour des raisons de sécurité et de transparence.';

  @override
  String get vehicleRegistration => 'Carte grise';

  @override
  String get uploadVehicleRegistration =>
      'Importez le certificat d’immatriculation';

  @override
  String get insurance => 'Assurance';

  @override
  String get uploadCarInsurance =>
      'Importez l’assurance du véhicule pour vérification';

  @override
  String get todayLower => 'aujourd’hui';

  @override
  String get tomorrowLower => 'demain';

  @override
  String inDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans $count jour',
    );
    return '$_temp0';
  }

  @override
  String get docInsuranceLetter => 'Attestation d’assurance';

  @override
  String get docTaxiDriverLicense => 'Carte professionnelle de taxi';

  @override
  String get docTaxiLicenseShort => 'Carte taxi';

  @override
  String get docRegistrationCertificate => 'Certificat d’immatriculation';

  @override
  String get docRegistrationShort => 'Immatriculation';

  @override
  String get docDriversLicense => 'Permis de conduire';

  @override
  String get docVehicleVerification => 'Vérification du véhicule';

  @override
  String get docDriversId => 'Pièce d’identité du chauffeur';

  @override
  String get docExpiredCantGoOnline =>
      'Expiré · Vous ne pouvez pas passer en ligne';

  @override
  String docExpiresWhenDate(String when, String date) {
    return 'Expire $when · $date';
  }

  @override
  String docNewTitle(String title) {
    return 'Nouveau document : $title';
  }

  @override
  String get docTakeClearPhoto =>
      'Prenez une photo nette du document entier. Movera le vérifie avant qu’il soit pris en compte.';

  @override
  String get docSendNew => 'Envoyer le nouveau document';

  @override
  String get docDemoNoFileLeaves =>
      'Démo : aucun fichier ne quitte le téléphone.';

  @override
  String get docSentForReview => 'Envoyé pour vérification';

  @override
  String docTitleExpired(String title) {
    return '$title expiré';
  }

  @override
  String get youCanGoOnlineNow => 'Vous pouvez passer en ligne.';

  @override
  String get docNewInReviewGoOnlineWhenApproved =>
      'Votre nouveau document est en cours de vérification. Vous pourrez passer en ligne dès que Movera l’aura approuvé.';

  @override
  String get docUploadNewGoOnlineWhenApproved =>
      'Importez-en un nouveau. Vous pourrez passer en ligne dès que Movera l’aura approuvé.';

  @override
  String get approveDemo => 'Approuver (démo)';

  @override
  String get uploadNew => 'Importer un nouveau';

  @override
  String get documents => 'Documents';

  @override
  String get docTermsAndConditions => 'Conditions générales';

  @override
  String get docVirtualInfoSession => 'Session d’information en ligne';

  @override
  String get docDriversLicenseLower => 'Permis de conduire';

  @override
  String get docProfilePhoto => 'Photo de profil';

  @override
  String get docCompanyRegistration => 'Immatriculation de l’entreprise';

  @override
  String get docCompanyRegistrationNote =>
      'Extrait de Bolagsverket ou de Skatteverket. Inutile avec un partenaire de flotte.';

  @override
  String get docTaxiTrafficPermit => 'Autorisation de transport de taxi';

  @override
  String get docTaxSettings => 'Paramètres fiscaux';

  @override
  String get docBankStatement => 'Relevé bancaire';

  @override
  String get docFrontPage => 'Première page';

  @override
  String get docStockholmTrips => 'Stockholm · Courses';

  @override
  String get docEarnAnywhereSweden => 'Gagnez de l’argent partout en Suède';

  @override
  String get docSampleListNotice =>
      'Liste d’exemple · L’envoi de ces documents n’est pas encore disponible dans l’application. Rien n’a été importé ni vérifié.';

  @override
  String docApprovedOfTotal(int approved, int total) {
    return '$approved sur $total approuvés';
  }

  @override
  String docLeftCount(int count) {
    return '$count restant(s)';
  }

  @override
  String get vehicle => 'Véhicule';

  @override
  String get docStatusApproved => 'Approuvé';

  @override
  String get docStatusInReview => 'En vérification';

  @override
  String get docStatusNeeded => 'Requis';

  @override
  String get docPreviewNotAvailable =>
      'Pas encore disponible — page d’exemple. L’envoi de ce document ne fait pas encore partie de l’application. Aucun document n’a été importé ni vérifié.';

  @override
  String schedRidesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses masquées',
      one: '$count course masquée',
    );
    return '$_temp0';
  }

  @override
  String schedClashBody(String time) {
    return 'Elle chevauche votre prise en charge de $time : pas assez de temps pour y aller.';
  }

  @override
  String get reminder => 'Rappel';

  @override
  String get schedAvailableToday => 'Disponibles aujourd’hui';

  @override
  String get schedUpcoming => 'À venir';

  @override
  String get schedPreviewNotBinding =>
      'Aperçu — sans engagement. Vos choix durent jusqu’au redémarrage de l’application.';

  @override
  String schedAcceptedPickupAt(String time) {
    return 'Acceptée · prise en charge $time';
  }

  @override
  String get laterLower => 'plus tard';

  @override
  String get schedReservationCancelled => 'Réservation annulée';

  @override
  String get schedPlanAhead => 'Anticipez et choisissez votre prochaine course';

  @override
  String get schedRequestsTab => 'Demandes';

  @override
  String get schedAcceptedTab => 'Acceptées';

  @override
  String schedSeedTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String schedPickupTomorrowAt(String time) {
    return 'Prise en charge demain à $time';
  }

  @override
  String schedBackupNote(String time) {
    return 'Votre prise en charge de $time a été confiée à un chauffeur de secours.';
  }

  @override
  String get schedSampleReservation => 'Réservation d’exemple';

  @override
  String get schedReservationDetails => 'Détails de la réservation';

  @override
  String get schedIllustrativeRoute =>
      'Itinéraire indicatif — données d’exemple';

  @override
  String get schedViewRoute => 'Voir l’itinéraire de la réservation';

  @override
  String get schedDemoAccepted => 'Acceptée (démo)';

  @override
  String get schedAvailable => 'Disponible';

  @override
  String get rideTypeLabel => 'Type de course';

  @override
  String get trip2 => 'Course';

  @override
  String get route => 'Itinéraire';

  @override
  String get schedBeforeThisRide => 'Avant cette course';

  @override
  String get goodToKnow => 'Bon à savoir';

  @override
  String get schedBeReadyEarly => 'Soyez prêt à l’avance';

  @override
  String schedGoOnlineMinBefore(String minutes) {
    return 'Passez en ligne $minutes min avant la prise en charge pour que l’application vous guide à temps.';
  }

  @override
  String get schedTripsOnTheWay => 'Courses sur le trajet';

  @override
  String get schedOnlyTripsToward =>
      'Avant la prise en charge, vous ne recevez que des courses qui vont dans sa direction et vous laissent le temps d’y arriver.';

  @override
  String get schedStillReceiveRides =>
      'Vous pouvez encore recevoir des courses adaptées avant la prise en charge prévue.';

  @override
  String get schedPlansChanged => 'Changement de programme ?';

  @override
  String schedDriversNeverPay(String line) {
    return '$line Les chauffeurs ne paient jamais pour annuler.';
  }

  @override
  String get schedLocalPreviewCancel =>
      'Ceci est un aperçu local. Annuler retire la réservation d’exemple jusqu’au redémarrage de l’application.';

  @override
  String get schedReservedForYou => 'Réservée pour vous';

  @override
  String get schedKeepInAccepted =>
      'Nous gardons cette course dans votre liste Acceptées. Si vous annulez, un motif vous sera demandé avant tout changement.';

  @override
  String get schedCancelReservation => 'Annuler la réservation';

  @override
  String schedAcceptPrice(String price) {
    return 'Accepter  •  $price';
  }

  @override
  String get chooseBestReason => 'Choisissez le motif qui correspond le mieux.';

  @override
  String get schedCancelThisReservation => 'Annuler cette réservation ?';

  @override
  String get schedReasonDoesntCount => 'Ce motif ne compte pas contre vous.';

  @override
  String get schedRemovesSample =>
      'Cela retire la réservation d’exemple de cette session. Aucune vraie réservation n’est annulée et l’accès au compte ne change pas.';

  @override
  String get schedKeepReservation => 'Garder la réservation';

  @override
  String tomorrowAtClock(String clock) {
    return 'demain $clock';
  }

  @override
  String schedFreeCancelHoursBefore(String hours) {
    return 'Annulation gratuite jusqu’à $hours h avant la prise en charge.';
  }

  @override
  String schedLateCancelUnder(String hours) {
    return 'Annulation tardive : moins de $hours h avant la prise en charge.';
  }

  @override
  String schedFreeCancelUntil(String time) {
    return 'Annulation gratuite jusqu’à $time.';
  }

  @override
  String get schedRidesAreOff => 'Les courses planifiées sont désactivées';

  @override
  String schedRidesOffUntil(String date) {
    return 'Courses planifiées désactivées jusqu’au $date';
  }

  @override
  String schedRidesPausedUntil(String date) {
    return 'Courses planifiées en pause jusqu’au $date';
  }

  @override
  String get schedOffInYourArea =>
      'Movera a suspendu les nouvelles courses planifiées dans votre zone. Les courses que vous avez déjà acceptées ont quand même lieu.';

  @override
  String get schedTurnedOffByMovera =>
      'Movera a désactivé les courses planifiées pour votre compte. Contactez l’assistance si vous avez des questions.';

  @override
  String schedLateCancelsInDays(String count, String days) {
    return 'Vous avez eu $count annulations tardives en $days jours. Vos courses acceptées sont conservées.';
  }

  @override
  String get schedNeverPayLateCounts =>
      'Vous ne payez jamais pour annuler, mais cette annulation tardive compte.';

  @override
  String schedNeverPayUnderHours(String hours) {
    return 'Vous ne payez jamais pour annuler. À moins de $hours h de la prise en charge, l’annulation est tardive et compte pour une pause.';
  }

  @override
  String schedLateCancelPauses(String count, String days, String date) {
    return 'C’est une annulation tardive ($count en $days jours). Les courses planifiées sont en pause jusqu’au $date.';
  }

  @override
  String get schedLateCancelCounts =>
      'C’est une annulation tardive et elle compte. Vous ne payez jamais.';

  @override
  String get schedAcceptedBadge => 'Acceptée';

  @override
  String get supportCatTripRider => 'Course et passager';

  @override
  String get supportCatWallet => 'Portefeuille et paiements';

  @override
  String get supportCatAccount => 'Compte et documents';

  @override
  String get supportCatTechnical => 'Problème technique';

  @override
  String get supportLocalDraftBadge => 'BROUILLON LOCAL';

  @override
  String get supportCouldNotRecover =>
      'Impossible de récupérer l’assistance locale. Réessayez.';

  @override
  String get supportCouldNotSaveConversation =>
      'Impossible d’enregistrer la conversation locale. Réessayez.';

  @override
  String get supportCouldNotLoadDraft =>
      'Impossible de charger le brouillon local.';

  @override
  String get supportCouldNotSaveDraft =>
      'Impossible d’enregistrer le brouillon local.';

  @override
  String get supportLocalTicketDraft => 'Brouillon de demande local';

  @override
  String get category => 'Catégorie';

  @override
  String get subject => 'Objet';

  @override
  String get enterSubject => 'Saisissez un objet';

  @override
  String get tellUsWhatHappened => 'Dites-nous ce qui s’est passé';

  @override
  String get enterMessage => 'Saisissez un message';

  @override
  String get supportCouldNotSaveTicket =>
      'Impossible d’enregistrer la demande locale. Réessayez.';

  @override
  String get supportSavingDraft => 'Enregistrement du brouillon local…';

  @override
  String get supportSaveDraftDemo => 'Enregistrer le brouillon (démo)';

  @override
  String get supportTicketSavedDraftNotCleared =>
      'Demande enregistrée localement, mais le brouillon n’a pas pu être effacé.';

  @override
  String get supportDemo => 'Assistance (démo)';

  @override
  String get supportDraftLocalTicket => 'Rédiger une demande locale';

  @override
  String get supportLocalPreview => 'Aperçu de l’assistance locale';

  @override
  String get supportLocalDraftsNoService =>
      'Brouillons locaux sur cet appareil — aucun service d’assistance.';

  @override
  String get supportCouldNotLoadRetry =>
      'Impossible de charger l’assistance locale — Réessayer';

  @override
  String get supportRecoverPreserve =>
      'Récupérer l’assistance locale (conserver les données illisibles)';

  @override
  String get supportYourConversations => 'Vos conversations';

  @override
  String supportLocalDraftSubject(String subject) {
    return 'Brouillon local : $subject';
  }

  @override
  String get supportWriteLocalDraft => 'Rédigez un brouillon local';

  @override
  String get supportSaveLocalReply => 'Enregistrer la réponse locale';

  @override
  String get promoWeekdayPeak => 'Pointe en semaine';

  @override
  String get promoWeekdayPeakDetail =>
      'Effectuez 8 courses entre 07:00 et 09:00.';

  @override
  String get promoWeekdayPeakWindow => 'Lun–ven · cette semaine';

  @override
  String get promoAirportRuns => 'Trajets aéroport';

  @override
  String get promoAirportRunsDetail =>
      'Deux courses vers l’aéroport le même jour.';

  @override
  String get promoUntilSunday => 'Jusqu’à dimanche';

  @override
  String get promoEveningHours => 'Heures du soir';

  @override
  String get promoEveningHoursDetail => 'Restez en ligne 3 heures après 18:00.';

  @override
  String get promoTonight => 'Ce soir';

  @override
  String promoDemoCodeCopied(String code) {
    return 'Code de démo $code copié';
  }

  @override
  String get promoCouldNotCopy =>
      'Impossible de copier le code. Veuillez réessayer.';

  @override
  String get promoPreviewTitle => 'Aperçu des promotions';

  @override
  String get preview => 'Aperçu';

  @override
  String get promoSavedTab => 'Enregistrées';

  @override
  String get promoNothingSaved => 'Rien d’enregistré pour l’instant';

  @override
  String get promoSave => 'Enregistrer';

  @override
  String get vehicles => 'Véhicules';

  @override
  String get addVehicle => 'Ajouter un véhicule';

  @override
  String get vehCouldNotLoadDrafts =>
      'Impossible de charger les brouillons de véhicule — Réessayer';

  @override
  String get vehLocalDraftsNotVerified =>
      'Brouillons de véhicule locaux — non activés ni vérifiés';

  @override
  String get vehTripsOnly => 'Courses uniquement';

  @override
  String get vehManageVehicles => 'Gérer les véhicules';

  @override
  String get vehExploreOpportunities => 'Découvrir les offres de véhicules';

  @override
  String get vehConnectFleetPartner =>
      'Rejoignez un partenaire de flotte ou consultez les offres de location ou d’achat si vous avez besoin d’un autre véhicule.';

  @override
  String get vehCouldNotSaveDraft =>
      'Impossible d’enregistrer le brouillon du véhicule. Réessayez.';

  @override
  String get year => 'Année';

  @override
  String get vehRequirements => 'Exigences pour le véhicule';

  @override
  String get vehRequirementsBody =>
      'Pour conduire avec Movera, il vous faut un véhicule de 1990 ou plus récent, non accidenté grave.';

  @override
  String get vehEnterInformation =>
      'Saisissez les informations de votre véhicule';

  @override
  String get make => 'Marque';

  @override
  String get searchByMake => 'Rechercher par marque';

  @override
  String get model => 'Modèle';

  @override
  String get searchByModel => 'Rechercher par modèle';

  @override
  String get selectEllipsis => 'Choisir…';

  @override
  String get requiredMark => '* Obligatoire';

  @override
  String get vehPhotoCouldNotSave =>
      'La photo n’a pas pu être enregistrée localement. Réessayez.';

  @override
  String get vehRemoveDraftQ => 'Supprimer le brouillon du véhicule ?';

  @override
  String vehRemovesNameAndPhotos(String name) {
    return 'Cela supprime $name et les photos de documents enregistrées de cet appareil.';
  }

  @override
  String get vehKeepVehicle => 'Garder le véhicule';

  @override
  String get vehRemoveVehicle => 'Supprimer le véhicule';

  @override
  String get vehCouldNotRemoveDraft =>
      'Impossible de supprimer le brouillon local. Réessayez.';

  @override
  String get vehPhotosStayOnDevice =>
      'Les photos de documents restent sur cet appareil. Aucun service d’envoi ni de vérification n’est connecté.';

  @override
  String get vehCouldNotLoadDocuments =>
      'Impossible de charger les documents du véhicule.';

  @override
  String get vehDraftNoLongerAvailable =>
      'Ce brouillon de véhicule n’est plus disponible.';

  @override
  String get vehRegistrationCertFront =>
      'Certificat d’immatriculation (première page)';

  @override
  String get vehSavedLocallyNotVerified =>
      'Enregistré localement — non vérifié';

  @override
  String get vehRecommendedNextStep => 'Étape suivante conseillée';

  @override
  String get vehTakePhotoRegistration =>
      'Prenez en photo votre certificat d’immatriculation (première page)';

  @override
  String get vehDocBlueBlackWhite =>
      'Le document doit être bleu, noir et blanc.';

  @override
  String get vehAllFourCorners => 'Les quatre coins sont visibles.';

  @override
  String get vehInsuranceLetter => 'Attestation d’assurance';

  @override
  String get vehTakePhotoInsurance =>
      'Prenez en photo votre attestation d’assurance';

  @override
  String get vehInsuranceShowsTaxi =>
      'Le document indique l’immatriculation du véhicule et qu’il est enregistré comme taxi.';

  @override
  String get vehInsuranceDatesVisible =>
      'Les dates de début et de fin de l’assurance sont visibles.';

  @override
  String get vehSavedPhotoCannotDisplay =>
      'La photo enregistrée ne peut pas être affichée. Reprenez la photo de ce document.';

  @override
  String get vehPhotoTooLarge =>
      'La photo est trop lourde pour être gardée sur cet appareil. Reprenez-la de plus près et avec moins de détails.';

  @override
  String get vehCameraNotAvailable =>
      'L’appareil photo n’est pas disponible dans cet aperçu.';

  @override
  String get vehBeforeSavingCheck =>
      'Avant d’enregistrer la photo, vérifiez les points suivants :';

  @override
  String get takingPhoto => 'Prise de la photo…';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get promoSaved => 'Enregistrée';

  @override
  String get prefStandardEveryday => 'Standard • Course du quotidien';

  @override
  String get prefExtraComfort => 'Confort supplémentaire • Douillet';

  @override
  String get prefLuxuryPremium => 'Luxe • Service premium';

  @override
  String get prefFasterPickup => 'Prise en charge plus rapide • Priorité';

  @override
  String get prefSixSeat => '6 places • Spacieux';

  @override
  String get prefLowEmissions => 'Faibles émissions • Éco';

  @override
  String get prefPetFriendly => 'Animaux acceptés • Caisse OK';

  @override
  String get prefChildSeat => 'Siège enfant • Sûr pour les enfants';

  @override
  String prefCategoriesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories de course enregistrées',
      one: '$count catégorie de course enregistrée',
    );
    return '$_temp0';
  }

  @override
  String prefActiveOfTotal(int active, int total) {
    return '$active sur $total actives';
  }

  @override
  String get prefChooseRideOptions => 'Choisissez vos options de course';

  @override
  String get prefSelectRideTypes =>
      'Sélectionnez les types de course que vous souhaitez recevoir';

  @override
  String get prefMoveraSetsFromCar =>
      'Movera les définit d’après votre véhicule. Désactivez ceux que vous ne voulez pas.';

  @override
  String get prefSave => 'Enregistrer les préférences';

  @override
  String get safetyContactEmergencyQ => 'Contacter les services d’urgence ?';

  @override
  String get safetyUse112Only =>
      'N’appelez le 112 que si vous ou une autre personne avez besoin d’une aide immédiate.';

  @override
  String get safetyDialerOpened =>
      'Composeur d’urgence ouvert — confirmez l’appel sur votre appareil.';

  @override
  String get safetyAudioUnavailable =>
      'L’enregistrement audio n’est pas disponible dans cette démo.';

  @override
  String get safetyTripSharingUnavailable =>
      'Le partage de course n’est pas disponible dans cette démo.';

  @override
  String get safetyPreferences => 'Préférences de sécurité';

  @override
  String get safetyRideCheckOnOthersPreview =>
      'Le contrôle de course est activé. Les autres sont en aperçu.';

  @override
  String get safetyUnavailableWithoutVerification =>
      'Indisponible sans vérification du compte';

  @override
  String get safetyAutoTripSharing => 'Partage automatique de la course';

  @override
  String get safetyUnavailableWithoutSharing =>
      'Indisponible sans service de partage';

  @override
  String get safetyOnSetByMovera =>
      'Activé · défini par Movera pour chaque course';

  @override
  String get safetyOn => 'Activé';

  @override
  String get safetyRideCheckExplained =>
      'Activé pour chaque course. Demande « Tout va bien ? » après un long arrêt, une dépose loin de la destination, un grand détour ou un freinage très brusque.';

  @override
  String get safetyTools => 'Outils de sécurité';

  @override
  String get safetyQuickTools =>
      'Des outils rapides pour vous protéger à chaque course.';

  @override
  String get safetyContact112 => 'Contacter le 112';

  @override
  String get safetyShareTrip => 'Partager la course';

  @override
  String get safetyRideCheckOnPreviewOnly =>
      'Contrôle de course activé · les autres en aperçu';

  @override
  String get destChooseOneAddress => 'Choisissez une adresse';

  @override
  String get destTripsInYourDirection => 'Courses dans votre direction';

  @override
  String get destMoveraPrioritizes =>
      'Movera donnera la priorité aux demandes qui vous rapprochent de cette adresse.';

  @override
  String get destAddAddress => 'Ajouter une adresse de destination';

  @override
  String get destSuggestedAddresses => 'Adresses suggérées';

  @override
  String get destResults => 'Résultats';

  @override
  String get destNoAddressFound => 'Aucune adresse trouvée';

  @override
  String get destTryAnother =>
      'Essayez une autre rue, un autre lieu ou une autre zone.';

  @override
  String get destFastestRoute =>
      'Itinéraire le plus rapide vers votre destination';

  @override
  String destOnlyTripsYourWay(String place) {
    return 'Vous ne recevrez que des courses dans votre direction : chaque course vous rapproche de $place.';
  }

  @override
  String destArriveBy(String time) {
    return 'Arrivée vers $time';
  }

  @override
  String get destConfirm => 'Confirmer la destination';

  @override
  String get waybillLocalDemo => 'Démo locale';

  @override
  String get waybillDemoRadar => 'Radar de démo';

  @override
  String get demoDriverIdentityUnavailable =>
      'Chauffeur de démo — identité indisponible';

  @override
  String get vehicleDataUnavailable => 'Données du véhicule indisponibles';

  @override
  String get plateUnavailable => 'Immatriculation indisponible';

  @override
  String positionOfCount(int position, int count) {
    return '$position sur $count';
  }

  @override
  String get rrMatchingTrip => 'Attribution de la course';

  @override
  String get rrConfirmingRealTime =>
      'Confirmation de la demande en temps réel…';

  @override
  String get rrCouldNotMatch => 'Impossible d’obtenir la course. Réessayez.';

  @override
  String get rrConnectionInterrupted =>
      'Connexion interrompue. Vous pouvez réessayer cette demande.';

  @override
  String get rrAssignedOpening =>
      'Cette demande vous est attribuée. Ouverture de la course…';

  @override
  String get rrAnotherMatchedFirst =>
      'Un autre chauffeur a obtenu cette course en premier.';

  @override
  String get rrNoLongerOnRadar => 'Cette course n’est plus sur le Radar.';

  @override
  String rrTripsTowardPickup(String time) {
    return 'Courses vers votre prise en charge de $time';
  }

  @override
  String get rrLive => 'En direct';

  @override
  String rrFreshNew(int count) {
    return '$count nouvelles';
  }

  @override
  String get rrNew => 'Nouveau';

  @override
  String get rrDestinationRoute => 'Itinéraire vers la destination';

  @override
  String rrTripsToward(String place) {
    return 'Courses vers $place';
  }

  @override
  String get rrScanningNearby => 'Recherche à proximité';

  @override
  String get rrNewTripsAppear =>
      'Les nouvelles courses s’afficheront ici dès que le radar trouvera des demandes autour de vous.';

  @override
  String get moveraDriver => 'Chauffeur Movera';

  @override
  String get legalPrivacyBody =>
      'Movera Driver utilise la localisation et les données de course et de véhicule pour attribuer les courses, afficher les itinéraires et conserver une feuille de route sur cet appareil.\n\nLes versions de démo gardent ces informations en mémoire sur le téléphone. Rien n’est vendu à des annonceurs. Vous pouvez vous déconnecter à tout moment depuis Profil.\n\nUne fois un vrai serveur connecté, les mêmes écrans utiliseront ce texte jusqu’à la publication d’une version signée.';

  @override
  String get legalTermsBody =>
      'Vous vous engagez à conduire uniquement avec un permis et une assurance valides et un véhicule conforme aux documents de cette application.\n\nLes offres Radar vont au premier qui les prend. Accepter une autre course pendant un trajet est facultatif. Terminer une course crée une feuille de route que vous pouvez rouvrir depuis l’accueil.\n\nMovera peut suspendre un compte de démo qui utilise abusivement les outils de sécurité ou les appels d’urgence.';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d’utilisation';

  @override
  String get profSampleDriver => 'Profil de chauffeur d’exemple';

  @override
  String get profDemoNoVerified => 'Démo — aucun compte vérifié';

  @override
  String get analytics => 'Statistiques';

  @override
  String get myBank => 'Ma banque';

  @override
  String get helpCenter => 'Centre d’aide';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get logOutQ => 'Se déconnecter ?';

  @override
  String get profLogOutClears =>
      'Les données d’aperçu de cet appareil seront effacées, y compris l’historique des courses, les contacts et les brouillons. Vous reviendrez à l’écran de connexion hors ligne.';

  @override
  String get stay => 'Rester';

  @override
  String get profCouldNotClear =>
      'Impossible d’effacer les données locales. Vous êtes toujours connecté. Veuillez réessayer.';

  @override
  String get anaPreview => 'Aperçu des statistiques';

  @override
  String get anaSample3Rides => 'Exemple : 3 courses terminées';

  @override
  String get anaSampleLastTrip => 'Dernière course (exemple)';

  @override
  String get anaSamplePerformance => 'Performances (exemple)';

  @override
  String get anaCancel => 'Annulation';

  @override
  String get earnings => 'Gains';

  @override
  String get anaSamePeriodHome => 'Même période que sur l’accueil';

  @override
  String get acceptanceRate => 'Taux d’acceptation';

  @override
  String anaSampleAcceptance(String rate) {
    return 'Exemple · $rate des offres acceptées';
  }

  @override
  String get cancellationRate => 'Taux d’annulation';

  @override
  String anaSampleCancellation(String rate) {
    return 'Exemple · $rate des courses acceptées';
  }

  @override
  String get anaSampleStrongestArea => 'Zone la plus active (exemple)';

  @override
  String get bankAddHolderName => 'Ajoutez le nom du titulaire du compte.';

  @override
  String get bankCheckIban =>
      'Vérifiez le format de l’IBAN et sa clé avec votre relevé bancaire.';

  @override
  String get bankBicFormat =>
      'Le BIC / SWIFT comporte 8 ou 11 lettres et chiffres.';

  @override
  String get bankCheckClearing =>
      'Vérifiez le numéro de clearing : 4 chiffres, ou 5 commençant par 8 pour Swedbank.';

  @override
  String get bankAccountDigits =>
      'Le numéro de compte comporte 6 à 10 chiffres.';

  @override
  String get bankPreviewNotSaved =>
      'Aperçu uniquement — compte non enregistré.';

  @override
  String get countrySweden => 'Suède';

  @override
  String get international => 'International';

  @override
  String get bankAccount => 'Compte bancaire';

  @override
  String get bankHolder => 'Titulaire';

  @override
  String get country => 'Pays';

  @override
  String get bank => 'Banque';

  @override
  String get clearing => 'Clearing';

  @override
  String get bankUseIban =>
      'Utilisez l’IBAN de votre relevé bancaire. Les IBAN étrangers affichent un code pays ; aucune connexion bancaire n’est vérifiée.';

  @override
  String get bankFoundFromClearing =>
      'La banque est déduite du numéro de clearing.';

  @override
  String get checkDetails => 'Vérifier les informations';

  @override
  String get bankDemoNotSaved =>
      'Démo : compte non enregistré ni envoyé à une banque';

  @override
  String minutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String get yesterday => 'Hier';

  @override
  String daysAgo(int days) {
    return 'il y a $days jours';
  }

  @override
  String get noNotificationsYet => 'Aucune notification pour l’instant';

  @override
  String get filterAll => 'Toutes';

  @override
  String get filterDemand => 'Demande';

  @override
  String get logsPreview => 'Aperçu du journal de conduite';

  @override
  String get logsSampleNotLive =>
      'Données de temps de conduite d’exemple · pas en direct';

  @override
  String get logsSampleWeek => 'Semaine d’exemple';

  @override
  String get monday => 'Lundi';

  @override
  String get tuesday => 'Mardi';

  @override
  String get wednesday => 'Mercredi';

  @override
  String get thursday => 'Jeudi';

  @override
  String logsOnlineFromTo(String from, String to) {
    return 'En ligne $from – $to';
  }

  @override
  String get logsSampleOnlineState => 'État en ligne d’exemple';

  @override
  String get logsDemoCompliance =>
      'Texte de conformité de démo uniquement. Les limites de conduite et de pause ne sont pas reliées au compte ni aux données réglementaires.';

  @override
  String get pinVerifyAll => 'Vérifier toutes les courses';

  @override
  String get pinAskEveryPickup =>
      'Demandez le code PIN du passager à chaque prise en charge.';

  @override
  String get pinVerifySession => 'Vérifier cette session';

  @override
  String get pinAskUntilOffline =>
      'Demandez-le jusqu’à ce que vous passiez hors ligne.';

  @override
  String get pinDontVerify => 'Ne pas vérifier';

  @override
  String get pinSkipOnDevice => 'Pas de code PIN sur cet appareil.';

  @override
  String get pinPreviewNotSaved =>
      'Aperçu de la vérification PIN — ce choix n’est ni enregistré ni appliqué dans la démo.';

  @override
  String get pinNotConnected =>
      'La vérification PIN n’est pas connectée dans cette démo.';

  @override
  String get bankPreviewAccountDetails => 'Aperçu des coordonnées bancaires';

  @override
  String get bankLocalPreviewOnly =>
      'Aperçu local uniquement. Aucune banque n’est connectée, rien n’est vérifié et aucun versement n’est prévu.';

  @override
  String get bankCheckInPreview =>
      'Vous pouvez vérifier des coordonnées dans le formulaire d’aperçu. Elles sont effacées quand vous le quittez ; aucun compte de versement n’est connecté.';

  @override
  String get emEmergencyServices112 => 'Services d’urgence — 112';

  @override
  String get emEmergency => 'Urgence';

  @override
  String get emAlreadyInContacts => 'Ce numéro figure déjà dans vos contacts.';

  @override
  String get emFamily => 'Famille';

  @override
  String get chatLocalDemo =>
      'Discussion de démo locale · les messages ne sont pas envoyés au passager.';

  @override
  String get chatSendMessageHint => 'envoyer un message…';

  @override
  String get chatSaveLocally => 'Enregistrer le message localement';

  @override
  String get chatLocalNotSent => 'Aperçu local · non envoyé';

  @override
  String get queueAirportPreview => 'Aperçu de la file d’attente aéroport';

  @override
  String get queueSample10Ahead => 'Exemple : 10 chauffeurs devant vous';

  @override
  String get queueViewSampleDetails => 'voir les détails de l’exemple';

  @override
  String get queueClose => 'Fermer la position dans la file';

  @override
  String get queueMyPosition => 'Ma position dans la file';

  @override
  String get queueMediumWait => 'Attente moyenne';

  @override
  String get queueSampleRank => 'Rang (exemple)';

  @override
  String get queueUnavailablePreview => 'File d’attente indisponible — aperçu';

  @override
  String get queueRanks => 'Rangs';

  @override
  String get earnTypeTab => 'Type';

  @override
  String get earnMoveraDemo => 'Démo Movera';

  @override
  String get cancelRateTitle => 'Taux d’annulation';

  @override
  String get notYourRealRateYet => 'ce n’est pas encore votre vrai taux';

  @override
  String get tripsConfirmed => 'Courses confirmées';

  @override
  String get completedTripsLower => 'courses terminées';

  @override
  String get canceledTrips => 'Courses annulées';

  @override
  String get sampleNumbersNotReal =>
      'Chiffres d’exemple pour cet aperçu, pas votre vrai taux.';

  @override
  String get cancelRateKeepLow =>
      'Gardez un taux d’annulation bas pour garder un accès complet aux courses';

  @override
  String get cancelRateEveryCancelCounts =>
      'Chaque annulation compte, sauf les motifs marqués « Ne compte pas », comme un passager absent ou un problème de sécurité.';

  @override
  String get moreInformation => 'Plus d’informations';

  @override
  String get cancelRateHowCalculated =>
      'Comment votre taux d’annulation est calculé';

  @override
  String get cancelRateHowBody =>
      'Votre taux d’annulation compare le nombre de courses que vous annulez au total des courses que vous confirmez. Nous utilisons vos 100 dernières demandes confirmées pour ce pourcentage.';

  @override
  String get cancelRateWhyMatters => 'Pourquoi le taux d’annulation compte';

  @override
  String get cancelRateWhyBody =>
      'Un taux d’annulation élevé nuit à la fiabilité du service et peut réduire les demandes de course que vous recevez. Un taux bas garantit un meilleur service pour tous.';

  @override
  String get acceptRateTitle => 'Taux d’acceptation';

  @override
  String get exclusiveOffers => 'Offres exclusives';

  @override
  String get acceptedOffersLower => 'offres acceptées';

  @override
  String get declinedOrMissed => 'refusées ou manquées';

  @override
  String get acceptRateOnlyExclusive => 'Seules les offres exclusives comptent';

  @override
  String get acceptRateExclusiveBody =>
      'Les offres exclusives et les autres offres envoyées à vous seul comptent. Les courses Radar ne comptent jamais.';

  @override
  String get acceptRateHowCalculated =>
      'Comment votre taux d’acceptation est calculé';

  @override
  String get acceptRateHowBody =>
      'Votre taux d’acceptation compare les offres exclusives que vous acceptez à toutes celles que vous recevez. Les courses Radar ne comptent jamais. Nous utilisons vos 100 dernières offres exclusives.';

  @override
  String get acceptRateWhyMatters => 'Pourquoi le taux d’acceptation compte';

  @override
  String get acceptRateWhyBody =>
      'Un taux d’acceptation bas réduit vos chances de recevoir des demandes et peut nuire à votre position sur la plateforme. Un taux élevé vous apporte plus de courses et une expérience fiable pour les passagers.';

  @override
  String get rcTriggerDroppedFar => 'Terminée loin de la dépose';

  @override
  String get rcTriggerLongStop => 'Arrêt prolongé';

  @override
  String get rcTriggerOffRoute => 'Hors itinéraire';

  @override
  String get rcTriggerPossibleCrash => 'Accident possible';

  @override
  String get rcTopicAccident => 'Accident ou collision';

  @override
  String get rcTopicHurt => 'Quelqu’un est blessé ou se sent mal';

  @override
  String get rcTopicUnsafe => 'Je ne me sens pas en sécurité';

  @override
  String get rcTopicCarProblem => 'Problème de voiture';

  @override
  String get rcTopicRiderAskedStop => 'Le passager a demandé un arrêt';

  @override
  String get rcTopicTraffic => 'Circulation ou travaux';

  @override
  String get rcTopicRiderStopHere => 'Le passager a demandé à s’arrêter ici';

  @override
  String get rcTopicRiderChangedDestination =>
      'Le passager a changé de destination';

  @override
  String get rcTopicRoadClosed => 'Route fermée ou accès impossible';

  @override
  String get rcTopicRiderOtherRoute =>
      'Le passager a demandé un autre itinéraire';

  @override
  String get rcShortAccident => 'Accident';

  @override
  String get rcShortHurt => 'Personne blessée';

  @override
  String get rcShortUnsafe => 'Insécurité';

  @override
  String get rcShortRiderStop => 'Arrêt passager';

  @override
  String get rcShortTraffic => 'Circulation';

  @override
  String get rcShortNewDestination => 'Nouvelle destination';

  @override
  String get rcShortRoadClosed => 'Route fermée';

  @override
  String get rcShortOtherRoute => 'Autre itinéraire';

  @override
  String get rcQuestionAnyoneHurt => 'Quelqu’un est-il blessé ?';

  @override
  String get rcQuestionCarSafe => 'La voiture est-elle en lieu sûr ?';

  @override
  String get rcQuestionOtherPersonOk => 'L’autre personne va-t-elle bien ?';

  @override
  String get rcQuestionWhoNeedsHelp => 'Qui a besoin d’aide ?';

  @override
  String get rcQuestionInDanger => 'Êtes-vous en danger en ce moment ?';

  @override
  String get rcQuestionCanContinue => 'Pouvez-vous continuer la course ?';

  @override
  String get rcAnswerYes => 'Oui';

  @override
  String get rcAnswerNo => 'Non';

  @override
  String get rcAnswerNotSure => 'Je ne sais pas';

  @override
  String get rcAnswerMe => 'Moi';

  @override
  String get rcAnswerTheRider => 'Le passager';

  @override
  String get rcAnswerSomeoneElse => 'Quelqu’un d’autre';

  @override
  String get rcLongerLead => 'Cette course dure ';

  @override
  String rcPercent(int percent) {
    return '$percent %';
  }

  @override
  String get rcLongerTrail => ' de plus que prévu';

  @override
  String get rcStoppedLead => 'Votre voiture est arrêtée depuis ';

  @override
  String rcMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get rcEndedLead => 'Votre course s’est terminée à ';

  @override
  String rcEndedFromTrail(String place) {
    return ' de $place';
  }

  @override
  String get rcOffRouteLead => 'Vous êtes à ';

  @override
  String get rcOffRouteTrail => ' de l’itinéraire';

  @override
  String rcOffRouteToTrail(String place) {
    return ' de l’itinéraire vers $place';
  }

  @override
  String get rcCrashLead => 'Un ';

  @override
  String get rcCrashBold => 'freinage très brusque';

  @override
  String get rcCrashTrail => ' a été détecté';

  @override
  String rcCrashTrailAt(String place) {
    return ' a été détecté · $place';
  }

  @override
  String get tipHighBoostNearby => 'Forte majoration à proximité';

  @override
  String tipHighBoostIn(String kr, String zone) {
    return 'Forte majoration · +$kr kr à $zone';
  }

  @override
  String get tipExpectTrip => 'Une course est attendue d’ici 2 à 5 min';

  @override
  String tipPromotionRides(String rides, String kr) {
    return 'Promotion · $rides courses = $kr kr';
  }

  @override
  String get tipBusyArea => 'Zone animée · courses attendues bientôt';

  @override
  String tipAirportQueue(String count) {
    return 'File aéroport : $count chauffeurs';
  }

  @override
  String tipGoodStreak(String count) {
    return 'Belle série · $count courses d’affilée';
  }

  @override
  String get tipDemandRising => 'La demande augmente près de vous';

  @override
  String tipPeakStart(String time) {
    return 'Les heures de pointe commencent à $time';
  }

  @override
  String get tipTopZone => 'Vous êtes dans une zone très demandée';

  @override
  String get noticeNewScheduledRide => 'Nouvelle course planifiée';

  @override
  String noticeScheduledBody(String day, String time, String fare) {
    return '$day $time · $fare · Touchez pour voir';
  }

  @override
  String get view => 'Voir';

  @override
  String noticeSecondsToAccept(int seconds) {
    return '$seconds s pour accepter';
  }

  @override
  String noticeHighDemandIn(String area) {
    return 'Forte demande à $area';
  }

  @override
  String get noticeGoOnlineNow => 'Passez en ligne maintenant';

  @override
  String noticeDocExpires(String title, String when) {
    return '$title expire $when';
  }

  @override
  String get noticeUploadNewKeepDriving =>
      'Importez-en un nouveau pour continuer à conduire.';

  @override
  String noticeDocApprovedBody(String title) {
    return '$title approuvé. Vous pouvez passer en ligne.';
  }

  @override
  String get noticeCanGoOnlineAgain =>
      'Vous pouvez de nouveau passer en ligne.';

  @override
  String noticeTooManyLateCancels(String date) {
    return 'Trop d’annulations tardives. Retour le $date.';
  }

  @override
  String get rcWhatHappened => 'Ce qui s’est passé';

  @override
  String get rcCalled112 => '112 appelé';

  @override
  String get rcDialer112 => 'Composeur du 112 :';

  @override
  String get rcDialerOpened => 'ouvert';

  @override
  String get rcDialerDidNotOpen => 'ne s’est pas ouvert';

  @override
  String get selectCountry => 'Choisir un pays';

  @override
  String get searchCountry => 'Rechercher un pays';

  @override
  String get colorRed => 'Rouge';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorBlack => 'Noir';

  @override
  String get colorWhite => 'Blanc';

  @override
  String get colorGray => 'Gris';

  @override
  String get colorSilver => 'Argent';

  @override
  String get colorYellow => 'Jaune';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorBrown => 'Marron';

  @override
  String get colorPurple => 'Violet';

  @override
  String get colorPink => 'Rose';

  @override
  String get chooseVehicleColor => 'Choisir la couleur du véhicule';

  @override
  String get closeColorPicker => 'Fermer le sélecteur de couleur';

  @override
  String get mapCameraUnavailable =>
      'Caméra de la carte indisponible — touchez Recentrer pour réessayer';

  @override
  String get dismiss => 'Fermer';

  @override
  String ratingAndRides(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '$count course',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String mapOfArea(String area) {
    return 'Carte de $area';
  }

  @override
  String get cashYouOweMovera => 'Vous devez à Movera';

  @override
  String get cashMoveraOwesYou => 'Movera vous doit';

  @override
  String get cashSettled => 'Soldé';

  @override
  String stopNext(String stop) {
    return 'Ensuite : $stop';
  }

  @override
  String get pickupOnLeftSide => 'Prise en charge côté gauche';

  @override
  String get pickupOnRightSide => 'Prise en charge côté droit';

  @override
  String get moveWithin100MOfPickup =>
      'Approchez-vous à moins de 100 m du point de prise en charge pour confirmer l’arrivée.';

  @override
  String get moveWithin100MOfStop =>
      'Approchez-vous à moins de 100 m de l’arrêt pour confirmer l’arrivée.';

  @override
  String get riderPhoneNotConnected =>
      'Le contact téléphonique du passager n’est pas connecté dans cette démo.';

  @override
  String get recordAudioStarting => 'démarrage…';

  @override
  String get photoTooLargeForDevice =>
      'La photo est trop volumineuse pour être conservée sur cet appareil.';

  @override
  String get photoStorageFull =>
      'Le stockage des photos sur cet appareil est plein. Supprimez d’abord les photos d’un autre véhicule.';

  @override
  String get demoDataBadge => 'DONNÉES DE DÉMO';

  @override
  String get drivingInHeader => 'ZONE DE CONDUITE';

  @override
  String get anaSampleTripRoute => 'Gare centrale → Södermalm';

  @override
  String get demandBusy => 'Élevée';

  @override
  String get demandSteady => 'Stable';

  @override
  String get demandQuiet => 'Calme';

  @override
  String get aroundStockholm => 'Autour de Stockholm';

  @override
  String get noticeBonusProgressTitle => 'Progression du bonus';

  @override
  String noticeBonusProgressBody(
    String done,
    String goal,
    String left,
    String amount,
  ) {
    return '$done courses sur $goal cette semaine. Encore $left pour $amount.';
  }

  @override
  String get noticePayoutSentTitle => 'Paiement envoyé';

  @override
  String noticePayoutSentBody(String amount) {
    return '$amount est en route vers votre banque.';
  }

  @override
  String get signInOr => 'ou';

  @override
  String destResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trouvés',
      one: '$count trouvé',
    );
    return '$_temp0';
  }

  @override
  String get queueEstimatedWait => 'Environ 15 à 30 min d’attente';

  @override
  String get queueDriversAhead => 'Chauffeurs devant';

  @override
  String get paymentCard => 'Carte';

  @override
  String get offersBadge => 'OFFRES';
}
