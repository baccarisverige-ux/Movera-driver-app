// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Movera Förare';

  @override
  String get hideReservationRequest => 'Dölj bokningsförfrågan';

  @override
  String tripMinutesMinTrip(Object tripMinutes) {
    return '$tripMinutes min resa';
  }

  @override
  String get n1Stop => '1 stopp';

  @override
  String pickupWhenLabel(Object whenLabel) {
    return 'Upphämtning $whenLabel';
  }

  @override
  String get reservation => 'Bokning';

  @override
  String get exclusive => 'Exklusiv';

  @override
  String pickupMinutesMin(Object minutes) {
    return ' · Upphämtning $minutes min';
  }

  @override
  String get findingTrips => 'Söker resor';

  @override
  String get notNow => 'Inte nu';

  @override
  String get ridePreferences => 'Biltyper';

  @override
  String get wallet => 'Plånbok';

  @override
  String get inbox => 'Inkorg';

  @override
  String get scheduled => 'Bokade';

  @override
  String get exclusiveForYou => 'Exklusiv för dig';

  @override
  String get destinationSet => 'Destination vald';

  @override
  String get recommendations => 'Rekommendationer';

  @override
  String get destination => 'Destination';

  @override
  String get driverStatus => 'FÖRARSTATUS';

  @override
  String get accountAccessPaused => 'Kontot är pausat';

  @override
  String get yourDriverStatusIsCurrentlySuspended =>
      'Din förarstatus är avstängd just nu, så du kan inte ta emot nya resor och Radar kan inte startas.';

  @override
  String get moveraWillUseAuthoritativeAccountStatus =>
      'Movera använder kontots officiella status. Den här skärmen gissar inte orsak eller när kontot öppnas igen.';

  @override
  String get gotIt => 'Uppfattat';

  @override
  String get pickup => 'Upphämtning';

  @override
  String stopNumber(Object number) {
    return 'Stopp $number';
  }

  @override
  String get arrive => 'Framme';

  @override
  String get backToRequest => 'Tillbaka till förfrågan';

  @override
  String tripMinutesMinDistance(Object tripMinutes, Object distance) {
    return '$tripMinutes min · $distance';
  }

  @override
  String get dropOff => 'Avlämning';

  @override
  String destinationModeUntilUntil(Object until) {
    return 'Destinationsläge till $until';
  }

  @override
  String get showRoute => 'Visa rutt';

  @override
  String get turnOffDestination => 'Stäng av destination';

  @override
  String versionLatestVersion(Object latestVersion) {
    return 'Version $latestVersion';
  }

  @override
  String get openingUpdateEllipsis => 'Öppnar uppdateringen…';

  @override
  String get couldNotOpenUpdatePleaseTry =>
      'Det gick inte att öppna uppdateringen. Försök igen.';

  @override
  String get updating => 'UPPDATERAR';

  @override
  String get slideToOpen => 'DRA FÖR ATT ÖPPNA';

  @override
  String get rideHistory => 'Resehistorik';

  @override
  String get goOfflineQuestion => 'Gå offline?';

  @override
  String get youStopGettingTripOffersUntil =>
      'Du får inga reseerbjudanden förrän du går online igen.';

  @override
  String get stayOnline => 'Stanna online';

  @override
  String get goOffline => 'Gå offline';

  @override
  String restUntilTime(Object time) {
    return 'Vila till $time';
  }

  @override
  String timeLeftToDrive(Object time) {
    return '$time kvar att köra';
  }

  @override
  String get paused => 'Pausad';

  @override
  String get findingYourLocation => 'Söker din position';

  @override
  String untilTime(Object time) {
    return 'Till $time';
  }

  @override
  String get documentExpired => 'Dokumentet har gått ut';

  @override
  String get skipExclusiveOffer => 'Hoppa över exklusivt erbjudande';

  @override
  String get pleaseWait => 'Vänta';

  @override
  String get tapToAccept => 'Tryck här';

  @override
  String headToYourPickupTimePickup(Object pickupTime, Object pickupAddress) {
    return 'Åk nu till din upphämtning $pickupTime: $pickupAddress.';
  }

  @override
  String headToYourPickupTimePickup2(Object pickupTime) {
    return 'Åk till din upphämtning $pickupTime';
  }

  @override
  String leaveNowForPickupTimePickup(Object pickupTime) {
    return 'Åk nu till upphämtningen $pickupTime';
  }

  @override
  String get scheduledRide => 'Bokad resa';

  @override
  String pickupAtPickupTimeInLeft(
    Object pickupTime,
    Object left,
    Object pickupAddress,
  ) {
    return 'Upphämtning $pickupTime om $left: $pickupAddress.';
  }

  @override
  String pickupTimePickupInLeft(Object pickupTime, Object left) {
    return 'Upphämtning $pickupTime om $left';
  }

  @override
  String goOnlineNowForYourPickup(Object pickupTime) {
    return 'Gå online nu för din upphämtning $pickupTime.';
  }

  @override
  String goOnlineForPickupTimePickup(Object pickupTime) {
    return 'Gå online för upphämtningen $pickupTime';
  }

  @override
  String get matching => 'Matchar';

  @override
  String get accept => 'Acceptera';

  @override
  String get recenter => 'Centrera';

  @override
  String get contactSupport => 'Kontakta support';

  @override
  String get skipDemo => 'Hoppa över demo';

  @override
  String get retry => 'Försök igen';

  @override
  String get safetyToolkit => 'Säkerhetsverktyg';

  @override
  String get menu => 'Meny';

  @override
  String get searchDestination => 'Sök destination';

  @override
  String get lastTrip => 'SENASTE RESAN';

  @override
  String get hold => 'Håll';

  @override
  String get rightNow => 'Just nu';

  @override
  String get cashRides => 'Kontantresor';

  @override
  String get performance => 'Resultat';

  @override
  String get latestWaybill => 'Senaste körordern';

  @override
  String get noneYet => 'Inga än';

  @override
  String get rating => 'Betyg';

  @override
  String get acceptance => 'Acceptans';

  @override
  String get cancellation => 'Avbokning';

  @override
  String get drivingTime => 'Körtid';

  @override
  String get worked => 'Arbetat';

  @override
  String get leftBeforeRest => 'Kvar före vila';

  @override
  String get restUntil => 'Vila till';

  @override
  String get workLimit => 'Arbetsgräns';

  @override
  String get restAfterIt => 'Vila efteråt';

  @override
  String countsWhileRadarIsOnAfter(Object workHours, Object restHours) {
    return 'Räknas medan Radar är på. Efter $workHours h vilar du $restHours h innan du går online igen. En paus på $restHours h nollställer den.';
  }

  @override
  String get closeSheet => 'Stäng panelen';

  @override
  String get today => 'Idag';

  @override
  String get exclusiveReservation => 'Exklusiv bokning';

  @override
  String get exclusiveOffer => 'Exklusivt erbjudande';

  @override
  String get moveraRadar => 'Movera Radar';

  @override
  String get rider => 'Resenär';

  @override
  String get cash => 'Kontant';

  @override
  String islandRadarOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erbjudanden · radar',
      one: '1 erbjudande · radar',
    );
    return '$_temp0';
  }

  @override
  String get savedTripCouldNotBeOpened =>
      'Den sparade resan gick inte att öppna.';

  @override
  String get tripStorageUnavailable =>
      'Resornas lagring på den här enheten kunde inte öppnas, så ingen sparad resa kan återställas nu. Du kan ändå gå online.';

  @override
  String get unresolvedTrip => 'Oavslutad resa';

  @override
  String get thisSavedTripIsOlderThan =>
      'Den här sparade resan är äldre än sex timmar. Återuppta den eller avsluta den själv.';

  @override
  String get savedRouteCoordinatesAreUnavailableClose =>
      'Den sparade ruttens koordinater saknas. Avsluta resan innan du accepterar en ny.';

  @override
  String get closeTrip => 'Avsluta resan';

  @override
  String get resumeTrip => 'Återuppta resan';

  @override
  String get savedTripCouldNotBeClosed =>
      'Den sparade resan gick inte att avsluta.';

  @override
  String get savedTripCannotBeRead => 'Den sparade resan går inte att läsa';

  @override
  String get tripSavedOnThisDeviceIs =>
      'Resan som sparats på den här enheten är skadad eller från en annan appversion. Avsluta den för att fortsätta. En kopia sparas på enheten för support.';

  @override
  String get closeUnreadableTrip => 'Avsluta oläsbar resa';

  @override
  String get savedTripCouldNotBeRead =>
      'En sparad resa gick inte att läsa. Avsluta den för att gå online.';

  @override
  String get review => 'Visa';

  @override
  String get unreadableTripCouldNotBeClosed =>
      'Den oläsbara resan gick inte att avsluta.';

  @override
  String get riderDataUnavailable => 'Resenärsuppgifter saknas';

  @override
  String get finishOrCloseSavedTripBefore =>
      'Slutför eller avsluta den sparade resan innan du går online.';

  @override
  String get openSavedTrip => 'Öppna sparad resa';

  @override
  String get account => 'Konto';

  @override
  String get radar => 'Radar';

  @override
  String get tapForDetails => 'Tryck för detaljer';

  @override
  String get notActive => 'Inte aktiv';

  @override
  String get tapToScan => 'Tryck här';

  @override
  String get connecting => 'Ansluter';

  @override
  String get tripFound => 'Resa hittad';

  @override
  String get tapForAll => 'Visa alla';

  @override
  String get scanning => 'Söker';

  @override
  String get currentTrip => 'Pågående resa';

  @override
  String get nextTripSecured => 'Nästa resa klar';

  @override
  String riderNameIsOnWay(Object riderName) {
    return '$riderName är på väg';
  }

  @override
  String get tripUpdatesCouldNotBeRefreshed =>
      'Reseuppdateringarna gick inte att hämta.';

  @override
  String get tripUpdateCouldNotBeSaved =>
      'Reseuppdateringen gick inte att spara. Försöker igen automatiskt.';

  @override
  String get retryNow => 'Försök igen nu';

  @override
  String get couldNotSaveRiderCancellationRetry =>
      'Resenärens avbokning gick inte att spara. Försök igen.';

  @override
  String get tripProgressCouldNotBeSaved =>
      'Reseförloppet gick inte att spara. Håll skärmen öppen och försök igen.';

  @override
  String get thisStopNeedsVerifiedMapLocation =>
      'Stoppet behöver en bekräftad kartposition innan du kan vara framme.';

  @override
  String get locationUnavailableEnableLocationToConfirm =>
      'Position saknas. Slå på platstjänster för att bekräfta att du är framme.';

  @override
  String get preciseLocationOff =>
      'Exakt plats är avstängd. Slå på den i Inställningar för att visa din position och bekräfta att du är framme.';

  @override
  String get preciseLocationOffShort => 'Exakt plats avstängd';

  @override
  String get yourDriverHasArrivedAtPickup =>
      'Din förare har kommit till upphämtningsplatsen.';

  @override
  String get locationUpdatingEllipsis => 'Uppdaterar position…';

  @override
  String get stopLocationUnavailable => 'Stoppets position saknas';

  @override
  String get couldNotFinishSavingThisTrip =>
      'Resan gick inte att spara klart. Försök slutföra igen; kvittot dubbleras inte.';

  @override
  String get alongYourDestination => 'Längs vägen till din destination';

  @override
  String get cancelNextTripQuestion => 'Avboka nästa resa?';

  @override
  String get endThisTripEarlyQuestion => 'Avsluta resan i förtid?';

  @override
  String get cancelThisTripQuestion => 'Avboka den här resan?';

  @override
  String reasonTitle(Object title) {
    return 'Orsak: $title';
  }

  @override
  String get yourCurrentTripContinuesNextTrip =>
      'Din pågående resa fortsätter. Nästa resa går till en annan förare.';

  @override
  String get onlyEndTripAfterYouHave =>
      'Avsluta bara resan när du har stannat på en säker plats och resenären kan kliva ur säkert.';

  @override
  String get cancelNextTrip => 'Avboka nästa resa';

  @override
  String get endTripEarly => 'Avsluta i förtid';

  @override
  String get cancelTrip => 'Avboka resan';

  @override
  String get keepTrip => 'Behåll resan';

  @override
  String get thisTripCannotBeCancelledRight =>
      'Den här resan kan inte avbokas just nu.';

  @override
  String get couldNotSaveCancellationRetry =>
      'Avbokningen gick inte att spara. Försök igen.';

  @override
  String get firstTripEndedStartingNextOne =>
      'Första resan klar · nästa startar';

  @override
  String tripEndedEarlyTitle(Object title) {
    return 'Resan avslutad i förtid · $title';
  }

  @override
  String tripCancelledTitle(Object title) {
    return 'Resan avbokad · $title';
  }

  @override
  String get tripRouteAndOptions => 'Rutt och alternativ';

  @override
  String get now => 'Nu';

  @override
  String get arrival => 'Ankomst';

  @override
  String get arriving => 'Nästan framme';

  @override
  String get turnExclusiveOffersOff => 'Stäng av exklusiva erbjudanden';

  @override
  String get turnExclusiveOffersOn => 'Slå på exklusiva erbjudanden';

  @override
  String get cashCollectInCar => 'Kontant: ta betalt i bilen';

  @override
  String get paidByCard => 'Betalt med kort';

  @override
  String get rideCheckDemo => 'Demo av resekoll';

  @override
  String demoValue(Object value) {
    return 'Demo: $value';
  }

  @override
  String get routeProgress => 'Ruttens förlopp';

  @override
  String get unavailable => 'Saknas';

  @override
  String get addressUnavailable => 'Adress saknas';

  @override
  String get doesnTCount => 'Räknas inte';

  @override
  String get tripUpdatesDisconnectedReconnectingIsRequired =>
      'Reseuppdateringarna är frånkopplade. Du måste ansluta igen.';

  @override
  String pickingUpRiderName(Object riderName) {
    return 'Hämtar $riderName';
  }

  @override
  String waitingForRiderName(Object riderName) {
    return 'Väntar på $riderName';
  }

  @override
  String waitingAtStopNumber(Object number) {
    return 'Väntar vid stopp $number';
  }

  @override
  String headingToStopNumber(Object number) {
    return 'På väg till stopp $number';
  }

  @override
  String droppingOffRiderName(Object riderName) {
    return 'Lämnar av $riderName';
  }

  @override
  String pickUpRiderName(Object riderName) {
    return 'Hämta $riderName';
  }

  @override
  String driveToStopNumber(Object number) {
    return 'Kör till stopp $number';
  }

  @override
  String dropOffRiderName(Object riderName) {
    return 'Lämna av $riderName';
  }

  @override
  String get enRoute => 'På väg';

  @override
  String paidWaitAtStopNumber(Object number) {
    return 'Betald väntan vid stopp $number';
  }

  @override
  String get includedWaitThenPaid => 'Inkluderad väntan · sedan betald';

  @override
  String get paidWaitRunning => 'Betald väntan pågår';

  @override
  String get paidWaitNoShowAvailable => 'Betald väntan · uteblivet möjligt';

  @override
  String get nextStop => 'Nästa stopp';

  @override
  String get toDropOff => 'Till avlämning';

  @override
  String get waiting => 'Väntar';

  @override
  String get tripStarted => 'Resan har startat';

  @override
  String get tripCompleted => 'Resan är klar';

  @override
  String holdForRiderName(Object riderName) {
    return 'Vänta på $riderName';
  }

  @override
  String get thenDropOff => 'Sedan avlämning';

  @override
  String stop1OfStopAddressesLength(Object stopAddressesLength) {
    return 'Stopp 1 av $stopAddressesLength';
  }

  @override
  String get actionCouldNotBeCompletedPlease =>
      'Det gick inte att slutföra. Försök igen.';

  @override
  String get confirmThisTripActionQuestion => 'Bekräfta åtgärden?';

  @override
  String get cancel => 'Avbryt';

  @override
  String get confirm => 'Bekräfta';

  @override
  String get finishSoSoonQuestion => 'Avsluta så snart?';

  @override
  String youPickedUpRiderMinutesMin(Object minutes) {
    return 'Du hämtade resenären för $minutes min sedan. Avsluta bara om resan verkligen är slut.';
  }

  @override
  String get backToRide => 'Tillbaka till resan';

  @override
  String get finishTrip => 'Avsluta resan';

  @override
  String get isEverythingOkQuestion => 'Är allt okej?';

  @override
  String rideCheckTitle(Object title) {
    return 'Resekoll. $title';
  }

  @override
  String get rideCheck => 'Resekoll';

  @override
  String get call112 => 'Ring 112';

  @override
  String get iMOk => 'Allt är okej';

  @override
  String get orTellUsWhatSHappening => 'Eller berätta vad som händer';

  @override
  String get yourAnswerIsSavedToThis => 'Ditt svar sparas på resan.';

  @override
  String rideCheckShort(Object short) {
    return 'Resekoll · $short';
  }

  @override
  String get whatIsHappeningQuestion => 'Vad händer?';

  @override
  String get thanksThisIsSavedToTrip => 'Tack, det är sparat på resan.';

  @override
  String get done => 'Klar';

  @override
  String get yourAnswersAreSavedToThis => 'Dina svar sparas på resan.';

  @override
  String get rideCheck112 => 'Resekoll · 112';

  @override
  String get call112OnYourPhone => 'Ring 112 från din telefon';

  @override
  String get couldNotOpenDialerDial112 =>
      'Telefonen gick inte att öppna. Slå 112 själv.';

  @override
  String get yourDialerOpensWith112Movera =>
      'Telefonen öppnas med 112. Movera ringer aldrig åt dig.';

  @override
  String get moveraCouldNotBeAlerted => 'Movera kunde inte larmas';

  @override
  String get rideCheckSent => 'Skickat';

  @override
  String get moveraSafetyTeamAlerted => 'Moveras säkerhetsteam har larmats';

  @override
  String get safetyAlertKeptOnPhoneDemo =>
      'Demo: larmet sparas bara på den här telefonen. Ingen på Movera har larmats.';

  @override
  String get safetyAlertNotSentLive =>
      'Inte skickat: Movera kan inte ta emot larm från resekontrollen än. Vid fara, ring 112.';

  @override
  String get call112IfYouNeedHelp => '\nRing 112 om du behöver hjälp nu.';

  @override
  String get tripDriverAndRiderDetailsWere =>
      '\nUppgifter om resa, förare och resenär har skickats.';

  @override
  String get call112Now => 'Ring 112 nu';

  @override
  String get ifSomeoneIsHurtOrIn =>
      'Om någon är skadad eller i fara, ring räddningstjänsten.';

  @override
  String get tellUsInFewWords => 'Berätta med några ord';

  @override
  String recordingTime(Object time) {
    return 'Spelar in $time';
  }

  @override
  String get savedOnlyOnThisPhone => 'sparas bara på den här telefonen';

  @override
  String get recordAudio => 'Spela in ljud';

  @override
  String get audioStoppedWhenAppLeft => 'stoppades när Movera lämnade skärmen';

  @override
  String audioSavedTime(Object time) {
    return 'Ljud sparat · $time';
  }

  @override
  String get onlyOnThisPhone => 'bara på den här telefonen';

  @override
  String get notAvailableOnThisDevice => 'finns inte på den här enheten';

  @override
  String get allowMicrophoneFirst => 'tillåt mikrofonen först';

  @override
  String get couldNotRecordTryAgain => 'inspelningen misslyckades, försök igen';

  @override
  String get stop => 'Stoppa';

  @override
  String get moveraRecordedThisTripAsCompleted =>
      'Movera har registrerat resan som klar.';

  @override
  String get tripCancelledByMovera => 'Resan avbokad av Movera';

  @override
  String get moveraCancelledThisTripStopIn =>
      'Movera har avbokat resan. Stanna på en säker plats innan du lämnar skärmen.';

  @override
  String get moveraClosedThisTripStopIn =>
      'Movera har avslutat resan. Stanna på en säker plats innan du lämnar skärmen.';

  @override
  String get tripCancelled => 'Resan avbokad';

  @override
  String get thisTripWasCancelledFromYour => 'Resan avbokades från ditt konto.';

  @override
  String get riderCancelled => 'Resenären avbokade';

  @override
  String get riderCancelledThisTrip => 'Resenären avbokade resan.';

  @override
  String get riderNoShowRecorded => 'Utebliven resenär registrerad';

  @override
  String get thisPickupWasClosedBecauseRider =>
      'Upphämtningen avslutades eftersom resenären inte kom.';

  @override
  String get tripExpired => 'Resan har gått ut';

  @override
  String get thisTripIsNoLongerActive => 'Resan är inte längre aktiv.';

  @override
  String get tripCouldNotContinue => 'Resan kunde inte fortsätta';

  @override
  String get tripWasClosedBecauseOfSystem =>
      'Resan avslutades på grund av ett systemfel. Kontakta support om resenären fortfarande är med dig.';

  @override
  String get tripRemovedByMovera => 'Resan borttagen av Movera';

  @override
  String get moveraGaveThisTripBackTo =>
      'Movera har skickat tillbaka resan för ny tilldelning. Stanna på en säker plats innan du lämnar skärmen.';

  @override
  String get tripEnded => 'Resan avslutad';

  @override
  String bodyYourNextTripStartsNow(Object body) {
    return '$body Din nästa resa startar nu.';
  }

  @override
  String get goToNextTrip => 'Till nästa resa';

  @override
  String get holdToStopNextTrips => 'Håll för att stoppa nästa resor';

  @override
  String get holdToStartNextTrips => 'Håll för att starta nästa resor';

  @override
  String get stopRadar => 'Stoppa';

  @override
  String get startRadar => 'Starta';

  @override
  String get headingToPickup => 'På väg till upphämtning';

  @override
  String waitingForFirst(Object first) {
    return 'Väntar på $first';
  }

  @override
  String get toNextStop => 'Till nästa stopp';

  @override
  String get onYourWay => 'Längs din väg';

  @override
  String get afterThisDropOff => 'Efter den här avlämningen';

  @override
  String get availableAfterYourCurrentDropOff =>
      'Tillgänglig efter din nuvarande avlämning';

  @override
  String exclusiveSecondsS(Object seconds) {
    return 'Exklusiv · $seconds s';
  }

  @override
  String get onThisRide => 'Under den här resan';

  @override
  String pickupMinutesMinAway(Object pickupMinutes) {
    return '$pickupMinutes min bort';
  }

  @override
  String get deny => 'Neka';

  @override
  String get demoOffers => 'Demoerbjudanden';

  @override
  String get demoOffersLiveLocationUnavailableStale =>
      'Demoerbjudanden — liveposition saknas eller är gammal';

  @override
  String get navigateWithGoogleMaps => 'Navigera med Google Maps';

  @override
  String get googleMapsIsUnavailable => 'Google Maps är inte tillgängligt.';

  @override
  String get callRider => 'Ring resenären';

  @override
  String get messageRider => 'Skriv till resenären';

  @override
  String get riderDetailsFromBookingWillAppear =>
      'Resenärsuppgifter från bokningen visas här när profilen är kopplad till servern.';

  @override
  String get retryRoute => 'Hämta rutten igen';

  @override
  String get routeUnavailableYourTripRemainsActive =>
      'Rutten saknas. Din resa är fortfarande aktiv.';

  @override
  String get currentWaybill => 'Aktuell körorder';

  @override
  String get currentTripWaybill => 'Körorder för pågående resa';

  @override
  String get nextTripWaybill => 'Körorder för nästa resa';

  @override
  String get nextTripsOnYourWay => 'Nästa resor längs din väg';

  @override
  String get shareTripRecordAudioGetHelp =>
      'Dela resan, spela in ljud, få hjälp';

  @override
  String get shareTripGetHelp => 'Dela resan, få hjälp';

  @override
  String get stopSafelyFirstReasonRequired =>
      'Stanna säkert först · orsak krävs';

  @override
  String get whyAreYouCancellingNextTripQuestion =>
      'Varför avbokar du nästa resa?';

  @override
  String get whyAreYouEndingTripQuestion => 'Varför avslutar du resan?';

  @override
  String get whyAreYouCancellingQuestion => 'Varför avbokar du?';

  @override
  String get yourCurrentTripContinues => 'Din pågående resa fortsätter.';

  @override
  String get stopInSafePlaceFirst => 'Stanna på en säker plats först.';

  @override
  String get pickReasonThatFitsBest => 'Välj den orsak som passar bäst.';

  @override
  String get riderEndedTrip => 'Resenären avslutade resan';

  @override
  String riderNameCancelledWhileTripWas(Object riderName) {
    return '$riderName avbokade under resan. Stanna på en säker plats innan du lämnar skärmen.';
  }

  @override
  String riderNameCancelledThisRequestCurrent(Object riderName) {
    return '$riderName avbokade förfrågan. Upphämtningen är inte längre aktiv.';
  }

  @override
  String get activeTripCancelledByRider => 'Pågående resa avbokad av resenären';

  @override
  String get pickupCancelledByRider => 'Upphämtning avbokad av resenären';

  @override
  String get tripUpdate => 'RESEUPPDATERING';

  @override
  String get keepControlOfVehicleAndStop =>
      'Behåll kontrollen över bilen och stanna säkert innan du fortsätter.';

  @override
  String get iHaveStoppedSafely => 'Jag har stannat säkert';

  @override
  String get returnToRequests => 'Tillbaka till förfrågningar';

  @override
  String get waitingInProgress => 'Väntan pågår';

  @override
  String get takeCashBeforeYouFinish =>
      'Ta emot kontanterna innan du avslutar.';

  @override
  String takeCashFromFirstBeforeYou(Object first) {
    return 'Ta emot kontanterna från $first innan du avslutar.';
  }

  @override
  String get notYet => 'Inte än';

  @override
  String collectAmountInCash(Object amount) {
    return 'Ta emot $amount kontant';
  }

  @override
  String get collect => 'Ta emot';

  @override
  String get inCash => 'kontant';

  @override
  String get yourFare => 'Ditt pris';

  @override
  String get cashFromRider => 'Kontant från resenären';

  @override
  String get riderPaidMoreThanYourFare =>
      'Resenären betalade mer än ditt pris (kampanj). Det regleras i din nästa utbetalning.';

  @override
  String get riderPaidLessThanYourFare =>
      'Resenären betalade mindre än ditt pris (kampanj). Movera lägger till mellanskillnaden i din nästa utbetalning.';

  @override
  String get to => 'TILL';

  @override
  String get pickupArrived => 'Upphämtning · framme';

  @override
  String get pickupPickedUp => 'Upphämtning · hämtad';

  @override
  String stopNumberDone(Object number) {
    return 'Stopp $number · klart';
  }

  @override
  String get yourTrip => 'Din resa';

  @override
  String pickupPickupMinutesMin(Object pickupMinutes) {
    return 'Upphämtning · $pickupMinutes min';
  }

  @override
  String dropOffTripMinutesMinTrip(Object tripMinutes) {
    return 'Avlämning · $tripMinutes min resa';
  }

  @override
  String get nextTripOptions => 'Alternativ för nästa resa';

  @override
  String get openWaybill => 'Öppna körorder';

  @override
  String get contactRider => 'Kontakta resenären';

  @override
  String get yourCurrentTripContinuesReasonRequired =>
      'Din pågående resa fortsätter · orsak krävs';

  @override
  String nextTripCancelledTitle(Object title) {
    return 'Nästa resa avbokad · $title';
  }

  @override
  String get waybill => 'Körorder';

  @override
  String get stopWait => 'Väntan vid stopp';

  @override
  String get pickupWait => 'Väntan vid upphämtning';

  @override
  String get everyMinuteIsPaid => 'Varje minut är betald';

  @override
  String get thisStopHasNoFreeMinutes =>
      'Det här stoppet har inga gratisminuter. Hela väntan läggs till priset.';

  @override
  String ruleForThisPickupRule(Object rule) {
    return 'Regel för upphämtningen: $rule';
  }

  @override
  String get includedTime => 'Inkluderad tid';

  @override
  String get openingMinutesStayInsideFare =>
      'De första minuterna ingår i priset.';

  @override
  String get waitTime => 'Väntetid';

  @override
  String get addedFromFirstSecondAtThis =>
      'Läggs till från första sekunden vid stoppet.';

  @override
  String get addedToFareWhenThisTrip => 'Läggs till priset när resan är klar.';

  @override
  String perMinuteFormattedMin(Object perMinuteFormatted) {
    return '$perMinuteFormatted / min';
  }

  @override
  String get noShow => 'Uteblivet';

  @override
  String canBeAppliedAfterNoShow(Object noShowAfterMinutes) {
    return 'Kan användas efter $noShowAfterMinutes min om resenären inte har kommit.';
  }

  @override
  String get riderDidnTShow => 'Resenären kom inte';

  @override
  String youGetDriverShareWaitPercent(Object driverShareWaitPercent) {
    return 'Du får $driverShareWaitPercent % av väntetiden.';
  }

  @override
  String youGetDriverShareWaitPercent2(
    Object driverShareWaitPercent,
    Object driverShareNoShowPercent,
    Object driverNoShowFeeFormatted,
  ) {
    return 'Du får $driverShareWaitPercent % av väntetiden och $driverShareNoShowPercent % av avgiften för uteblivet ($driverNoShowFeeFormatted).';
  }

  @override
  String get amountsCanChangeWithTaxesAnd =>
      'Beloppen kan ändras med skatter och avgifter.';

  @override
  String get close => 'Stäng';

  @override
  String waitingFeePerMinuteFormattedMin(Object perMinuteFormatted) {
    return 'väntavgift · $perMinuteFormatted / min';
  }

  @override
  String get later => 'Senare';

  @override
  String get includedMinutes => 'Inkluderade minuter';

  @override
  String get theseFirstMinutesAreAlreadyPart =>
      'De första minuterna ingår redan i priset.';

  @override
  String get waitTimeIsRunning => 'Väntetiden löper';

  @override
  String get eachMinuteAfterIncludedTimeIs =>
      'Varje minut efter den inkluderade tiden läggs till när resan avslutas.';

  @override
  String get noShowCanBeApplied => 'Uteblivet kan användas';

  @override
  String get riderIsStillNotHereNo =>
      'Resenären är fortfarande inte här. Beloppet för uteblivet finns nu.';

  @override
  String get tripDetails => 'Resedetaljer';

  @override
  String get justNow => 'Nyss';

  @override
  String get rideCompleted => 'Resan är klar';

  @override
  String get payment => 'Betalning';

  @override
  String get lastWaybill => 'Senaste körordern';

  @override
  String get open => 'Öppna';

  @override
  String get tripId => 'Rese-ID';

  @override
  String get completed => 'Klar';

  @override
  String get ratingNotSentDemo => 'Betyget skickades inte (demo)';

  @override
  String rateRider(Object rider) {
    return 'Betygsätt $rider';
  }

  @override
  String get trip => 'Resa nr';

  @override
  String get time => 'Tid';

  @override
  String get fare => 'Pris';

  @override
  String get passenger => 'Resenär';

  @override
  String get via => 'Via';

  @override
  String get from => 'Från';

  @override
  String get to2 => 'Till';

  @override
  String get driver => 'Förare';

  @override
  String get licensePlate => 'Registreringsnummer';

  @override
  String get passengerCapacity => 'Antal platser';

  @override
  String get paidByPassenger => 'Betalt av resenären';

  @override
  String get inApp => 'I appen';

  @override
  String basePriceService(Object service) {
    return 'Grundpris · $service';
  }

  @override
  String get moveraFee => 'Moveras avgift';

  @override
  String get yourEarnings => 'Din intäkt';

  @override
  String get riderPays => 'Resenären betalar';

  @override
  String get roundToNearestWholeKronaIn =>
      '* Avrunda till närmaste hela krona i taxametern.';

  @override
  String get feature => 'Funktion';

  @override
  String get samplePeriod => 'Exempelperiod';

  @override
  String get clear => 'Rensa';

  @override
  String get back => 'Tillbaka';

  @override
  String get earningsPreview => 'Förhandsvisning av intäkter';

  @override
  String get demoRider => 'Demoresenär';

  @override
  String get sampleDistance => 'Exempelsträcka';

  @override
  String get sample => 'Exempel';

  @override
  String get pickupFrom => 'Upphämtning från';

  @override
  String get samplePickupStockholm => 'Exempelupphämtning, Stockholm';

  @override
  String get dropOffLocation => 'Avlämningsplats';

  @override
  String get sampleDropOffStockholm => 'Exempelavlämning, Stockholm';

  @override
  String get noAnswer => 'Inget svar';

  @override
  String answerAnswer(Object answer) {
    return 'Svar: $answer';
  }

  @override
  String audioSavedOnlyOnThisPhone(Object time) {
    return 'Ljud sparat bara på den här telefonen · $time';
  }

  @override
  String get pastRideRouteDriven => 'Körd rutt';

  @override
  String get pastRidePlannedRoute => 'Planerad rutt';

  @override
  String get pastRideRouteUnavailable => 'Rutten är inte tillgänglig';

  @override
  String get rideCost => 'Resans pris';

  @override
  String get tip => 'Dricks';

  @override
  String get paymentMethod => 'Betalsätt';

  @override
  String get rideType => 'Resetyp';

  @override
  String get cashCollected => 'Kontant mottaget';

  @override
  String get cashMatchedYourFare => 'Kontanterna stämde med ditt pris';

  @override
  String get cashMatchedYourEarnings =>
      'Kontanterna motsvarade din förtjänst: inget att reglera';

  @override
  String get settledInYourNextPayout => 'Regleras i din nästa utbetalning';

  @override
  String get rideCompletedOn => 'Resan klar';

  @override
  String get cancelledByRider => 'Avbokad av resenären';

  @override
  String get cancelledByDriver => 'Avbokad av föraren';

  @override
  String get cancelledBySupport => 'Avbokad av support';

  @override
  String get cancelledByMovera => 'Avbokad av Movera';

  @override
  String get riderDidNotArrive => 'Resenären kom inte';

  @override
  String get tripFailed => 'Resan misslyckades';

  @override
  String get previous => 'Tidigare';

  @override
  String get last7Days => 'Senaste 7 dagarna';

  @override
  String get loadingRideHistoryEllipsis => 'Laddar resehistorik…';

  @override
  String get couldNotLoadRideHistory => 'Resehistoriken gick inte att ladda.';

  @override
  String get earningsHistory => 'Intäkter och historik';

  @override
  String get allRides => 'Alla resor';

  @override
  String get yourMoveraActivity => 'Din Movera-aktivitet';

  @override
  String get online => 'Online';

  @override
  String get rides => 'Resor';

  @override
  String get earningsBreakdown => 'Intäkter i detalj';

  @override
  String get latestRides => 'Senaste resorna';

  @override
  String get noCompletedRidesInThisPeriod => 'Inga klara resor under perioden.';

  @override
  String viewAllVisibleRideCountRides(Object visibleRideCount) {
    return 'Visa alla $visibleRideCount resor';
  }

  @override
  String periodRidesRidesInPeriodLabel(Object periodRides, Object periodLabel) {
    return '$periodRides resor · $periodLabel';
  }

  @override
  String get week => 'Vecka';

  @override
  String get month => 'Månad';

  @override
  String get recordedFares => 'Registrerade intäkter';

  @override
  String get tipsAndFees => 'Dricks och avgifter';

  @override
  String get notAvailable => 'Saknas';

  @override
  String get otherEarnings => 'Övriga intäkter';

  @override
  String otherEarningsTripsLengthCash(Object tripsLength) {
    return 'Övriga intäkter · $tripsLength kontant';
  }

  @override
  String get cashTripsYourFareMinusCash =>
      'Kontantresor: ditt pris minus kontanterna du tog emot.';

  @override
  String get noCashTripsInThisPeriod => 'Inga kontantresor under perioden.';

  @override
  String get totalYouOweMovera => 'Totalt du är skyldig Movera';

  @override
  String get totalMoveraOwesYou => 'Totalt Movera är skyldig dig';

  @override
  String get totalBalance => 'Totalt saldo';

  @override
  String get settledInYourNextPayout2 => 'Regleras i din nästa utbetalning.';

  @override
  String fareFareFormattedCashCashCollected(
    Object fareFormatted,
    Object cashCollectedFormatted,
  ) {
    return 'Intäkt $fareFormatted · Kontant $cashCollectedFormatted';
  }

  @override
  String cashFareFeeLine(String fare, String fee, String cash) {
    return 'Pris $fare · Avgift $fee · Kontant $cash';
  }

  @override
  String get driver2 => 'FÖRARE';

  @override
  String get profile => 'Profil';

  @override
  String get accountVehicleAndDocuments => 'Konto, fordon och dokument';

  @override
  String get earningsAndWeeklyPayouts => 'Intäkter och veckoutbetalningar';

  @override
  String get completedAndPreviousRides => 'Klara och tidigare resor';

  @override
  String get notifications => 'Aviseringar';

  @override
  String get rideAlertsDemandAndAccount =>
      'Resevarningar, efterfrågan och konto';

  @override
  String get work => 'ARBETE';

  @override
  String get scheduledRides => 'Bokade resor';

  @override
  String get reservationsAndAcceptedTrips => 'Bokningar och accepterade resor';

  @override
  String get chooseCategoriesYouWantToReceive =>
      'Välj vilka kategorier du vill få';

  @override
  String get promotions => 'Kampanjer';

  @override
  String get bonusesAndCampaignOffers => 'Bonusar och kampanjerbjudanden';

  @override
  String get drivingLogs => 'Körjournal';

  @override
  String get hoursOnlineAndRestRules => 'Timmar online och viloregler';

  @override
  String get supportApp => 'SUPPORT OCH APP';

  @override
  String get support => 'Support';

  @override
  String get messagesAndSupportTickets => 'Meddelanden och supportärenden';

  @override
  String get settings => 'Inställningar';

  @override
  String get appAndDriverSettings => 'App- och förarinställningar';

  @override
  String sampleRating(Object rating) {
    return 'Exempelbetyg $rating';
  }

  @override
  String get active => 'Aktiv';

  @override
  String get pending => 'Väntar';

  @override
  String get soundVoice => 'Ljud och röst';

  @override
  String get savingPreferencesEllipsis => 'Sparar inställningar…';

  @override
  String get changesNotSavedRetry => 'Ändringarna sparades inte — Försök igen';

  @override
  String get couldNotLoadSavedPreferencesRetry =>
      'Inställningarna gick inte att ladda — Försök igen';

  @override
  String get localDemoPreferencesSavedOnThis =>
      'Lokala demoinställningar — sparas på den här enheten; effekterna är förhandsvisningar.';

  @override
  String get volume => 'Volym';

  @override
  String get generalVolume => 'Allmän volym';

  @override
  String get alwaysPlayTripRequests => 'Spela alltid reseförfrågningar';

  @override
  String get playsEvenWhenPhoneIsSilent =>
      'Spelas även när telefonen är ljudlös';

  @override
  String get voice => 'Röst';

  @override
  String get voiceNavigation => 'Röstnavigering';

  @override
  String get spokenTurnsWhileYouDrive => 'Upplästa sväng medan du kör';

  @override
  String get readRiderMessages => 'Läs upp resenärens meddelanden';

  @override
  String get readsNewChatMessagesAloud => 'Läser upp nya chattmeddelanden';

  @override
  String get testAlerts => 'Testa larm';

  @override
  String get testVoice => 'Testa röst';

  @override
  String get playingAlertSoundMock => 'Spelar larmljud (simulering)';

  @override
  String get playingVoiceSoundMock => 'Spelar röst (simulering)';

  @override
  String get accessibility => 'Tillgänglighet';

  @override
  String get hearing => 'Hörsel';

  @override
  String get tellRidersIfYouAreDeaf =>
      'Berätta för resenärer om du är döv eller hörselskadad.';

  @override
  String get demoPreviewNoInformationIsShared =>
      'Demoförhandsvisning — ingen information delas med resenärer.';

  @override
  String get closePreview => 'Stäng förhandsvisning';

  @override
  String get flashForRequests => 'Blinka vid förfrågningar';

  @override
  String get screenFlashesWhenRequestArrives =>
      'Skärmen blinkar när en förfrågan kommer.';

  @override
  String get vibrationForRequests => 'Vibration vid förfrågningar';

  @override
  String get phoneVibratesWhenRequestArrives =>
      'Telefonen vibrerar när en förfrågan kommer.';

  @override
  String get appSettings => 'Appinställningar';

  @override
  String get darkMode => 'Mörkt läge';

  @override
  String get unavailableInDemo => 'Inte tillgängligt i demo';

  @override
  String get language => 'Språk';

  @override
  String get pinVerification => 'PIN-verifiering';

  @override
  String get emergencyContacts => 'Nödkontakter';

  @override
  String get safety => 'Säkerhet';

  @override
  String get trustedContact => 'Betrodd kontakt';

  @override
  String get dialerIsUnavailable => 'Telefonen är inte tillgänglig.';

  @override
  String get addTrustedContact => 'Lägg till betrodd kontakt';

  @override
  String get couldNotLoadTrustedContactsRetry =>
      'Betrodda kontakter gick inte att ladda — Försök igen';

  @override
  String get trustedContactsStayOnThisDevice =>
      'Betrodda kontakter stannar på den här enheten. Samtal öppnar din telefon.';

  @override
  String callName(Object name) {
    return 'Ring $name';
  }

  @override
  String get contactCouldNotBeSavedRetry =>
      'Kontakten gick inte att spara. Försök igen.';

  @override
  String get name => 'Namn';

  @override
  String get enterName => 'Ange ett namn';

  @override
  String get phone => 'Telefon';

  @override
  String get enterValidPhoneNumber => 'Ange ett giltigt telefonnummer';

  @override
  String get relation => 'Relation';

  @override
  String get savingContactEllipsis => 'Sparar kontakt…';

  @override
  String get saveContact => 'Spara kontakt';

  @override
  String get recentPayouts => 'Senaste utbetalningar';

  @override
  String get seeAll => 'Visa alla';

  @override
  String get previewOnly => 'Endast förhandsvisning';

  @override
  String get noPayoutBalanceUntilPaymentService =>
      'Inget saldo att betala ut förrän en betaltjänst är ansluten.';

  @override
  String get noAutomaticPayout => 'Ingen automatisk utbetalning';

  @override
  String get payoutDateIsNotAvailable => 'Utbetalningsdatum saknas';

  @override
  String get notSet => 'Inte angivet';

  @override
  String get noPayoutsYetLocalPreviewCannot =>
      'Inga utbetalningar än. Den lokala förhandsvisningen hittar inte på intäkter.';

  @override
  String get payoutAccount => 'Utbetalningskonto';

  @override
  String get noPayoutAccountConnected => 'Inget utbetalningskonto anslutet';

  @override
  String ratingRiderTripsTrips(Object rating, Object riderTrips) {
    return '$rating · $riderTrips resor';
  }

  @override
  String get closeOffer => 'Stäng erbjudandet';

  @override
  String reservationTime(Object time) {
    return 'Bokning · $time';
  }

  @override
  String get priority => 'Prioriterad';

  @override
  String get demoModeNoAccount => 'Demoläge — inget konto';

  @override
  String labelUnavailableInDemo(Object label) {
    return '$label — inte tillgängligt i demo';
  }

  @override
  String get routeUpdated => 'Rutten uppdaterad';

  @override
  String get gpsRestored => 'GPS återställd';

  @override
  String get waitingAtStop => 'Väntar vid stopp';

  @override
  String get paidWaiting => 'Betald väntan';

  @override
  String get waitingTime => 'Väntetid';

  @override
  String nearValue(Object value) {
    return 'Nära: $value';
  }

  @override
  String get arrivingSoon => 'Snart framme';

  @override
  String trafficAheadValueMin(Object value) {
    return 'Trafik framåt · +$value min';
  }

  @override
  String arrivingInEtaMinTimeTime2(Object eta, Object time, Object time2) {
    return 'Framme om $eta min · $time:$time2';
  }

  @override
  String nextTripSecuredNextTripFare(Object nextTripFare) {
    return 'Nästa resa klar · $nextTripFare';
  }

  @override
  String get tollAhead => 'Vägtull framåt';

  @override
  String pickupOverKmKm(Object km) {
    return 'Upphämtning över $km km';
  }

  @override
  String get assignedByMovera => 'Tilldelad av Movera';

  @override
  String get islandOnline => 'Radar online';

  @override
  String get islandOffline => 'Radar offline';

  @override
  String get islandRiderCancelled => 'Resenären avbokade';

  @override
  String get islandRiderEndedTrip => 'Resenären avslutade';

  @override
  String get islandTripRemoved => 'Resan borttagen av Movera';

  @override
  String islandCancelFee(Object amount) {
    return '+$amount';
  }

  @override
  String get islandCancelNoFee => 'ingen avgift';

  @override
  String islandReservationCancelled(Object time) {
    return '$time avbokad';
  }

  @override
  String get islandMatching => 'Matchar…';

  @override
  String get islandMatched => 'Resa matchad';

  @override
  String get islandTakenByOther => 'Tagen av en annan förare';

  @override
  String get islandTripUnavailable => 'Resan är inte tillgänglig';

  @override
  String get islandNoConnection => 'Ingen anslutning';

  @override
  String get islandContactSupport => 'Kontakta support';

  @override
  String get islandAccountOnHold => 'Kontot pausat · Kontakta support';

  @override
  String get islandAccountNotActive =>
      'Kontot inte aktivt · Slutför registreringen';

  @override
  String get islandNewReservation => 'Ny bokning';

  @override
  String get islandExclusiveRide => 'Exklusiv resa';

  @override
  String get islandExclusiveReservation => 'Exklusiv bokning';

  @override
  String get islandReservationAccepted => 'Bokning accepterad';

  @override
  String islandReservationAcceptedAt(Object time) {
    return 'Accepterad · upphämtning $time';
  }

  @override
  String get islandNoLongerAvailable => 'Inte längre tillgänglig';

  @override
  String get islandAssignedByMovera => 'Tilldelad av Movera';

  @override
  String get islandAssignmentAccepted => 'Bokad resa accepterad';

  @override
  String get islandAssignmentNotAccepted => 'Tilldelningen accepterades inte';

  @override
  String islandPickupIn(Object time, Object left) {
    return 'Upphämtning $time om $left';
  }

  @override
  String islandGoOnlineFor(Object time) {
    return 'Gå online för $time';
  }

  @override
  String islandLeaveNow(Object time) {
    return 'Åk nu till upphämtningen $time';
  }

  @override
  String islandHeadToPickup(Object time) {
    return 'Åk till upphämtningen $time';
  }

  @override
  String get islandGivenToBackup => 'Gick till reservförare';

  @override
  String islandLateReassigned(Object minutes) {
    return 'Gick till annan förare: $minutes min sen';
  }

  @override
  String get lateEtaReassignedTitle => 'Resan gick till en annan förare';

  @override
  String lateEtaReassignedNote(String time, int minutes) {
    return 'Resan gick till en annan förare — du skulle nå upphämtningen $time ungefär $minutes min för sent.';
  }

  @override
  String get islandCashOn => 'Kontantresor på';

  @override
  String get islandCashOff => 'Kontantresor av';

  @override
  String islandOfflineMissed(Object count) {
    return 'Offline: $count missade erbjudanden';
  }

  @override
  String islandDrivingLeft(Object minutes) {
    return '$minutes min kvar att köra';
  }

  @override
  String islandRestUntil(Object time) {
    return 'Vila till $time';
  }

  @override
  String get islandRestOver => 'Vilan är slut';

  @override
  String islandDocumentExpires(Object document, Object when) {
    return '$document går ut $when';
  }

  @override
  String islandDocumentExpired(Object document) {
    return '$document har gått ut';
  }

  @override
  String get islandDocumentInReview => 'Nytt dokument granskas';

  @override
  String get islandDocumentApproved => 'Dokumentet godkänt';

  @override
  String islandHighDemand(Object area) {
    return 'Hög efterfrågan · $area';
  }

  @override
  String get islandScheduledPaused => 'Bokade resor pausade';

  @override
  String get islandSavedTripOpen => 'Sparad resa öppen';

  @override
  String get islandNewerTripKept => 'Nyare resa behölls';

  @override
  String get islandRecordSetAside => 'Resan lades åt sidan';

  @override
  String get islandRecoveryFailed => 'Återställningen misslyckades';

  @override
  String get islandTripNotClosed => 'Resan inte avslutad';

  @override
  String get islandCloseSavedTrip => 'Avsluta sparad resa';

  @override
  String get islandSeeEarnings => 'Tryck för att se intäkter';

  @override
  String get islandDestinationsUsed => 'Dagens destinationer är slut';

  @override
  String get islandDestinationOff => 'Destinationsläget är avstängt här';

  @override
  String get islandDestinationEnded => 'Destinationsläget har avslutats';

  @override
  String get offerYourShare => 'Din andel';

  @override
  String get offerFare => 'Pris';

  @override
  String get offerPickup => 'Upphämtning';

  @override
  String get offerDropoff => 'Avlämning';

  @override
  String get offerPickupNearby => 'Upphämtning nära';

  @override
  String offerKmAway(Object km) {
    return '$km km bort';
  }

  @override
  String offerTripLength(Object minutes, Object km) {
    return '$minutes min resa · $km km';
  }

  @override
  String get offerMatch => 'Ta resan';

  @override
  String get offerMatching => 'Matchar…';

  @override
  String get offerAccept => 'Acceptera';

  @override
  String get offerOnYourWay => 'Längs din väg';

  @override
  String get offerHide => 'Dölj erbjudandet';

  @override
  String get offerReservationRequest => 'Bokningsförfrågan';

  @override
  String get offerYourNextRide => 'Din nästa resa';

  @override
  String get offerViewRoute => 'Visa rutt';

  @override
  String get offerNewReservation => 'Ny bokning';

  @override
  String get offerViewDetails => 'Visa detaljer';

  @override
  String get tripArrived => 'Jag är framme';

  @override
  String get tripStart => 'Starta resan';

  @override
  String get tripStartFirstStop => 'Till första stoppet';

  @override
  String get tripArriveAtStop => 'Framme vid stoppet';

  @override
  String get tripComplete => 'Avsluta resan';

  @override
  String tripGoToStop(Object stop) {
    return 'Kör till $stop stoppet';
  }

  @override
  String get tripGoToDropoff => 'Kör till avlämning';

  @override
  String get cashPriceChanged => 'Priset ändrades – ta emot det nya beloppet';

  @override
  String get cashPriceRecalculatedEarlyEnd =>
      'Avslutas före destinationen – priset räknades om';

  @override
  String get tripCollectCash => 'Ta emot kontant';

  @override
  String get tripCompleteRide => 'Avsluta resan';

  @override
  String get tripFinishRide => 'Avsluta resan';

  @override
  String get cancelReasonRiderNoShow => 'Resenären kom inte';

  @override
  String get cancelReasonRiderNoShowDetail =>
      'Väntetiden har gått ut och resenären är inte här';

  @override
  String get cancelReasonRiderRequestedCancel => 'Resenären bad om avbokning';

  @override
  String get cancelReasonRiderRequestedCancelDetail =>
      'Resenären vill inte fortsätta';

  @override
  String get cancelReasonRiderNotAtPickup =>
      'Resenären är inte vid upphämtningen';

  @override
  String get cancelReasonRiderNotAtPickupDetail =>
      'Du är framme men hittar inte resenären';

  @override
  String get cancelReasonUnsafePickup => 'Osäker upphämtning';

  @override
  String get cancelReasonUnsafePickupDetail =>
      'Du kan inte stanna där på ett säkert sätt';

  @override
  String get cancelReasonVehicleIssueBeforeStart => 'Fel på bilen';

  @override
  String get cancelReasonVehicleIssueBeforeStartDetail =>
      'Bilen klarar inte resan';

  @override
  String get cancelReasonDriverEmergencyBeforeStart => 'Personligt nödläge';

  @override
  String get cancelReasonDriverEmergencyBeforeStartDetail =>
      'Något akut har hänt';

  @override
  String get cancelReasonOtherBeforeStart => 'Annan orsak';

  @override
  String get cancelReasonOtherBeforeStartDetail =>
      'Något annat hindrar upphämtningen';

  @override
  String get cancelReasonRiderRequestedEarlyEnd =>
      'Resenären vill avsluta resan';

  @override
  String get cancelReasonRiderRequestedEarlyEndDetail =>
      'Resenären vill kliva av före destinationen';

  @override
  String get cancelReasonSafetyConcernOnTrip => 'Säkerhetsrisk';

  @override
  String get cancelReasonSafetyConcernOnTripDetail =>
      'Det kan vara osäkert att fortsätta resan';

  @override
  String get cancelReasonVehicleIssueOnTrip => 'Fel på bilen';

  @override
  String get cancelReasonVehicleIssueOnTripDetail =>
      'Ett fel på bilen gör det osäkert att fortsätta';

  @override
  String get cancelReasonAccidentOrRoadEmergency =>
      'Olycka eller nödläge på vägen';

  @override
  String get cancelReasonAccidentOrRoadEmergencyDetail =>
      'En händelse eller ett nödläge hindrar resan';

  @override
  String get cancelReasonRiderBehavior => 'Resenärens beteende';

  @override
  String get cancelReasonRiderBehaviorDetail =>
      'Resenärens beteende gör att resan måste avslutas';

  @override
  String get cancelReasonTripOrDestinationIssue =>
      'Problem med resan eller destinationen';

  @override
  String get cancelReasonTripOrDestinationIssueDetail =>
      'En resedetalj eller destinationen hindrar resan';

  @override
  String get cancelReasonOtherOnTrip => 'Annan orsak';

  @override
  String get cancelReasonOtherOnTripDetail =>
      'Ett annat problem gör att resan måste avslutas i förtid';

  @override
  String get cancelReasonScheduledCannotMakeTime =>
      'Jag hinner inte till upphämtningen';

  @override
  String get cancelReasonScheduledVehicleIssue => 'Fel på bilen';

  @override
  String get cancelReasonScheduledPersonalEmergency => 'Personligt nödläge';

  @override
  String get cancelReasonScheduledPickupTooFar =>
      'Upphämtningen är för långt bort';

  @override
  String get cancelReasonScheduledTripDetails =>
      'Resans detaljer passar mig inte längre';

  @override
  String get cancelReasonScheduledOther => 'Annan orsak';

  @override
  String get cancelReasonNextTripCurrentRunningLate =>
      'Pågående resa tar längre tid';

  @override
  String get cancelReasonNextTripCurrentRunningLateDetail =>
      'Du hinner inte till nästa upphämtning';

  @override
  String get cancelReasonNextTripPickupTooFar => 'För långt till upphämtningen';

  @override
  String get cancelReasonNextTripPickupTooFarDetail =>
      'Nästa upphämtning är längre bort än väntat';

  @override
  String get cancelReasonNextTripRiderRequested => 'Resenären bad mig avboka';

  @override
  String get cancelReasonNextTripRiderRequestedDetail =>
      'Nästa resenär vill inte ha resan';

  @override
  String get cancelReasonNextTripVehicleIssue => 'Problem med bilen';

  @override
  String get cancelReasonNextTripVehicleIssueDetail =>
      'Bilen klarar inte nästa resa';

  @override
  String get cancelReasonNextTripDriverEmergency => 'Personligt nödläge';

  @override
  String get cancelReasonNextTripDriverEmergencyDetail => 'Något akut har hänt';

  @override
  String get cancelReasonNextTripOther => 'Annan orsak';

  @override
  String get cancelReasonNextTripOtherDetail =>
      'Något annat hindrar nästa resa';

  @override
  String get cancelReasonPickupIncorrect => 'Upphämtningsplatsen är fel';

  @override
  String get cancelReasonWrongRideOption => 'Jag valde fel resealternativ';

  @override
  String get cancelReasonRequestedByMistake => 'Jag beställde resan av misstag';

  @override
  String get cancelReasonWaitTooLong => 'Väntan tar för lång tid';

  @override
  String get cancelReasonDestinationChange => 'Destinationen behöver ändras';

  @override
  String get cancelReasonDriverNotSuitable => 'Förare eller resa passar inte';

  @override
  String get cancelReasonPlansChanged => 'Ändrade planer';

  @override
  String get cancelReasonSomethingElse => 'Något annat';

  @override
  String get exclusiveReasonBestMatch => 'Bästa matchningen';

  @override
  String get exclusiveReasonFavourite => 'Resenärens favorit';

  @override
  String get exclusiveReasonFinishingNearby => 'Du avslutar i närheten';

  @override
  String get exclusiveReasonAirportQueue => 'Flygplatskö';

  @override
  String get exclusiveReasonPickupSoon => 'Upphämtning snart';

  @override
  String get exclusiveReasonNearby => 'Bara för dig · i närheten';

  @override
  String get waitingRulePickupFarAway => 'Upphämtning långt bort';

  @override
  String get waitingRuleScheduledRide => 'Bokad resa';

  @override
  String get waitingRuleAirportPickup => 'Upphämtning på flygplats';

  @override
  String get waitingRuleEventPickup => 'Upphämtning vid evenemang';

  @override
  String riderBags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resenären har $count väskor',
      one: 'Resenären har 1 väska',
    );
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Språk';

  @override
  String get languageZoneDefault => 'Standard för din zon';

  @override
  String get languageSaveFailed => 'Språket sparades inte. Försök igen.';

  @override
  String get mapUnavailable =>
      'Kartan är inte tillgänglig. Kontrollera anslutningen och öppna Movera igen.';

  @override
  String get tomorrow => 'Imorgon';

  @override
  String get todayCaps => 'IDAG';

  @override
  String get statusRest => 'VILA';

  @override
  String get statusHold => 'SPÄRR';

  @override
  String whenInMinutes(Object minutes) {
    return 'Om $minutes min';
  }

  @override
  String whenInHours(Object hours) {
    return 'Om $hours h';
  }

  @override
  String whenToday(Object time) {
    return 'Idag $time';
  }

  @override
  String whenTomorrow(Object time) {
    return 'Imorgon $time';
  }

  @override
  String get stopOrdinal1 => 'första';

  @override
  String get stopOrdinal2 => 'andra';

  @override
  String get stopOrdinal3 => 'tredje';

  @override
  String get stopOrdinal4 => 'fjärde';

  @override
  String get stopOrdinal5 => 'femte';

  @override
  String stopOrdinalN(Object number) {
    return '$number:e';
  }

  @override
  String get hideRequest => 'Dölj förfrågan';

  @override
  String get holdToGoOffline => 'Håll för att gå offline';

  @override
  String get tripOptions => 'Resealternativ';

  @override
  String get orbMatch => 'TA';

  @override
  String get orbWait => 'VÄNTA';

  @override
  String get orbOff => 'AV';

  @override
  String get orbOn => 'PÅ';

  @override
  String get orbNew => 'NY';

  @override
  String get orbLive => 'LIVE';

  @override
  String get orbPaused => 'PAUS';

  @override
  String get orbStarting => 'STARTAR';

  @override
  String get navArrived => 'FRAMME';

  @override
  String get navNear => 'NÄRA';

  @override
  String get navNow => 'NU';

  @override
  String get menuOnline => 'ONLINE';

  @override
  String get menuOffline => 'OFFLINE';

  @override
  String get menuReady => 'KLAR';

  @override
  String get menuPending => 'VÄNTAR';

  @override
  String get ok => 'OK';

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resor',
      one: '1 resa',
    );
    return '$_temp0';
  }

  @override
  String stopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stopp',
      one: '1 stopp',
    );
    return '$_temp0';
  }

  @override
  String get navArrive => 'Ankomst';

  @override
  String get navHeadOut => 'Kör iväg';

  @override
  String get navKeepLeft => 'Håll vänster';

  @override
  String get navKeepRight => 'Håll höger';

  @override
  String get navTunnelAhead => 'Tunnel längre fram';

  @override
  String get navTollRoadAhead => 'Avgiftsväg längre fram';

  @override
  String get navContinueStraight => 'Fortsätt rakt fram';

  @override
  String get navContinue => 'Fortsätt';

  @override
  String get navRoundabout => 'Rondell';

  @override
  String navRoundaboutExit(String exit) {
    return 'Rondell, avfart $exit';
  }

  @override
  String get navRoundaboutUTurn => 'Rondell, U-sväng';

  @override
  String navRoundaboutUTurnExit(String exit) {
    return 'Rondell, U-sväng · avfart $exit';
  }

  @override
  String navSignedExit(String exit) {
    return 'Avfart $exit';
  }

  @override
  String navSignedExitTowards(String exit, String place) {
    return 'Avfart $exit · $place';
  }

  @override
  String get navExitLeft => 'Avfart till vänster';

  @override
  String get navExitRight => 'Avfart till höger';

  @override
  String get navTakeExit => 'Ta avfarten';

  @override
  String get navRampOnto => 'Ta påfarten mot';

  @override
  String get navRampLeft => 'Ta påfarten till vänster';

  @override
  String get navRampRight => 'Ta påfarten till höger';

  @override
  String get navRamp => 'Ta påfarten';

  @override
  String get navMergeLeft => 'Kör in till vänster';

  @override
  String get navMergeRight => 'Kör in till höger';

  @override
  String get navMerge => 'Kör in';

  @override
  String get navForkLeft => 'Vid vägskälet, kör vänster';

  @override
  String get navForkRight => 'Vid vägskälet, kör höger';

  @override
  String get navContinueAtFork => 'Fortsätt vid vägskälet';

  @override
  String get navTurnLeft => 'Sväng vänster';

  @override
  String get navTurnRight => 'Sväng höger';

  @override
  String get navEndOfRoad => 'Vägens slut';

  @override
  String get navUTurn => 'U-sväng';

  @override
  String get navSharpLeft => 'Sväng skarpt vänster';

  @override
  String get navSharpRight => 'Sväng skarpt höger';

  @override
  String get navSlightLeft => 'Sväng svagt vänster';

  @override
  String get navSlightRight => 'Sväng svagt höger';

  @override
  String get navDistanceNow => 'nu';

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
    return 'om $distance';
  }

  @override
  String navActionIn(String action, String distance) {
    return '$action om $distance';
  }

  @override
  String navActionNow(String action) {
    return '$action nu';
  }

  @override
  String navActionFor(String action, String distance) {
    return '$action i $distance';
  }

  @override
  String navOnto(String action, String road) {
    return '$action in på $road';
  }

  @override
  String get navArriveAtDestination => 'Du är framme vid målet';

  @override
  String navHeadOutOn(String road) {
    return 'Kör iväg på $road';
  }

  @override
  String navContinueOn(String road) {
    return 'Fortsätt på $road';
  }

  @override
  String get navRoundaboutContinue => 'Fortsätt i rondellen';

  @override
  String navRoundaboutTakeExit(String exit) {
    return 'Ta avfart $exit i rondellen';
  }

  @override
  String get navExitOnLeft => 'Ta avfarten till vänster';

  @override
  String get navExitOnRight => 'Ta avfarten till höger';

  @override
  String get navEndTurnLeft => 'Sväng vänster vid vägens slut';

  @override
  String get navEndTurnRight => 'Sväng höger vid vägens slut';

  @override
  String get navAtEndOfRoad => 'Vid vägens slut';

  @override
  String get navMakeUTurn => 'Gör en U-sväng';

  @override
  String navUseLeftLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Använd de $count vänstra körfälten',
      one: 'Använd vänster körfält',
    );
    return '$_temp0';
  }

  @override
  String navUseRightLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Använd de $count högra körfälten',
      one: 'Använd höger körfält',
    );
    return '$_temp0';
  }

  @override
  String navUseMiddleLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Använd de $count mittersta körfälten',
      one: 'Använd mittersta körfältet',
    );
    return '$_temp0';
  }

  @override
  String navTowards(String place) {
    return 'mot $place';
  }

  @override
  String get navToDestination => 'Mot målet';

  @override
  String navExitSemantics(String cue, String exit) {
    return '$cue, avfart $exit';
  }

  @override
  String get navPickupAhead => 'Upphämtning strax framför';

  @override
  String get navDropOffAhead => 'Avlämning strax framför';

  @override
  String navPointAhead(String point) {
    return '$point strax framför';
  }

  @override
  String get navToPickup => 'Navigera till upphämtningen';

  @override
  String navToPoint(String point) {
    return 'Navigera till $point';
  }

  @override
  String get navDropOffLower => 'avlämningen';

  @override
  String get navWaitingForRider => 'Väntar på resenären';

  @override
  String get navRouteUpdating => 'Rutten uppdateras…';

  @override
  String get navRouteRecalculating => 'Beräknar om rutten…';

  @override
  String get navRouteUnavailableRetry =>
      'Rutten är inte tillgänglig – försök igen';

  @override
  String get navRouteUnavailableLocation =>
      'Rutten är inte tillgänglig – kontrollera platsen';

  @override
  String get licensePlateNumber => 'Registreringsnummer';

  @override
  String get createAccount => 'Skapa konto';

  @override
  String get enterValidPhoneForCode =>
      'Ange ett giltigt telefonnummer som vi kan skicka en verifieringskod till';

  @override
  String get fullName => 'Fullständigt namn';

  @override
  String get emailAddress => 'E-postadress';

  @override
  String get acceptTermsAndPrivacy =>
      'Godkänn villkoren och integritetspolicyn';

  @override
  String get byContinuingIAgreeTo => ' Genom att fortsätta godkänner jag ';

  @override
  String get termsOfUse => 'Användarvillkoren';

  @override
  String get andWord => ' och ';

  @override
  String get privacyPolicy => 'Integritetspolicyn';

  @override
  String get phoneVerification => 'Verifiering av telefon';

  @override
  String get codeDeliveryUnavailableDemo =>
      'Koder skickas inte i den här demon';

  @override
  String get accountVerificationNeedsService =>
      ' Kontoverifiering kräver kontotjänsten.';

  @override
  String get didNotGetCode => 'Fick du ingen kod?';

  @override
  String get signInUnavailableInPreview =>
      'Inloggning är inte tillgänglig i förhandsvisningen';

  @override
  String get verificationUnavailableDemo =>
      'Verifiering är inte tillgänglig i den här demon.';

  @override
  String get signIn => 'Logga in';

  @override
  String get welcomeBackRiding => 'Välkommen tillbaka! Nu kör vi';

  @override
  String get continueWithPhone => 'Fortsätt med telefon';

  @override
  String get continueWithApple => 'Fortsätt med Apple';

  @override
  String get continueWithGoogle => 'Fortsätt med Google';

  @override
  String get dontHaveAccount => 'Har du inget konto?';

  @override
  String get signUp => 'Registrera dig';

  @override
  String get signInWithPhone => 'Logga in med telefonnummer';

  @override
  String get phoneSignInUnavailableDemo =>
      'Inloggning med telefon är inte tillgänglig i den här demon. Ingen kod skickas.';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get phoneSignInNeedsService =>
      'Inloggning med telefon kräver kontotjänsten.';

  @override
  String get socialSignInNeedsService =>
      'Inloggning med Apple eller Google kräver kontotjänsten.';

  @override
  String get enterValidPhoneWeWillSend =>
      'Ange ett giltigt telefonnummer som vi skickar till';

  @override
  String get insurance => 'Försäkring';

  @override
  String get todayLower => 'i dag';

  @override
  String get tomorrowLower => 'i morgon';

  @override
  String inDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'om $count dagar',
      one: 'om 1 dag',
    );
    return '$_temp0';
  }

  @override
  String get docInsuranceLetter => 'Försäkringsbrev';

  @override
  String get docTaxiDriverLicense => 'Taxiförarlegitimation';

  @override
  String get docTaxiLicenseShort => 'Taxilegitimation';

  @override
  String get docRegistrationCertificate => 'Registreringsbevis';

  @override
  String get docRegistrationShort => 'Registrering';

  @override
  String get docDriversLicense => 'Körkort';

  @override
  String get docVehicleVerification => 'Fordonskontroll';

  @override
  String get docDriversId => 'Förarens id-handling';

  @override
  String get docExpiredCantGoOnline => 'Har gått ut · Du kan inte gå online';

  @override
  String docExpiresWhenDate(String when, String date) {
    return 'Går ut $when · $date';
  }

  @override
  String docNewTitle(String title) {
    return 'Nytt dokument: $title';
  }

  @override
  String get docTakeClearPhoto =>
      'Ta ett tydligt foto av hela dokumentet. Movera kontrollerar det innan det gäller.';

  @override
  String get docSendNew => 'Skicka nytt dokument';

  @override
  String get docDemoNoFileLeaves => 'Demo: ingen fil lämnar telefonen.';

  @override
  String get docSentForReview => 'Skickat för granskning';

  @override
  String docTitleExpired(String title) {
    return '$title har gått ut';
  }

  @override
  String get youCanGoOnlineNow => 'Du kan gå online nu.';

  @override
  String get docNewInReviewGoOnlineWhenApproved =>
      'Ditt nya dokument granskas. Du kan gå online när Movera har godkänt det.';

  @override
  String get docUploadNewGoOnlineWhenApproved =>
      'Ladda upp ett nytt. Du kan gå online när Movera har godkänt det.';

  @override
  String get approveDemo => 'Godkänn (demo)';

  @override
  String get uploadNew => 'Ladda upp nytt';

  @override
  String get documents => 'Dokument';

  @override
  String get docTermsAndConditions => 'Villkor';

  @override
  String get docVirtualInfoSession => 'Digital informationsträff';

  @override
  String get docDriversLicenseLower => 'Körkort';

  @override
  String get docProfilePhoto => 'Profilfoto';

  @override
  String get docCompanyRegistration => 'Företagsregistrering';

  @override
  String get docCompanyRegistrationNote =>
      'Utdrag från Bolagsverket eller Skatteverket. Behövs inte med en flottpartner.';

  @override
  String get docTaxiTrafficPermit => 'Taxitrafiktillstånd';

  @override
  String get docTaxSettings => 'Skatteinställningar';

  @override
  String get docBankStatement => 'Kontoutdrag';

  @override
  String get docFrontPage => 'Första sidan';

  @override
  String get docStockholmTrips => 'Stockholm · Resor';

  @override
  String get docEarnAnywhereSweden => 'Tjäna pengar i hela Sverige';

  @override
  String get docSampleListNotice =>
      'Exempellista · Det går inte att skicka de här dokumenten i appen än. Inget här har laddats upp eller granskats.';

  @override
  String docApprovedOfTotal(int approved, int total) {
    return '$approved av $total godkända';
  }

  @override
  String docLeftCount(int count) {
    return '$count kvar';
  }

  @override
  String get vehicle => 'Fordon';

  @override
  String get docPreviewNotAvailable =>
      'Inte tillgängligt än – exempelsida. Att skicka det här dokumentet finns inte i appen än. Inget dokument har laddats upp eller granskats.';

  @override
  String schedRidesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resor dolda',
      one: '1 resa dold',
    );
    return '$_temp0';
  }

  @override
  String schedClashBody(String time) {
    return 'Den krockar med din upphämtning $time: inte tillräckligt med tid för att hinna dit.';
  }

  @override
  String get reminder => 'Påminnelse';

  @override
  String get schedAvailableToday => 'Tillgängliga i dag';

  @override
  String get schedUpcoming => 'Kommande';

  @override
  String get schedPreviewNotBinding =>
      'Förhandsvisning – inte bindande. Valen gäller tills appen startas om.';

  @override
  String get schedNoneYet =>
      'Inga schemalagda resor än. Bokningar från Movera visas här.';

  @override
  String schedAcceptedPickupAt(String time) {
    return 'Accepterad · upphämtning $time';
  }

  @override
  String get laterLower => 'senare';

  @override
  String get schedReservationCancelled => 'Bokningen är avbokad';

  @override
  String get schedPlanAhead => 'Planera i förväg och välj din nästa resa';

  @override
  String get schedRequestsTab => 'Förfrågningar';

  @override
  String get schedAcceptedTab => 'Accepterade';

  @override
  String schedSeedTime(String day, String time) {
    return '$day $time';
  }

  @override
  String schedPickupTomorrowAt(String time) {
    return 'Upphämtning i morgon kl. $time';
  }

  @override
  String schedBackupNote(String time) {
    return 'Din upphämtning $time har lämnats till en reservförare.';
  }

  @override
  String get schedSampleReservation => 'Exempelbokning';

  @override
  String get schedReservationDetails => 'Bokningsdetaljer';

  @override
  String get schedIllustrativeRoute => 'Illustrerad rutt – exempeldata';

  @override
  String get schedViewRoute => 'Visa bokningens rutt';

  @override
  String get schedDemoAccepted => 'Accepterad (demo)';

  @override
  String get schedAvailable => 'Tillgänglig';

  @override
  String get rideTypeLabel => 'Resetyp';

  @override
  String get trip2 => 'Resa';

  @override
  String get route => 'Rutt';

  @override
  String get schedBeforeThisRide => 'Före den här resan';

  @override
  String get goodToKnow => 'Bra att veta';

  @override
  String get schedBeReadyEarly => 'Var redo i god tid';

  @override
  String schedGoOnlineMinBefore(String minutes) {
    return 'Gå online $minutes min före upphämtningen så att appen kan guida dig i tid.';
  }

  @override
  String get schedTripsOnTheWay => 'Resor på vägen';

  @override
  String get schedOnlyTripsToward =>
      'Före upphämtningen får du bara resor som går mot den och lämnar tid att hinna dit.';

  @override
  String get schedStillReceiveRides =>
      'Du kan fortfarande få passande resor före den bokade upphämtningen.';

  @override
  String get schedPlansChanged => 'Ändrade planer?';

  @override
  String schedDriversNeverPay(String line) {
    return '$line Förare betalar aldrig för att avboka.';
  }

  @override
  String get schedLocalPreviewCancel =>
      'Det här är en lokal förhandsvisning. Att avboka tar bort exempelbokningen tills appen startas om.';

  @override
  String get schedReservedForYou => 'Reserverad åt dig';

  @override
  String get schedKeepInAccepted =>
      'Vi behåller resan i din lista Accepterade. Om du avbokar får du ange ett skäl innan något ändras.';

  @override
  String get schedCancelReservation => 'Avboka';

  @override
  String schedAcceptPrice(String price) {
    return 'Acceptera  •  $price';
  }

  @override
  String get chooseBestReason => 'Välj det skäl som passar bäst.';

  @override
  String get schedCancelThisReservation => 'Avboka den här bokningen?';

  @override
  String get schedReasonDoesntCount => 'Det här skälet räknas inte emot dig.';

  @override
  String get schedRemovesSample =>
      'Det här tar bort exempelbokningen från sessionen. Ingen riktig bokning avbokas och kontots åtkomst ändras inte.';

  @override
  String get schedKeepReservation => 'Behåll bokningen';

  @override
  String tomorrowAtClock(String clock) {
    return 'i morgon $clock';
  }

  @override
  String schedFreeCancelHoursBefore(String hours) {
    return 'Gratis avbokning fram till $hours h före upphämtning.';
  }

  @override
  String schedLateCancelUnder(String hours) {
    return 'Sen avbokning: under $hours h till upphämtning.';
  }

  @override
  String schedFreeCancelUntil(String time) {
    return 'Gratis avbokning fram till $time.';
  }

  @override
  String get schedRidesAreOff => 'Bokade resor är avstängda';

  @override
  String schedRidesOffUntil(String date) {
    return 'Bokade resor avstängda till $date';
  }

  @override
  String schedRidesPausedUntil(String date) {
    return 'Bokade resor pausade till $date';
  }

  @override
  String get schedOffInYourArea =>
      'Movera har pausat nya bokade resor i ditt område. Resor du redan har accepterat blir av ändå.';

  @override
  String get schedTurnedOffByMovera =>
      'Movera har stängt av bokade resor för ditt konto. Kontakta supporten om du har frågor.';

  @override
  String schedLateCancelsInDays(String count, String days) {
    return 'Du har haft $count sena avbokningar på $days dagar. Dina accepterade resor finns kvar.';
  }

  @override
  String get schedNeverPayLateCounts =>
      'Du betalar aldrig för att avboka, men den här sena avbokningen räknas.';

  @override
  String schedNeverPayUnderHours(String hours) {
    return 'Du betalar aldrig för att avboka. Under $hours h före upphämtning är avbokningen sen och räknas mot en paus.';
  }

  @override
  String schedLateCancelPauses(String count, String days, String date) {
    return 'Det här är en sen avbokning ($count på $days dagar). Bokade resor pausas till $date.';
  }

  @override
  String get schedLateCancelCounts =>
      'Det här är en sen avbokning och den räknas. Du betalar aldrig.';

  @override
  String get schedAcceptedBadge => 'Accepterad';

  @override
  String get supportCatTripRider => 'Resa och resenär';

  @override
  String get supportCatWallet => 'Plånbok och betalningar';

  @override
  String get supportCatAccount => 'Konto och dokument';

  @override
  String get supportCatTechnical => 'Tekniskt problem';

  @override
  String get supportLocalDraftBadge => 'LOKALT UTKAST';

  @override
  String get supportCouldNotRecover =>
      'Det gick inte att återställa lokal support. Försök igen.';

  @override
  String get supportCouldNotSaveConversation =>
      'Det gick inte att spara den lokala konversationen. Försök igen.';

  @override
  String get supportCouldNotLoadDraft =>
      'Det gick inte att läsa in det lokala utkastet.';

  @override
  String get supportCouldNotSaveDraft =>
      'Det gick inte att spara det lokala utkastet.';

  @override
  String get supportLocalTicketDraft => 'Lokalt ärendeutkast';

  @override
  String get category => 'Kategori';

  @override
  String get subject => 'Ämne';

  @override
  String get enterSubject => 'Ange ett ämne';

  @override
  String get tellUsWhatHappened => 'Berätta vad som hände';

  @override
  String get enterMessage => 'Skriv ett meddelande';

  @override
  String get supportCouldNotSaveTicket =>
      'Det gick inte att spara det lokala ärendet. Försök igen.';

  @override
  String get supportSavingDraft => 'Sparar lokalt utkast…';

  @override
  String get supportSaveDraftDemo => 'Spara utkast i demon';

  @override
  String get supportTicketSavedDraftNotCleared =>
      'Ärendet sparades lokalt, men utkastet kunde inte rensas.';

  @override
  String get supportDemo => 'Support (demo)';

  @override
  String get supportDraftLocalTicket => 'Skriv ett lokalt ärende';

  @override
  String get supportLocalPreview => 'Förhandsvisning av lokal support';

  @override
  String get supportLocalDraftsNoService =>
      'Lokala utkast på den här enheten – ingen supporttjänst.';

  @override
  String get supportCouldNotLoadRetry =>
      'Det gick inte att läsa in lokal support – Försök igen';

  @override
  String get supportRecoverPreserve =>
      'Återställ lokal support (behåll oläsbar data)';

  @override
  String get supportYourConversations => 'Dina konversationer';

  @override
  String supportLocalDraftSubject(String subject) {
    return 'Lokalt utkast: $subject';
  }

  @override
  String get supportWriteLocalDraft => 'Skriv ett lokalt utkast';

  @override
  String get supportSaveLocalReply => 'Spara lokalt svar';

  @override
  String get promoWeekdayPeak => 'Rusning på vardagar';

  @override
  String get promoWeekdayPeakDetail => 'Kör 8 resor mellan 07:00 och 09:00.';

  @override
  String get promoWeekdayPeakWindow => 'Mån–fre · den här veckan';

  @override
  String get promoAirportRuns => 'Flygplatsresor';

  @override
  String get promoAirportRunsDetail => 'Två flygplatsresor samma dag.';

  @override
  String get promoUntilSunday => 'Till söndag';

  @override
  String get promoEveningHours => 'Kvällstimmar';

  @override
  String get promoEveningHoursDetail => 'Var online i 3 timmar efter 18:00.';

  @override
  String get promoTonight => 'I kväll';

  @override
  String promoDemoCodeCopied(String code) {
    return 'Demokoden $code har kopierats';
  }

  @override
  String get promoCouldNotCopy =>
      'Det gick inte att kopiera koden. Försök igen.';

  @override
  String get promoPreviewTitle => 'Förhandsvisning av kampanjer';

  @override
  String get preview => 'Förhandsvisning';

  @override
  String get promoSavedTab => 'Sparade';

  @override
  String get promoNothingSaved => 'Inget sparat än';

  @override
  String get promoSave => 'Spara';

  @override
  String get vehicles => 'Fordon';

  @override
  String get addVehicle => 'Lägg till fordon';

  @override
  String get vehCouldNotLoadDrafts =>
      'Det gick inte att läsa in fordonsutkasten – Försök igen';

  @override
  String get vehLocalDraftsNotVerified =>
      'Lokala fordonsutkast – inte aktiverade eller verifierade';

  @override
  String get vehTripsOnly => 'Endast resor';

  @override
  String get vehManageVehicles => 'Hantera fordon';

  @override
  String get vehExploreOpportunities => 'Utforska fordonsalternativ';

  @override
  String get vehConnectFleetPartner =>
      'Anslut till en flottpartner eller se hyr- och köperbjudanden om du behöver ett annat fordon.';

  @override
  String get vehCouldNotSaveDraft =>
      'Det gick inte att spara fordonsutkastet. Försök igen.';

  @override
  String get year => 'År';

  @override
  String get vehRequirements => 'Krav på fordonet';

  @override
  String get vehRequirementsBody =>
      'För att köra med Movera behöver du ett fordon från 1990 eller nyare som inte är skrotat.';

  @override
  String get vehEnterInformation => 'Ange uppgifter om ditt fordon';

  @override
  String get make => 'Märke';

  @override
  String get searchByMake => 'Sök efter märke';

  @override
  String get model => 'Modell';

  @override
  String get searchByModel => 'Sök efter modell';

  @override
  String get selectEllipsis => 'Välj…';

  @override
  String get requiredMark => '* Obligatoriskt';

  @override
  String get vehPhotoCouldNotSave =>
      'Fotot kunde inte sparas lokalt. Försök igen.';

  @override
  String get vehRemoveDraftQ => 'Ta bort fordonsutkastet?';

  @override
  String vehRemovesNameAndPhotos(String name) {
    return 'Det här tar bort $name och dess sparade dokumentfoton från enheten.';
  }

  @override
  String get vehKeepVehicle => 'Behåll fordonet';

  @override
  String get vehRemoveVehicle => 'Ta bort fordonet';

  @override
  String get vehCouldNotRemoveDraft =>
      'Det gick inte att ta bort utkastet. Försök igen.';

  @override
  String get vehPhotosStayOnDevice =>
      'Dokumentfotona stannar på enheten. Ingen uppladdnings- eller verifieringstjänst är ansluten.';

  @override
  String get vehCouldNotLoadDocuments =>
      'Det gick inte att läsa in fordonsdokumenten.';

  @override
  String get vehDraftNoLongerAvailable =>
      'Det här fordonsutkastet finns inte längre.';

  @override
  String get vehRegistrationCertFront => 'Registreringsbevis (första sidan)';

  @override
  String get vehSavedLocallyNotVerified => 'Sparat lokalt – inte verifierat';

  @override
  String get vehRecommendedNextStep => 'Rekommenderat nästa steg';

  @override
  String get vehTakePhotoRegistration =>
      'Ta ett foto av registreringsbeviset (första sidan)';

  @override
  String get vehDocBlueBlackWhite =>
      'Dokumentet ska vara blått, svart och vitt.';

  @override
  String get vehAllFourCorners => 'Alla fyra hörnen syns.';

  @override
  String get vehInsuranceLetter => 'Försäkringsbrev';

  @override
  String get vehTakePhotoInsurance => 'Ta ett foto av försäkringsbrevet';

  @override
  String get vehInsuranceShowsTaxi =>
      'Dokumentet visar bilens registreringsnummer och att den är registrerad som taxi.';

  @override
  String get vehInsuranceDatesVisible =>
      'Försäkringens start- och slutdatum syns.';

  @override
  String get vehSavedPhotoCannotDisplay =>
      'Det sparade fotot kan inte visas. Ta om fotot av dokumentet.';

  @override
  String get vehPhotoTooLarge =>
      'Fotot är för stort för att sparas på enheten. Ta om det närmare och med mindre detaljer.';

  @override
  String get vehCameraNotAvailable =>
      'Kameran är inte tillgänglig i förhandsvisningen.';

  @override
  String get vehBeforeSavingCheck =>
      'Kontrollera följande innan du sparar fotot:';

  @override
  String get takingPhoto => 'Tar foto…';

  @override
  String get takePhoto => 'Ta foto';

  @override
  String get promoSaved => 'Sparad';

  @override
  String get prefStandardEveryday => 'Standard • Vardagsresa';

  @override
  String get prefExtraComfort => 'Extra komfort • Bekvämt';

  @override
  String get prefLuxuryPremium => 'Lyx • Premiumservice';

  @override
  String get prefFasterPickup => 'Snabbare upphämtning • Prioritet';

  @override
  String get prefSixSeat => '6 platser • Rymlig';

  @override
  String get prefLowEmissions => 'Låga utsläpp • Eko';

  @override
  String get prefPetFriendly => 'Husdjursvänlig • Bur OK';

  @override
  String get prefChildSeat => 'Barnstol • Säkert för barn';

  @override
  String prefCategoriesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resekategorier sparade',
      one: '1 resekategori sparad',
    );
    return '$_temp0';
  }

  @override
  String prefActiveOfTotal(int active, int total) {
    return '$active av $total aktiva';
  }

  @override
  String get prefChooseRideOptions => 'Välj dina reseval';

  @override
  String get prefSelectRideTypes => 'Välj vilka resetyper du vill få';

  @override
  String get prefMoveraSetsFromCar =>
      'Movera ställer in dessa utifrån din bil. Stäng av dem du inte vill ha.';

  @override
  String get prefSave => 'Spara inställningar';

  @override
  String get safetyContactEmergencyQ => 'Kontakta räddningstjänsten?';

  @override
  String get safetyUse112Only =>
      'Ring 112 bara när du eller någon annan behöver hjälp direkt.';

  @override
  String get rideCheckSosSentWithPosition => '\nSOS skickat med din position.';

  @override
  String get safetySos => 'SOS';

  @override
  String get safetySosHint => 'Ringer 112 och larmar Movera';

  @override
  String get safetySosQ => 'Skicka SOS?';

  @override
  String get safetySosBody =>
      'Moveras säkerhetsteam larmas med din position, och telefonen öppnar 112.';

  @override
  String get safetySosSend => 'Skicka SOS';

  @override
  String get safetySosSent => 'SOS skickat';

  @override
  String get safetySosSentNoDialer =>
      'SOS skickat. Telefonen kunde inte öppnas: ring 112 på din telefon.';

  @override
  String get safetySosNotSent => 'SOS nådde inte Movera. Ring 112.';

  @override
  String get safetySosNoTrip =>
      'SOS till Movera fungerar under en resa. Ring 112.';

  @override
  String get safetyDialerOpened =>
      'Nödsamtalet är förberett – bekräfta samtalet på din enhet.';

  @override
  String get safetyDialerAskedBrowser =>
      'Webbläsaren ombads ringa 112. Om inget samtal startar, slå 112 på din telefon.';

  @override
  String get safetyAudioUnavailable =>
      'Ljudinspelning är inte tillgänglig i den här demon.';

  @override
  String get safetyTripSharingUnavailable =>
      'Delning av resa är inte tillgänglig i den här demon.';

  @override
  String get safetyPreferences => 'Säkerhetsinställningar';

  @override
  String get safetyRideCheckOnOthersPreview =>
      'Resekontroll är på. De andra är bara förhandsvisning.';

  @override
  String get safetyUnavailableWithoutVerification =>
      'Inte tillgängligt utan kontoverifiering';

  @override
  String get safetyAutoTripSharing => 'Automatisk delning av resa';

  @override
  String get safetyUnavailableWithoutSharing =>
      'Inte tillgängligt utan delningstjänst';

  @override
  String get safetyOnSetByMovera => 'På · inställt av Movera för varje resa';

  @override
  String get safetyOn => 'På';

  @override
  String get safetyRideCheckExplained =>
      'På för varje resa. Frågar ”Är allt okej?” efter ett långt stopp, en avlämning långt från målet, en stor omväg eller en mycket hård inbromsning.';

  @override
  String get safetyTools => 'Säkerhetsverktyg';

  @override
  String get safetyQuickTools =>
      'Snabba verktyg som skyddar dig under varje resa.';

  @override
  String get safetyContact112 => 'Kontakta 112';

  @override
  String get safetyShareTripHint => 'Visa någon var du är';

  @override
  String get safetyShareTrip => 'Dela resan';

  @override
  String get safetyRideCheckOnPreviewOnly =>
      'Resekontroll på · de andra är förhandsvisning';

  @override
  String get destChooseOneAddress => 'Välj en adress';

  @override
  String get destTripsInYourDirection => 'Resor åt ditt håll';

  @override
  String get destMoveraPrioritizes =>
      'Movera prioriterar förfrågningar som tar dig mot den här adressen.';

  @override
  String get destAddAddress => 'Lägg till måladress';

  @override
  String get destSuggestedAddresses => 'Föreslagna adresser';

  @override
  String get destResults => 'Resultat';

  @override
  String get destNoAddressFound => 'Ingen adress hittades';

  @override
  String get destTryAnother =>
      'Prova en annan gata, plats eller ett annat område.';

  @override
  String get destFastestRoute => 'Snabbaste vägen till ditt mål';

  @override
  String destOnlyTripsYourWay(String place) {
    return 'Du får bara resor åt ditt håll, så varje resa tar dig närmare $place.';
  }

  @override
  String destArriveBy(String time) {
    return 'Framme kl. $time';
  }

  @override
  String get destConfirm => 'Bekräfta målet';

  @override
  String get waybillLocalDemo => 'Lokal demo';

  @override
  String get waybillDemoRadar => 'Demoradar';

  @override
  String get demoDriverIdentityUnavailable => 'Demoförare – identitet saknas';

  @override
  String get vehicleDataUnavailable => 'Fordonsuppgifter saknas';

  @override
  String get plateUnavailable => 'Registreringsnummer saknas';

  @override
  String positionOfCount(int position, int count) {
    return '$position av $count';
  }

  @override
  String get rrMatchingTrip => 'Matchar resan';

  @override
  String get rrConfirmingRealTime => 'Bekräftar förfrågan i realtid…';

  @override
  String get rrCouldNotMatch => 'Det gick inte att få resan. Försök igen.';

  @override
  String get rrConnectionInterrupted =>
      'Anslutningen bröts. Du kan försöka igen.';

  @override
  String get rrAssignedOpening => 'Förfrågan är tilldelad dig. Öppnar resan…';

  @override
  String get rrAnotherMatchedFirst => 'En annan förare fick resan först.';

  @override
  String get rrNoLongerOnRadar => 'Resan finns inte längre på radarn.';

  @override
  String rrTripsTowardPickup(String time) {
    return 'Resor mot din upphämtning $time';
  }

  @override
  String get rrLive => 'Live';

  @override
  String rrFreshNew(int count) {
    return '$count nya';
  }

  @override
  String get rrNew => 'Ny';

  @override
  String get rrDestinationRoute => 'Rutt till målet';

  @override
  String rrTripsToward(String place) {
    return 'Resor mot $place';
  }

  @override
  String get rrScanningNearby => 'Söker i närheten';

  @override
  String get rrNewTripsAppear =>
      'Nya resor visas här när radarn hittar förfrågningar runt dig.';

  @override
  String get moveraDriver => 'Movera-förare';

  @override
  String get legalPrivacyBody =>
      'Movera Driver använder plats-, rese- och fordonsdata för att tilldela resor, visa rutter och spara en körjournal på enheten.\n\nDemoversioner sparar informationen i telefonens minne. Inget säljs till annonsörer. Du kan logga ut när som helst från Profil.\n\nNär en riktig server är ansluten används samma text tills en signerad version publiceras.';

  @override
  String get legalTermsBody =>
      'Du godkänner att bara köra med giltigt körkort, försäkring och ett fordon som stämmer med dokumenten i appen.\n\nRadarerbjudanden går till den som är först. Att ta en ny resa under en pågående resa är frivilligt. En avslutad resa skapar en körjournal som du kan öppna igen från start.\n\nMovera kan stänga av ett demokonto som missbrukar säkerhetsverktygen eller nödsamtal.\n\nKrasch- och felrapporter: när appen kraschar eller visar ett fel skickar den automatiskt en rapport till Movera så att vi kan rätta felet: felet, var i appen det hände, appversion, plattform och tid. Namn, telefonnummer, e-postadresser, adresser och platser tas bort innan rapporten lämnar din enhet. Rapporterna sparas i 30 dagar.';

  @override
  String get privacyPolicyTitle => 'Integritetspolicy';

  @override
  String get termsOfService => 'Användarvillkor';

  @override
  String get profSampleDriver => 'Exempelprofil för förare';

  @override
  String get profDemoNoVerified => 'Demo – inget verifierat konto';

  @override
  String get analytics => 'Statistik';

  @override
  String get myBank => 'Min bank';

  @override
  String get helpCenter => 'Hjälpcenter';

  @override
  String get logOut => 'Logga ut';

  @override
  String get logOutQ => 'Logga ut?';

  @override
  String get profLogOutClears =>
      'Förhandsdata på enheten rensas, även resehistorik, kontakter och utkast. Du kommer tillbaka till inloggningen offline.';

  @override
  String get stay => 'Stanna kvar';

  @override
  String get profCouldNotClear =>
      'Det gick inte att rensa lokal data. Du är fortfarande inloggad. Försök igen.';

  @override
  String get anaPreview => 'Förhandsvisning av statistik';

  @override
  String get anaSample3Rides => 'Exempel: 3 resor slutförda';

  @override
  String get anaSampleLastTrip => 'Senaste resan (exempel)';

  @override
  String get anaSamplePerformance => 'Prestation (exempel)';

  @override
  String get anaCancel => 'Avbokning';

  @override
  String get earnings => 'Intäkter';

  @override
  String get anaSamePeriodHome => 'Samma period som på startsidan';

  @override
  String get acceptanceRate => 'Acceptansgrad';

  @override
  String anaSampleAcceptance(String rate) {
    return 'Exempel · $rate av erbjudandena accepterade';
  }

  @override
  String get cancellationRate => 'Avbokningsgrad';

  @override
  String anaSampleCancellation(String rate) {
    return 'Exempel · $rate av accepterade resor';
  }

  @override
  String get anaSampleStrongestArea => 'Starkaste området (exempel)';

  @override
  String get bankAddHolderName => 'Ange kontoinnehavarens namn.';

  @override
  String get bankCheckIban =>
      'Kontrollera IBAN-formatet och kontrollsiffrorna mot ditt kontoutdrag.';

  @override
  String get bankBicFormat => 'BIC/SWIFT har 8 eller 11 bokstäver och siffror.';

  @override
  String get bankCheckClearing =>
      'Kontrollera clearingnumret: 4 siffror, eller 5 som börjar med 8 för Swedbank.';

  @override
  String get bankAccountDigits => 'Kontonumret har 6 till 10 siffror.';

  @override
  String get bankPreviewNotSaved =>
      'Endast förhandsvisning – kontot sparades inte.';

  @override
  String get countrySweden => 'Sverige';

  @override
  String get international => 'Internationellt';

  @override
  String get bankAccount => 'Bankkonto';

  @override
  String get bankHolder => 'Innehavare';

  @override
  String get country => 'Land';

  @override
  String get bank => 'Bank';

  @override
  String get clearing => 'Clearing';

  @override
  String get bankUseIban =>
      'Använd IBAN från ditt kontoutdrag. Utländska IBAN visar en landskod; ingen bankanslutning verifieras.';

  @override
  String get bankFoundFromClearing => 'Banken hittas via clearingnumret.';

  @override
  String get checkDetails => 'Kontrollera uppgifterna';

  @override
  String get bankDemoNotSaved =>
      'Demo: kontot sparas inte och skickas inte till någon bank';

  @override
  String minutesAgo(int minutes) {
    return 'för $minutes min sedan';
  }

  @override
  String hoursAgo(int hours) {
    return 'för $hours h sedan';
  }

  @override
  String get yesterday => 'I går';

  @override
  String daysAgo(int days) {
    return 'för $days dagar sedan';
  }

  @override
  String get noNotificationsYet => 'Inga aviseringar än';

  @override
  String get filterAll => 'Alla';

  @override
  String get filterDemand => 'Efterfrågan';

  @override
  String get logsPreview => 'Förhandsvisning av körlogg';

  @override
  String get logsSampleNotLive => 'Exempeldata för körtid · inte live';

  @override
  String get logsSampleWeek => 'Exempelvecka';

  @override
  String get monday => 'Måndag';

  @override
  String get tuesday => 'Tisdag';

  @override
  String get wednesday => 'Onsdag';

  @override
  String get thursday => 'Torsdag';

  @override
  String logsOnlineFromTo(String from, String to) {
    return 'Online $from–$to';
  }

  @override
  String get logsSampleOnlineState => 'Exempel på onlinestatus';

  @override
  String get logsDemoCompliance =>
      'Endast demotext. Kör- och vilotidsgränser är inte kopplade till kontot eller till regelverksdata.';

  @override
  String get pinVerifyAll => 'Verifiera alla resor';

  @override
  String get pinAskEveryPickup =>
      'Be om resenärens pinkod vid varje upphämtning.';

  @override
  String get pinVerifySession => 'Verifiera den här sessionen';

  @override
  String get pinAskUntilOffline => 'Fråga tills du går offline.';

  @override
  String get pinDontVerify => 'Verifiera inte';

  @override
  String get pinSkipOnDevice => 'Hoppa över pinkoden på den här enheten.';

  @override
  String get pinPreviewNotSaved =>
      'Förhandsvisning av pinverifiering – valet sparas inte och tillämpas inte i demon.';

  @override
  String get pinNotConnected =>
      'Pinverifiering är inte ansluten i den här demon.';

  @override
  String get bankPreviewAccountDetails => 'Förhandsvisa kontouppgifter';

  @override
  String get bankLocalPreviewOnly =>
      'Endast lokal förhandsvisning. Ingen bank är ansluten, inget verifieras och ingen utbetalning är planerad.';

  @override
  String get bankCheckInPreview =>
      'Du kan kontrollera kontouppgifter i förhandsformuläret. Uppgifterna rensas när du lämnar formuläret; inget utbetalningskonto är anslutet.';

  @override
  String get emEmergencyServices112 => 'Räddningstjänst – 112';

  @override
  String get emEmergency => 'Nödsituation';

  @override
  String get emAlreadyInContacts => 'Numret finns redan bland dina kontakter.';

  @override
  String get emFamily => 'Familj';

  @override
  String get callUnavailableUseChat =>
      'Samtal är inte tillgängliga än – använd chatten';

  @override
  String get chatClosedAfterTrip => 'Chatten är stängd efter resan';

  @override
  String get chatLocalDemo =>
      'Lokal demochatt · meddelanden skickas inte till resenären.';

  @override
  String get chatSendMessageHint => 'skicka meddelande…';

  @override
  String get chatSaveLocally => 'Spara meddelandet lokalt';

  @override
  String get chatLocalNotSent => 'Lokal förhandsvisning · inte skickat';

  @override
  String get chatSend => 'Skicka meddelande';

  @override
  String get chatSending => 'Skickar…';

  @override
  String get chatNotSentTapToRetry =>
      'Inte skickat · Tryck för att försöka igen';

  @override
  String get chatSendFailed =>
      'Movera kunde inte skicka ditt meddelande. Försök igen.';

  @override
  String get chatHistoryFailed => 'Tidigare meddelanden kunde inte läsas in.';

  @override
  String chatNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya meddelanden från resenären',
      one: '1 nytt meddelande från resenären',
    );
    return '$_temp0';
  }

  @override
  String get queueAirportPreview => 'Förhandsvisning av flygplatskön';

  @override
  String get queueSample10Ahead => 'Exempel: 10 förare före dig';

  @override
  String get queueViewSampleDetails => 'visa exempeldetaljer';

  @override
  String get queueClose => 'Stäng köplatsen';

  @override
  String get queueMyPosition => 'Min plats i kön';

  @override
  String get queueMediumWait => 'Medellång väntan';

  @override
  String get queueSampleRank => 'Placering (exempel)';

  @override
  String get queueUnavailablePreview =>
      'Kön är inte tillgänglig – förhandsvisning';

  @override
  String get queueRanks => 'Placeringar';

  @override
  String get earnTypeTab => 'Typ';

  @override
  String get earnMoveraDemo => 'Movera-demo';

  @override
  String get cancelRateTitle => 'Avbokningsgrad';

  @override
  String get notYourRealRateYet => 'inte din riktiga grad än';

  @override
  String get tripsConfirmed => 'Bekräftade resor';

  @override
  String get completedTripsLower => 'slutförda resor';

  @override
  String get canceledTrips => 'Avbokade resor';

  @override
  String get sampleNumbersNotReal =>
      'Exempelsiffror för förhandsvisningen, inte din riktiga grad.';

  @override
  String get cancelRateKeepLow =>
      'Håll avbokningsgraden låg för att behålla full tillgång till resor';

  @override
  String get cancelRateEveryCancelCounts =>
      'Varje avbokning räknas, utom skäl som är märkta ”Räknas inte”, till exempel en resenär som inte dyker upp eller ett säkerhetsproblem.';

  @override
  String get moreInformation => 'Mer information';

  @override
  String get cancelRateHowCalculated => 'Så beräknas din avbokningsgrad';

  @override
  String get cancelRateHowBody =>
      'Din avbokningsgrad jämför antalet resor du avbokar med alla resor du bekräftar. Vi använder dina senaste 100 bekräftade förfrågningar för procentsatsen.';

  @override
  String get cancelRateWhyMatters => 'Varför avbokningsgraden spelar roll';

  @override
  String get cancelRateWhyBody =>
      'En hög avbokningsgrad påverkar tjänstens tillförlitlighet och kan minska hur många förfrågningar du får. En låg grad ger bättre service för alla.';

  @override
  String get acceptRateTitle => 'Acceptansgrad';

  @override
  String get exclusiveOffers => 'Exklusiva erbjudanden';

  @override
  String get acceptedOffersLower => 'accepterade erbjudanden';

  @override
  String get declinedOrMissed => 'avböjda eller missade';

  @override
  String get acceptRateOnlyExclusive => 'Bara exklusiva erbjudanden räknas';

  @override
  String get acceptRateExclusiveBody =>
      'Exklusiva erbjudanden och andra erbjudanden som bara skickas till dig räknas. Radarresor räknas aldrig.';

  @override
  String get acceptRateHowCalculated => 'Så beräknas din acceptansgrad';

  @override
  String get acceptRateHowBody =>
      'Din acceptansgrad jämför de exklusiva erbjudanden du accepterar med alla du får. Radarresor räknas aldrig. Vi använder dina senaste 100 exklusiva erbjudanden.';

  @override
  String get acceptRateWhyMatters => 'Varför acceptansgraden spelar roll';

  @override
  String get acceptRateWhyBody =>
      'En låg acceptansgrad minskar chansen att få förfrågningar och kan påverka din ställning på plattformen. En hög grad ger dig fler resor och en pålitlig upplevelse för resenärerna.';

  @override
  String get rcTriggerDroppedFar => 'Avslutad långt från avlämningen';

  @override
  String get rcTriggerLongStop => 'Långt stopp';

  @override
  String get rcTriggerOffRoute => 'Utanför rutten';

  @override
  String get rcTriggerPossibleCrash => 'Möjlig krock';

  @override
  String get rcTopicAccident => 'Olycka eller krock';

  @override
  String get rcTopicHurt => 'Någon är skadad eller mår dåligt';

  @override
  String get rcTopicUnsafe => 'Jag känner mig otrygg';

  @override
  String get rcTopicCarProblem => 'Problem med bilen';

  @override
  String get rcTopicRiderAskedStop => 'Resenären bad om ett stopp';

  @override
  String get rcTopicTraffic => 'Trafik eller vägarbete';

  @override
  String get rcTopicRiderStopHere => 'Resenären bad att få stanna här';

  @override
  String get rcTopicRiderChangedDestination => 'Resenären ändrade mål';

  @override
  String get rcTopicRoadClosed => 'Vägen är avstängd eller saknar tillfart';

  @override
  String get rcTopicRiderOtherRoute => 'Resenären bad om en annan väg';

  @override
  String get rcShortAccident => 'Olycka';

  @override
  String get rcShortHurt => 'Någon skadad';

  @override
  String get rcShortUnsafe => 'Otrygg';

  @override
  String get rcShortRiderStop => 'Resenärsstopp';

  @override
  String get rcShortTraffic => 'Trafik';

  @override
  String get rcShortNewDestination => 'Nytt mål';

  @override
  String get rcShortRoadClosed => 'Avstängd väg';

  @override
  String get rcShortOtherRoute => 'Annan väg';

  @override
  String get rcQuestionAnyoneHurt => 'Är någon skadad?';

  @override
  String get rcQuestionCarSafe => 'Står bilen på en säker plats?';

  @override
  String get rcQuestionOtherPersonOk => 'Mår den andra personen bra?';

  @override
  String get rcQuestionWhoNeedsHelp => 'Vem behöver hjälp?';

  @override
  String get rcQuestionInDanger => 'Är du i fara just nu?';

  @override
  String get rcQuestionCanContinue => 'Kan du fortsätta resan?';

  @override
  String get rcAnswerYes => 'Ja';

  @override
  String get rcAnswerNo => 'Nej';

  @override
  String get rcAnswerNotSure => 'Osäker';

  @override
  String get rcAnswerMe => 'Jag';

  @override
  String get rcAnswerTheRider => 'Resenären';

  @override
  String get rcAnswerSomeoneElse => 'Någon annan';

  @override
  String get rcLongerLead => 'Resan tar ';

  @override
  String rcPercent(int percent) {
    return '$percent %';
  }

  @override
  String get rcLongerTrail => ' längre än väntat';

  @override
  String get rcStoppedLead => 'Bilen har stått still i ';

  @override
  String rcMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get rcEndedLead => 'Resan slutade ';

  @override
  String rcEndedFromTrail(String place) {
    return ' från $place';
  }

  @override
  String get rcOffRouteLead => 'Du är ';

  @override
  String get rcOffRouteTrail => ' från rutten';

  @override
  String rcOffRouteToTrail(String place) {
    return ' från rutten till $place';
  }

  @override
  String get rcCrashLead => 'En ';

  @override
  String get rcCrashBold => 'mycket hård inbromsning';

  @override
  String get rcCrashTrail => ' upptäcktes';

  @override
  String rcCrashTrailAt(String place) {
    return ' upptäcktes · $place';
  }

  @override
  String get tipHighBoostNearby => 'Hög bonus i närheten';

  @override
  String get tipExpectTrip => 'Räkna med en resa om 2–5 min';

  @override
  String tipPromotionRides(String rides, String kr) {
    return 'Kampanj · $rides resor = $kr kr';
  }

  @override
  String get tipBusyArea => 'Livligt område · resor väntas snart';

  @override
  String tipAirportQueue(String count) {
    return 'Flygplatskö: $count förare';
  }

  @override
  String tipGoodStreak(String count) {
    return 'Bra svit · $count resor i rad';
  }

  @override
  String get tipDemandRising => 'Efterfrågan ökar nära dig';

  @override
  String tipPeakStart(String time) {
    return 'Rusningstiden börjar $time';
  }

  @override
  String get tipTopZone => 'Du är i en toppzon just nu';

  @override
  String get noticeNewScheduledRide => 'Ny bokad resa';

  @override
  String noticeScheduledBody(String day, String time, String fare) {
    return '$day $time · $fare · Tryck för att visa';
  }

  @override
  String get view => 'Visa';

  @override
  String noticeSecondsToAccept(int seconds) {
    return '$seconds s att acceptera';
  }

  @override
  String noticeHighDemandIn(String area) {
    return 'Hög efterfrågan i $area';
  }

  @override
  String get noticeGoOnlineNow => 'Gå online nu';

  @override
  String noticeDocExpires(String title, String when) {
    return '$title går ut $when';
  }

  @override
  String get noticeUploadNewKeepDriving =>
      'Ladda upp ett nytt så att du kan fortsätta köra.';

  @override
  String noticeDocApprovedBody(String title) {
    return '$title är godkänt. Du kan gå online.';
  }

  @override
  String get noticeCanGoOnlineAgain => 'Du kan gå online igen.';

  @override
  String noticeTooManyLateCancels(String date) {
    return 'För många sena avbokningar. Tillbaka $date.';
  }

  @override
  String get rcWhatHappened => 'Vad som hände';

  @override
  String get rcCalled112 => 'Ringde 112';

  @override
  String get rcDialer112 => 'Uppringning till 112:';

  @override
  String get rcDialerOpened => 'öppnades';

  @override
  String get rcDialerDidNotOpen => 'öppnades inte';

  @override
  String get selectCountry => 'Välj land';

  @override
  String get searchCountry => 'Sök land';

  @override
  String get colorRed => 'Röd';

  @override
  String get colorBlue => 'Blå';

  @override
  String get colorGreen => 'Grön';

  @override
  String get colorBlack => 'Svart';

  @override
  String get colorWhite => 'Vit';

  @override
  String get colorGray => 'Grå';

  @override
  String get colorSilver => 'Silver';

  @override
  String get colorYellow => 'Gul';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorBrown => 'Brun';

  @override
  String get colorPurple => 'Lila';

  @override
  String get colorPink => 'Rosa';

  @override
  String get chooseVehicleColor => 'Välj fordonets färg';

  @override
  String get closeColorPicker => 'Stäng färgväljaren';

  @override
  String get mapCameraUnavailable =>
      'Kartkameran är inte tillgänglig – tryck på centrera för att försöka igen';

  @override
  String get dismiss => 'Stäng';

  @override
  String ratingAndRides(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resor',
      one: '1 resa',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String mapOfArea(String area) {
    return 'Karta över $area';
  }

  @override
  String get cashYouOweMovera => 'Du är skyldig Movera';

  @override
  String get cashMoveraOwesYou => 'Movera är skyldig dig';

  @override
  String get cashSettled => 'Kvitt';

  @override
  String stopNext(String stop) {
    return 'Härnäst: $stop';
  }

  @override
  String get pickupOnLeftSide => 'Upphämtning på vänster sida';

  @override
  String get pickupOnRightSide => 'Upphämtning på höger sida';

  @override
  String get moveWithin100MOfPickup =>
      'Kom inom 100 m från upphämtningsplatsen för att vara framme.';

  @override
  String get moveWithin100MOfStop =>
      'Kom inom 100 m från stoppet för att vara framme.';

  @override
  String get recordAudioStarting => 'startar…';

  @override
  String get photoTooLargeForDevice =>
      'Fotot är för stort för att sparas på den här enheten.';

  @override
  String get photoStorageFull =>
      'Fotolagringen på den här enheten är full. Ta först bort foton från ett annat fordon.';

  @override
  String get demoDataBadge => 'DEMODATA';

  @override
  String get drivingInHeader => 'KÖR I';

  @override
  String get anaSampleTripRoute => 'Centralstationen → Södermalm';

  @override
  String get demandBusy => 'Hög';

  @override
  String get demandSteady => 'Jämn';

  @override
  String get demandQuiet => 'Lugn';

  @override
  String get aroundStockholm => 'Runt Stockholm';

  @override
  String get noticeBonusProgressTitle => 'Bonusframsteg';

  @override
  String noticeBonusProgressBody(
    String done,
    String goal,
    String left,
    String amount,
  ) {
    return '$done av $goal resor den här veckan. $left till för $amount.';
  }

  @override
  String get noticePayoutSentTitle => 'Utbetalning skickad';

  @override
  String noticePayoutSentBody(String amount) {
    return '$amount är på väg till din bank.';
  }

  @override
  String get signInOr => 'eller';

  @override
  String destResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count träffar',
      one: '1 träff',
    );
    return '$_temp0';
  }

  @override
  String get queueEstimatedWait => 'Cirka 15–30 min väntetid';

  @override
  String get queueDriversAhead => 'Förare före';

  @override
  String get paymentCard => 'Kort';

  @override
  String get offersBadge => 'ERBJUDANDEN';

  @override
  String get bankAccountSection => 'KONTO';

  @override
  String get locationNotAllowed =>
      'Movera ser inte din position, så inga resor kan nå dig.';

  @override
  String get allowLocation => 'Tillåt';

  @override
  String get locationBlockedSettings =>
      'Platsåtkomst är blockerad för Movera. Tillåt den i Inställningar för att få resor.';

  @override
  String get authDriverWord => 'Förare';

  @override
  String get authBrandTagline => 'På väg mot en ny era.';

  @override
  String get authEnterPhone => 'Ange ditt telefonnummer';

  @override
  String get authTextFourDigitCode => 'Vi skickar en fyrsiffrig kod via sms.';

  @override
  String get authInvalidMobileNumber => 'Ange ett giltigt mobilnummer.';

  @override
  String get authConsentLabel =>
      'Jag godkänner villkoren och integritetspolicyn';

  @override
  String get authConsentPrefix => 'Genom att fortsätta godkänner du ';

  @override
  String get authConsentTerms => 'villkoren';

  @override
  String get authAnd => ' och ';

  @override
  String get authConsentPrivacy => 'integritetspolicyn';

  @override
  String get authConsentTickFirst =>
      'Bocka i rutan för att godkänna innan du fortsätter.';

  @override
  String get authContinue => 'Fortsätt';

  @override
  String authStepOf(Object step, Object total) {
    return 'Steg $step av $total';
  }

  @override
  String get authChangeLanguage => 'Byt språk';

  @override
  String get authChooseCountry => 'Välj ditt land';

  @override
  String get authSearchCountry => 'Sök land eller landsnummer';

  @override
  String get authNoCountryFound => 'Inget land matchar din sökning.';

  @override
  String authPhoneCountryCode(Object country, Object dial) {
    return 'Landsnummer: $country, $dial';
  }

  @override
  String get authChangeCountryCode => 'Byt land';

  @override
  String get authEnterYourCodeHead => 'Ange din ';

  @override
  String get authEnterYourCodeAccent => 'kod';

  @override
  String get authCodeSentToPhone => 'Vi har skickat en kod till din telefon.';

  @override
  String get authSentTo => 'Skickad till ';

  @override
  String get authNewCodeSent => 'Ny kod skickad.';

  @override
  String get authReenterPhone =>
      'Gå tillbaka och ange ditt telefonnummer igen.';

  @override
  String get authRequestNewCode => 'Gå tillbaka och begär en ny kod.';

  @override
  String get authNeverAskCode =>
      'Movera ringer eller sms:ar aldrig och ber om den här koden.';

  @override
  String get authVerify => 'Verifiera';

  @override
  String get authResendCodeIn => 'Skicka koden igen om ';

  @override
  String get authResendCode => 'Skicka koden igen';

  @override
  String get authErrOffline =>
      'Ingen anslutning. Kontrollera internet och försök igen.';

  @override
  String get authErrTooManyWait =>
      'För många försök. Vänta en stund och försök igen.';

  @override
  String authErrTooManyIn(Object wait) {
    return 'För många försök. Försök igen om $wait.';
  }

  @override
  String authRetrySeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sekunder',
      one: '1 sekund',
    );
    return '$_temp0';
  }

  @override
  String get authErrServer =>
      'Movera har problem just nu. Försök igen om en stund.';

  @override
  String get authErrWrongCode =>
      'Koden stämmer inte. Kontrollera den och försök igen.';

  @override
  String get authCodeExpired =>
      'Koden har gått ut. Tryck på Skicka koden igen för att få en ny.';

  @override
  String get authErrSendCode => 'Kunde inte skicka koden. Försök igen.';

  @override
  String get authErrCheckCode => 'Kunde inte kontrollera koden. Försök igen.';

  @override
  String get authSignInRestricted =>
      'Det här numret kan inte logga in än. Gå med i väntelistan så hör vi av oss.';

  @override
  String get acctDetailsTitle => 'Dina uppgifter';

  @override
  String get acctDetailsIntro =>
      'Movera kontrollerar dem innan du kan köra. Fyll i dem en gång.';

  @override
  String get acctFirstName => 'Förnamn';

  @override
  String get acctLastName => 'Efternamn';

  @override
  String get acctDateOfBirth => 'Födelsedatum';

  @override
  String get acctPickDate => 'Välj datum';

  @override
  String get acctEmail => 'E-post';

  @override
  String get acctCountry => 'Land';

  @override
  String get acctCity => 'Stad';

  @override
  String get acctChooseCity => 'Välj din stad';

  @override
  String get acctLanguage => 'Språk';

  @override
  String get acctAccountType => 'Kontotyp';

  @override
  String get acctComingSoon => 'Kommer snart';

  @override
  String get acctCountrySweden => 'Sverige';

  @override
  String get acctCountryFrance => 'Frankrike';

  @override
  String get acctCountryTunisia => 'Tunisien';

  @override
  String get acctTypeDriverTitle => 'Förare';

  @override
  String get acctTypeDriverBody => 'Jag kör för ett åkeri';

  @override
  String get acctTypeFleetTitle => 'Åkeri';

  @override
  String get acctTypeFleetBody => 'Jag driver ett företag med bilar och förare';

  @override
  String get acctCompanyName => 'Företagsnamn';

  @override
  String get acctOrgNumberSe => 'Organisationsnummer';

  @override
  String get acctOrgNumberFr => 'SIREN';

  @override
  String get acctCompanyAddress => 'Företagsadress';

  @override
  String get acctJoinNow => 'Gå med i ditt åkeri nu';

  @override
  String get acctJoinNowBody =>
      'Ägaren av ditt åkeri delar en Movera-kod med dig. Du kan också göra det senare i Profil › Mitt åkeri.';

  @override
  String get acctFleetCode => 'Åkerikod';

  @override
  String get acctOwnerName => 'Ägarens fullständiga namn';

  @override
  String get acctOwnerEmail => 'Ägarens e-post';

  @override
  String get acctRequired => 'Obligatoriskt';

  @override
  String acctUnderAge(int age) {
    return 'Du måste vara minst $age år för att köra med Movera.';
  }

  @override
  String get acctInvalidDate => 'Ange ett giltigt datum.';

  @override
  String get acctInvalidEmail => 'Ange en giltig e-postadress.';

  @override
  String get acctCountryNotOpen =>
      'Movera är inte öppet i det här landet ännu.';

  @override
  String get acctInvalidCity => 'Välj en stad i ditt land.';

  @override
  String get acctTermsRequired => 'Godkänn villkoren för att fortsätta.';

  @override
  String get acctCompanyRequired => 'Fyll i företagets uppgifter.';

  @override
  String get acctDetailsLocked =>
      'Dina uppgifter är redan godkända. Kontakta supporten för att ändra dem.';

  @override
  String get acctCouldNotSend =>
      'Kunde inte skicka dina uppgifter. Försök igen.';

  @override
  String get acctTooManyTriesHour =>
      'För många försök. Vänta ungefär en timme och försök igen.';

  @override
  String get acctChangedReload =>
      'Ditt konto ändrades under tiden. Dra för att uppdatera och försök igen.';

  @override
  String get acctCouldNotLoad => 'Kunde inte läsa in ditt konto.';

  @override
  String get acctTryAgain => 'Något gick fel. Försök igen.';

  @override
  String get holdBeingChecked =>
      'Ditt konto kontrolleras. Ladda upp dina dokument så säger vi till när du kan köra.';

  @override
  String get holdWaitingFleetVehicle =>
      'Väntar på ditt åkeris fordonsuppgifter';

  @override
  String get myFleet => 'Mitt åkeri';

  @override
  String get docYou => 'Du';

  @override
  String get docCompany => 'Företag';

  @override
  String docCar(Object plate) {
    return 'Bil $plate';
  }

  @override
  String get docMoveraBooks => 'Movera bokar detta med dig';

  @override
  String get docTakePhoto => 'Ta foto';

  @override
  String get docChoosePhoto => 'Välj foto';

  @override
  String get docChoosePdf => 'Välj PDF';

  @override
  String get docUploading => 'Laddar upp…';

  @override
  String get docUploaded => 'Uppladdat. Movera kontrollerar det.';

  @override
  String get docUploadFailed => 'Kunde inte ladda upp. Försök igen.';

  @override
  String get docFileTooLarge => 'Filen är större än 10 MB.';

  @override
  String get docUnsupportedFile => 'Skicka en JPEG, PNG, HEIC eller PDF.';

  @override
  String get docEmptyFile => 'Filen är tom.';

  @override
  String get docTypeNotAccepted =>
      'Det här dokumentet kan inte laddas upp här.';

  @override
  String get docCouldNotLoad => 'Kunde inte läsa in dina dokument.';

  @override
  String get docNoneYet => 'Inget att ladda upp ännu.';

  @override
  String get docUploadNew => 'Ladda upp nytt';

  @override
  String get fleetJoinTitle => 'Gå med i ditt åkeri';

  @override
  String get fleetJoinBody =>
      'Ägaren av ditt åkeri delar Movera-koden med dig. Ange den tillsammans med ägarens namn och e-post så som de är registrerade hos Movera.';

  @override
  String get fleetJoin => 'Gå med';

  @override
  String fleetJoined(Object name) {
    return 'Du är med i $name.';
  }

  @override
  String get fleetJoinMismatch =>
      'Koden, ägarens namn och e-post matchar inget åkeri. Kontrollera dem med ägaren.';

  @override
  String get fleetAlreadyIn => 'Du är redan med i ett åkeri. Lämna det först.';

  @override
  String get fleetAccountHasOwn => 'Ett åkerikonto har sitt eget åkeri.';

  @override
  String get fleetOnTrip => 'Avsluta resan först.';

  @override
  String get fleetOwnerCannotLeave => 'Ägaren kan inte lämna åkeriet.';

  @override
  String get fleetNotInOne => 'Du är inte med i något åkeri.';

  @override
  String get fleetOwnerOnly => 'Bara åkeriets ägare kan göra det.';

  @override
  String get fleetYourCompany => 'Ditt företag';

  @override
  String get fleetYourFleet => 'Ditt åkeri';

  @override
  String get fleetCode => 'Åkerikod';

  @override
  String get fleetCodeHint =>
      'Dela den med dina förare tillsammans med ditt namn och din e-post.';

  @override
  String get fleetCodeWaiting => 'Väntar på Moveras godkännande';

  @override
  String fleetCodeShareText(
    Object name,
    Object code,
    Object owner,
    Object email,
  ) {
    return 'Gå med i $name på Movera Driver. Kod: $code. Ägare: $owner, $email.';
  }

  @override
  String get fleetShare => 'Dela';

  @override
  String get fleetCopy => 'Kopiera';

  @override
  String get fleetCodeCopied => 'Koden kopierad';

  @override
  String get fleetDrivers => 'Förare';

  @override
  String get fleetNoDrivers => 'Inga förare ännu. Dela din kod.';

  @override
  String get fleetRemove => 'Ta bort';

  @override
  String fleetRemoveDriverQ(Object name) {
    return 'Ta bort $name från ditt åkeri?';
  }

  @override
  String get fleetCars => 'Bilar';

  @override
  String get fleetNoCars => 'Inga bilar ännu.';

  @override
  String get fleetNoCarsMember => 'Ditt åkeri har ingen godkänd bil ännu.';

  @override
  String get fleetAddCar => 'Lägg till bil';

  @override
  String get fleetChooseCar => 'Välj den här bilen';

  @override
  String get fleetYourCar => 'Din bil';

  @override
  String get fleetInUse => 'Används av en annan förare';

  @override
  String fleetPickedBy(Object name) {
    return 'Vald av $name';
  }

  @override
  String get fleetLeave => 'Lämna åkeriet';

  @override
  String fleetLeaveQ(Object name) {
    return 'Lämna $name? Du kan gå med i ett annat åkeri med en ny kod.';
  }

  @override
  String get fleetCouldNotLoad => 'Kunde inte läsa in ditt åkeri.';

  @override
  String get fleetStatusPending => 'Väntar på godkännande';

  @override
  String get fleetStatusBlocked => 'Blockerat';

  @override
  String get fleetVehicleInUse => 'En annan förare kör den här bilen just nu.';

  @override
  String get fleetVehicleNotApproved => 'Den här bilen är inte godkänd ännu.';

  @override
  String get fleetVehicleNotYours => 'Den här bilen tillhör inte ditt åkeri.';

  @override
  String get fleetPlateTaken =>
      'En bil med det här registreringsnumret finns redan.';

  @override
  String get fleetCarAdded => 'Bilen är tillagd. Movera kontrollerar den.';

  @override
  String get fleetCouldNotAddCar => 'Kunde inte lägga till bilen. Försök igen.';

  @override
  String get fleetCouldNotPick => 'Kunde inte välja bilen. Försök igen.';

  @override
  String get fleetColour => 'Färg';

  @override
  String get fleetPlate => 'Registreringsnummer';

  @override
  String get fleetSeats => 'Säten';

  @override
  String get fleetCarTypes => 'Biltyper';

  @override
  String fleetMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förare',
      one: '1 förare',
    );
    return '$_temp0';
  }

  @override
  String fleetCarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilar',
      one: '1 bil',
    );
    return '$_temp0';
  }

  @override
  String fleetOrgNumber(Object number) {
    return 'Org.nr $number';
  }

  @override
  String get fleetOnline => 'Online';

  @override
  String get fleetOffline => 'Offline';

  @override
  String get vehStatusBlocked => 'Blockerad';

  @override
  String get vehDocumentsOnDocs => 'Ladda upp bilens dokument under Dokument.';

  @override
  String fleetCarSeatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count säten',
      one: '1 säte',
    );
    return '$_temp0';
  }

  @override
  String get fleetJoinLink => 'Gå med i ett åkeri';

  @override
  String get docChooseHow => 'Hur vill du lägga till det?';

  @override
  String get fleetVehiclesAwait =>
      'Ditt åkeri lägger till sina bilar; här väljer du den du kör.';

  @override
  String get liveOnlineFailed => 'Kunde inte gå online. Försök igen.';

  @override
  String get liveOfflineFailed =>
      'Movera kunde inte registrera att du gick offline. Försök igen.';

  @override
  String get liveOnlineNotActive =>
      'Ditt konto är inte aktivt än, så du kan inte gå online.';

  @override
  String get liveOnlineNoFleet => 'Gå med i ett åkeri innan du går online.';

  @override
  String get liveOnlineFleetNotApproved =>
      'Ditt åkeri är inte godkänt än, så du kan inte gå online.';

  @override
  String get liveOnlineNoVehicle => 'Välj en godkänd bil innan du går online.';

  @override
  String get liveOnlineVehicleNotApproved =>
      'Din bil är inte godkänd än, så du kan inte gå online.';

  @override
  String get liveOnlineVehicleInUse =>
      'En annan förare har den här bilen nu. Välj din bil igen.';

  @override
  String get liveOnlineNoCategory => 'Ingen resetyp är vald för din bil än.';

  @override
  String get liveOfflineOnTrip => 'Avsluta din resa innan du går offline.';

  @override
  String get liveTripNotAtPickup =>
      'Movera ser dig inte vid upphämtningen än. Kör närmare och försök igen.';

  @override
  String get liveTripNoShowTooEarly =>
      'Det är för tidigt för en utebliven resenär. Vänta lite till.';

  @override
  String get liveTripChanged =>
      'Resan har ändrats under tiden. Kontrollera den och försök igen.';

  @override
  String get liveTripFailed =>
      'Movera kunde inte registrera det här steget. Försök igen.';

  @override
  String get authProviderComingSoon =>
      'Inloggning med Apple och Google kommer snart. Använd ditt telefonnummer.';

  @override
  String get authErrProvider =>
      'Det gick inte att logga in så. Försök igen eller använd ditt telefonnummer.';

  @override
  String get authLinkExpired =>
      'Inloggningen tog för lång tid. Börja om med Apple eller Google, eller använd ditt telefonnummer.';

  @override
  String authContinueWith(String provider) {
    return 'Fortsätt med $provider';
  }

  @override
  String get authOr => 'eller';

  @override
  String authProviderPhoneOnce(String provider) {
    return 'Bekräfta ditt telefonnummer en gång för att slutföra inloggningen med $provider. Vi skickar en fyrsiffrig kod via sms.';
  }

  @override
  String get authUsePhoneInstead => 'Logga in bara med mitt telefonnummer';

  @override
  String get acctDetailsHead => 'Dina ';

  @override
  String get acctDetailsAccent => 'uppgifter';

  @override
  String get acctDetailsEditIntro =>
      'Movera kontrollerar ditt konto. Du kan ändra uppgifterna tills det är godkänt.';

  @override
  String get acctPhone => 'Telefonnummer';

  @override
  String get acctTapToChange => 'Tryck för att ändra';

  @override
  String get acctChooseCountry => 'Välj land';

  @override
  String get acctChooseCountryBody => 'Där du kommer att köra.';

  @override
  String get acctChooseLanguage => 'Välj språk';

  @override
  String get acctChooseLanguageBody => 'Appens språk. Du kan byta senare.';

  @override
  String get acctCityStockholmHint => 'Stockholm, Södertälje och hela länet';

  @override
  String get acctCityParisHint => 'Paris och Île-de-France';

  @override
  String acctFromProvider(String provider) {
    return 'från $provider';
  }

  @override
  String get acctOrgNumberSeRule => 'Ange organisationsnumrets 10 siffror.';

  @override
  String get acctOrgNumberFrRule =>
      'Ange ett SIREN (9 siffror) eller SIRET (14 siffror).';

  @override
  String get acctCompanyAddressHint => 'Gata, postnummer, ort';

  @override
  String get acctOwnerEmailHint => 'namn@företag.se';

  @override
  String get acctJoinNowShort => 'Ägaren delar en Movera-kod med dig.';

  @override
  String get acctLeaveSignUpQ => 'Avbryta registreringen?';

  @override
  String get acctLeaveSignUpBody =>
      'Du loggas ut och kommer tillbaka till första steget. Det du skrivit finns kvar på den här telefonen tills du loggar in igen.';

  @override
  String get acctSaveDetails => 'Spara uppgifter';

  @override
  String get acctDetailsSaved =>
      'Dina uppgifter är sparade. Movera kontrollerar dem.';

  @override
  String get fleetRequestPending =>
      'Du har redan skickat en förfrågan till ett åkeri. Vänta på svaret eller återkalla den.';

  @override
  String get fleetInvitePending => 'Det numret har redan en öppen inbjudan.';

  @override
  String get fleetOwnPhone => 'Det är ditt eget nummer.';

  @override
  String get fleetInvalidPhone =>
      'Ange numret i internationellt format, t.ex. +46 70 123 45 67.';

  @override
  String get fleetNotApprovedYet =>
      'Movera har inte godkänt ditt åkeri än. Du kan bjuda in förare efter det.';

  @override
  String get fleetInvitationExpired => 'Inbjudan har gått ut.';

  @override
  String get fleetInvitationGone => 'Inbjudan är inte längre öppen.';

  @override
  String get fleetADriver => 'En förare';

  @override
  String get fleetRequestBodyOwner => 'Vill gå med i ditt åkeri med din kod.';

  @override
  String get fleetInviteWaitsSignUp =>
      'Inbjuden. Väntar på att numret registrerar sig i Movera Förare.';

  @override
  String get fleetInviteWaitsAnswer => 'Inbjuden. Väntar på förarens svar.';

  @override
  String get fleetInviteBodyDriver =>
      'Bjuder in dig till sitt åkeri. Tacka ja för att köra dess bilar; Movera kontrollerar sedan dina dokument.';

  @override
  String get fleetRequestWaitsOwner =>
      'Din förfrågan är skickad. Åkeriets ägare godkänner den i appen.';

  @override
  String get fleetInviteNew => 'Svara';

  @override
  String fleetInviteExpires(String date) {
    return 'Gäller till $date';
  }

  @override
  String get fleetAccept => 'Tacka ja';

  @override
  String get fleetDecline => 'Tacka nej';

  @override
  String get fleetCancelling => 'Återkallar…';

  @override
  String fleetPendingInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar väntar på ditt svar',
      one: '1 inbjudan väntar på ditt svar',
    );
    return '$_temp0';
  }

  @override
  String get fleetInviteDriver => 'Bjud in förare';

  @override
  String get fleetInviteDriverBody =>
      'Förarens telefonnummer, det han loggar in med. Han tackar ja i sin app; ett nummer utan konto får ett sms med länk till appen.';

  @override
  String get fleetInviteDriverHint => 'Inbjudan gäller i 7 dagar.';

  @override
  String get fleetSendInvite => 'Skicka inbjudan';

  @override
  String get fleetAskToJoin => 'Be om att gå med';

  @override
  String get fleetAskToJoinHint =>
      'Åkeriets ägare godkänner din förfrågan i sin app.';

  @override
  String get fleetCancelInviteQ => 'Återkalla inbjudan?';

  @override
  String fleetDeclineInviteQ(String name) {
    return 'Tacka nej till $name?';
  }

  @override
  String get fleetCancelInvite => 'Återkalla';

  @override
  String fleetDriverJoined(String name) {
    return '$name är nu med i ditt åkeri.';
  }

  @override
  String fleetInviteSent(String who) {
    return 'Inbjudan skickad till $who.';
  }

  @override
  String get fleetRequests => 'Förfrågningar';

  @override
  String fleetInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count väntar',
      one: '1 väntar',
    );
    return '$_temp0';
  }

  @override
  String get fleetInvites => 'Inbjudningar';

  @override
  String get fleetNoInvites =>
      'Ingen öppen inbjudan. Bjud in en förare via telefonnummer eller dela din kod.';

  @override
  String get fleetYourRequest => 'Din förfrågan';

  @override
  String fleetRequestSent(String name) {
    return 'Förfrågan skickad till $name. Ägaren svarar i appen.';
  }

  @override
  String get notifCouldNotLoad => 'Det gick inte att läsa in dina aviseringar.';

  @override
  String get notifNone =>
      'Inga aviseringar än. Inbjudningar från åkerier och svar visas här.';

  @override
  String get profLiveNoNameYet => 'Dina uppgifter är inte skickade än';

  @override
  String get rcTripTotal => 'Resans totalpris';

  @override
  String get rcMoveraCommission => 'Moveras provision';

  @override
  String get rcYouGet => 'Du får';

  @override
  String get ratingTagOnTime => 'I tid';

  @override
  String get ratingTagPolite => 'Artig';

  @override
  String get ratingTagClearPickup => 'Tydlig upphämtning';

  @override
  String get ratingCommentOptional => 'Kommentar (valfri)';

  @override
  String get ratingCouldNotSend => 'Betyget kunde inte skickas.';

  @override
  String get message => 'Meddelande';

  @override
  String get supportTicketMovera => 'Movera support';

  @override
  String get supportSendFailed => 'Kunde inte skicka. Försök igen.';

  @override
  String get supportSendToMovera => 'Skicka till Movera';

  @override
  String get supportSentToMovera => 'Skickat till Movera. Svaret visas här.';

  @override
  String get supportWriteToMovera => 'Skriv till Movera';

  @override
  String get supportNoTicketsYet => 'Inga meddelanden till Movera än.';

  @override
  String get contentUpdateTitle => 'Uppdatera appen';

  @override
  String get contentUpdateBody =>
      'Den här versionen av Movera Driver kan inte längre användas. Uppdatera den för att fortsätta köra.';

  @override
  String get contentUpdateStore => 'Öppna butiken';

  @override
  String get contentUpdateStoreFailed => 'Butiken kunde inte öppnas.';

  @override
  String get contentUpdateRecommended => 'En ny version av appen finns.';

  @override
  String get contentUpdateAfterTrip => 'Uppdatera appen efter resan.';

  @override
  String get contentTermsTitle => 'Nya villkor';

  @override
  String get contentTermsAccept => 'Jag godkänner';

  @override
  String get contentTermsFailed =>
      'Inte sparat. Kontrollera anslutningen och försök igen.';

  @override
  String get contentTermsBlockOnline =>
      'Godkänn de nya villkoren för att gå online.';

  @override
  String get mapYourCar => 'Din bil';

  @override
  String get noticeDemoEventTitle => 'Kvällsefterfrågan i Stockholm';

  @override
  String get noticeDemoEventBody =>
      '18:00–22:30 · Centrala Stockholm. Var online före den stora avresetiden.';

  @override
  String get noticeDemoEventIsland => 'Evenemang i kväll · City';

  @override
  String get categoryComfort => 'Komfort';

  @override
  String get categoryPriority => 'Prioritet';

  @override
  String get categoryElectric => 'Elbil';

  @override
  String get categoryBoosterSeat => 'Bältesstol';

  @override
  String get demoPickupNearYou => 'Upphämtning nära dig';

  @override
  String demoNearPlace(String place) {
    return 'Nära $place';
  }

  @override
  String get demoYourDestination => 'din destination';

  @override
  String demoOnYourWayPercent(int percent) {
    return 'På vägen · $percent %';
  }

  @override
  String get demoAwayFromRoute => 'Utanför din rutt';

  @override
  String get demoBehindYou => 'Bakom dig';

  @override
  String get vehDocsMissingCantDrive => 'Kan inte köras – ladda upp dokument';

  @override
  String docsNotApprovedCar(String names) {
    return 'Den här bilen kan inte köras förrän dess dokument är godkända. Saknas: $names';
  }

  @override
  String docsNotApprovedAccount(String names) {
    return 'Ditt konto kan inte användas förrän de här dokumenten är godkända: $names';
  }

  @override
  String get authStartingServer => 'Servern startar…';

  @override
  String authErrTooManyWrongCodes(String button) {
    return 'För många fel försök – tryck på $button';
  }

  @override
  String authRetryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuter',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String get authJoinWaitlist => 'Gå med i väntelistan';

  @override
  String get authWaitlistSaved =>
      'Du står på väntelistan. Vi hör av oss när inloggningen öppnar för ditt nummer.';

  @override
  String get authTestNumbersTitle => 'Testnummer (endast testversion)';

  @override
  String get authTestStatusNew => 'Test · inget konto än';

  @override
  String get gateSignOut => 'Logga ut';

  @override
  String get gateTryAgain => 'Försök igen';

  @override
  String get authNeedHelp => 'Behöver du hjälp?';

  @override
  String get authHelpComingSoon => 'Kontaktuppgifter kommer snart';

  @override
  String get authHelpEmail => 'E-post';

  @override
  String get authHelpPhone => 'Telefon';

  @override
  String get authHelpCompany => 'Företag';

  @override
  String get authHelpClose => 'Stäng';

  @override
  String remTitle(Object count) {
    return 'Viktiga påminnelser ($count)';
  }

  @override
  String get remShow => 'Visa påminnelser';

  @override
  String get remHide => 'Dölj påminnelser';

  @override
  String get remBlocksOnlineLegend =>
      'Rött: du kan inte gå online förrän det är fixat';

  @override
  String remDocOfCar(Object document, Object car) {
    return '$document · $car';
  }

  @override
  String remDocumentNeeded(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'other': '$document saknas',
    });
    return '$_temp0';
  }

  @override
  String remDocumentRejected(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'other': '$document godkändes inte',
    });
    return '$_temp0';
  }

  @override
  String remDocumentExpired(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'other': '$document har gått ut',
    });
    return '$_temp0';
  }

  @override
  String remDocumentExpiring(Object document, Object when, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'other': '$document går ut $when',
    });
    return '$_temp0';
  }

  @override
  String remDocumentInReview(Object document) {
    return '$document: Movera granskar det';
  }

  @override
  String get remCantGoOnlineUntil =>
      'Du kan inte gå online förrän Movera godkänt det nya.';

  @override
  String get remAccountNotActive => 'Movera granskar ditt konto';

  @override
  String get remAccountNotActiveDetail =>
      'Allt är skickat. Du kan gå online när Movera aktiverat ditt konto.';

  @override
  String get remFleetNotApproved => 'Movera har inte godkänt ditt åkeri än';

  @override
  String get remFleetNoApprovedCar => 'Ditt åkeri har ingen godkänd bil än';

  @override
  String get remFleetNoApprovedCarOwner =>
      'Lägg till en bil eller slutför dess dokument under Mitt åkeri. Förarna kan gå online när en bil är godkänd.';

  @override
  String get remFleetNoApprovedCarMember =>
      'Du kan gå online när åkeriägaren har en godkänd bil som du kan välja.';

  @override
  String get remNoVehicle => 'Välj en bil från ditt åkeri innan du går online';

  @override
  String get remUpload => 'Ladda upp';

  @override
  String get remUploadNew => 'Ladda upp nytt';

  @override
  String get remOpen => 'Öppna';

  @override
  String remCantGoOnline(Object reason) {
    return 'Du kan inte gå online än: $reason';
  }

  @override
  String liveOnlineDocumentsExpired(Object documents) {
    return 'Ett dokument har gått ut: $documents. Ladda upp det nya för att gå online.';
  }

  @override
  String get infoHowToBook => 'Så bokar du ditt informationsmöte';

  @override
  String get infoHowToBookShort => 'Så bokar du';

  @override
  String get infoNoContent =>
      'Movera kontaktar dig för att boka en tid. Du behöver inte göra något mer nu.';

  @override
  String get infoHeld =>
      'Movera har markerat ditt informationsmöte som genomfört.';

  @override
  String get infoOpenLink => 'Öppna bokningssidan';

  @override
  String get infoRequiredBeforeOnline =>
      'Informationsmötet krävs innan du kan gå online.';

  @override
  String get guideExampleLabel => 'Exempel ritat av Movera';

  @override
  String get guideMustBeVisible => 'Se till att detta syns';

  @override
  String get guideTipsTitle => 'Tips för ett bra foto';

  @override
  String get guideUpload => 'Ladda upp';

  @override
  String get guidePickTakePhoto => 'Ta foto';

  @override
  String get guidePickLibrary => 'Bildbibliotek';

  @override
  String get guidePickFile => 'Välj fil';

  @override
  String get guideCameraBlockedTitle => 'Movera kan inte använda kameran';

  @override
  String get guideCameraBlockedBody =>
      'Kameraåtkomst är avstängd för Movera. Slå på den i Inställningar, eller välj en fil du redan har.';

  @override
  String get guideOpenSettings => 'Öppna Inställningar';

  @override
  String get guideUploadingSlow => 'Laddar upp… det kan ta upp till en minut.';

  @override
  String get guideKeptPhoto =>
      'Uppladdningen blev inte klar. Ditt foto finns kvar, så du kan försöka igen.';

  @override
  String get guideTryAgain => 'Försök igen';

  @override
  String get guideChooseAnother => 'Välj en annan';

  @override
  String guideExpiryNote(Object days) {
    return 'Dokumentet har ett slutdatum. Movera fyller i det vid godkännandet och påminner dig $days dagar innan.';
  }

  @override
  String guideCurrentStatus(Object status) {
    return 'Nu: $status';
  }

  @override
  String guideExpiresOn(Object date) {
    return 'Går ut $date';
  }

  @override
  String guideSelectedFile(Object name) {
    return 'Vald: $name';
  }

  @override
  String get guideLicenceBothSides => 'Körkortets fram- och baksida';

  @override
  String get guideNameAndPhoto => 'Ditt namn och foto';

  @override
  String get guideValidUntil => 'Giltig till-datumet';

  @override
  String get guideLicenceCategoryB => 'Behörighet B';

  @override
  String get guideLicenceCategoryB3Years => 'Behörighet B, i minst 3 år';

  @override
  String get guideIdWholeCard => 'Hela kortet eller passets fotosida';

  @override
  String get guidePhotoFaceFront => 'Ditt ansikte rakt framifrån, ögonen öppna';

  @override
  String get guidePhotoPlainBackground => 'En enkel, ljus bakgrund';

  @override
  String get guidePhotoNoSunglasses =>
      'Inga solglasögon, keps eller andra personer';

  @override
  String get guideCardBothSides => 'Kortets fram- och baksida';

  @override
  String get guideCardNumber => 'Kortnumret';

  @override
  String get guideSeRegistrationBolagsverket =>
      'Registreringsbeviset från Bolagsverket';

  @override
  String get guideKbisRecent =>
      'Kbis eller SIRENE-intyg, högst 3 månader gammalt';

  @override
  String get guideCompanyNameAndNumber => 'Företagets namn och nummer';

  @override
  String get guideAllPages => 'Alla sidor';

  @override
  String get guideSeTrafficPermit =>
      'Taxitrafiktillståndet från Transportstyrelsen';

  @override
  String get guideSeFTax => 'F-skattsedeln från Skatteverket';

  @override
  String get guideFrRib => 'Företagets RIB med IBAN och BIC';

  @override
  String get guideSeBankAccount => 'Kontobeviset med clearing- och kontonummer';

  @override
  String get guideAccountHolderName => 'Kontoinnehavarens namn';

  @override
  String get guideFrVtcRegister => 'Intyget från VTC-registret';

  @override
  String get guideFrRcPro => 'RC Pro-intyget för persontransport';

  @override
  String get guideFrUrssafRecent => 'URSSAF-intyget, högst 6 månader gammalt';

  @override
  String get guideFrCarteGrise => 'Carte grise, framsidan';

  @override
  String get guideSeRegistrationFront => 'Registreringsbeviset, del 1';

  @override
  String get guidePlateVisible => 'Registreringsnumret';

  @override
  String get guideOwnerName => 'Ägarens namn';

  @override
  String get guideFrPassengerInsurance =>
      'Försäkringsintyget för persontransport';

  @override
  String get guideSeInsuranceLetter => 'Försäkringsbrevet för taxitrafik';

  @override
  String get guideFrStickerOnCar => 'VTC-dekalen på vindrutan';

  @override
  String get guideCarFront => 'Hela bilens framsida';

  @override
  String get guideCarBack => 'Hela bilens baksida';

  @override
  String get guideCarSide => 'Hela bilens sida, med hjulen';

  @override
  String get guideCarInside => 'Sätena från bakdörren, rena';

  @override
  String get guidePlateReadable => 'Registreringsskylten går att läsa';

  @override
  String get guideWholeDocument => 'Hela dokumentet, alla hörn';

  @override
  String get guideNameAndPhotoIfAny => 'Ditt namn (och foto, om det finns)';

  @override
  String get tipFlatDarkSurface => 'Lägg det plant på ett mörkt bord';

  @override
  String get tipNoGlare => 'Ingen blixt och inga reflexer';

  @override
  String get tipFourCorners => 'Alla fyra hörn med på bilden';

  @override
  String get tipPhotoHoldStill => 'Håll still så att texten blir skarp';

  @override
  String get tipPhotoDaylight => 'Bra dagsljus, inget motljus';

  @override
  String get tipPhotoNoFilter => 'Inga filter eller redigeringar';

  @override
  String get tipCarWholeInFrame =>
      'Ta ett steg bakåt så att hela bilen kommer med';

  @override
  String get docOpenGuide => 'Öppna guiden och ladda upp';

  @override
  String docExpiresOnNote(Object date) {
    return 'Går ut $date';
  }

  @override
  String get startCompanyTitle => 'Starta eget företag';

  @override
  String get startCompanyIntro =>
      'Ditt konto blir ett företagskonto (åkeri). Dokumenten du redan har finns kvar – du lägger bara till företagets och bilarnas dokument. Sedan godkänner Movera det som ett nytt åkeri.';

  @override
  String startCompanyLeavesFleet(Object fleet) {
    return 'Du lämnar $fleet och går offline. Du kan inte gå online förrän Movera godkänt ditt företag.';
  }

  @override
  String get startCompanyConfirmQ =>
      'Göra ditt konto till ett företagskonto? Movera granskar det innan du kan köra igen.';

  @override
  String get startCompanySend => 'Skicka till Movera';

  @override
  String get startCompanySent => 'Skickat. Ditt företag väntar på Movera.';

  @override
  String get startCompanyFailed => 'Kunde inte starta företaget. Försök igen.';

  @override
  String get startCompanyAlreadyFleet =>
      'Ditt konto är redan ett företagskonto.';

  @override
  String get carFuel => 'Drivmedel';

  @override
  String get fuelPetrol => 'Bensin';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelElectric => 'El';

  @override
  String carTypesFitHint(Object country) {
    return 'Bara biltyperna som bilen passar för visas (Moveras regler för $country).';
  }

  @override
  String get carTypesEnterFirst =>
      'Fyll i årsmodell, platser och drivmedel för att se biltyperna.';

  @override
  String get carNoTypeFits =>
      'Bilen passar ingen biltyp. Kontrollera årsmodell, platser och drivmedel.';

  @override
  String get carRulesCouldNotLoad => 'Kunde inte hämta Moveras bilregler.';

  @override
  String get carCategoryNotAllowed =>
      'Bilen passar inte en av de valda biltyperna.';

  @override
  String get carPhotosTitle => 'Foton av bilen';

  @override
  String carPhotosIntro(Object car) {
    return 'Movera behöver de här 4 fotona av $car innan bilen kan köras.';
  }

  @override
  String get carPhotosDone => 'Klar';

  @override
  String get vehNotApprovedCantDrive =>
      'Kan inte köras – Movera har inte godkänt bilen än';

  @override
  String get vehDocsMissingOwnerUploads =>
      'Kan inte köras – åkeriägaren behöver slutföra bilens dokument';

  @override
  String get swTripStatusDraft => 'Utkast';

  @override
  String get swTripStatusQuoted => 'Offererad';

  @override
  String get swTripStatusRequested => 'Begärd';

  @override
  String get swTripStatusSearching => 'Söker';

  @override
  String get swTripStatusOffered => 'Erbjuden';

  @override
  String get swTripStatusAccepted => 'Accepterad';

  @override
  String get swTripStatusDriverToPickup => 'Förare till upphämtning';

  @override
  String get swTripStatusArrived => 'Framme';

  @override
  String get swTripStatusRiderOnboard => 'Resenären ombord';

  @override
  String get swTripStatusInTrip => 'På resa';

  @override
  String get swTripStatusApproachingDropoff => 'Närmar sig avlämning';

  @override
  String get swTripStatusCompleted => 'Slutförd';

  @override
  String get swTripStatusCancelledByRider => 'Avbokad av resenär';

  @override
  String get swTripStatusCancelledByDriver => 'Avbokad av förare';

  @override
  String get swTripStatusCancelledByAdmin => 'Avbokad av admin';

  @override
  String get swTripStatusCancelledBySystem => 'Avbokad av systemet';

  @override
  String get swTripStatusNoShow => 'Utebliven';

  @override
  String get swTripStatusExpired => 'Utgången';

  @override
  String get swTripStatusFailed => 'Misslyckad';

  @override
  String get swDriverAccountStatusPending => 'Väntande';

  @override
  String get swDriverAccountStatusActive => 'Aktiv';

  @override
  String get swDriverAccountStatusOnHold => 'Väntar på granskning';

  @override
  String get swDriverAccountStatusSuspended => 'Avstängd';

  @override
  String get swDriverOnlineStatusOffline => 'Offline';

  @override
  String get swDriverOnlineStatusGoingOnline => 'Går online';

  @override
  String get swDriverOnlineStatusOnline => 'Online';

  @override
  String get swDriverOnlineStatusOnTrip => 'På resa';

  @override
  String get swDriverOnlineStatusSuspended => 'Avstängd';

  @override
  String get swPaymentStatusPending => 'Väntande';

  @override
  String get swPaymentStatusAuthorized => 'Auktoriserad';

  @override
  String get swPaymentStatusCaptured => 'Debiterad';

  @override
  String get swPaymentStatusFailed => 'Misslyckad';

  @override
  String get swPaymentStatusRefunded => 'Återbetald';

  @override
  String get swPaymentStatusPartiallyRefunded => 'Delvis återbetald';

  @override
  String get swFeeStatusPaid => 'Betald';

  @override
  String get swFeeStatusOwed => 'Obetald';

  @override
  String get swFeeStatusWaived => 'Efterskänkt';

  @override
  String get swPayoutStatusPending => 'Väntande';

  @override
  String get swPayoutStatusPaid => 'Utbetald';

  @override
  String get swDocumentStatusNeeded => 'Krävs';

  @override
  String get swDocumentStatusInReview => 'Granskas';

  @override
  String get swDocumentStatusApproved => 'Godkänt';

  @override
  String get swDocumentStatusRejected => 'Avslaget';

  @override
  String get swDocumentStatusExpired => 'Utgånget';

  @override
  String get swDocumentStatusExpiring => 'Går ut snart';

  @override
  String get swDocumentStatusMissing => 'Saknas';

  @override
  String get swDocumentStatusWaitingForMovera => 'Väntar på Movera';

  @override
  String get swTicketStatusOpen => 'Öppet';

  @override
  String get swTicketStatusPending => 'Väntande';

  @override
  String get swTicketStatusResolved => 'Löst';

  @override
  String get swTicketStatusClosed => 'Stängt';

  @override
  String get swVehicleReviewStatusInReview => 'Granskas';

  @override
  String get swVehicleReviewStatusApproved => 'Godkänt';

  @override
  String get swVehicleReviewStatusRejected => 'Avslaget';

  @override
  String get swOfferStatusOpen => 'Öppet';

  @override
  String get swOfferStatusClaimed => 'Taget';

  @override
  String get swOfferStatusClaimedElsewhere => 'Taget av annan förare';

  @override
  String get swOfferStatusDeclined => 'Avböjt';

  @override
  String get swOfferStatusExpired => 'Utgånget';

  @override
  String get swOfferStatusWithdrawn => 'Tillbakadraget';

  @override
  String get swRatingStatusNotRequested => 'Inte begärt';

  @override
  String get swRatingStatusPending => 'Väntande';

  @override
  String get swRatingStatusSubmitted => 'Lämnat';

  @override
  String get swRatingStatusSkipped => 'Överhoppat';

  @override
  String get docFleetOwnerOnly =>
      'Bara åkeriägaren kan ladda upp eller öppna bilens dokument.';

  @override
  String get remNoFleet =>
      'Gå med i ett åkeri för att köra – be din åkare om Movera-koden, hans namn och e-post';

  @override
  String get remActionJoinFleet => 'Gå med i ett åkeri';

  @override
  String get remActionStartCompany => 'Starta mitt eget företag';

  @override
  String get remNoVehicleNotActive => 'Välj en bil från ditt åkeri';

  @override
  String get fleetNoApprovedCarOwnerHere =>
      'Lägg till en bil nedan eller slutför dess dokument. Förarna kan gå online när en bil är godkänd.';

  @override
  String get holdAccountChecking =>
      'Ditt konto kontrolleras. Vi säger till när du kan köra.';

  @override
  String get carExtraNeedsRide =>
      'Bältesstol är ett tillval: välj också en biltyp.';

  @override
  String get carRulesNotMet => 'Bilen uppfyller inte Moveras regler:';

  @override
  String carProblemLine(Object category, Object problem) {
    return '$category: $problem';
  }

  @override
  String get carWholeCar => 'Bilen';

  @override
  String get carProblemYearTooOld => 'bilen är för gammal för Movera';

  @override
  String carProblemYearTooOldBase(int year) {
    return 'bilen måste vara årsmodell $year eller nyare';
  }

  @override
  String get carProblemCategoryOff => 'erbjuds inte i det här landet';

  @override
  String get carProblemTooFewSeats => 'för få platser';

  @override
  String get carProblemFuelNotAllowed => 'drivmedlet är inte tillåtet';

  @override
  String get carProblemFuelRequired => 'välj drivmedel';

  @override
  String get carProblemExtraNeedsRide => 'bara tillsammans med en biltyp';

  @override
  String get carProblemOther => 'passar inte';

  @override
  String get pushAskTitle => 'Få aviseringar när appen är stängd?';

  @override
  String get pushAskBody =>
      'Movera meddelar dig när ett dokument snart går ut, när Movera har granskat dina dokument eller din bil, om flottinbjudningar och meddelanden från resenärer. Du kan stänga av det när som helst i webbläsarens eller telefonens inställningar.';

  @override
  String get pushAskAllow => 'Slå på';

  @override
  String get pushAskLater => 'Inte nu';

  @override
  String get backgroundLocationTitle => 'Movera är online';

  @override
  String get backgroundLocationBody =>
      'Din position skickas för att du ska få resor';

  @override
  String get locationRequired => 'Slå på platstjänster för att gå online';

  @override
  String get locationOpenSettings => 'Öppna inställningar';

  @override
  String get batterySaverWarning =>
      'Batterisparläget är på. Movera kan sluta skicka din position – stäng av det för att få resor.';

  @override
  String get setOfflineLine =>
      'Du har satts offline – tryck för att gå online igen';

  @override
  String get outsideAreaTitle => 'Du får inte köra i det här området';

  @override
  String outsideAreaBody(String zones) {
    return 'Du får inga resor här. Kör tillbaka till $zones för att få resor.';
  }

  @override
  String get outsideAreaOk => 'OK';

  @override
  String get anaYourPerformance => 'Ditt resultat · senaste 30 dagarna';

  @override
  String anaAcceptanceDetail(String rate) {
    return '$rate av erbjudandena accepterade';
  }

  @override
  String anaCancellationDetail(String rate) {
    return '$rate av accepterade resor';
  }

  @override
  String get destRecentAddresses => 'Dina senaste destinationer';

  @override
  String get destSearchUnavailable => 'Adressökningen fungerar inte just nu';

  @override
  String get destSearchTryAgain => 'Kontrollera anslutningen och försök igen.';

  @override
  String get destSearchStart => 'Sök efter en adress';

  @override
  String get destSearchStartBody =>
      'Skriv en gata, en plats eller en stad. Dina 5 senaste destinationer visas här.';

  @override
  String get anaNotEnoughData => 'Inte tillräckligt med underlag än';

  @override
  String get authSignedOutExpired => 'Du loggades ut – logga in igen';

  @override
  String get authSignedOutRevoked => 'Du loggades ut – logga in igen';

  @override
  String get authSignedOutDetailExpired =>
      'Du har inte använt appen på 30 dagar.';

  @override
  String get authSignedOutDetailRevoked => 'Movera avslutade din session.';

  @override
  String get docInvalidFileContent => 'Filen är inte ett foto eller en PDF';

  @override
  String get docExpiryTooFar => 'Kontrollera slutdatumet';

  @override
  String remFleetInvitation(String fleet) {
    return '$fleet bjöd in dig';
  }

  @override
  String get remActionAcceptInvitation => 'Acceptera';

  @override
  String get remActionDeclineInvitation => 'Avböj';

  @override
  String get safetyCall112 => 'Ring 112';

  @override
  String authPhoneFieldLabel(String dial) {
    return 'Mobilnummer ($dial)';
  }

  @override
  String get authCodeFieldLabel => 'Fyrsiffrig kod från sms:et';

  @override
  String get legalCouldNotLoad =>
      'Kunde inte läsa in texten. Kontrollera anslutningen och försök igen.';

  @override
  String get docRenewalWaiting => 'Nytt dokument väntar på granskning';

  @override
  String get docRenewalRejected => 'Nytt dokument avvisat';

  @override
  String get remRenewalInReview => 'Ditt nya granskas';

  @override
  String get remRenewalRejected => 'Ditt nya avvisades';

  @override
  String get carTypesByMovera =>
      'Movera väljer resetyperna när bilen godkänns.';

  @override
  String get offerAccepting => 'Accepterar…';

  @override
  String get offerNoLongerAvailable =>
      'Erbjudandet är inte längre tillgängligt';

  @override
  String get riderRatingLabel => 'Kundens betyg';

  @override
  String get soundOffNotice => 'Ljudet är av – du kan missa erbjudanden';

  @override
  String get soundOffTapToAllow => 'Tryck för att tillåta ljud';

  @override
  String riderRidesOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resor',
      one: '1 resa',
    );
    return '$_temp0';
  }

  @override
  String get eventRunning => 'Pågår nu';

  @override
  String eventStarts(String time) {
    return 'Börjar $time';
  }

  @override
  String get eventPickupNote => 'Upphämtning';

  @override
  String get offlineCardTitle => 'Du är offline';

  @override
  String offlineReasonNoPosition(int minutes) {
    return 'Telefonen skickade ingen position på $minutes min';
  }

  @override
  String get offlineReasonAppRestart =>
      'Appen startades om medan du var online';

  @override
  String offlineReasonMissedOffers(int count) {
    return 'Du missade eller nekade $count erbjudanden i rad';
  }

  @override
  String get offlineReasonMovera => 'Movera satte dig offline';

  @override
  String get offlineCheckPhone => 'Kontrollera min telefon';

  @override
  String get offlineChecking => 'Kontrollerar…';

  @override
  String get offlineCheckLocation => 'Plats på och tillåten';

  @override
  String get offlineCheckInternet => 'Internet och Moveras server';

  @override
  String get offlineCheckBattery => 'Batterisparläge av';

  @override
  String get offlineCheckNotifications => 'Aviseringar tillåtna';

  @override
  String get offlineCheckUnknown => 'Kan inte kontrolleras här';

  @override
  String get offlineCheckBrowser =>
      'Tillåt det i webbläsarens webbplatsinställningar';

  @override
  String get offlineFixTurnOn => 'Slå på';

  @override
  String get offlineGoOnline => 'Gå online';

  @override
  String get offlineReasonVehicleBlocked => 'Din bil kan inte användas just nu';

  @override
  String get offlineReasonFleetRemoved => 'Du är inte längre med i ett åkeri';

  @override
  String get offlineReasonAccountStatus =>
      'Ditt konto är pausat – kontakta Movera';

  @override
  String get tripSettings => 'Reseinställningar';

  @override
  String get navigationApp => 'Navigationsapp';

  @override
  String get navigationAppHint => 'Öppnas från kartknappen under en resa';

  @override
  String get navigateWithWaze => 'Navigera med Waze';

  @override
  String get wazeIsUnavailable => 'Waze är inte tillgängligt.';

  @override
  String noShowConfirmYouGet(Object amount) {
    return 'Markera som utebliven kund? Du får $amount';
  }

  @override
  String get noShowConfirmNoFee => 'Markera som utebliven kund? Ingen avgift';

  @override
  String feeKindNoShow(Object amount) {
    return 'Avgift för utebliven kund $amount';
  }

  @override
  String feeKindCancel(Object amount) {
    return 'Avbokningsavgift $amount';
  }

  @override
  String etaArrivesIn(Object min, Object distance) {
    return 'Anländer om $min min · $distance';
  }

  @override
  String etaToDropoff(Object min, Object distance) {
    return 'Framme om $min min · $distance';
  }

  @override
  String distanceKm(Object value) {
    return '$value km';
  }

  @override
  String distanceM(Object value) {
    return '$value m';
  }

  @override
  String get pickupMovedIsland => 'Upphämtningen flyttades';

  @override
  String waitingChargedSoFar(Object amount) {
    return 'Väntetid debiterad hittills: $amount';
  }

  @override
  String get cancelAfterArrivedNote =>
      'Avbokning efter att föraren anlänt och den fria väntetiden gått ut räknas som utebliven kund';

  @override
  String get navigationAppSaveFailed =>
      'Navigationsapp inte sparad. Försök igen.';

  @override
  String etaLastKnown(Object eta) {
    return 'Senast kända: $eta';
  }

  @override
  String get feeKindNoShowShort => 'Avgift för utebliven kund';

  @override
  String get feeKindCancelShort => 'Avbokningsavgift';

  @override
  String noShowFromTime(Object time) {
    return 'Kan användas från $time om resenären inte har kommit.';
  }

  @override
  String g6RuleFarPickup(Object km) {
    return 'Upphämtning över $km km bort';
  }

  @override
  String get g6RuleAirport => 'Hämtning på flygplats';

  @override
  String get g6RuleScheduled => 'Bokad resa';

  @override
  String get g6RuleEvent => 'Hämtning vid evenemang';

  @override
  String get g6PinAsk => 'Fråga resenären efter den fyrsiffriga koden';

  @override
  String g6PinWrong(Object left) {
    return 'Fel kod. $left försök kvar';
  }

  @override
  String g6PinLocked(Object min) {
    return 'För många försök. Försök igen om $min min';
  }

  @override
  String get g6PinTitle => 'Resenärens kod';

  @override
  String get g6PinConfirm => 'Bekräfta och starta';

  @override
  String get g6PinFourDigits => 'Skriv fyra siffror';

  @override
  String get g6PinNeeded => 'Den här resan behöver resenärens kod innan start';

  @override
  String get g6AlertPaid => 'Betald väntetid har börjat';

  @override
  String get g6AlertNoShow => 'Du kan nu markera utebliven kund';

  @override
  String g6StopFreeWait(Object min) {
    return 'Gratis väntan vid stopp: $min min';
  }

  @override
  String get g6PinBlocked => 'För många fel koder. Ring Movera support';

  @override
  String get g6PinNotNow =>
      'Koden kan skrivas när du är framme vid upphämtningen';

  @override
  String get g7RouteAsk => 'Resenären vill ändra resan';

  @override
  String g7RouteEarnings(String earnings, String difference) {
    return 'Ny intjäning $earnings ($difference)';
  }

  @override
  String get g7RouteAccept => 'Godkänn';

  @override
  String get g7RouteRefuse => 'Neka';

  @override
  String get g7RouteChanged => 'Resenären har ändrat resan.';

  @override
  String g7StopPrice(String perMin) {
    return 'Väntan vid stopp: $perMin/min';
  }

  @override
  String g7StopFree(int min, String perMin) {
    return '$min min gratis vid varje stopp, sedan $perMin/min';
  }

  @override
  String g7MaxStops(int max) {
    return 'Du kan lägga till högst $max stopp.';
  }

  @override
  String g7RouteSecondsLeft(int seconds) {
    return '$seconds s kvar att svara';
  }

  @override
  String get g7RouteNewDestination => 'Ny destination';

  @override
  String g7RouteStops(int count, int max) {
    return 'Stopp: $count (högst $max)';
  }

  @override
  String get g7RouteAcceptedIsland => 'Ny resa godkänd';

  @override
  String get g7RouteRefusedIsland =>
      'Ändringen nekad. Fortsätt till den första destinationen';

  @override
  String get g7RouteExpiredIsland => 'Inget svar i tid. Resan är oförändrad';

  @override
  String get g7RouteWithdrawnIsland => 'Resenären drog tillbaka ändringen';

  @override
  String get g8LineTrip => 'Resa';

  @override
  String get g8LinePickupPay => 'Upphämtning';

  @override
  String get g8LineBonus => 'Bonus';

  @override
  String get g8LineTip => 'Dricks';

  @override
  String get g8LineAdjustment => 'Ändrat av Movera';

  @override
  String get g8YourShare => 'Din andel';

  @override
  String g8TipGot(String amount) {
    return 'Dricks från resenären: $amount';
  }

  @override
  String g8TipCash(String amount) {
    return 'Resenären ger dig $amount i dricks kontant.';
  }

  @override
  String g8RiderEndedCollect(String amount) {
    return 'Resenären avslutade resan. Ta betalt $amount.';
  }

  @override
  String get g8PricedForDriven => 'Priset gäller sträckan som körts.';

  @override
  String get g8BookedPriceStands => 'Det bokade priset gäller.';

  @override
  String get g8EndedEarly => 'Avslutad i förtid';

  @override
  String get g8RiderEnded => 'Resenären avslutade resan i förtid.';

  @override
  String get g8DriverEnded => 'Föraren avslutade resan före målet.';

  @override
  String get g8DebtLine => 'Tidigare obetald avgift (till den resan)';

  @override
  String get g8Continue => 'Fortsätt';

  @override
  String get liveDrivingLogsSoon =>
      'Dina timmar online och vilotider visas här när Movera räknar dem på servern. Inga exempelsiffror visas.';

  @override
  String get livePromotionsSoon =>
      'Kampanjer är inte anslutna till appen än. Bonusar på dina resor syns i dina intäkter.';

  @override
  String get liveBankSoon =>
      'Att lägga till ett utbetalningskonto i appen kommer snart.';

  @override
  String get livePinSoon =>
      'Movera bestämmer per område om en PIN-kod krävs vid upphämtning. När den krävs ber appen om resenärens kod när du är framme.';

  @override
  String get liveAnalyticsSoon =>
      'Din resestatistik visas här när Movera räknar den på servern.';

  @override
  String get walletThisWeek => 'Den här veckan';

  @override
  String get walletLiveBalanceNote => 'Intjänat den här veckan enligt Movera.';

  @override
  String get walletLiveNoPayouts => 'Inga utbetalningar än.';

  @override
  String get walletLiveUnavailable =>
      'Det gick inte att hämta dina intäkter. Försök igen senare.';

  @override
  String get walletPayoutPaid => 'Utbetald';

  @override
  String get walletPayoutPending => 'Väntar';
}
