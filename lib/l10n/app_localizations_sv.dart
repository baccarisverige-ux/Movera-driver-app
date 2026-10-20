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
  String get ridePreferences => 'Reseinställningar';

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
  String get tapToAccept => 'Tryck för att acceptera';

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
  String get rider => 'Passagerare';

  @override
  String get cash => 'Kontant';

  @override
  String get allOffers => 'ALLA ERBJUDANDEN';

  @override
  String get savedTripCouldNotBeOpened =>
      'Den sparade resan gick inte att öppna.';

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
  String get riderDataUnavailable => 'Passageraruppgifter saknas';

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
  String get tapToScan => 'Tryck för att söka';

  @override
  String get connecting => 'Ansluter';

  @override
  String get tripFound => 'Resa hittad';

  @override
  String get tapForAll => 'Tryck för alla';

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
      'Passagerarens avbokning gick inte att spara. Försök igen.';

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
  String moveWithin100MOfWhere(Object where) {
    return 'Kom inom 100 m ($where) för att vara framme.';
  }

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
      'Avsluta bara resan när du har stannat på en säker plats och passageraren kan kliva ur säkert.';

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
    return 'Du hämtade passageraren för $minutes min sedan. Avsluta bara om resan verkligen är slut.';
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
  String get moveraSafetyTeamAlerted => 'Moveras säkerhetsteam har larmats';

  @override
  String get call112IfYouNeedHelp => '\nRing 112 om du behöver hjälp nu.';

  @override
  String get tripDriverAndRiderDetailsWere =>
      '\nUppgifter om resa, förare och passagerare har skickats.';

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
  String get riderCancelled => 'Passageraren avbokade';

  @override
  String get riderCancelledThisTrip => 'Passageraren avbokade resan.';

  @override
  String get riderNoShowRecorded => 'Utebliven passagerare registrerad';

  @override
  String get thisPickupWasClosedBecauseRider =>
      'Upphämtningen avslutades eftersom passageraren inte kom.';

  @override
  String get tripExpired => 'Resan har gått ut';

  @override
  String get thisTripIsNoLongerActive => 'Resan är inte längre aktiv.';

  @override
  String get tripCouldNotContinue => 'Resan kunde inte fortsätta';

  @override
  String get tripWasClosedBecauseOfSystem =>
      'Resan avslutades på grund av ett systemfel. Kontakta support om passageraren fortfarande är med dig.';

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
  String get stopRadar => 'Stoppa radar';

  @override
  String get startRadar => 'Starta radar';

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
  String get callRider => 'Ring passageraren';

  @override
  String get messageRider => 'Skriv till passageraren';

  @override
  String get riderDetailsFromBookingWillAppear =>
      'Passageraruppgifter från bokningen visas här när profilen är kopplad till servern.';

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
  String get riderEndedTrip => 'Passageraren avslutade resan';

  @override
  String riderNameCancelledWhileTripWas(Object riderName) {
    return '$riderName avbokade under resan. Stanna på en säker plats innan du lämnar skärmen.';
  }

  @override
  String riderNameCancelledThisRequestCurrent(Object riderName) {
    return '$riderName avbokade förfrågan. Upphämtningen är inte längre aktiv.';
  }

  @override
  String get activeTripCancelledByRider =>
      'Pågående resa avbokad av passageraren';

  @override
  String get pickupCancelledByRider => 'Upphämtning avbokad av passageraren';

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
  String get cashFromRider => 'Kontant från passageraren';

  @override
  String get riderPaidMoreThanYourFare =>
      'Passageraren betalade mer än ditt pris (kampanj). Det regleras i din nästa utbetalning.';

  @override
  String get riderPaidLessThanYourFare =>
      'Passageraren betalade mindre än ditt pris (kampanj). Movera lägger till mellanskillnaden i din nästa utbetalning.';

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
  String get contactRider => 'Kontakta passageraren';

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
    return 'Kan användas efter $noShowAfterMinutes min om passageraren inte har kommit.';
  }

  @override
  String get riderDidnTShow => 'Passageraren kom inte';

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
      'Passageraren är fortfarande inte här. Beloppet för uteblivet finns nu.';

  @override
  String get tripDetails => 'Resedetaljer';

  @override
  String get justNow => 'Nyss';

  @override
  String get rideCompleted => 'Resan är klar';

  @override
  String includesFeeWaitingFee(Object fee) {
    return 'Inkl. $fee väntavgift';
  }

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
  String get passenger => 'Passagerare';

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
  String get paidByPassenger => 'Betalt av passageraren';

  @override
  String get inApp => 'I appen';

  @override
  String basePriceService(Object service) {
    return 'Grundpris · $service';
  }

  @override
  String get moveraFee => 'Moveras avgift';

  @override
  String get moveraBonus => 'Movera-bonus';

  @override
  String get yourEarnings => 'Din intäkt';

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
  String get demoRider => 'Demopassagerare';

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
  String get illustrativeMapArchivedRouteUnavailable =>
      'Illustrativ karta · arkiverad rutt saknas';

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
  String get settledInYourNextPayout => 'Regleras i din nästa utbetalning';

  @override
  String get rideCompletedOn => 'Resan klar';

  @override
  String get cancelledByRider => 'Avbokad av passageraren';

  @override
  String get cancelledByDriver => 'Avbokad av föraren';

  @override
  String get cancelledBySupport => 'Avbokad av support';

  @override
  String get cancelledByMovera => 'Avbokad av Movera';

  @override
  String get riderDidNotArrive => 'Passageraren kom inte';

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
  String get recordedFares => 'Registrerade priser';

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
    return 'Pris $fareFormatted · Kontant $cashCollectedFormatted';
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
  String get readRiderMessages => 'Läs upp passagerarens meddelanden';

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
      'Berätta för passagerare om du är döv eller hörselskadad.';

  @override
  String get demoPreviewNoInformationIsShared =>
      'Demoförhandsvisning — ingen information delas med passagerare.';

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
  String get showTrafficOnMap => 'Visa trafik på kartan';

  @override
  String get trafficColoursOnTripMap => 'Trafikfärger på resekartan';

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
  String pickupOnPickupSideSide(Object pickupSide) {
    return 'Upphämtning på $pickupSide sida';
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
  String inclBonusMoveraBonus(Object bonus) {
    return 'inkl. +$bonus Movera-bonus';
  }

  @override
  String get islandOnline => 'Radar online';

  @override
  String get islandOffline => 'Radar offline';

  @override
  String get islandRiderCancelled => 'Passageraren avbokade';

  @override
  String get islandRiderEndedTrip => 'Passageraren avslutade';

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
  String get islandCashOn => 'Kontantresor på';

  @override
  String get islandCashOff => 'Kontantresor av';

  @override
  String get islandLastMissed => 'Nästa missade erbjudande: offline';

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
  String get tripCollectCash => 'Ta emot kontant';

  @override
  String get tripCompleteRide => 'Avsluta resan';

  @override
  String tripFinishCategory(Object category) {
    return 'Avsluta $category';
  }

  @override
  String get tripFinishRide => 'Avsluta resan';

  @override
  String get cancelReasonRiderNoShow => 'Passageraren kom inte';

  @override
  String get cancelReasonRiderNoShowDetail =>
      'Väntetiden har gått ut och passageraren är inte här';

  @override
  String get cancelReasonRiderRequestedCancel =>
      'Passageraren bad om avbokning';

  @override
  String get cancelReasonRiderRequestedCancelDetail =>
      'Passageraren vill inte fortsätta';

  @override
  String get cancelReasonRiderNotAtPickup =>
      'Passageraren är inte vid upphämtningen';

  @override
  String get cancelReasonRiderNotAtPickupDetail =>
      'Du är framme men hittar inte passageraren';

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
      'Passageraren vill avsluta resan';

  @override
  String get cancelReasonRiderRequestedEarlyEndDetail =>
      'Passageraren vill kliva av före destinationen';

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
  String get cancelReasonRiderBehavior => 'Passagerarens beteende';

  @override
  String get cancelReasonRiderBehaviorDetail =>
      'Passagerarens beteende gör att resan måste avslutas';

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
  String get cancelReasonNextTripRiderRequested =>
      'Passageraren bad mig avboka';

  @override
  String get cancelReasonNextTripRiderRequestedDetail =>
      'Nästa passagerare vill inte ha resan';

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
  String get exclusiveReasonFavourite => 'Passagerarens favorit';

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
      other: 'Passageraren har $count väskor',
      one: 'Passageraren har 1 väska',
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
}
