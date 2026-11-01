// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Movera Driver';

  @override
  String get hideReservationRequest => 'Hide reservation request';

  @override
  String tripMinutesMinTrip(Object tripMinutes) {
    return '$tripMinutes min trip';
  }

  @override
  String get n1Stop => '1 stop';

  @override
  String pickupWhenLabel(Object whenLabel) {
    return 'Pickup $whenLabel';
  }

  @override
  String get reservation => 'Reservation';

  @override
  String get exclusive => 'Exclusive';

  @override
  String pickupMinutesMin(Object minutes) {
    return ' · Pickup $minutes min';
  }

  @override
  String get findingTrips => 'Finding trips';

  @override
  String get notNow => 'Not now';

  @override
  String get ridePreferences => 'Ride preferences';

  @override
  String get wallet => 'Wallet';

  @override
  String get inbox => 'Inbox';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get exclusiveForYou => 'Exclusive for you';

  @override
  String get destinationSet => 'Destination Set';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get destination => 'Destination';

  @override
  String get driverStatus => 'DRIVER STATUS';

  @override
  String get accountAccessPaused => 'Account access paused';

  @override
  String get yourDriverStatusIsCurrentlySuspended =>
      'Your driver status is currently suspended, so new trip requests cannot be accepted and Radar cannot be started.';

  @override
  String get moveraWillUseAuthoritativeAccountStatus =>
      'Movera will use the authoritative account status. This screen does not guess a reason or unlock time.';

  @override
  String get gotIt => 'Got it';

  @override
  String get pickup => 'Pickup';

  @override
  String stopNumber(Object number) {
    return 'Stop $number';
  }

  @override
  String get arrive => 'Arrive';

  @override
  String get backToRequest => 'Back to request';

  @override
  String tripMinutesMinDistance(Object tripMinutes, Object distance) {
    return '$tripMinutes min · $distance';
  }

  @override
  String get dropOff => 'Drop-off';

  @override
  String destinationModeUntilUntil(Object until) {
    return 'Destination mode until $until';
  }

  @override
  String get showRoute => 'Show route';

  @override
  String get turnOffDestination => 'Turn off destination';

  @override
  String versionLatestVersion(Object latestVersion) {
    return 'Version $latestVersion';
  }

  @override
  String get openingUpdateEllipsis => 'Opening update…';

  @override
  String get couldNotOpenUpdatePleaseTry =>
      'Could not open the update. Please try again.';

  @override
  String get updating => 'UPDATING';

  @override
  String get slideToOpen => 'SLIDE TO OPEN';

  @override
  String get rideHistory => 'Ride history';

  @override
  String get goOfflineQuestion => 'Go offline?';

  @override
  String get youStopGettingTripOffersUntil =>
      'You stop getting trip offers until you go online again.';

  @override
  String get stayOnline => 'Stay online';

  @override
  String get goOffline => 'Go offline';

  @override
  String restUntilTime(Object time) {
    return 'Rest until $time';
  }

  @override
  String timeLeftToDrive(Object time) {
    return '$time left to drive';
  }

  @override
  String get paused => 'Paused';

  @override
  String get findingYourLocation => 'Finding your location';

  @override
  String untilTime(Object time) {
    return 'Until $time';
  }

  @override
  String get documentExpired => 'Document expired';

  @override
  String get skipExclusiveOffer => 'Skip Exclusive offer';

  @override
  String get pleaseWait => 'Please wait';

  @override
  String get tapToAccept => 'Tap here';

  @override
  String headToYourPickupTimePickup(Object pickupTime, Object pickupAddress) {
    return 'Head to your $pickupTime pickup now: $pickupAddress.';
  }

  @override
  String headToYourPickupTimePickup2(Object pickupTime) {
    return 'Head to your $pickupTime pickup';
  }

  @override
  String leaveNowForPickupTimePickup(Object pickupTime) {
    return 'Leave now for $pickupTime pickup';
  }

  @override
  String get scheduledRide => 'Scheduled ride';

  @override
  String pickupAtPickupTimeInLeft(
    Object pickupTime,
    Object left,
    Object pickupAddress,
  ) {
    return 'Pickup at $pickupTime in $left: $pickupAddress.';
  }

  @override
  String pickupTimePickupInLeft(Object pickupTime, Object left) {
    return '$pickupTime pickup in $left';
  }

  @override
  String goOnlineNowForYourPickup(Object pickupTime) {
    return 'Go online now for your $pickupTime pickup.';
  }

  @override
  String goOnlineForPickupTimePickup(Object pickupTime) {
    return 'Go online for $pickupTime pickup';
  }

  @override
  String get matching => 'Matching';

  @override
  String get accept => 'Accept';

  @override
  String get recenter => 'Recenter';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get skipDemo => 'Skip demo';

  @override
  String get retry => 'Retry';

  @override
  String get safetyToolkit => 'Safety toolkit';

  @override
  String get menu => 'Menu';

  @override
  String get searchDestination => 'Search destination';

  @override
  String get lastTrip => 'LAST TRIP';

  @override
  String get hold => 'Hold';

  @override
  String get rightNow => 'Right now';

  @override
  String get cashRides => 'Cash rides';

  @override
  String get performance => 'Performance';

  @override
  String get latestWaybill => 'Latest waybill';

  @override
  String get noneYet => 'None yet';

  @override
  String get rating => 'Rating';

  @override
  String get acceptance => 'Acceptance';

  @override
  String get cancellation => 'Cancellation';

  @override
  String get drivingTime => 'Driving time';

  @override
  String get worked => 'Worked';

  @override
  String get leftBeforeRest => 'Left before rest';

  @override
  String get restUntil => 'Rest until';

  @override
  String get workLimit => 'Work limit';

  @override
  String get restAfterIt => 'Rest after it';

  @override
  String countsWhileRadarIsOnAfter(Object workHours, Object restHours) {
    return 'Counts while Radar is on. After $workHours h you rest $restHours h before going online again. A $restHours h break starts it from zero.';
  }

  @override
  String get closeSheet => 'Close sheet';

  @override
  String get today => 'Today';

  @override
  String get exclusiveReservation => 'Exclusive reservation';

  @override
  String get exclusiveOffer => 'Exclusive offer';

  @override
  String get moveraRadar => 'Movera Radar';

  @override
  String get rider => 'Rider';

  @override
  String get cash => 'Cash';

  @override
  String islandRadarOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers · radar',
      one: '1 offer · radar',
    );
    return '$_temp0';
  }

  @override
  String get savedTripCouldNotBeOpened => 'The saved trip could not be opened.';

  @override
  String get tripStorageUnavailable =>
      'Trip storage on this device could not be opened, so no saved trip can be restored now. You can still go online.';

  @override
  String get unresolvedTrip => 'Unresolved trip';

  @override
  String get thisSavedTripIsOlderThan =>
      'This saved trip is older than six hours. Resume it or close it explicitly.';

  @override
  String get savedRouteCoordinatesAreUnavailableClose =>
      'Saved route coordinates are unavailable. Close this trip explicitly before accepting another.';

  @override
  String get closeTrip => 'Close trip';

  @override
  String get resumeTrip => 'Resume trip';

  @override
  String get savedTripCouldNotBeClosed => 'The saved trip could not be closed.';

  @override
  String get savedTripCannotBeRead => 'Saved trip cannot be read';

  @override
  String get tripSavedOnThisDeviceIs =>
      'The trip saved on this device is damaged or from another app version. Close it to continue. A copy is kept on this device for support.';

  @override
  String get closeUnreadableTrip => 'Close unreadable trip';

  @override
  String get savedTripCouldNotBeRead =>
      'A saved trip could not be read. Close it to go online.';

  @override
  String get review => 'Review';

  @override
  String get unreadableTripCouldNotBeClosed =>
      'The unreadable trip could not be closed.';

  @override
  String get riderDataUnavailable => 'Rider data unavailable';

  @override
  String get finishOrCloseSavedTripBefore =>
      'Finish or close the saved trip before going online.';

  @override
  String get openSavedTrip => 'Open saved trip';

  @override
  String get account => 'Account';

  @override
  String get radar => 'Radar';

  @override
  String get tapForDetails => 'Tap for details';

  @override
  String get notActive => 'Not active';

  @override
  String get tapToScan => 'Tap to scan';

  @override
  String get connecting => 'Connecting';

  @override
  String get tripFound => 'Trip found';

  @override
  String get tapForAll => 'Tap for all';

  @override
  String get scanning => 'Scanning';

  @override
  String get currentTrip => 'Current trip';

  @override
  String get nextTripSecured => 'Next trip secured';

  @override
  String riderNameIsOnWay(Object riderName) {
    return '$riderName is on the way';
  }

  @override
  String get tripUpdatesCouldNotBeRefreshed =>
      'Trip updates could not be refreshed.';

  @override
  String get tripUpdateCouldNotBeSaved =>
      'Trip update could not be saved. Retrying automatically.';

  @override
  String get retryNow => 'Retry now';

  @override
  String get couldNotSaveRiderCancellationRetry =>
      'Could not save rider cancellation. Retry.';

  @override
  String get tripProgressCouldNotBeSaved =>
      'Trip progress could not be saved. Keep this screen open and retry.';

  @override
  String get thisStopNeedsVerifiedMapLocation =>
      'This stop needs a verified map location before arrival.';

  @override
  String get locationUnavailableEnableLocationToConfirm =>
      'Location unavailable. Enable location to confirm arrival.';

  @override
  String get preciseLocationOff =>
      'Precise location is off. Turn it on in Settings to show your position and confirm arrival.';

  @override
  String get preciseLocationOffShort => 'Precise location off';

  @override
  String get yourDriverHasArrivedAtPickup =>
      'Your driver has arrived at the pickup point.';

  @override
  String get locationUpdatingEllipsis => 'Location updating…';

  @override
  String get stopLocationUnavailable => 'Stop location unavailable';

  @override
  String get couldNotFinishSavingThisTrip =>
      'Could not finish saving this trip. Retry completion; the receipt will not duplicate.';

  @override
  String get alongYourDestination => 'Along your destination';

  @override
  String get cancelNextTripQuestion => 'Cancel the next trip?';

  @override
  String get endThisTripEarlyQuestion => 'End this trip early?';

  @override
  String get cancelThisTripQuestion => 'Cancel this trip?';

  @override
  String reasonTitle(Object title) {
    return 'Reason: $title';
  }

  @override
  String get yourCurrentTripContinuesNextTrip =>
      'Your current trip continues. The next trip goes back to dispatch for another driver.';

  @override
  String get onlyEndTripAfterYouHave =>
      'Only end the trip after you have stopped in a safe place and the rider can exit safely.';

  @override
  String get cancelNextTrip => 'Cancel next trip';

  @override
  String get endTripEarly => 'End trip early';

  @override
  String get cancelTrip => 'Cancel trip';

  @override
  String get keepTrip => 'Keep trip';

  @override
  String get thisTripCannotBeCancelledRight =>
      'This trip cannot be cancelled right now.';

  @override
  String get couldNotSaveCancellationRetry =>
      'Could not save cancellation. Retry.';

  @override
  String get firstTripEndedStartingNextOne =>
      'First trip ended · starting the next one';

  @override
  String tripEndedEarlyTitle(Object title) {
    return 'Trip ended early · $title';
  }

  @override
  String tripCancelledTitle(Object title) {
    return 'Trip cancelled · $title';
  }

  @override
  String get tripRouteAndOptions => 'Trip route and options';

  @override
  String get now => 'Now';

  @override
  String get arrival => 'Arrival';

  @override
  String get arriving => 'Arriving';

  @override
  String get turnExclusiveOffersOff => 'Turn Exclusive offers off';

  @override
  String get turnExclusiveOffersOn => 'Turn Exclusive offers on';

  @override
  String get cashCollectInCar => 'Cash: collect in the car';

  @override
  String get paidByCard => 'Paid by card';

  @override
  String get rideCheckDemo => 'Ride check demo';

  @override
  String demoValue(Object value) {
    return 'Demo: $value';
  }

  @override
  String get routeProgress => 'Route progress';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get addressUnavailable => 'Address unavailable';

  @override
  String get doesnTCount => 'Doesn’t count';

  @override
  String get tripUpdatesDisconnectedReconnectingIsRequired =>
      'Trip updates disconnected. Reconnecting is required.';

  @override
  String pickingUpRiderName(Object riderName) {
    return 'Picking up $riderName';
  }

  @override
  String waitingForRiderName(Object riderName) {
    return 'Waiting for $riderName';
  }

  @override
  String waitingAtStopNumber(Object number) {
    return 'Waiting at stop $number';
  }

  @override
  String headingToStopNumber(Object number) {
    return 'Heading to stop $number';
  }

  @override
  String droppingOffRiderName(Object riderName) {
    return 'Dropping off $riderName';
  }

  @override
  String pickUpRiderName(Object riderName) {
    return 'Pick up $riderName';
  }

  @override
  String driveToStopNumber(Object number) {
    return 'Drive to stop $number';
  }

  @override
  String dropOffRiderName(Object riderName) {
    return 'Drop off $riderName';
  }

  @override
  String get enRoute => 'En route';

  @override
  String paidWaitAtStopNumber(Object number) {
    return 'Paid wait at stop $number';
  }

  @override
  String get includedWaitThenPaid => 'Included wait · then paid';

  @override
  String get paidWaitRunning => 'Paid wait running';

  @override
  String get paidWaitNoShowAvailable => 'Paid wait · no-show available';

  @override
  String get nextStop => 'Next stop';

  @override
  String get toDropOff => 'To drop-off';

  @override
  String get waiting => 'Waiting';

  @override
  String get tripStarted => 'Trip started';

  @override
  String get tripCompleted => 'Trip completed';

  @override
  String holdForRiderName(Object riderName) {
    return 'Hold for $riderName';
  }

  @override
  String get thenDropOff => 'Then drop-off';

  @override
  String stop1OfStopAddressesLength(Object stopAddressesLength) {
    return 'Stop 1 of $stopAddressesLength';
  }

  @override
  String get actionCouldNotBeCompletedPlease =>
      'The action could not be completed. Please retry.';

  @override
  String get confirmThisTripActionQuestion => 'Confirm this trip action?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get finishSoSoonQuestion => 'Finish so soon?';

  @override
  String youPickedUpRiderMinutesMin(Object minutes) {
    return 'You picked up the rider $minutes min ago. Finish only if the trip really ended.';
  }

  @override
  String get backToRide => 'Back to ride';

  @override
  String get finishTrip => 'Finish trip';

  @override
  String get isEverythingOkQuestion => 'Is everything OK?';

  @override
  String rideCheckTitle(Object title) {
    return 'Ride check. $title';
  }

  @override
  String get rideCheck => 'Ride check';

  @override
  String get call112 => 'Call 112';

  @override
  String get iMOk => 'I\'m OK';

  @override
  String get orTellUsWhatSHappening => 'Or tell us what\'s happening';

  @override
  String get yourAnswerIsSavedToThis => 'Your answer is saved to this trip.';

  @override
  String rideCheckShort(Object short) {
    return 'Ride check · $short';
  }

  @override
  String get whatIsHappeningQuestion => 'What is happening?';

  @override
  String get thanksThisIsSavedToTrip => 'Thanks, this is saved to the trip.';

  @override
  String get done => 'Done';

  @override
  String get yourAnswersAreSavedToThis =>
      'Your answers are saved to this trip.';

  @override
  String get rideCheck112 => 'Ride check · 112';

  @override
  String get call112OnYourPhone => 'Call 112 on your phone';

  @override
  String get couldNotOpenDialerDial112 =>
      'Could not open the dialer. Dial 112 manually.';

  @override
  String get yourDialerOpensWith112Movera =>
      'Your dialer opens with 112. Movera never calls for you.';

  @override
  String get moveraCouldNotBeAlerted => 'Movera could not be alerted';

  @override
  String get rideCheckSent => 'Sent';

  @override
  String get moveraSafetyTeamAlerted => 'Movera safety team alerted';

  @override
  String get safetyAlertKeptOnPhoneDemo =>
      'Demo: alert kept on this phone only. No one at Movera was notified.';

  @override
  String get safetyAlertNotSentLive =>
      'Not sent: Movera cannot receive ride-check alerts yet. In danger, call 112.';

  @override
  String get call112IfYouNeedHelp => '\nCall 112 if you need help now.';

  @override
  String get tripDriverAndRiderDetailsWere =>
      '\nTrip, driver and rider details were sent.';

  @override
  String get call112Now => 'Call 112 now';

  @override
  String get ifSomeoneIsHurtOrIn =>
      'If someone is hurt or in danger, call emergency services.';

  @override
  String get tellUsInFewWords => 'Tell us in a few words';

  @override
  String recordingTime(Object time) {
    return 'Recording $time';
  }

  @override
  String get savedOnlyOnThisPhone => 'saved only on this phone';

  @override
  String get recordAudio => 'Record audio';

  @override
  String get audioStoppedWhenAppLeft => 'stopped when Movera left the screen';

  @override
  String audioSavedTime(Object time) {
    return 'Audio saved · $time';
  }

  @override
  String get onlyOnThisPhone => 'only on this phone';

  @override
  String get notAvailableOnThisDevice => 'not available on this device';

  @override
  String get allowMicrophoneFirst => 'allow the microphone first';

  @override
  String get couldNotRecordTryAgain => 'could not record, try again';

  @override
  String get stop => 'Stop';

  @override
  String get moveraRecordedThisTripAsCompleted =>
      'Movera recorded this trip as completed.';

  @override
  String get tripCancelledByMovera => 'Trip cancelled by Movera';

  @override
  String get moveraCancelledThisTripStopIn =>
      'Movera cancelled this trip. Stop in a safe place before leaving this screen.';

  @override
  String get moveraClosedThisTripStopIn =>
      'Movera closed this trip. Stop in a safe place before leaving this screen.';

  @override
  String get tripCancelled => 'Trip cancelled';

  @override
  String get thisTripWasCancelledFromYour =>
      'This trip was cancelled from your account.';

  @override
  String get riderCancelled => 'Rider cancelled';

  @override
  String get riderCancelledThisTrip => 'The rider cancelled this trip.';

  @override
  String get riderNoShowRecorded => 'Rider no-show recorded';

  @override
  String get thisPickupWasClosedBecauseRider =>
      'This pickup was closed because the rider did not arrive.';

  @override
  String get tripExpired => 'Trip expired';

  @override
  String get thisTripIsNoLongerActive => 'This trip is no longer active.';

  @override
  String get tripCouldNotContinue => 'Trip could not continue';

  @override
  String get tripWasClosedBecauseOfSystem =>
      'The trip was closed because of a system problem. Contact support if the rider is still with you.';

  @override
  String get tripRemovedByMovera => 'Trip removed by Movera';

  @override
  String get moveraGaveThisTripBackTo =>
      'Movera gave this trip back to dispatch. Stop in a safe place before leaving this screen.';

  @override
  String get tripEnded => 'Trip ended';

  @override
  String bodyYourNextTripStartsNow(Object body) {
    return '$body Your next trip starts now.';
  }

  @override
  String get goToNextTrip => 'Go to next trip';

  @override
  String get holdToStopNextTrips => 'Hold to stop next trips';

  @override
  String get holdToStartNextTrips => 'Hold to start next trips';

  @override
  String get stopRadar => 'Stop radar';

  @override
  String get startRadar => 'Start radar';

  @override
  String get headingToPickup => 'Heading to pickup';

  @override
  String waitingForFirst(Object first) {
    return 'Waiting for $first';
  }

  @override
  String get toNextStop => 'To next stop';

  @override
  String get onYourWay => 'On your way';

  @override
  String get afterThisDropOff => 'After this drop-off';

  @override
  String get availableAfterYourCurrentDropOff =>
      'Available after your current drop-off';

  @override
  String exclusiveSecondsS(Object seconds) {
    return 'Exclusive · ${seconds}s';
  }

  @override
  String get onThisRide => 'On this ride';

  @override
  String pickupMinutesMinAway(Object pickupMinutes) {
    return '$pickupMinutes min away';
  }

  @override
  String get deny => 'Deny';

  @override
  String get demoOffers => 'Demo offers';

  @override
  String get demoOffersLiveLocationUnavailableStale =>
      'Demo offers — live location unavailable/stale';

  @override
  String get navigateWithGoogleMaps => 'Navigate with Google Maps';

  @override
  String get googleMapsIsUnavailable => 'Google Maps is unavailable.';

  @override
  String get callRider => 'Call rider';

  @override
  String get messageRider => 'Message rider';

  @override
  String get riderDetailsFromBookingWillAppear =>
      'Rider details from the booking will appear here when the backend profile is connected.';

  @override
  String get retryRoute => 'Retry route';

  @override
  String get routeUnavailableYourTripRemainsActive =>
      'Route unavailable. Your trip remains active.';

  @override
  String get currentWaybill => 'Current waybill';

  @override
  String get currentTripWaybill => 'Current trip waybill';

  @override
  String get nextTripWaybill => 'Next trip waybill';

  @override
  String get nextTripsOnYourWay => 'Next trips on your way';

  @override
  String get shareTripRecordAudioGetHelp =>
      'Share trip, record audio, get help';

  @override
  String get shareTripGetHelp => 'Share trip, get help';

  @override
  String get stopSafelyFirstReasonRequired =>
      'Stop safely first · reason required';

  @override
  String get whyAreYouCancellingNextTripQuestion =>
      'Why are you cancelling the next trip?';

  @override
  String get whyAreYouEndingTripQuestion => 'Why are you ending the trip?';

  @override
  String get whyAreYouCancellingQuestion => 'Why are you cancelling?';

  @override
  String get yourCurrentTripContinues => 'Your current trip continues.';

  @override
  String get stopInSafePlaceFirst => 'Stop in a safe place first.';

  @override
  String get pickReasonThatFitsBest => 'Pick the reason that fits best.';

  @override
  String get riderEndedTrip => 'Rider ended the trip';

  @override
  String riderNameCancelledWhileTripWas(Object riderName) {
    return '$riderName cancelled while the trip was active. Stop in a safe place before leaving this screen.';
  }

  @override
  String riderNameCancelledThisRequestCurrent(Object riderName) {
    return '$riderName cancelled this request. The current pickup is no longer active.';
  }

  @override
  String get activeTripCancelledByRider => 'Active trip cancelled by rider';

  @override
  String get pickupCancelledByRider => 'Pickup cancelled by rider';

  @override
  String get tripUpdate => 'TRIP UPDATE';

  @override
  String get keepControlOfVehicleAndStop =>
      'Keep control of the vehicle and stop safely before continuing.';

  @override
  String get iHaveStoppedSafely => 'I have stopped safely';

  @override
  String get returnToRequests => 'Return to requests';

  @override
  String get waitingInProgress => 'Waiting in progress';

  @override
  String get takeCashBeforeYouFinish => 'Take the cash before you finish.';

  @override
  String takeCashFromFirstBeforeYou(Object first) {
    return 'Take the cash from $first before you finish.';
  }

  @override
  String get notYet => 'Not yet';

  @override
  String collectAmountInCash(Object amount) {
    return 'Collect $amount in cash';
  }

  @override
  String get collect => 'Collect';

  @override
  String get inCash => 'in cash';

  @override
  String get yourFare => 'Your fare';

  @override
  String get cashFromRider => 'Cash from rider';

  @override
  String get riderPaidMoreThanYourFare =>
      'The rider paid more than your fare (promotion). It is settled in your next payout.';

  @override
  String get riderPaidLessThanYourFare =>
      'The rider paid less than your fare (promotion). Movera adds it to your next payout.';

  @override
  String get to => 'TO';

  @override
  String get pickupArrived => 'Pickup · arrived';

  @override
  String get pickupPickedUp => 'Pickup · picked up';

  @override
  String stopNumberDone(Object number) {
    return 'Stop $number · done';
  }

  @override
  String get yourTrip => 'Your trip';

  @override
  String pickupPickupMinutesMin(Object pickupMinutes) {
    return 'Pickup · $pickupMinutes min';
  }

  @override
  String dropOffTripMinutesMinTrip(Object tripMinutes) {
    return 'Drop-off · $tripMinutes min trip';
  }

  @override
  String get nextTripOptions => 'Next trip options';

  @override
  String get openWaybill => 'Open waybill';

  @override
  String get contactRider => 'Contact rider';

  @override
  String get yourCurrentTripContinuesReasonRequired =>
      'Your current trip continues · reason required';

  @override
  String nextTripCancelledTitle(Object title) {
    return 'Next trip cancelled · $title';
  }

  @override
  String get waybill => 'Waybill';

  @override
  String get stopWait => 'Stop wait';

  @override
  String get pickupWait => 'Pickup wait';

  @override
  String get everyMinuteIsPaid => 'Every minute is paid';

  @override
  String get thisStopHasNoFreeMinutes =>
      'This stop has no free minutes. The whole wait is added to the fare.';

  @override
  String ruleForThisPickupRule(Object rule) {
    return 'Rule for this pickup: $rule';
  }

  @override
  String get includedTime => 'Included time';

  @override
  String get openingMinutesStayInsideFare =>
      'The opening minutes stay inside the fare.';

  @override
  String get waitTime => 'Wait time';

  @override
  String get addedFromFirstSecondAtThis =>
      'Added from the first second at this stop.';

  @override
  String get addedToFareWhenThisTrip =>
      'Added to the fare when this trip is completed.';

  @override
  String perMinuteFormattedMin(Object perMinuteFormatted) {
    return '$perMinuteFormatted / min';
  }

  @override
  String get noShow => 'No-show';

  @override
  String canBeAppliedAfterNoShow(Object noShowAfterMinutes) {
    return 'Can be applied after $noShowAfterMinutes min if the rider has not arrived.';
  }

  @override
  String get riderDidnTShow => 'Rider didn’t show';

  @override
  String youGetDriverShareWaitPercent(Object driverShareWaitPercent) {
    return 'You get $driverShareWaitPercent% of the wait time.';
  }

  @override
  String youGetDriverShareWaitPercent2(
    Object driverShareWaitPercent,
    Object driverShareNoShowPercent,
    Object driverNoShowFeeFormatted,
  ) {
    return 'You get $driverShareWaitPercent% of the wait time and $driverShareNoShowPercent% of the no-show fee ($driverNoShowFeeFormatted).';
  }

  @override
  String get amountsCanChangeWithTaxesAnd =>
      'Amounts can change with taxes and fees.';

  @override
  String get close => 'Close';

  @override
  String waitingFeePerMinuteFormattedMin(Object perMinuteFormatted) {
    return 'waiting fee · $perMinuteFormatted / min';
  }

  @override
  String get later => 'Later';

  @override
  String get includedMinutes => 'Included minutes';

  @override
  String get theseFirstMinutesAreAlreadyPart =>
      'These first minutes are already part of the fare.';

  @override
  String get waitTimeIsRunning => 'Wait time is running';

  @override
  String get eachMinuteAfterIncludedTimeIs =>
      'Each minute after the included time is added when the trip ends.';

  @override
  String get noShowCanBeApplied => 'No-show can be applied';

  @override
  String get riderIsStillNotHereNo =>
      'The rider is still not here. The no-show amount is now available.';

  @override
  String get tripDetails => 'Trip details';

  @override
  String get justNow => 'Just now';

  @override
  String get rideCompleted => 'Ride completed';

  @override
  String get payment => 'Payment';

  @override
  String get lastWaybill => 'Last waybill';

  @override
  String get open => 'Open';

  @override
  String get tripId => 'Trip ID';

  @override
  String get completed => 'Completed';

  @override
  String get ratingNotSentDemo => 'Rating not sent (demo)';

  @override
  String rateRider(Object rider) {
    return 'Rate $rider';
  }

  @override
  String get trip => 'Trip #';

  @override
  String get time => 'Time';

  @override
  String get fare => 'Fare';

  @override
  String get passenger => 'Passenger';

  @override
  String get via => 'Via';

  @override
  String get from => 'From';

  @override
  String get to2 => 'To';

  @override
  String get driver => 'Driver';

  @override
  String get licensePlate => 'License plate';

  @override
  String get passengerCapacity => 'Passenger capacity';

  @override
  String get paidByPassenger => 'Paid by the passenger';

  @override
  String get inApp => 'In the app';

  @override
  String basePriceService(Object service) {
    return 'Base price · $service';
  }

  @override
  String get moveraFee => 'Movera fee';

  @override
  String get yourEarnings => 'Your earnings';

  @override
  String get riderPays => 'Rider pays';

  @override
  String get roundToNearestWholeKronaIn =>
      '* Round to the nearest whole krona in the taximeter.';

  @override
  String get feature => 'Feature';

  @override
  String get samplePeriod => 'Sample period';

  @override
  String get clear => 'Clear';

  @override
  String get back => 'Back';

  @override
  String get earningsPreview => 'Earnings preview';

  @override
  String get demoRider => 'Demo rider';

  @override
  String get sampleDistance => 'Sample distance';

  @override
  String get sample => 'Sample';

  @override
  String get pickupFrom => 'Pickup from';

  @override
  String get samplePickupStockholm => 'Sample pickup, Stockholm';

  @override
  String get dropOffLocation => 'Drop off location';

  @override
  String get sampleDropOffStockholm => 'Sample drop-off, Stockholm';

  @override
  String get noAnswer => 'No answer';

  @override
  String answerAnswer(Object answer) {
    return 'Answer: $answer';
  }

  @override
  String audioSavedOnlyOnThisPhone(Object time) {
    return 'Audio saved only on this phone · $time';
  }

  @override
  String get pastRideRouteDriven => 'Route driven';

  @override
  String get pastRidePlannedRoute => 'Planned route';

  @override
  String get pastRideRouteUnavailable => 'Route not available';

  @override
  String get rideCost => 'Ride Cost';

  @override
  String get tip => 'Tip';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get rideType => 'Ride Type';

  @override
  String get cashCollected => 'Cash collected';

  @override
  String get cashMatchedYourFare => 'Cash matched your fare';

  @override
  String get cashMatchedYourEarnings =>
      'Cash matched your earnings: nothing to settle';

  @override
  String get settledInYourNextPayout => 'Settled in your next payout';

  @override
  String get rideCompletedOn => 'Ride completed on';

  @override
  String get cancelledByRider => 'Cancelled by rider';

  @override
  String get cancelledByDriver => 'Cancelled by driver';

  @override
  String get cancelledBySupport => 'Cancelled by support';

  @override
  String get cancelledByMovera => 'Cancelled by Movera';

  @override
  String get riderDidNotArrive => 'Rider did not arrive';

  @override
  String get tripFailed => 'Trip failed';

  @override
  String get previous => 'Previous';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get loadingRideHistoryEllipsis => 'Loading ride history…';

  @override
  String get couldNotLoadRideHistory => 'Could not load ride history.';

  @override
  String get earningsHistory => 'Earnings & history';

  @override
  String get allRides => 'All rides';

  @override
  String get yourMoveraActivity => 'Your Movera activity';

  @override
  String get online => 'Online';

  @override
  String get rides => 'Rides';

  @override
  String get earningsBreakdown => 'Earnings breakdown';

  @override
  String get latestRides => 'Latest rides';

  @override
  String get noCompletedRidesInThisPeriod =>
      'No completed rides in this period.';

  @override
  String viewAllVisibleRideCountRides(Object visibleRideCount) {
    return 'View all $visibleRideCount rides';
  }

  @override
  String periodRidesRidesInPeriodLabel(Object periodRides, Object periodLabel) {
    return '$periodRides rides in $periodLabel';
  }

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get recordedFares => 'Recorded earnings';

  @override
  String get tipsAndFees => 'Tips and fees';

  @override
  String get notAvailable => 'Not available';

  @override
  String get otherEarnings => 'Other earnings';

  @override
  String otherEarningsTripsLengthCash(Object tripsLength) {
    return 'Other earnings · $tripsLength cash';
  }

  @override
  String get cashTripsYourFareMinusCash =>
      'Cash trips: your fare minus the cash you collected.';

  @override
  String get noCashTripsInThisPeriod => 'No cash trips in this period.';

  @override
  String get totalYouOweMovera => 'Total you owe Movera';

  @override
  String get totalMoveraOwesYou => 'Total Movera owes you';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get settledInYourNextPayout2 => 'Settled in your next payout.';

  @override
  String fareFareFormattedCashCashCollected(
    Object fareFormatted,
    Object cashCollectedFormatted,
  ) {
    return 'Earnings $fareFormatted · Cash $cashCollectedFormatted';
  }

  @override
  String cashFareFeeLine(String fare, String fee, String cash) {
    return 'Fare $fare · Fee $fee · Cash $cash';
  }

  @override
  String get driver2 => 'DRIVER';

  @override
  String get profile => 'Profile';

  @override
  String get accountVehicleAndDocuments => 'Account, vehicle and documents';

  @override
  String get earningsAndWeeklyPayouts => 'Earnings and weekly payouts';

  @override
  String get completedAndPreviousRides => 'Completed and previous rides';

  @override
  String get notifications => 'Notifications';

  @override
  String get rideAlertsDemandAndAccount => 'Ride alerts, demand and account';

  @override
  String get work => 'WORK';

  @override
  String get scheduledRides => 'Scheduled rides';

  @override
  String get reservationsAndAcceptedTrips => 'Reservations and accepted trips';

  @override
  String get chooseCategoriesYouWantToReceive =>
      'Choose categories you want to receive';

  @override
  String get promotions => 'Promotions';

  @override
  String get bonusesAndCampaignOffers => 'Bonuses and campaign offers';

  @override
  String get drivingLogs => 'Driving logs';

  @override
  String get hoursOnlineAndRestRules => 'Hours online and rest rules';

  @override
  String get supportApp => 'SUPPORT & APP';

  @override
  String get support => 'Support';

  @override
  String get messagesAndSupportTickets => 'Messages and support tickets';

  @override
  String get settings => 'Settings';

  @override
  String get appAndDriverSettings => 'App and driver settings';

  @override
  String sampleRating(Object rating) {
    return 'Sample rating $rating';
  }

  @override
  String get active => 'Active';

  @override
  String get pending => 'Pending';

  @override
  String get soundVoice => 'Sound & voice';

  @override
  String get savingPreferencesEllipsis => 'Saving preferences…';

  @override
  String get changesNotSavedRetry => 'Changes not saved — Retry';

  @override
  String get couldNotLoadSavedPreferencesRetry =>
      'Could not load saved preferences — Retry';

  @override
  String get localDemoPreferencesSavedOnThis =>
      'Local demo preferences — saved on this device; effects are previews.';

  @override
  String get volume => 'Volume';

  @override
  String get generalVolume => 'General volume';

  @override
  String get alwaysPlayTripRequests => 'Always play trip requests';

  @override
  String get playsEvenWhenPhoneIsSilent =>
      'Plays even when the phone is silent';

  @override
  String get voice => 'Voice';

  @override
  String get voiceNavigation => 'Voice navigation';

  @override
  String get spokenTurnsWhileYouDrive => 'Spoken turns while you drive';

  @override
  String get readRiderMessages => 'Read rider messages';

  @override
  String get readsNewChatMessagesAloud => 'Reads new chat messages aloud';

  @override
  String get testAlerts => 'Test alerts';

  @override
  String get testVoice => 'Test voice';

  @override
  String get playingAlertSoundMock => 'Playing alert sound (mock)';

  @override
  String get playingVoiceSoundMock => 'Playing voice sound (mock)';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get hearing => 'Hearing';

  @override
  String get tellRidersIfYouAreDeaf =>
      'Tell riders if you are deaf or hard of hearing.';

  @override
  String get demoPreviewNoInformationIsShared =>
      'Demo preview — no information is shared with riders.';

  @override
  String get closePreview => 'Close preview';

  @override
  String get flashForRequests => 'Flash for requests';

  @override
  String get screenFlashesWhenRequestArrives =>
      'The screen flashes when a request arrives.';

  @override
  String get vibrationForRequests => 'Vibration for requests';

  @override
  String get phoneVibratesWhenRequestArrives =>
      'The phone vibrates when a request arrives.';

  @override
  String get appSettings => 'App settings';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get unavailableInDemo => 'Unavailable in demo';

  @override
  String get language => 'Language';

  @override
  String get pinVerification => 'PIN verification';

  @override
  String get emergencyContacts => 'Emergency contacts';

  @override
  String get safety => 'Safety';

  @override
  String get trustedContact => 'Trusted contact';

  @override
  String get dialerIsUnavailable => 'Dialer is unavailable.';

  @override
  String get addTrustedContact => 'Add trusted contact';

  @override
  String get couldNotLoadTrustedContactsRetry =>
      'Could not load trusted contacts — Retry';

  @override
  String get trustedContactsStayOnThisDevice =>
      'Trusted contacts stay on this device. Calling opens your dialer.';

  @override
  String callName(Object name) {
    return 'Call $name';
  }

  @override
  String get contactCouldNotBeSavedRetry =>
      'Contact could not be saved. Retry.';

  @override
  String get name => 'Name';

  @override
  String get enterName => 'Enter a name';

  @override
  String get phone => 'Phone';

  @override
  String get enterValidPhoneNumber => 'Enter a valid phone number';

  @override
  String get relation => 'Relation';

  @override
  String get savingContactEllipsis => 'Saving contact…';

  @override
  String get saveContact => 'Save contact';

  @override
  String get recentPayouts => 'Recent payouts';

  @override
  String get seeAll => 'See all';

  @override
  String get previewOnly => 'Preview only';

  @override
  String get noPayoutBalanceUntilPaymentService =>
      'No payout balance until a payment service is connected.';

  @override
  String get noAutomaticPayout => 'No automatic payout';

  @override
  String get payoutDateIsNotAvailable => 'Payout date is not available';

  @override
  String get notSet => 'Not set';

  @override
  String get noPayoutsYetLocalPreviewCannot =>
      'No payouts yet. Local preview cannot invent earnings.';

  @override
  String get payoutAccount => 'Payout account';

  @override
  String get noPayoutAccountConnected => 'No payout account connected';

  @override
  String ratingRiderTripsTrips(Object rating, Object riderTrips) {
    return '$rating · $riderTrips trips';
  }

  @override
  String get closeOffer => 'Close offer';

  @override
  String reservationTime(Object time) {
    return 'Reservation · $time';
  }

  @override
  String get priority => 'Priority';

  @override
  String get demoModeNoAccount => 'Demo mode — no account';

  @override
  String labelUnavailableInDemo(Object label) {
    return '$label — unavailable in demo';
  }

  @override
  String get routeUpdated => 'Route updated';

  @override
  String get gpsRestored => 'GPS restored';

  @override
  String get waitingAtStop => 'Waiting at stop';

  @override
  String get paidWaiting => 'Paid waiting';

  @override
  String get waitingTime => 'Waiting time';

  @override
  String nearValue(Object value) {
    return 'Near $value';
  }

  @override
  String get arrivingSoon => 'Arriving soon';

  @override
  String trafficAheadValueMin(Object value) {
    return 'Traffic ahead · +$value min';
  }

  @override
  String arrivingInEtaMinTimeTime2(Object eta, Object time, Object time2) {
    return 'Arriving in $eta min · $time:$time2';
  }

  @override
  String nextTripSecuredNextTripFare(Object nextTripFare) {
    return 'Next trip secured · $nextTripFare';
  }

  @override
  String get tollAhead => 'Toll ahead';

  @override
  String pickupOverKmKm(Object km) {
    return 'Pickup over $km km';
  }

  @override
  String get assignedByMovera => 'Assigned by Movera';

  @override
  String get islandOnline => 'Radar online';

  @override
  String get islandOffline => 'Radar offline';

  @override
  String get islandRiderCancelled => 'Rider cancelled';

  @override
  String get islandRiderEndedTrip => 'Rider ended trip';

  @override
  String get islandTripRemoved => 'Trip removed by Movera';

  @override
  String islandCancelFee(Object amount) {
    return '+$amount';
  }

  @override
  String get islandCancelNoFee => 'no fee';

  @override
  String islandReservationCancelled(Object time) {
    return '$time cancelled';
  }

  @override
  String get islandMatching => 'Matching…';

  @override
  String get islandMatched => 'Trip matched';

  @override
  String get islandTakenByOther => 'Taken by another driver';

  @override
  String get islandTripUnavailable => 'Trip unavailable';

  @override
  String get islandNoConnection => 'No connection';

  @override
  String get islandContactSupport => 'Contact support';

  @override
  String get islandAccountOnHold => 'Account on hold · Contact support';

  @override
  String get islandAccountNotActive => 'Account not active · Finish sign-up';

  @override
  String get islandNewReservation => 'New reservation';

  @override
  String get islandExclusiveRide => 'Exclusive ride';

  @override
  String get islandExclusiveReservation => 'Exclusive reservation';

  @override
  String get islandReservationAccepted => 'Reservation accepted';

  @override
  String islandReservationAcceptedAt(Object time) {
    return 'Accepted · pickup $time';
  }

  @override
  String get islandNoLongerAvailable => 'No longer available';

  @override
  String get islandAssignedByMovera => 'Assigned by Movera';

  @override
  String get islandAssignmentAccepted => 'Scheduled ride accepted';

  @override
  String get islandAssignmentNotAccepted => 'Assignment not accepted';

  @override
  String islandPickupIn(Object time, Object left) {
    return '$time pickup in $left';
  }

  @override
  String islandGoOnlineFor(Object time) {
    return 'Go online for $time pickup';
  }

  @override
  String islandLeaveNow(Object time) {
    return 'Leave now for $time pickup';
  }

  @override
  String islandHeadToPickup(Object time) {
    return 'Head to your $time pickup';
  }

  @override
  String get islandGivenToBackup => 'Given to backup driver';

  @override
  String islandLateReassigned(Object minutes) {
    return 'Given to another driver: $minutes min late';
  }

  @override
  String get lateEtaReassignedTitle => 'Ride given to another driver';

  @override
  String lateEtaReassignedNote(String time, int minutes) {
    return 'Ride given to another driver — you would reach the $time pickup about $minutes min late.';
  }

  @override
  String get islandCashOn => 'Cash rides on';

  @override
  String get islandCashOff => 'Cash rides off';

  @override
  String islandOfflineMissed(Object count) {
    return 'Offline: $count offers missed';
  }

  @override
  String islandDrivingLeft(Object minutes) {
    return '$minutes min left to drive';
  }

  @override
  String islandRestUntil(Object time) {
    return 'Rest until $time';
  }

  @override
  String get islandRestOver => 'Rest over';

  @override
  String islandDocumentExpires(Object document, Object when) {
    return '$document expires $when';
  }

  @override
  String islandDocumentExpired(Object document) {
    return '$document expired';
  }

  @override
  String get islandDocumentInReview => 'New document in review';

  @override
  String get islandDocumentApproved => 'Document approved';

  @override
  String islandHighDemand(Object area) {
    return 'High demand · $area';
  }

  @override
  String get islandScheduledPaused => 'Scheduled rides paused';

  @override
  String get islandSavedTripOpen => 'Saved trip open';

  @override
  String get islandNewerTripKept => 'Newer trip kept';

  @override
  String get islandRecordSetAside => 'Trip record set aside';

  @override
  String get islandRecoveryFailed => 'Recovery failed';

  @override
  String get islandTripNotClosed => 'Trip not closed';

  @override
  String get islandCloseSavedTrip => 'Close saved trip';

  @override
  String get islandSeeEarnings => 'Tap to see earnings';

  @override
  String get islandDestinationsUsed => 'Today\'s destinations used';

  @override
  String get islandDestinationOff => 'Destination mode is off here';

  @override
  String get islandDestinationEnded => 'Destination mode ended';

  @override
  String get offerYourShare => 'Your share';

  @override
  String get offerFare => 'Fare';

  @override
  String get offerPickup => 'Pickup';

  @override
  String get offerDropoff => 'Drop-off';

  @override
  String get offerPickupNearby => 'Pickup nearby';

  @override
  String offerKmAway(Object km) {
    return '$km km away';
  }

  @override
  String offerTripLength(Object minutes, Object km) {
    return '$minutes min trip · $km km';
  }

  @override
  String get offerMatch => 'Match';

  @override
  String get offerMatching => 'Matching…';

  @override
  String get offerAccept => 'Accept';

  @override
  String get offerOnYourWay => 'On your way';

  @override
  String get offerHide => 'Hide offer';

  @override
  String get offerReservationRequest => 'Reservation request';

  @override
  String get offerYourNextRide => 'Your next ride';

  @override
  String get offerViewRoute => 'View route';

  @override
  String get offerNewReservation => 'New reservation';

  @override
  String get offerViewDetails => 'View details';

  @override
  String get tripArrived => 'I\'ve arrived';

  @override
  String get tripStart => 'Start trip';

  @override
  String get tripStartFirstStop => 'Start first stop';

  @override
  String get tripArriveAtStop => 'Arrive at the stop';

  @override
  String get tripComplete => 'Complete trip';

  @override
  String tripGoToStop(Object stop) {
    return 'Go to $stop stop';
  }

  @override
  String get tripGoToDropoff => 'Go to drop-off';

  @override
  String get cashPriceChanged => 'The price changed – collect the new amount';

  @override
  String get cashPriceRecalculatedEarlyEnd =>
      'Ending before the destination – price recalculated';

  @override
  String get tripCollectCash => 'Collect cash';

  @override
  String get tripCompleteRide => 'Complete ride';

  @override
  String get tripFinishRide => 'Finish ride';

  @override
  String get cancelReasonRiderNoShow => 'Rider did not arrive';

  @override
  String get cancelReasonRiderNoShowDetail =>
      'The no-show time has passed and the rider is not here';

  @override
  String get cancelReasonRiderRequestedCancel => 'Rider asked to cancel';

  @override
  String get cancelReasonRiderRequestedCancelDetail =>
      'The rider doesn’t want to continue';

  @override
  String get cancelReasonRiderNotAtPickup => 'Rider not at pickup';

  @override
  String get cancelReasonRiderNotAtPickupDetail =>
      'You arrived but couldn’t find the rider';

  @override
  String get cancelReasonUnsafePickup => 'Pickup unsafe';

  @override
  String get cancelReasonUnsafePickupDetail => 'You can’t stop there safely';

  @override
  String get cancelReasonVehicleIssueBeforeStart => 'Vehicle problem';

  @override
  String get cancelReasonVehicleIssueBeforeStartDetail =>
      'Your car can’t make the trip';

  @override
  String get cancelReasonDriverEmergencyBeforeStart => 'Personal emergency';

  @override
  String get cancelReasonDriverEmergencyBeforeStartDetail =>
      'Something urgent came up';

  @override
  String get cancelReasonOtherBeforeStart => 'Other reason';

  @override
  String get cancelReasonOtherBeforeStartDetail =>
      'Something else stops this pickup';

  @override
  String get cancelReasonRiderRequestedEarlyEnd =>
      'Rider asked to end the trip';

  @override
  String get cancelReasonRiderRequestedEarlyEndDetail =>
      'The rider wants to leave before the destination';

  @override
  String get cancelReasonSafetyConcernOnTrip => 'Safety concern';

  @override
  String get cancelReasonSafetyConcernOnTripDetail =>
      'Continuing the trip may be unsafe';

  @override
  String get cancelReasonVehicleIssueOnTrip => 'Vehicle problem';

  @override
  String get cancelReasonVehicleIssueOnTripDetail =>
      'A vehicle issue makes it unsafe to continue';

  @override
  String get cancelReasonAccidentOrRoadEmergency =>
      'Accident or road emergency';

  @override
  String get cancelReasonAccidentOrRoadEmergencyDetail =>
      'An incident or emergency prevents continuing';

  @override
  String get cancelReasonRiderBehavior => 'Rider behavior';

  @override
  String get cancelReasonRiderBehaviorDetail =>
      'The rider’s behavior requires the trip to end';

  @override
  String get cancelReasonTripOrDestinationIssue => 'Trip or destination issue';

  @override
  String get cancelReasonTripOrDestinationIssueDetail =>
      'A trip detail or destination problem prevents continuing';

  @override
  String get cancelReasonOtherOnTrip => 'Other reason';

  @override
  String get cancelReasonOtherOnTripDetail =>
      'Another issue requires the trip to end early';

  @override
  String get cancelReasonScheduledCannotMakeTime =>
      'I can no longer make the pickup time';

  @override
  String get cancelReasonScheduledVehicleIssue => 'Vehicle issue';

  @override
  String get cancelReasonScheduledPersonalEmergency => 'Personal emergency';

  @override
  String get cancelReasonScheduledPickupTooFar => 'Pickup is too far from me';

  @override
  String get cancelReasonScheduledTripDetails =>
      'Trip details no longer work for me';

  @override
  String get cancelReasonScheduledOther => 'Other reason';

  @override
  String get cancelReasonNextTripCurrentRunningLate =>
      'Current trip is taking longer';

  @override
  String get cancelReasonNextTripCurrentRunningLateDetail =>
      'You can’t reach the next pickup in time';

  @override
  String get cancelReasonNextTripPickupTooFar => 'Too far from the pickup';

  @override
  String get cancelReasonNextTripPickupTooFarDetail =>
      'The next pickup is further than expected';

  @override
  String get cancelReasonNextTripRiderRequested => 'Rider asked me to cancel';

  @override
  String get cancelReasonNextTripRiderRequestedDetail =>
      'The next rider doesn’t want the trip';

  @override
  String get cancelReasonNextTripVehicleIssue => 'Problem with the car';

  @override
  String get cancelReasonNextTripVehicleIssueDetail =>
      'Your car can’t make the next trip';

  @override
  String get cancelReasonNextTripDriverEmergency => 'Personal emergency';

  @override
  String get cancelReasonNextTripDriverEmergencyDetail =>
      'Something urgent came up';

  @override
  String get cancelReasonNextTripOther => 'Other reason';

  @override
  String get cancelReasonNextTripOtherDetail =>
      'Something else stops the next trip';

  @override
  String get cancelReasonPickupIncorrect => 'Pickup point is incorrect';

  @override
  String get cancelReasonWrongRideOption => 'I chose the wrong ride option';

  @override
  String get cancelReasonRequestedByMistake =>
      'I requested the ride by mistake';

  @override
  String get cancelReasonWaitTooLong => 'The wait is taking too long';

  @override
  String get cancelReasonDestinationChange => 'Destination needs to be changed';

  @override
  String get cancelReasonDriverNotSuitable =>
      'Driver/ride details are not suitable';

  @override
  String get cancelReasonPlansChanged => 'Plans changed';

  @override
  String get cancelReasonSomethingElse => 'Something else';

  @override
  String get exclusiveReasonBestMatch => 'Best match';

  @override
  String get exclusiveReasonFavourite => 'Rider\'s favourite';

  @override
  String get exclusiveReasonFinishingNearby => 'Finishing nearby';

  @override
  String get exclusiveReasonAirportQueue => 'Airport queue';

  @override
  String get exclusiveReasonPickupSoon => 'Pickup soon';

  @override
  String get exclusiveReasonNearby => 'Only for you · nearby';

  @override
  String get waitingRulePickupFarAway => 'Pickup far away';

  @override
  String get waitingRuleScheduledRide => 'Scheduled ride';

  @override
  String get waitingRuleAirportPickup => 'Airport pickup';

  @override
  String get waitingRuleEventPickup => 'Event pickup';

  @override
  String riderBags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rider has $count bags',
      one: 'Rider has 1 bag',
    );
    return '$_temp0';
  }

  @override
  String get languageTitle => 'Language';

  @override
  String get languageZoneDefault => 'Default for your zone';

  @override
  String get languageSaveFailed => 'Language not saved. Try again.';

  @override
  String get mapUnavailable =>
      'Map unavailable. Check your connection, then reopen Movera.';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get todayCaps => 'TODAY';

  @override
  String get statusRest => 'REST';

  @override
  String get statusHold => 'HOLD';

  @override
  String whenInMinutes(Object minutes) {
    return 'In $minutes min';
  }

  @override
  String whenInHours(Object hours) {
    return 'In $hours h';
  }

  @override
  String whenToday(Object time) {
    return 'Today $time';
  }

  @override
  String whenTomorrow(Object time) {
    return 'Tomorrow $time';
  }

  @override
  String get stopOrdinal1 => 'first';

  @override
  String get stopOrdinal2 => 'second';

  @override
  String get stopOrdinal3 => 'third';

  @override
  String get stopOrdinal4 => 'fourth';

  @override
  String get stopOrdinal5 => 'fifth';

  @override
  String stopOrdinalN(Object number) {
    return '${number}th';
  }

  @override
  String get hideRequest => 'Hide request';

  @override
  String get holdToGoOffline => 'Hold to go offline';

  @override
  String get tripOptions => 'Trip options';

  @override
  String get orbMatch => 'MATCH';

  @override
  String get orbWait => 'WAIT';

  @override
  String get orbOff => 'OFF';

  @override
  String get orbOn => 'ON';

  @override
  String get orbNew => 'NEW';

  @override
  String get orbLive => 'LIVE';

  @override
  String get orbPaused => 'PAUSED';

  @override
  String get orbStarting => 'STARTING';

  @override
  String get navArrived => 'ARRIVED';

  @override
  String get navNear => 'NEAR';

  @override
  String get navNow => 'NOW';

  @override
  String get menuOnline => 'ONLINE';

  @override
  String get menuOffline => 'OFFLINE';

  @override
  String get menuReady => 'READY';

  @override
  String get menuPending => 'PENDING';

  @override
  String get ok => 'OK';

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '1 trip',
    );
    return '$_temp0';
  }

  @override
  String stopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get navArrive => 'Arrive';

  @override
  String get navHeadOut => 'Head out';

  @override
  String get navKeepLeft => 'Keep left';

  @override
  String get navKeepRight => 'Keep right';

  @override
  String get navTunnelAhead => 'Tunnel ahead';

  @override
  String get navTollRoadAhead => 'Toll road ahead';

  @override
  String get navContinueStraight => 'Continue straight';

  @override
  String get navContinue => 'Continue';

  @override
  String get navRoundabout => 'Roundabout';

  @override
  String navRoundaboutExit(String exit) {
    return 'Roundabout, exit $exit';
  }

  @override
  String get navRoundaboutUTurn => 'Roundabout, U-turn';

  @override
  String navRoundaboutUTurnExit(String exit) {
    return 'Roundabout, U-turn · exit $exit';
  }

  @override
  String navSignedExit(String exit) {
    return 'Exit $exit';
  }

  @override
  String navSignedExitTowards(String exit, String place) {
    return 'Exit $exit · $place';
  }

  @override
  String get navExitLeft => 'Exit left';

  @override
  String get navExitRight => 'Exit right';

  @override
  String get navTakeExit => 'Take the exit';

  @override
  String get navRampOnto => 'Take the ramp onto';

  @override
  String get navRampLeft => 'Take the ramp on the left';

  @override
  String get navRampRight => 'Take the ramp on the right';

  @override
  String get navRamp => 'Take the ramp';

  @override
  String get navMergeLeft => 'Merge left';

  @override
  String get navMergeRight => 'Merge right';

  @override
  String get navMerge => 'Merge';

  @override
  String get navForkLeft => 'At the fork, go left';

  @override
  String get navForkRight => 'At the fork, go right';

  @override
  String get navContinueAtFork => 'Continue at the fork';

  @override
  String get navTurnLeft => 'Turn left';

  @override
  String get navTurnRight => 'Turn right';

  @override
  String get navEndOfRoad => 'End of the road';

  @override
  String get navUTurn => 'U-turn';

  @override
  String get navSharpLeft => 'Turn sharp left';

  @override
  String get navSharpRight => 'Turn sharp right';

  @override
  String get navSlightLeft => 'Turn slight left';

  @override
  String get navSlightRight => 'Turn slight right';

  @override
  String get navDistanceNow => 'now';

  @override
  String navMeters(String meters) {
    return '$meters m';
  }

  @override
  String navKilometers(String km) {
    return '$km km';
  }

  @override
  String get navDecimalMark => '.';

  @override
  String navInDistance(String distance) {
    return 'in $distance';
  }

  @override
  String navActionIn(String action, String distance) {
    return '$action in $distance';
  }

  @override
  String navActionNow(String action) {
    return '$action now';
  }

  @override
  String navActionFor(String action, String distance) {
    return '$action $distance';
  }

  @override
  String navOnto(String action, String road) {
    return '$action onto $road';
  }

  @override
  String get navArriveAtDestination => 'Arrive at destination';

  @override
  String navHeadOutOn(String road) {
    return 'Head out on $road';
  }

  @override
  String navContinueOn(String road) {
    return 'Continue on $road';
  }

  @override
  String get navRoundaboutContinue => 'At the roundabout, continue';

  @override
  String navRoundaboutTakeExit(String exit) {
    return 'At roundabout, take exit $exit';
  }

  @override
  String get navExitOnLeft => 'Take the exit on the left';

  @override
  String get navExitOnRight => 'Take the exit on the right';

  @override
  String get navEndTurnLeft => 'Turn left at the end of the road';

  @override
  String get navEndTurnRight => 'Turn right at the end of the road';

  @override
  String get navAtEndOfRoad => 'At the end of the road';

  @override
  String get navMakeUTurn => 'Make a U-turn';

  @override
  String navUseLeftLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use the $count left lanes',
      one: 'Use the left lane',
    );
    return '$_temp0';
  }

  @override
  String navUseRightLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use the $count right lanes',
      one: 'Use the right lane',
    );
    return '$_temp0';
  }

  @override
  String navUseMiddleLanes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use the $count middle lanes',
      one: 'Use the middle lane',
    );
    return '$_temp0';
  }

  @override
  String navTowards(String place) {
    return 'towards $place';
  }

  @override
  String get navToDestination => 'To destination';

  @override
  String navExitSemantics(String cue, String exit) {
    return '$cue, exit $exit';
  }

  @override
  String get navPickupAhead => 'Pickup ahead';

  @override
  String get navDropOffAhead => 'Drop-off ahead';

  @override
  String navPointAhead(String point) {
    return '$point ahead';
  }

  @override
  String get navToPickup => 'Navigate to pickup';

  @override
  String navToPoint(String point) {
    return 'Navigate to $point';
  }

  @override
  String get navDropOffLower => 'drop-off';

  @override
  String get navWaitingForRider => 'Waiting for rider';

  @override
  String get navRouteUpdating => 'Route updating…';

  @override
  String get navRouteRecalculating => 'Recalculating route…';

  @override
  String get navRouteUnavailableRetry => 'Route unavailable — retry';

  @override
  String get navRouteUnavailableLocation =>
      'Route unavailable — check location';

  @override
  String get licensePlateNumber => 'License plate number';

  @override
  String get createAccount => 'Create account';

  @override
  String get enterValidPhoneForCode =>
      'Enter a valid phone number where we will send a verification code';

  @override
  String get fullName => 'Full name';

  @override
  String get emailAddress => 'Email address';

  @override
  String get acceptTermsAndPrivacy => 'Accept terms and privacy policy';

  @override
  String get byContinuingIAgreeTo => ' By continuing, I agree to the ';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get andWord => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get phoneVerification => 'Phone verification';

  @override
  String get codeDeliveryUnavailableDemo =>
      'Code delivery is unavailable in this demo';

  @override
  String get accountVerificationNeedsService =>
      ' Account verification requires the account service.';

  @override
  String get didNotGetCode => 'Didn’t get the code?';

  @override
  String get signInUnavailableInPreview => 'Sign in unavailable in preview';

  @override
  String get verificationUnavailableDemo =>
      'Verification is unavailable in this demo.';

  @override
  String get signIn => 'Sign in';

  @override
  String get welcomeBackRiding => 'Welcome back! Let’s get you riding';

  @override
  String get continueWithPhone => 'Continue with phone';

  @override
  String get continueWithApple => 'Continue with apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get signInWithPhone => 'Sign in with phone number';

  @override
  String get phoneSignInUnavailableDemo =>
      'Phone sign-in is unavailable in this demo. No verification code is sent.';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get phoneSignInNeedsService =>
      'Phone sign-in requires the account service.';

  @override
  String get socialSignInNeedsService =>
      'Apple and Google sign-in require the account service.';

  @override
  String get enterValidPhoneWeWillSend =>
      'Enter a valid phone number where we will send';

  @override
  String get insurance => 'Insurance';

  @override
  String get todayLower => 'today';

  @override
  String get tomorrowLower => 'tomorrow';

  @override
  String inDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get docInsuranceLetter => 'Insurance letter';

  @override
  String get docTaxiDriverLicense => 'Taxi driver license';

  @override
  String get docTaxiLicenseShort => 'Taxi license';

  @override
  String get docRegistrationCertificate => 'Registration certificate';

  @override
  String get docRegistrationShort => 'Registration';

  @override
  String get docDriversLicense => 'Driver\'s License';

  @override
  String get docVehicleVerification => 'Vehicle Verification';

  @override
  String get docDriversId => 'Driver\'s ID';

  @override
  String get docExpiredCantGoOnline => 'Expired · You can’t go online';

  @override
  String docExpiresWhenDate(String when, String date) {
    return 'Expires $when · $date';
  }

  @override
  String docNewTitle(String title) {
    return 'New $title';
  }

  @override
  String get docTakeClearPhoto =>
      'Take a clear photo of the whole document. Movera checks it before it counts.';

  @override
  String get docSendNew => 'Send new document';

  @override
  String get docDemoNoFileLeaves => 'Demo: no file leaves the phone.';

  @override
  String get docSentForReview => 'Sent for review';

  @override
  String docTitleExpired(String title) {
    return '$title expired';
  }

  @override
  String get youCanGoOnlineNow => 'You can go online now.';

  @override
  String get docNewInReviewGoOnlineWhenApproved =>
      'Your new document is in review. You can go online when Movera approves it.';

  @override
  String get docUploadNewGoOnlineWhenApproved =>
      'Upload a new one. You can go online when Movera approves it.';

  @override
  String get approveDemo => 'Approve (demo)';

  @override
  String get uploadNew => 'Upload new';

  @override
  String get documents => 'Documents';

  @override
  String get docTermsAndConditions => 'Terms and Conditions';

  @override
  String get docVirtualInfoSession => 'Virtual information session';

  @override
  String get docDriversLicenseLower => 'Driver’s license';

  @override
  String get docProfilePhoto => 'Profile photo';

  @override
  String get docCompanyRegistration => 'Company registration';

  @override
  String get docCompanyRegistrationNote =>
      'Bolagsverket or Skatteverket extract. Not needed with a Fleet Partner.';

  @override
  String get docTaxiTrafficPermit => 'Taxi traffic permit';

  @override
  String get docTaxSettings => 'Tax settings';

  @override
  String get docBankStatement => 'Bank statement';

  @override
  String get docFrontPage => 'Front page';

  @override
  String get docStockholmTrips => 'Stockholm · Trips';

  @override
  String get docEarnAnywhereSweden => 'Earn anywhere in Sweden';

  @override
  String get docSampleListNotice =>
      'Sample list · Sending these documents is not available in the app yet. Nothing here was uploaded or reviewed.';

  @override
  String docApprovedOfTotal(int approved, int total) {
    return '$approved of $total approved';
  }

  @override
  String docLeftCount(int count) {
    return '$count left';
  }

  @override
  String get vehicle => 'Vehicle';

  @override
  String get docPreviewNotAvailable =>
      'Not available yet — sample page. Sending this document is not part of the app yet. No document was uploaded or reviewed.';

  @override
  String schedRidesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rides hidden',
      one: '1 ride hidden',
    );
    return '$_temp0';
  }

  @override
  String schedClashBody(String time) {
    return 'It clashes with your $time pickup: not enough time to get there.';
  }

  @override
  String get reminder => 'Reminder';

  @override
  String get schedAvailableToday => 'Available today';

  @override
  String get schedUpcoming => 'Upcoming';

  @override
  String get schedPreviewNotBinding =>
      'Preview — not binding. Decisions last until the app restarts.';

  @override
  String get schedNoneYet =>
      'No scheduled rides yet. Reservations from Movera will show up here.';

  @override
  String schedAcceptedPickupAt(String time) {
    return 'Accepted · pickup $time';
  }

  @override
  String get laterLower => 'later';

  @override
  String get schedReservationCancelled => 'Reservation cancelled';

  @override
  String get schedPlanAhead => 'Plan ahead and choose your next trip';

  @override
  String get schedRequestsTab => 'Requests';

  @override
  String get schedAcceptedTab => 'Accepted';

  @override
  String schedSeedTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String schedPickupTomorrowAt(String time) {
    return 'Pickup tomorrow at $time';
  }

  @override
  String schedBackupNote(String time) {
    return 'Your $time pickup was given to a backup driver.';
  }

  @override
  String get schedSampleReservation => 'Sample reservation';

  @override
  String get schedReservationDetails => 'Reservation details';

  @override
  String get schedIllustrativeRoute => 'Illustrative route — sample data';

  @override
  String get schedViewRoute => 'View reservation route';

  @override
  String get schedDemoAccepted => 'Demo accepted';

  @override
  String get schedAvailable => 'Available';

  @override
  String get rideTypeLabel => 'Ride type';

  @override
  String get trip2 => 'Trip';

  @override
  String get route => 'Route';

  @override
  String get schedBeforeThisRide => 'Before this ride';

  @override
  String get goodToKnow => 'Good to know';

  @override
  String get schedBeReadyEarly => 'Be ready early';

  @override
  String schedGoOnlineMinBefore(String minutes) {
    return 'Go online $minutes min before pickup so the app can guide you in time.';
  }

  @override
  String get schedTripsOnTheWay => 'Trips on the way';

  @override
  String get schedOnlyTripsToward =>
      'Before pickup you only get trips that head toward it and leave time to get there.';

  @override
  String get schedStillReceiveRides =>
      'You can still receive suitable rides before the scheduled pickup.';

  @override
  String get schedPlansChanged => 'Plans changed?';

  @override
  String schedDriversNeverPay(String line) {
    return '$line Drivers never pay to cancel.';
  }

  @override
  String get schedLocalPreviewCancel =>
      'This is a local preview. Cancelling removes the sample reservation until the app restarts.';

  @override
  String get schedReservedForYou => 'Reserved for you';

  @override
  String get schedKeepInAccepted =>
      'We’ll keep this ride in your Accepted list. If you cancel, you’ll be asked for a reason before anything changes.';

  @override
  String get schedCancelReservation => 'Cancel reservation';

  @override
  String schedAcceptPrice(String price) {
    return 'Accept  •  $price';
  }

  @override
  String get chooseBestReason => 'Choose the reason that best matches.';

  @override
  String get schedCancelThisReservation => 'Cancel this reservation?';

  @override
  String get schedReasonDoesntCount => 'This reason doesn’t count against you.';

  @override
  String get schedRemovesSample =>
      'This removes the sample reservation from this session. It does not cancel a real booking or change account access.';

  @override
  String get schedKeepReservation => 'Keep reservation';

  @override
  String tomorrowAtClock(String clock) {
    return 'tomorrow $clock';
  }

  @override
  String schedFreeCancelHoursBefore(String hours) {
    return 'Free cancel until $hours h before pickup.';
  }

  @override
  String schedLateCancelUnder(String hours) {
    return 'Late cancel: under $hours h to pickup.';
  }

  @override
  String schedFreeCancelUntil(String time) {
    return 'Free cancel until $time.';
  }

  @override
  String get schedRidesAreOff => 'Scheduled rides are off';

  @override
  String schedRidesOffUntil(String date) {
    return 'Scheduled rides off until $date';
  }

  @override
  String schedRidesPausedUntil(String date) {
    return 'Scheduled rides paused until $date';
  }

  @override
  String get schedOffInYourArea =>
      'Movera paused new scheduled rides in your area. Rides you already accepted still go ahead.';

  @override
  String get schedTurnedOffByMovera =>
      'Movera turned off Scheduled rides for your account. Contact support if you have questions.';

  @override
  String schedLateCancelsInDays(String count, String days) {
    return 'You had $count late cancels in $days days. Your accepted rides stay.';
  }

  @override
  String get schedNeverPayLateCounts =>
      'You never pay to cancel, but this late cancel counts.';

  @override
  String schedNeverPayUnderHours(String hours) {
    return 'You never pay to cancel. Under $hours h to pickup a cancel is late and counts toward a pause.';
  }

  @override
  String schedLateCancelPauses(String count, String days, String date) {
    return 'This is a late cancel ($count in $days days). Scheduled rides pause until $date.';
  }

  @override
  String get schedLateCancelCounts =>
      'This is a late cancel and it counts. You never pay.';

  @override
  String get schedAcceptedBadge => 'Accepted';

  @override
  String get supportCatTripRider => 'Trip & rider';

  @override
  String get supportCatWallet => 'Wallet & payments';

  @override
  String get supportCatAccount => 'Account & documents';

  @override
  String get supportCatTechnical => 'Technical issue';

  @override
  String get supportLocalDraftBadge => 'LOCAL DRAFT';

  @override
  String get supportCouldNotRecover =>
      'Could not recover local support. Retry.';

  @override
  String get supportCouldNotSaveConversation =>
      'Could not save local conversation. Retry.';

  @override
  String get supportCouldNotLoadDraft => 'Could not load the local draft.';

  @override
  String get supportCouldNotSaveDraft => 'Could not save local draft.';

  @override
  String get supportLocalTicketDraft => 'Local ticket draft';

  @override
  String get category => 'Category';

  @override
  String get subject => 'Subject';

  @override
  String get enterSubject => 'Enter a subject';

  @override
  String get tellUsWhatHappened => 'Tell us what happened';

  @override
  String get enterMessage => 'Enter a message';

  @override
  String get supportCouldNotSaveTicket => 'Could not save local ticket. Retry.';

  @override
  String get supportSavingDraft => 'Saving local draft…';

  @override
  String get supportSaveDraftDemo => 'Save draft in demo';

  @override
  String get supportTicketSavedDraftNotCleared =>
      'Ticket saved locally, but the composer draft could not be cleared.';

  @override
  String get supportDemo => 'Support demo';

  @override
  String get supportDraftLocalTicket => 'Draft local ticket';

  @override
  String get supportLocalPreview => 'Local support preview';

  @override
  String get supportLocalDraftsNoService =>
      'Local drafts on this device — no support service.';

  @override
  String get supportCouldNotLoadRetry => 'Could not load local support — Retry';

  @override
  String get supportRecoverPreserve =>
      'Recover local support (preserve unreadable data)';

  @override
  String get supportYourConversations => 'Your conversations';

  @override
  String supportLocalDraftSubject(String subject) {
    return 'Local draft: $subject';
  }

  @override
  String get supportWriteLocalDraft => 'Write a local draft';

  @override
  String get supportSaveLocalReply => 'Save local reply';

  @override
  String get promoWeekdayPeak => 'Weekday peak';

  @override
  String get promoWeekdayPeakDetail =>
      'Complete 8 trips between 07:00 and 09:00.';

  @override
  String get promoWeekdayPeakWindow => 'Mon–Fri · this week';

  @override
  String get promoAirportRuns => 'Airport runs';

  @override
  String get promoAirportRunsDetail => 'Two airport trips in the same day.';

  @override
  String get promoUntilSunday => 'Until Sunday';

  @override
  String get promoEveningHours => 'Evening hours';

  @override
  String get promoEveningHoursDetail => 'Stay online for 3 hours after 18:00.';

  @override
  String get promoTonight => 'Tonight';

  @override
  String promoDemoCodeCopied(String code) {
    return 'Demo code $code copied';
  }

  @override
  String get promoCouldNotCopy => 'Could not copy the code. Please try again.';

  @override
  String get promoPreviewTitle => 'Promotions preview';

  @override
  String get preview => 'Preview';

  @override
  String get promoSavedTab => 'Saved';

  @override
  String get promoNothingSaved => 'Nothing saved yet';

  @override
  String get promoSave => 'Save';

  @override
  String get vehicles => 'Vehicles';

  @override
  String get addVehicle => 'Add vehicle';

  @override
  String get vehCouldNotLoadDrafts =>
      'Could not load local vehicle drafts — Retry';

  @override
  String get vehLocalDraftsNotVerified =>
      'Local vehicle drafts — not activated or verified';

  @override
  String get vehTripsOnly => 'Trips only';

  @override
  String get vehManageVehicles => 'Manage vehicles';

  @override
  String get vehExploreOpportunities => 'Explore vehicle opportunities';

  @override
  String get vehConnectFleetPartner =>
      'Connect with a fleet partner or browse rental or purchase offers if you need another vehicle.';

  @override
  String get vehCouldNotSaveDraft =>
      'Could not save local vehicle draft. Retry.';

  @override
  String get year => 'Year';

  @override
  String get vehRequirements => 'Vehicle requirements';

  @override
  String get vehRequirementsBody =>
      'To drive with Movera, you need a vehicle that is 1990 or newer, and not salvaged.';

  @override
  String get vehEnterInformation => 'Enter your vehicle information';

  @override
  String get make => 'Make';

  @override
  String get searchByMake => 'Search by make';

  @override
  String get model => 'Model';

  @override
  String get searchByModel => 'Search by model';

  @override
  String get selectEllipsis => 'Select...';

  @override
  String get requiredMark => '* Required';

  @override
  String get vehPhotoCouldNotSave => 'Photo could not be saved locally. Retry.';

  @override
  String get vehRemoveDraftQ => 'Remove local vehicle draft?';

  @override
  String vehRemovesNameAndPhotos(String name) {
    return 'This removes $name and its saved document photos from this device.';
  }

  @override
  String get vehKeepVehicle => 'Keep vehicle';

  @override
  String get vehRemoveVehicle => 'Remove vehicle';

  @override
  String get vehCouldNotRemoveDraft => 'Could not remove local draft. Retry.';

  @override
  String get vehPhotosStayOnDevice =>
      'Document photos stay on this device. No upload or verification service is connected.';

  @override
  String get vehCouldNotLoadDocuments =>
      'Could not load local vehicle documents.';

  @override
  String get vehDraftNoLongerAvailable =>
      'This local vehicle draft is no longer available.';

  @override
  String get vehRegistrationCertFront =>
      'Vehicle Registration Certificate (Front Page)';

  @override
  String get vehSavedLocallyNotVerified => 'Saved locally — not verified';

  @override
  String get vehRecommendedNextStep => 'Recommended next step';

  @override
  String get vehTakePhotoRegistration =>
      'Take a photo of your Vehicle Registration Certificate (Front Page)';

  @override
  String get vehDocBlueBlackWhite =>
      'The document should be blue, black and white.';

  @override
  String get vehAllFourCorners => 'All four corners are visible.';

  @override
  String get vehInsuranceLetter => 'Insurance Letter';

  @override
  String get vehTakePhotoInsurance => 'Take a photo of your Insurance Letter';

  @override
  String get vehInsuranceShowsTaxi =>
      'The document shows the car’s registration number and that it is registered as a taxi.';

  @override
  String get vehInsuranceDatesVisible =>
      'The start and end dates of the insurance are visible.';

  @override
  String get vehSavedPhotoCannotDisplay =>
      'Saved photo cannot be displayed. Retake this document photo.';

  @override
  String get vehPhotoTooLarge =>
      'Photo is too large to keep on this device. Retake it closer and with less detail.';

  @override
  String get vehCameraNotAvailable =>
      'Camera is not available in this preview.';

  @override
  String get vehBeforeSavingCheck =>
      'Before saving the local photo, check the following:';

  @override
  String get takingPhoto => 'Taking photo…';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get promoSaved => 'Saved';

  @override
  String get prefStandardEveryday => 'Standard • Everyday ride';

  @override
  String get prefExtraComfort => 'Extra comfort • Plush';

  @override
  String get prefLuxuryPremium => 'Luxury • Premium service';

  @override
  String get prefFasterPickup => 'Faster pickup • Priority';

  @override
  String get prefSixSeat => '6 seat • Spacious';

  @override
  String get prefLowEmissions => 'Low emissions • Eco';

  @override
  String get prefPetFriendly => 'Pet friendly • Carrier OK';

  @override
  String get prefChildSeat => 'Child seat • Kids safe';

  @override
  String prefCategoriesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ride categories saved',
      one: '1 ride category saved',
    );
    return '$_temp0';
  }

  @override
  String prefActiveOfTotal(int active, int total) {
    return '$active of $total active';
  }

  @override
  String get prefChooseRideOptions => 'Choose your ride options';

  @override
  String get prefSelectRideTypes =>
      'Select the ride types you\'d like available for your trips';

  @override
  String get prefMoveraSetsFromCar =>
      'Movera sets these from your car. Switch off any you don’t want.';

  @override
  String get prefSave => 'Save preferences';

  @override
  String get safetyContactEmergencyQ => 'Contact emergency services?';

  @override
  String get safetyUse112Only =>
      'Use 112 only when you or someone else needs immediate help.';

  @override
  String get rideCheckSosSentWithPosition => '\nSOS sent with your position.';

  @override
  String get safetySos => 'SOS';

  @override
  String get safetySosHint => 'Calls 112 and alerts Movera';

  @override
  String get safetySosQ => 'Send SOS?';

  @override
  String get safetySosBody =>
      'Movera\'s safety team is alerted with your position, and your phone opens 112.';

  @override
  String get safetySosSend => 'Send SOS';

  @override
  String get safetySosSent => 'SOS sent';

  @override
  String get safetySosSentNoDialer =>
      'SOS sent. Could not open the dialer: dial 112 on your phone.';

  @override
  String get safetySosNotSent => 'SOS could not reach Movera. Call 112.';

  @override
  String get safetySosNoTrip => 'SOS to Movera works during a trip. Call 112.';

  @override
  String get safetyDialerOpened =>
      'Emergency dialer opened — confirm the call on your device.';

  @override
  String get safetyDialerAskedBrowser =>
      'Your browser was asked to call 112. If no call starts, dial 112 on your phone.';

  @override
  String get safetyAudioUnavailable =>
      'Audio recording is unavailable in this demo.';

  @override
  String get safetyTripSharingUnavailable =>
      'Trip sharing is unavailable in this demo.';

  @override
  String get safetyPreferences => 'Safety preferences';

  @override
  String get safetyRideCheckOnOthersPreview =>
      'Ride check is on. The others are preview only.';

  @override
  String get safetyUnavailableWithoutVerification =>
      'Unavailable without account verification';

  @override
  String get safetyAutoTripSharing => 'Automatic trip sharing';

  @override
  String get safetyUnavailableWithoutSharing =>
      'Unavailable without a sharing service';

  @override
  String get safetyOnSetByMovera => 'On · set by Movera for every trip';

  @override
  String get safetyOn => 'On';

  @override
  String get safetyRideCheckExplained =>
      'On for every trip. Asks \"Is everything OK?\" after a long stop, a drop-off far from the destination, a big detour or a very hard stop.';

  @override
  String get safetyTools => 'Safety tools';

  @override
  String get safetyQuickTools =>
      'Quick tools designed to protect you during every ride.';

  @override
  String get safetyContact112 => 'Contact 112';

  @override
  String get safetyShareTripHint => 'Show someone where you are';

  @override
  String get safetyShareTrip => 'Share trip';

  @override
  String get safetyRideCheckOnPreviewOnly =>
      'Ride check on · the others are preview only';

  @override
  String get destChooseOneAddress => 'Choose one address';

  @override
  String get destTripsInYourDirection => 'Trips in your direction';

  @override
  String get destMoveraPrioritizes =>
      'Movera will prioritize requests that keep you moving toward this address.';

  @override
  String get destAddAddress => 'Add destination address';

  @override
  String get destSuggestedAddresses => 'Suggested addresses';

  @override
  String get destResults => 'Results';

  @override
  String get destNoAddressFound => 'No address found';

  @override
  String get destTryAnother => 'Try another street, place, or area.';

  @override
  String get destFastestRoute => 'Fastest route to your destination';

  @override
  String destOnlyTripsYourWay(String place) {
    return 'You\'ll only get trips heading your way, so every ride takes you closer to $place.';
  }

  @override
  String destArriveBy(String time) {
    return 'Arrive by $time';
  }

  @override
  String get destConfirm => 'Confirm destination';

  @override
  String get waybillLocalDemo => 'Local demo';

  @override
  String get waybillDemoRadar => 'Demo Radar';

  @override
  String get demoDriverIdentityUnavailable =>
      'Demo driver — identity unavailable';

  @override
  String get vehicleDataUnavailable => 'Vehicle data unavailable';

  @override
  String get plateUnavailable => 'Plate unavailable';

  @override
  String positionOfCount(int position, int count) {
    return '$position of $count';
  }

  @override
  String get rrMatchingTrip => 'Matching trip';

  @override
  String get rrConfirmingRealTime => 'Confirming this request in real time…';

  @override
  String get rrCouldNotMatch => 'Could not match trip. Try again.';

  @override
  String get rrConnectionInterrupted =>
      'Connection interrupted. You can retry this request.';

  @override
  String get rrAssignedOpening =>
      'You’re assigned to this request. Opening trip…';

  @override
  String get rrAnotherMatchedFirst => 'Another driver matched this trip first.';

  @override
  String get rrNoLongerOnRadar => 'This trip is no longer on Radar.';

  @override
  String rrTripsTowardPickup(String time) {
    return 'Trips toward your $time pickup';
  }

  @override
  String get rrLive => 'Live';

  @override
  String rrFreshNew(int count) {
    return '$count new';
  }

  @override
  String get rrNew => 'New';

  @override
  String get rrDestinationRoute => 'Destination route';

  @override
  String rrTripsToward(String place) {
    return 'Trips toward $place';
  }

  @override
  String get rrScanningNearby => 'Scanning nearby';

  @override
  String get rrNewTripsAppear =>
      'New trips will appear here when the radar finds requests around you.';

  @override
  String get moveraDriver => 'Movera Driver';

  @override
  String get legalPrivacyBody =>
      'Movera Driver uses location, trip and vehicle data to assign rides, show routes and keep a waybill on this device.\n\nDemo builds keep this information in memory on the phone. Nothing is sold to advertisers. You can log out at any time from Profile.\n\nWhen a live backend is connected, the same screens will keep using this policy text until a signed version is published.';

  @override
  String get legalTermsBody =>
      'You agree to drive only with a valid licence, insurance and a vehicle that matches the documents in this app.\n\nRadar offers are first-come. Matching another order while on a trip is optional. Completing a trip creates a waybill you can reopen from Home.\n\nMovera may suspend a demo account that misuses Safety tools or emergency calling.\n\nCrash and error reports: when the app crashes or shows an error, it automatically sends a report to Movera so we can fix it: the error, where in the app it happened, the app version, the platform and the time. Names, phone numbers, e-mail addresses, addresses and locations are removed before the report leaves your device. Reports are kept for 30 days.';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get termsOfService => 'Terms of service';

  @override
  String get profSampleDriver => 'Sample driver profile';

  @override
  String get profDemoNoVerified => 'Demo — no verified account';

  @override
  String get analytics => 'Analytics';

  @override
  String get myBank => 'My bank';

  @override
  String get helpCenter => 'Help center';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutQ => 'Log out?';

  @override
  String get profLogOutClears =>
      'Local preview data on this device will be cleared, including trip history, contacts, and drafts. You will return to the sign-in screen offline.';

  @override
  String get stay => 'Stay';

  @override
  String get profCouldNotClear =>
      'Could not clear local data. You are still signed in. Please retry.';

  @override
  String get anaPreview => 'Analytics preview';

  @override
  String get anaSample3Rides => 'Sample: 3 rides completed';

  @override
  String get anaSampleLastTrip => 'Sample last trip';

  @override
  String get anaSamplePerformance => 'Sample performance';

  @override
  String get anaCancel => 'Cancel';

  @override
  String get earnings => 'Earnings';

  @override
  String get anaSamePeriodHome => 'Same period as the home sheet';

  @override
  String get acceptanceRate => 'Acceptance rate';

  @override
  String anaSampleAcceptance(String rate) {
    return 'Sample · $rate of offers accepted';
  }

  @override
  String get cancellationRate => 'Cancellation rate';

  @override
  String anaSampleCancellation(String rate) {
    return 'Sample · $rate of accepted trips';
  }

  @override
  String get anaSampleStrongestArea => 'Sample strongest area';

  @override
  String get bankAddHolderName => 'Add the account holder’s name.';

  @override
  String get bankCheckIban =>
      'Check the IBAN format and check digits against your bank statement.';

  @override
  String get bankBicFormat => 'BIC / SWIFT has 8 or 11 letters and digits.';

  @override
  String get bankCheckClearing =>
      'Check the clearing number: 4 digits, or 5 starting with 8 for Swedbank.';

  @override
  String get bankAccountDigits => 'The account number has 6 to 10 digits.';

  @override
  String get bankPreviewNotSaved => 'Preview only — account not saved.';

  @override
  String get countrySweden => 'Sweden';

  @override
  String get international => 'International';

  @override
  String get bankAccount => 'Bank account';

  @override
  String get bankHolder => 'Holder';

  @override
  String get country => 'Country';

  @override
  String get bank => 'Bank';

  @override
  String get clearing => 'Clearing';

  @override
  String get bankUseIban =>
      'Use the IBAN on your bank statement. Foreign IBANs show a country code; no bank connection is verified.';

  @override
  String get bankFoundFromClearing =>
      'The bank is found from the clearing number.';

  @override
  String get checkDetails => 'Check details';

  @override
  String get bankDemoNotSaved => 'Demo: account not saved or sent to a bank';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get filterAll => 'All';

  @override
  String get filterDemand => 'Demand';

  @override
  String get logsPreview => 'Driving log preview';

  @override
  String get logsSampleNotLive => 'Sample driving-time data · not live';

  @override
  String get logsSampleWeek => 'Sample week';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String logsOnlineFromTo(String from, String to) {
    return 'Online $from – $to';
  }

  @override
  String get logsSampleOnlineState => 'Sample online state';

  @override
  String get logsDemoCompliance =>
      'Demo compliance copy only. Driving and break limits are not connected to live account or regulatory data.';

  @override
  String get pinVerifyAll => 'Verify all trips';

  @override
  String get pinAskEveryPickup => 'Ask for the rider PIN on every pickup.';

  @override
  String get pinVerifySession => 'Verify this session';

  @override
  String get pinAskUntilOffline => 'Ask until you go offline.';

  @override
  String get pinDontVerify => 'Don’t verify';

  @override
  String get pinSkipOnDevice => 'Skip the PIN on this device.';

  @override
  String get pinPreviewNotSaved =>
      'PIN verification preview - this preference is not saved or enforced in the demo.';

  @override
  String get pinNotConnected =>
      'PIN verification is not connected in this demo.';

  @override
  String get bankPreviewAccountDetails => 'Preview account details';

  @override
  String get bankLocalPreviewOnly =>
      'Local preview only. No bank is connected, nothing is verified, and no payout is scheduled.';

  @override
  String get bankCheckInPreview =>
      'You can check account details in the preview form. Details are discarded when you leave the form; no payout account is connected.';

  @override
  String get emEmergencyServices112 => 'Emergency services — 112';

  @override
  String get emEmergency => 'Emergency';

  @override
  String get emAlreadyInContacts => 'This number is already in your contacts.';

  @override
  String get emFamily => 'Family';

  @override
  String get callUnavailableUseChat =>
      'Calls aren\'t available yet – use the chat';

  @override
  String get chatClosedAfterTrip => 'The chat is closed after the trip';

  @override
  String get chatLocalDemo =>
      'Local demo chat · messages are not sent to the rider.';

  @override
  String get chatSendMessageHint => 'send message...';

  @override
  String get chatSaveLocally => 'Save message locally';

  @override
  String get chatLocalNotSent => 'Local preview · not sent';

  @override
  String get chatSend => 'Send message';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatNotSentTapToRetry => 'Not sent · Tap to retry';

  @override
  String get chatSendFailed => 'Movera could not send your message. Try again.';

  @override
  String get chatHistoryFailed => 'Earlier messages could not be loaded.';

  @override
  String chatNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages from the rider',
      one: '1 new message from the rider',
    );
    return '$_temp0';
  }

  @override
  String get queueAirportPreview => 'Airport queue preview';

  @override
  String get queueSample10Ahead => 'Sample: 10 drivers ahead';

  @override
  String get queueViewSampleDetails => 'view sample details';

  @override
  String get queueClose => 'Close queue position';

  @override
  String get queueMyPosition => 'My Queue position';

  @override
  String get queueMediumWait => 'Medium Wait';

  @override
  String get queueSampleRank => 'Sample Rank';

  @override
  String get queueUnavailablePreview => 'Queue unavailable — preview';

  @override
  String get queueRanks => 'Ranks';

  @override
  String get earnTypeTab => 'Type';

  @override
  String get earnMoveraDemo => 'Movera demo';

  @override
  String get cancelRateTitle => 'Cancelation Rate';

  @override
  String get notYourRealRateYet => 'not your real rate yet';

  @override
  String get tripsConfirmed => 'Trips confirmed';

  @override
  String get completedTripsLower => 'completed trips';

  @override
  String get canceledTrips => 'Canceled trips';

  @override
  String get sampleNumbersNotReal =>
      'Sample numbers for this preview, not your real rate.';

  @override
  String get cancelRateKeepLow =>
      'Keep your cancel rate low to keep full access to trips';

  @override
  String get cancelRateEveryCancelCounts =>
      'Every cancel counts, except reasons marked “Doesn’t count”, such as a rider no-show or a safety issue.';

  @override
  String get moreInformation => 'More Information';

  @override
  String get cancelRateHowCalculated => 'How your cancelation is calculated';

  @override
  String get cancelRateHowBody =>
      'Your cancellation rate is calculated based on the number of trips you cancel compared to the total trips you confirm. We use your last 100 confirmed trip requests to determine this percentage.';

  @override
  String get cancelRateWhyMatters => 'Why cancelation rate matters';

  @override
  String get cancelRateWhyBody =>
      'A high cancellation rate affects the reliability of our service and can impact your ability to get ride requests. Maintaining a low cancellation rate helps ensure better service for all users.';

  @override
  String get acceptRateTitle => 'Acceptance Rate';

  @override
  String get exclusiveOffers => 'Exclusive offers';

  @override
  String get acceptedOffersLower => 'accepted offers';

  @override
  String get declinedOrMissed => 'declined or missed';

  @override
  String get acceptRateOnlyExclusive => 'Only Exclusive offers count';

  @override
  String get acceptRateExclusiveBody =>
      'Exclusive offers and other offers sent only to you count. Radar trips never count.';

  @override
  String get acceptRateHowCalculated =>
      'How your acceptance rate is calculated';

  @override
  String get acceptRateHowBody =>
      'Your acceptance rate is the Exclusive offers you accept compared with all the Exclusive offers you receive. Radar trips never count. We use your last 100 Exclusive offers.';

  @override
  String get acceptRateWhyMatters => 'Why acceptance rate matters';

  @override
  String get acceptRateWhyBody =>
      'A low acceptance rate reduces your chances of receiving ride requests and may affect your standing on the platform. Maintaining a high acceptance rate helps you get more trips and ensures a reliable experience for riders.';

  @override
  String get rcTriggerDroppedFar => 'Finished far from drop-off';

  @override
  String get rcTriggerLongStop => 'Long stop';

  @override
  String get rcTriggerOffRoute => 'Off the route';

  @override
  String get rcTriggerPossibleCrash => 'Possible crash';

  @override
  String get rcTopicAccident => 'Accident or collision';

  @override
  String get rcTopicHurt => 'Someone is hurt or feels ill';

  @override
  String get rcTopicUnsafe => 'I feel unsafe';

  @override
  String get rcTopicCarProblem => 'Car problem';

  @override
  String get rcTopicRiderAskedStop => 'The rider asked for a stop';

  @override
  String get rcTopicTraffic => 'Traffic or road works';

  @override
  String get rcTopicRiderStopHere => 'The rider asked to stop here';

  @override
  String get rcTopicRiderChangedDestination => 'The rider changed destination';

  @override
  String get rcTopicRoadClosed => 'Road closed or no access';

  @override
  String get rcTopicRiderOtherRoute => 'The rider asked for another route';

  @override
  String get rcShortAccident => 'Accident';

  @override
  String get rcShortHurt => 'Someone hurt';

  @override
  String get rcShortUnsafe => 'Unsafe';

  @override
  String get rcShortRiderStop => 'Rider stop';

  @override
  String get rcShortTraffic => 'Traffic';

  @override
  String get rcShortNewDestination => 'New destination';

  @override
  String get rcShortRoadClosed => 'Road closed';

  @override
  String get rcShortOtherRoute => 'Other route';

  @override
  String get rcQuestionAnyoneHurt => 'Is anyone hurt?';

  @override
  String get rcQuestionCarSafe => 'Is the car in a safe place?';

  @override
  String get rcQuestionOtherPersonOk => 'Is the other person OK?';

  @override
  String get rcQuestionWhoNeedsHelp => 'Who needs help?';

  @override
  String get rcQuestionInDanger => 'Are you in danger right now?';

  @override
  String get rcQuestionCanContinue => 'Can you continue the trip?';

  @override
  String get rcAnswerYes => 'Yes';

  @override
  String get rcAnswerNo => 'No';

  @override
  String get rcAnswerNotSure => 'Not sure';

  @override
  String get rcAnswerMe => 'Me';

  @override
  String get rcAnswerTheRider => 'The rider';

  @override
  String get rcAnswerSomeoneElse => 'Someone else';

  @override
  String get rcLongerLead => 'This trip is ';

  @override
  String rcPercent(int percent) {
    return '$percent%';
  }

  @override
  String get rcLongerTrail => ' longer than expected';

  @override
  String get rcStoppedLead => 'Your car has stopped for ';

  @override
  String rcMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get rcEndedLead => 'Your trip ended ';

  @override
  String rcEndedFromTrail(String place) {
    return ' from $place';
  }

  @override
  String get rcOffRouteLead => 'You are ';

  @override
  String get rcOffRouteTrail => ' off the route';

  @override
  String rcOffRouteToTrail(String place) {
    return ' off the route to $place';
  }

  @override
  String get rcCrashLead => 'A ';

  @override
  String get rcCrashBold => 'very hard stop';

  @override
  String get rcCrashTrail => ' was detected';

  @override
  String rcCrashTrailAt(String place) {
    return ' was detected · $place';
  }

  @override
  String get tipHighBoostNearby => 'High boost nearby';

  @override
  String get tipExpectTrip => 'Expect a trip in 2–5 min';

  @override
  String tipPromotionRides(String rides, String kr) {
    return 'Promotion · $rides rides = $kr kr';
  }

  @override
  String get tipBusyArea => 'Busy area · trips expected soon';

  @override
  String tipAirportQueue(String count) {
    return 'Airport queue: $count drivers';
  }

  @override
  String tipGoodStreak(String count) {
    return 'Good streak · $count trips in a row';
  }

  @override
  String get tipDemandRising => 'Demand rising near you';

  @override
  String tipPeakStart(String time) {
    return 'Peak hours start at $time';
  }

  @override
  String get tipTopZone => 'You\'re in a top zone right now';

  @override
  String get noticeNewScheduledRide => 'New scheduled ride';

  @override
  String noticeScheduledBody(String day, String time, String fare) {
    return '$day $time · $fare · Tap to view';
  }

  @override
  String get view => 'View';

  @override
  String noticeSecondsToAccept(int seconds) {
    return '$seconds s to accept';
  }

  @override
  String noticeHighDemandIn(String area) {
    return 'High demand in $area';
  }

  @override
  String get noticeGoOnlineNow => 'Go online now';

  @override
  String noticeDocExpires(String title, String when) {
    return '$title expires $when';
  }

  @override
  String get noticeUploadNewKeepDriving =>
      'Upload a new one so you can keep driving.';

  @override
  String noticeDocApprovedBody(String title) {
    return '$title approved. You can go online.';
  }

  @override
  String get noticeCanGoOnlineAgain => 'You can go online again.';

  @override
  String noticeTooManyLateCancels(String date) {
    return 'Too many late cancels. Back on $date.';
  }

  @override
  String get rcWhatHappened => 'What happened';

  @override
  String get rcCalled112 => 'Called 112';

  @override
  String get rcDialer112 => '112 dialer:';

  @override
  String get rcDialerOpened => 'opened';

  @override
  String get rcDialerDidNotOpen => 'did not open';

  @override
  String get selectCountry => 'Select Country';

  @override
  String get searchCountry => 'Search Country';

  @override
  String get colorRed => 'Red';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorWhite => 'White';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorSilver => 'Silver';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorPink => 'Pink';

  @override
  String get chooseVehicleColor => 'Choose vehicle color';

  @override
  String get closeColorPicker => 'Close color picker';

  @override
  String get mapCameraUnavailable =>
      'Map camera unavailable — tap recenter to retry';

  @override
  String get dismiss => 'Dismiss';

  @override
  String ratingAndRides(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rides',
      one: '1 ride',
    );
    return '$rating ★ · $_temp0';
  }

  @override
  String mapOfArea(String area) {
    return 'Map of $area';
  }

  @override
  String get cashYouOweMovera => 'You owe Movera';

  @override
  String get cashMoveraOwesYou => 'Movera owes you';

  @override
  String get cashSettled => 'Settled';

  @override
  String stopNext(String stop) {
    return '$stop next';
  }

  @override
  String get pickupOnLeftSide => 'Pickup on the left side';

  @override
  String get pickupOnRightSide => 'Pickup on the right side';

  @override
  String get moveWithin100MOfPickup =>
      'Move within 100 m of the pickup to arrive.';

  @override
  String get moveWithin100MOfStop => 'Move within 100 m of the stop to arrive.';

  @override
  String get recordAudioStarting => 'starting…';

  @override
  String get photoTooLargeForDevice =>
      'Photo is too large to keep on this device.';

  @override
  String get photoStorageFull =>
      'Photo storage on this device is full. Remove photos from another vehicle first.';

  @override
  String get demoDataBadge => 'DEMO DATA';

  @override
  String get drivingInHeader => 'DRIVING IN';

  @override
  String get anaSampleTripRoute => 'Central Station → Södermalm';

  @override
  String get demandBusy => 'Busy';

  @override
  String get demandSteady => 'Steady';

  @override
  String get demandQuiet => 'Quiet';

  @override
  String get aroundStockholm => 'Around Stockholm';

  @override
  String get noticeBonusProgressTitle => 'Bonus progress';

  @override
  String noticeBonusProgressBody(
    String done,
    String goal,
    String left,
    String amount,
  ) {
    return '$done of $goal trips this week. $left more for $amount.';
  }

  @override
  String get noticePayoutSentTitle => 'Payout sent';

  @override
  String noticePayoutSentBody(String amount) {
    return '$amount is on its way to your bank.';
  }

  @override
  String get signInOr => 'or';

  @override
  String destResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count found',
      one: '1 found',
    );
    return '$_temp0';
  }

  @override
  String get queueEstimatedWait => 'About 15–30 min wait';

  @override
  String get queueDriversAhead => 'Drivers ahead';

  @override
  String get paymentCard => 'Card';

  @override
  String get offersBadge => 'OFFERS';

  @override
  String get bankAccountSection => 'ACCOUNT';

  @override
  String get locationNotAllowed =>
      'Movera can\'t see your location, so trips can\'t reach you.';

  @override
  String get allowLocation => 'Allow';

  @override
  String get locationBlockedSettings =>
      'Location is blocked for Movera. Allow it in Settings to get trips.';

  @override
  String get authDriverWord => 'Driver';

  @override
  String get authBrandTagline => 'Moving to a new era.';

  @override
  String get authEnterPhone => 'Enter your phone number';

  @override
  String get authTextFourDigitCode => 'We\'ll text you a 4-digit code.';

  @override
  String get authInvalidMobileNumber => 'Enter a valid mobile number.';

  @override
  String get authConsentLabel => 'I accept the terms and the privacy policy';

  @override
  String get authConsentPrefix => 'By continuing you accept the ';

  @override
  String get authConsentTerms => 'terms';

  @override
  String get authAnd => ' and ';

  @override
  String get authConsentPrivacy => 'privacy policy';

  @override
  String get authConsentTickFirst =>
      'Tick the box to agree before you continue.';

  @override
  String get authContinue => 'Continue';

  @override
  String authStepOf(Object step, Object total) {
    return 'Step $step of $total';
  }

  @override
  String get authChangeLanguage => 'Change language';

  @override
  String get authChooseCountry => 'Choose your country';

  @override
  String get authSearchCountry => 'Search country or code';

  @override
  String get authNoCountryFound => 'No country matches your search.';

  @override
  String authPhoneCountryCode(Object country, Object dial) {
    return 'Country code: $country, $dial';
  }

  @override
  String get authChangeCountryCode => 'Change country';

  @override
  String get authEnterYourCodeHead => 'Enter your ';

  @override
  String get authEnterYourCodeAccent => 'code';

  @override
  String get authCodeSentToPhone => 'We\'ve sent a code to your phone.';

  @override
  String get authSentTo => 'Sent to ';

  @override
  String get authNewCodeSent => 'New code sent.';

  @override
  String get authReenterPhone => 'Go back and enter your phone number again.';

  @override
  String get authRequestNewCode => 'Go back and request a new code.';

  @override
  String get authNeverAskCode =>
      'Movera will never call or text you asking for this code.';

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCodeIn => 'Resend code in ';

  @override
  String get authResendCode => 'Resend code';

  @override
  String get authErrOffline =>
      'No connection. Check your internet and try again.';

  @override
  String get authErrTooManyWait =>
      'Too many tries. Wait a moment and try again.';

  @override
  String authErrTooManyIn(Object wait) {
    return 'Too many tries. Try again in $wait.';
  }

  @override
  String authRetrySeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get authErrServer =>
      'Movera is having trouble right now. Try again in a moment.';

  @override
  String get authErrWrongCode =>
      'That code isn\'t right. Check it and try again.';

  @override
  String get authCodeExpired =>
      'This code has expired. Tap Resend code for a new one.';

  @override
  String get authErrSendCode => 'Couldn\'t send the code. Try again.';

  @override
  String get authErrCheckCode => 'Couldn\'t check the code. Try again.';

  @override
  String get authSignInRestricted =>
      'This number isn’t open for sign-in yet. Join the waiting list and we’ll let you know.';

  @override
  String get acctDetailsTitle => 'Your details';

  @override
  String get acctDetailsIntro =>
      'Movera checks these before you can drive. Fill them in once.';

  @override
  String get acctFirstName => 'First name';

  @override
  String get acctLastName => 'Last name';

  @override
  String get acctDateOfBirth => 'Date of birth';

  @override
  String get acctPickDate => 'Pick a date';

  @override
  String get acctEmail => 'E-mail';

  @override
  String get acctCountry => 'Country';

  @override
  String get acctCity => 'City';

  @override
  String get acctChooseCity => 'Choose your city';

  @override
  String get acctLanguage => 'Language';

  @override
  String get acctAccountType => 'Account type';

  @override
  String get acctComingSoon => 'Coming soon';

  @override
  String get acctCountrySweden => 'Sweden';

  @override
  String get acctCountryFrance => 'France';

  @override
  String get acctCountryTunisia => 'Tunisia';

  @override
  String get acctTypeDriverTitle => 'Driver';

  @override
  String get acctTypeDriverBody => 'I drive for a fleet';

  @override
  String get acctTypeFleetTitle => 'Fleet';

  @override
  String get acctTypeFleetBody => 'I run a company with cars and drivers';

  @override
  String get acctCompanyName => 'Company name';

  @override
  String get acctOrgNumberSe => 'Organisation number';

  @override
  String get acctOrgNumberFr => 'SIREN';

  @override
  String get acctCompanyAddress => 'Company address';

  @override
  String get acctJoinNow => 'Join your fleet now';

  @override
  String get acctJoinNowBody =>
      'Your fleet owner shares a Movera code with you. You can also do this later from Profile › My fleet.';

  @override
  String get acctFleetCode => 'Fleet code';

  @override
  String get acctOwnerName => 'Owner’s full name';

  @override
  String get acctOwnerEmail => 'Owner’s e-mail';

  @override
  String get acctRequired => 'Required';

  @override
  String acctUnderAge(int age) {
    return 'You must be at least $age to drive with Movera.';
  }

  @override
  String get acctInvalidDate => 'Enter a valid date.';

  @override
  String get acctInvalidEmail => 'Enter a valid e-mail.';

  @override
  String get acctCountryNotOpen => 'Movera is not open in this country yet.';

  @override
  String get acctInvalidCity => 'Choose a city of your country.';

  @override
  String get acctTermsRequired => 'Accept the terms to continue.';

  @override
  String get acctCompanyRequired => 'Fill in your company’s details.';

  @override
  String get acctDetailsLocked =>
      'Your details are already approved. Contact support to change them.';

  @override
  String get acctCouldNotSend => 'Couldn’t send your details. Try again.';

  @override
  String get acctTooManyTriesHour =>
      'Too many tries. Wait about an hour and try again.';

  @override
  String get acctChangedReload =>
      'Your account changed meanwhile. Pull to refresh and try again.';

  @override
  String get acctCouldNotLoad => 'Couldn’t load your account.';

  @override
  String get acctTryAgain => 'Something went wrong. Try again.';

  @override
  String get holdBeingChecked =>
      'Your account is being checked. Upload your documents; we tell you when you can drive.';

  @override
  String get holdWaitingFleetVehicle =>
      'Waiting for your fleet’s vehicle details';

  @override
  String get myFleet => 'My fleet';

  @override
  String get docYou => 'You';

  @override
  String get docCompany => 'Company';

  @override
  String docCar(Object plate) {
    return 'Car $plate';
  }

  @override
  String get docMoveraBooks => 'Movera books this with you';

  @override
  String get docTakePhoto => 'Take photo';

  @override
  String get docChoosePhoto => 'Choose photo';

  @override
  String get docChoosePdf => 'Choose PDF';

  @override
  String get docUploading => 'Uploading…';

  @override
  String get docUploaded => 'Uploaded. Movera checks it.';

  @override
  String get docUploadFailed => 'Couldn’t upload. Try again.';

  @override
  String get docFileTooLarge => 'The file is larger than 10 MB.';

  @override
  String get docUnsupportedFile => 'Send a JPEG, PNG, HEIC or PDF.';

  @override
  String get docEmptyFile => 'The file is empty.';

  @override
  String get docTypeNotAccepted => 'This document can’t be uploaded here.';

  @override
  String get docCouldNotLoad => 'Couldn’t load your documents.';

  @override
  String get docNoneYet => 'Nothing to upload yet.';

  @override
  String get docUploadNew => 'Upload a new one';

  @override
  String get fleetJoinTitle => 'Join your fleet';

  @override
  String get fleetJoinBody =>
      'Your fleet owner shares the Movera code with you. Enter it with the owner’s name and e-mail as registered with Movera.';

  @override
  String get fleetJoin => 'Join';

  @override
  String fleetJoined(Object name) {
    return 'You’re in $name.';
  }

  @override
  String get fleetJoinMismatch =>
      'The code, the owner’s name and e-mail don’t match a fleet. Check them with your fleet owner.';

  @override
  String get fleetAlreadyIn => 'You’re already in a fleet. Leave it first.';

  @override
  String get fleetAccountHasOwn => 'A fleet account has its own fleet.';

  @override
  String get fleetOnTrip => 'Finish the trip first.';

  @override
  String get fleetOwnerCannotLeave => 'The owner can’t leave the fleet.';

  @override
  String get fleetNotInOne => 'You’re not in a fleet.';

  @override
  String get fleetOwnerOnly => 'Only the fleet owner can do that.';

  @override
  String get fleetYourCompany => 'Your company';

  @override
  String get fleetYourFleet => 'Your fleet';

  @override
  String get fleetCode => 'Fleet code';

  @override
  String get fleetCodeHint =>
      'Share it with your drivers together with your name and e-mail.';

  @override
  String get fleetCodeWaiting => 'Waiting for Movera’s approval';

  @override
  String fleetCodeShareText(
    Object name,
    Object code,
    Object owner,
    Object email,
  ) {
    return 'Join $name on Movera Driver. Code: $code. Owner: $owner, $email.';
  }

  @override
  String get fleetShare => 'Share';

  @override
  String get fleetCopy => 'Copy';

  @override
  String get fleetCodeCopied => 'Code copied';

  @override
  String get fleetDrivers => 'Drivers';

  @override
  String get fleetNoDrivers => 'No drivers yet. Share your code.';

  @override
  String get fleetRemove => 'Remove';

  @override
  String fleetRemoveDriverQ(Object name) {
    return 'Remove $name from your fleet?';
  }

  @override
  String get fleetCars => 'Cars';

  @override
  String get fleetNoCars => 'No cars yet.';

  @override
  String get fleetNoCarsMember => 'Your fleet has no approved car yet.';

  @override
  String get fleetAddCar => 'Add car';

  @override
  String get fleetChooseCar => 'Choose this car';

  @override
  String get fleetYourCar => 'Your car';

  @override
  String get fleetInUse => 'In use by another driver';

  @override
  String fleetPickedBy(Object name) {
    return 'Picked by $name';
  }

  @override
  String get fleetLeave => 'Leave fleet';

  @override
  String fleetLeaveQ(Object name) {
    return 'Leave $name? You can join another fleet with a new code.';
  }

  @override
  String get fleetCouldNotLoad => 'Couldn’t load your fleet.';

  @override
  String get fleetStatusPending => 'Waiting for approval';

  @override
  String get fleetStatusBlocked => 'Blocked';

  @override
  String get fleetVehicleInUse =>
      'Another driver is driving this car right now.';

  @override
  String get fleetVehicleNotApproved => 'This car isn’t approved yet.';

  @override
  String get fleetVehicleNotYours => 'This car isn’t your fleet’s.';

  @override
  String get fleetPlateTaken => 'A car with this plate is already registered.';

  @override
  String get fleetCarAdded => 'Car added. Movera checks it.';

  @override
  String get fleetCouldNotAddCar => 'Couldn’t add the car. Try again.';

  @override
  String get fleetCouldNotPick => 'Couldn’t choose the car. Try again.';

  @override
  String get fleetColour => 'Colour';

  @override
  String get fleetPlate => 'Plate';

  @override
  String get fleetSeats => 'Seats';

  @override
  String get fleetCarTypes => 'Car types';

  @override
  String fleetMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drivers',
      one: '1 driver',
    );
    return '$_temp0';
  }

  @override
  String fleetCarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cars',
      one: '1 car',
    );
    return '$_temp0';
  }

  @override
  String fleetOrgNumber(Object number) {
    return 'Org. no. $number';
  }

  @override
  String get fleetOnline => 'Online';

  @override
  String get fleetOffline => 'Offline';

  @override
  String get vehStatusBlocked => 'Blocked';

  @override
  String get vehDocumentsOnDocs =>
      'Upload the car’s documents under Documents.';

  @override
  String fleetCarSeatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get fleetJoinLink => 'Join a fleet';

  @override
  String get docChooseHow => 'How do you want to add it?';

  @override
  String get fleetVehiclesAwait =>
      'Your fleet adds its cars; you pick the one you drive here.';

  @override
  String get liveOnlineFailed => 'Could not go online. Try again.';

  @override
  String get liveOfflineFailed =>
      'Movera could not record that you went offline. Try again.';

  @override
  String get liveOnlineNotActive =>
      'Your account is not active yet, so you can\'t go online.';

  @override
  String get liveOnlineNoFleet => 'Join a fleet before you go online.';

  @override
  String get liveOnlineFleetNotApproved =>
      'Your fleet is not approved yet, so you can\'t go online.';

  @override
  String get liveOnlineNoVehicle =>
      'Choose an approved car before you go online.';

  @override
  String get liveOnlineVehicleNotApproved =>
      'Your car is not approved yet, so you can\'t go online.';

  @override
  String get liveOnlineVehicleInUse =>
      'Another driver has this car now. Choose your car again.';

  @override
  String get liveOnlineNoCategory => 'No ride type is set for your car yet.';

  @override
  String get liveOfflineOnTrip => 'Finish your trip before you go offline.';

  @override
  String get liveTripNotAtPickup =>
      'Movera doesn\'t see you at the pickup yet. Drive closer and try again.';

  @override
  String get liveTripNoShowTooEarly =>
      'It\'s too early for a no-show. Wait a little longer.';

  @override
  String get liveTripChanged =>
      'This trip changed meanwhile. Check it and try again.';

  @override
  String get liveTripFailed => 'Movera could not record this step. Try again.';

  @override
  String get authProviderComingSoon =>
      'Sign-in with Apple and Google is coming soon. Use your phone number.';

  @override
  String get authErrProvider =>
      'Couldn’t sign in that way. Try again, or use your phone number.';

  @override
  String get authLinkExpired =>
      'That sign-in took too long. Start again with Apple or Google, or use your phone number.';

  @override
  String authContinueWith(String provider) {
    return 'Continue with $provider';
  }

  @override
  String get authOr => 'or';

  @override
  String authProviderPhoneOnce(String provider) {
    return 'Confirm your phone number once to finish signing in with $provider. We’ll text you a 4-digit code.';
  }

  @override
  String get authUsePhoneInstead => 'Sign in with my phone number only';

  @override
  String get acctDetailsHead => 'Your ';

  @override
  String get acctDetailsAccent => 'details';

  @override
  String get acctDetailsEditIntro =>
      'Movera is checking your account. You can still change these until it is approved.';

  @override
  String get acctPhone => 'Phone number';

  @override
  String get acctTapToChange => 'Tap to change';

  @override
  String get acctChooseCountry => 'Choose your country';

  @override
  String get acctChooseCountryBody => 'Where you will drive.';

  @override
  String get acctChooseLanguage => 'Choose your language';

  @override
  String get acctChooseLanguageBody =>
      'The app’s language. You can change it later.';

  @override
  String get acctCityStockholmHint =>
      'Stockholm, Södertälje and the whole county';

  @override
  String get acctCityParisHint => 'Paris and the Île-de-France region';

  @override
  String acctFromProvider(String provider) {
    return 'from $provider';
  }

  @override
  String get acctOrgNumberSeRule =>
      'Enter the 10 digits of your organisation number.';

  @override
  String get acctOrgNumberFrRule =>
      'Enter a SIREN (9 digits) or a SIRET (14 digits).';

  @override
  String get acctCompanyAddressHint => 'Street, postcode, town';

  @override
  String get acctOwnerEmailHint => 'name@company.com';

  @override
  String get acctJoinNowShort =>
      'Your fleet owner shares a Movera code with you.';

  @override
  String get acctLeaveSignUpQ => 'Leave the sign-up?';

  @override
  String get acctLeaveSignUpBody =>
      'You will be signed out and back at the first step. What you typed stays on this phone until you sign in again.';

  @override
  String get acctSaveDetails => 'Save details';

  @override
  String get acctDetailsSaved => 'Your details are saved. Movera checks them.';

  @override
  String get fleetRequestPending =>
      'You already asked a fleet. Wait for its answer or cancel that request.';

  @override
  String get fleetInvitePending =>
      'That number already has an open invitation.';

  @override
  String get fleetOwnPhone => 'That is your own number.';

  @override
  String get fleetInvalidPhone =>
      'Enter the number in international form, e.g. +46 70 123 45 67.';

  @override
  String get fleetNotApprovedYet =>
      'Movera has not approved your fleet yet. You can invite drivers after that.';

  @override
  String get fleetInvitationExpired => 'This invitation has expired.';

  @override
  String get fleetInvitationGone => 'This invitation is no longer open.';

  @override
  String get fleetADriver => 'A driver';

  @override
  String get fleetRequestBodyOwner =>
      'Wants to join your fleet with your code.';

  @override
  String get fleetInviteWaitsSignUp =>
      'Invited. Waiting for this number to sign up in Movera Driver.';

  @override
  String get fleetInviteWaitsAnswer =>
      'Invited. Waiting for the driver’s answer.';

  @override
  String get fleetInviteBodyDriver =>
      'Invites you to its fleet. Accept to drive its cars; Movera then checks your documents.';

  @override
  String get fleetRequestWaitsOwner =>
      'Your request is sent. The fleet owner accepts it in the app.';

  @override
  String get fleetInviteNew => 'Answer';

  @override
  String fleetInviteExpires(String date) {
    return 'Valid until $date';
  }

  @override
  String get fleetAccept => 'Accept';

  @override
  String get fleetDecline => 'Decline';

  @override
  String get fleetCancelling => 'Cancelling…';

  @override
  String fleetPendingInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations waiting for your answer',
      one: '1 invitation waiting for your answer',
    );
    return '$_temp0';
  }

  @override
  String get fleetInviteDriver => 'Invite driver';

  @override
  String get fleetInviteDriverBody =>
      'The driver’s phone number, the one he signs in with. He accepts in his app; a number without an account gets an SMS with the app link.';

  @override
  String get fleetInviteDriverHint => 'The invitation is valid for 7 days.';

  @override
  String get fleetSendInvite => 'Send invitation';

  @override
  String get fleetAskToJoin => 'Ask to join';

  @override
  String get fleetAskToJoinHint =>
      'The fleet owner accepts your request in his app.';

  @override
  String get fleetCancelInviteQ => 'Take back this invitation?';

  @override
  String fleetDeclineInviteQ(String name) {
    return 'Decline $name?';
  }

  @override
  String get fleetCancelInvite => 'Take back';

  @override
  String fleetDriverJoined(String name) {
    return '$name is now in your fleet.';
  }

  @override
  String fleetInviteSent(String who) {
    return 'Invitation sent to $who.';
  }

  @override
  String get fleetRequests => 'Requests to join';

  @override
  String fleetInvitationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending',
      one: '1 pending',
    );
    return '$_temp0';
  }

  @override
  String get fleetInvites => 'Invitations';

  @override
  String get fleetNoInvites =>
      'No open invitation. Invite a driver by phone number, or share your code.';

  @override
  String get fleetYourRequest => 'Your request';

  @override
  String fleetRequestSent(String name) {
    return 'Request sent to $name. The owner answers in the app.';
  }

  @override
  String get notifCouldNotLoad => 'Couldn’t load your notifications.';

  @override
  String get notifNone =>
      'No notifications yet. Fleet invitations and answers show here.';

  @override
  String get profLiveNoNameYet => 'Your details are not sent yet';

  @override
  String get rcTripTotal => 'Trip total';

  @override
  String get rcMoveraCommission => 'Movera commission';

  @override
  String get rcYouGet => 'You get';

  @override
  String get ratingTagOnTime => 'On time';

  @override
  String get ratingTagPolite => 'Polite';

  @override
  String get ratingTagClearPickup => 'Clear pickup';

  @override
  String get ratingCommentOptional => 'Comment (optional)';

  @override
  String get ratingCouldNotSend => 'The rating could not be sent.';

  @override
  String get message => 'Message';

  @override
  String get supportTicketMovera => 'Movera support';

  @override
  String get supportSendFailed => 'Could not send. Try again.';

  @override
  String get supportSendToMovera => 'Send to Movera';

  @override
  String get supportSentToMovera => 'Sent to Movera. The answer shows here.';

  @override
  String get supportWriteToMovera => 'Write to Movera';

  @override
  String get supportNoTicketsYet => 'No messages to Movera yet.';

  @override
  String get contentUpdateTitle => 'Update the app';

  @override
  String get contentUpdateBody =>
      'This version of Movera Driver can no longer be used. Update it to keep driving.';

  @override
  String get contentUpdateStore => 'Open the store';

  @override
  String get contentUpdateStoreFailed => 'The store could not be opened.';

  @override
  String get contentUpdateRecommended => 'A new version of the app is ready.';

  @override
  String get contentUpdateAfterTrip => 'Update the app after this trip.';

  @override
  String get contentTermsTitle => 'New terms';

  @override
  String get contentTermsAccept => 'I accept';

  @override
  String get contentTermsFailed =>
      'Not saved. Check the connection and try again.';

  @override
  String get contentTermsBlockOnline => 'Accept the new terms to go online.';

  @override
  String get mapYourCar => 'Your car';

  @override
  String get noticeDemoEventTitle => 'Stockholm evening demand';

  @override
  String get noticeDemoEventBody =>
      '18:00–22:30 · Central Stockholm. Be online before the main departure window.';

  @override
  String get noticeDemoEventIsland => 'Event tonight · City';

  @override
  String get categoryComfort => 'Comfort';

  @override
  String get categoryPriority => 'Priority';

  @override
  String get categoryElectric => 'Electric';

  @override
  String get categoryBoosterSeat => 'Booster Seat';

  @override
  String get demoPickupNearYou => 'Pickup near you';

  @override
  String demoNearPlace(String place) {
    return 'Near $place';
  }

  @override
  String get demoYourDestination => 'your destination';

  @override
  String demoOnYourWayPercent(int percent) {
    return 'On your way · $percent %';
  }

  @override
  String get demoAwayFromRoute => 'Away from your route';

  @override
  String get demoBehindYou => 'Behind you';

  @override
  String get vehDocsMissingCantDrive => 'Can\'t be driven – upload documents';

  @override
  String docsNotApprovedCar(String names) {
    return 'This car can\'t be driven until its documents are approved. Missing: $names';
  }

  @override
  String docsNotApprovedAccount(String names) {
    return 'Your account can\'t be used until these documents are approved: $names';
  }

  @override
  String get authStartingServer => 'Starting the server…';

  @override
  String authErrTooManyWrongCodes(String button) {
    return 'Too many wrong tries – tap $button';
  }

  @override
  String authRetryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get authJoinWaitlist => 'Join the waiting list';

  @override
  String get authWaitlistSaved =>
      'You’re on the waiting list. We’ll let you know when sign-in opens for your number.';

  @override
  String get authTestNumbersTitle => 'Test numbers (test build only)';

  @override
  String get authTestStatusNew => 'Test · no account yet';

  @override
  String get gateSignOut => 'Sign out';

  @override
  String get gateTryAgain => 'Try again';

  @override
  String get authNeedHelp => 'Need help?';

  @override
  String get authHelpComingSoon => 'Contact details coming soon';

  @override
  String get authHelpEmail => 'E-mail';

  @override
  String get authHelpPhone => 'Phone';

  @override
  String get authHelpCompany => 'Company';

  @override
  String get authHelpClose => 'Close';

  @override
  String remTitle(Object count) {
    return 'Important reminders ($count)';
  }

  @override
  String get remShow => 'Show reminders';

  @override
  String get remHide => 'Hide reminders';

  @override
  String get remBlocksOnlineLegend =>
      'Red: you can\'t go online until it is fixed';

  @override
  String remDocOfCar(Object document, Object car) {
    return '$document · $car';
  }

  @override
  String remDocumentNeeded(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'yes': '$document are missing',
      'other': '$document is missing',
    });
    return '$_temp0';
  }

  @override
  String remDocumentRejected(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'yes': '$document were rejected',
      'other': '$document was rejected',
    });
    return '$_temp0';
  }

  @override
  String remDocumentExpired(Object document, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'yes': '$document have expired',
      'other': '$document has expired',
    });
    return '$_temp0';
  }

  @override
  String remDocumentExpiring(Object document, Object when, String plural) {
    String _temp0 = intl.Intl.selectLogic(plural, {
      'yes': '$document expire $when',
      'other': '$document expires $when',
    });
    return '$_temp0';
  }

  @override
  String remDocumentInReview(Object document) {
    return '$document: Movera is checking it';
  }

  @override
  String get remCantGoOnlineUntil =>
      'You can\'t go online until Movera approves the new one.';

  @override
  String get remAccountNotActive => 'Movera is checking your account';

  @override
  String get remAccountNotActiveDetail =>
      'Everything is sent. You can go online when Movera activates your account.';

  @override
  String get remFleetNotApproved => 'Movera has not approved your fleet yet';

  @override
  String get remFleetNoApprovedCar => 'Your fleet has no approved car yet';

  @override
  String get remFleetNoApprovedCarOwner =>
      'Add a car or finish its documents in My fleet. Drivers can go online once a car is approved.';

  @override
  String get remFleetNoApprovedCarMember =>
      'You can go online when your fleet owner has an approved car for you to choose.';

  @override
  String get remNoVehicle =>
      'Choose a car from your fleet before you go online';

  @override
  String get remUpload => 'Upload';

  @override
  String get remUploadNew => 'Upload new';

  @override
  String get remOpen => 'Open';

  @override
  String remCantGoOnline(Object reason) {
    return 'You can\'t go online yet: $reason';
  }

  @override
  String liveOnlineDocumentsExpired(Object documents) {
    return 'A document has expired: $documents. Upload the new one to go online.';
  }

  @override
  String get infoHowToBook => 'How to book your info session';

  @override
  String get infoHowToBookShort => 'How to book';

  @override
  String get infoNoContent =>
      'Movera will contact you to book a time. You don\'t need to do anything else now.';

  @override
  String get infoHeld => 'Movera has marked your info session as held.';

  @override
  String get infoOpenLink => 'Open the booking page';

  @override
  String get infoRequiredBeforeOnline =>
      'The info session is needed before you can go online.';

  @override
  String get guideExampleLabel => 'Example drawn by Movera';

  @override
  String get guideMustBeVisible => 'Make sure this is visible';

  @override
  String get guideTipsTitle => 'Tips for a good photo';

  @override
  String get guideUpload => 'Upload';

  @override
  String get guidePickTakePhoto => 'Take photo';

  @override
  String get guidePickLibrary => 'Photo library';

  @override
  String get guidePickFile => 'Choose file';

  @override
  String get guideCameraBlockedTitle => 'Movera can\'t use your camera';

  @override
  String get guideCameraBlockedBody =>
      'Camera access is off for Movera. Turn it on in Settings, or choose a file you already have.';

  @override
  String get guideOpenSettings => 'Open Settings';

  @override
  String get guideUploadingSlow => 'Uploading… this can take up to a minute.';

  @override
  String get guideKeptPhoto =>
      'The upload did not finish. Your photo is kept, so you can try again.';

  @override
  String get guideTryAgain => 'Try again';

  @override
  String get guideChooseAnother => 'Choose another';

  @override
  String guideExpiryNote(Object days) {
    return 'This document has an end date. Movera types it when approving, and reminds you $days days before.';
  }

  @override
  String guideCurrentStatus(Object status) {
    return 'Now: $status';
  }

  @override
  String guideExpiresOn(Object date) {
    return 'Expires $date';
  }

  @override
  String guideSelectedFile(Object name) {
    return 'Selected: $name';
  }

  @override
  String get guideLicenceBothSides => 'Front and back of the licence';

  @override
  String get guideNameAndPhoto => 'Your name and photo';

  @override
  String get guideValidUntil => 'The valid-until date';

  @override
  String get guideLicenceCategoryB => 'Category B';

  @override
  String get guideLicenceCategoryB3Years =>
      'Category B, held for at least 3 years';

  @override
  String get guideIdWholeCard => 'The whole card or the passport photo page';

  @override
  String get guidePhotoFaceFront => 'Your face from the front, eyes open';

  @override
  String get guidePhotoPlainBackground => 'A plain, light background';

  @override
  String get guidePhotoNoSunglasses => 'No sunglasses, cap or other people';

  @override
  String get guideCardBothSides => 'Front and back of the card';

  @override
  String get guideCardNumber => 'The card number';

  @override
  String get guideSeRegistrationBolagsverket =>
      'The registration certificate from Bolagsverket';

  @override
  String get guideKbisRecent => 'Kbis or SIRENE notice, less than 3 months old';

  @override
  String get guideCompanyNameAndNumber => 'The company name and number';

  @override
  String get guideAllPages => 'Every page';

  @override
  String get guideSeTrafficPermit =>
      'The taxi traffic permit from Transportstyrelsen';

  @override
  String get guideSeFTax => 'The F-skatt certificate from Skatteverket';

  @override
  String get guideFrRib => 'The company RIB with IBAN and BIC';

  @override
  String get guideSeBankAccount =>
      'The account certificate with clearing and account number';

  @override
  String get guideAccountHolderName => 'The account holder\'s name';

  @override
  String get guideFrVtcRegister =>
      'The certificate of the VTC operators register';

  @override
  String get guideFrRcPro => 'The RC Pro certificate for passenger transport';

  @override
  String get guideFrUrssafRecent =>
      'The URSSAF certificate, less than 6 months old';

  @override
  String get guideFrCarteGrise => 'The carte grise, front side';

  @override
  String get guideSeRegistrationFront => 'The registration certificate, part 1';

  @override
  String get guidePlateVisible => 'The plate number';

  @override
  String get guideOwnerName => 'The owner\'s name';

  @override
  String get guideFrPassengerInsurance =>
      'The passenger transport insurance certificate';

  @override
  String get guideSeInsuranceLetter => 'The insurance letter for taxi traffic';

  @override
  String get guideFrStickerOnCar => 'The VTC sticker on the windscreen';

  @override
  String get guideCarFront => 'The whole front of the car';

  @override
  String get guideCarBack => 'The whole back of the car';

  @override
  String get guideCarSide => 'The whole side of the car, wheels included';

  @override
  String get guideCarInside => 'The seats from the back door, clean';

  @override
  String get guidePlateReadable => 'The plate can be read';

  @override
  String get guideWholeDocument => 'The whole document, every corner';

  @override
  String get guideNameAndPhotoIfAny => 'Your name (and photo, if it has one)';

  @override
  String get tipFlatDarkSurface => 'Lay it flat on a dark table';

  @override
  String get tipNoGlare => 'No flash and no glare on it';

  @override
  String get tipFourCorners => 'All four corners in the photo';

  @override
  String get tipPhotoHoldStill => 'Hold still so the text is sharp';

  @override
  String get tipPhotoDaylight => 'Good daylight, no backlight';

  @override
  String get tipPhotoNoFilter => 'No filters or edits';

  @override
  String get tipCarWholeInFrame => 'Step back so the whole car fits';

  @override
  String get docOpenGuide => 'Open the guide and upload';

  @override
  String docExpiresOnNote(Object date) {
    return 'Expires $date';
  }

  @override
  String get startCompanyTitle => 'Start my own company';

  @override
  String get startCompanyIntro =>
      'Your account becomes a company (fleet) account. The documents you already have are kept – you only add the company\'s and your cars\' documents. Movera then approves it like a new fleet.';

  @override
  String startCompanyLeavesFleet(Object fleet) {
    return 'You leave $fleet and go offline. You can\'t go online until Movera approves your company.';
  }

  @override
  String get startCompanyConfirmQ =>
      'Make your account a company account? Movera checks it before you can drive again.';

  @override
  String get startCompanySend => 'Send to Movera';

  @override
  String get startCompanySent => 'Sent. Your company waits for Movera.';

  @override
  String get startCompanyFailed => 'Could not start the company. Try again.';

  @override
  String get startCompanyAlreadyFleet =>
      'Your account is already a company account.';

  @override
  String get carFuel => 'Fuel';

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelElectric => 'Electric';

  @override
  String carTypesFitHint(Object country) {
    return 'Only the car types this car fits are shown (Movera\'s rules for $country).';
  }

  @override
  String get carTypesEnterFirst =>
      'Enter the year, seats and fuel to see the car types.';

  @override
  String get carNoTypeFits =>
      'This car fits no car type. Check the year, seats and fuel.';

  @override
  String get carRulesCouldNotLoad => 'Could not load Movera\'s car rules.';

  @override
  String get carCategoryNotAllowed =>
      'This car does not fit one of the chosen car types.';

  @override
  String get carPhotosTitle => 'Photos of the car';

  @override
  String carPhotosIntro(Object car) {
    return 'Movera needs these 4 photos of $car before it can be driven.';
  }

  @override
  String get carPhotosDone => 'Done';

  @override
  String get vehNotApprovedCantDrive =>
      'Can\'t be driven – Movera has not approved this car yet';

  @override
  String get vehDocsMissingOwnerUploads =>
      'Can\'t be driven – the fleet owner must finish its documents';

  @override
  String get swTripStatusDraft => 'Draft';

  @override
  String get swTripStatusQuoted => 'Quoted';

  @override
  String get swTripStatusRequested => 'Requested';

  @override
  String get swTripStatusSearching => 'Searching';

  @override
  String get swTripStatusOffered => 'Offered';

  @override
  String get swTripStatusAccepted => 'Accepted';

  @override
  String get swTripStatusDriverToPickup => 'Driver to pickup';

  @override
  String get swTripStatusArrived => 'Arrived';

  @override
  String get swTripStatusRiderOnboard => 'Rider onboard';

  @override
  String get swTripStatusInTrip => 'In trip';

  @override
  String get swTripStatusApproachingDropoff => 'Approaching drop-off';

  @override
  String get swTripStatusCompleted => 'Completed';

  @override
  String get swTripStatusCancelledByRider => 'Cancelled by rider';

  @override
  String get swTripStatusCancelledByDriver => 'Cancelled by driver';

  @override
  String get swTripStatusCancelledByAdmin => 'Cancelled by admin';

  @override
  String get swTripStatusCancelledBySystem => 'Cancelled by system';

  @override
  String get swTripStatusNoShow => 'No show';

  @override
  String get swTripStatusExpired => 'Expired';

  @override
  String get swTripStatusFailed => 'Failed';

  @override
  String get swDriverAccountStatusPending => 'Pending';

  @override
  String get swDriverAccountStatusActive => 'Active';

  @override
  String get swDriverAccountStatusOnHold => 'Awaiting review';

  @override
  String get swDriverAccountStatusSuspended => 'Suspended';

  @override
  String get swDriverOnlineStatusOffline => 'Offline';

  @override
  String get swDriverOnlineStatusGoingOnline => 'Going online';

  @override
  String get swDriverOnlineStatusOnline => 'Online';

  @override
  String get swDriverOnlineStatusOnTrip => 'On a trip';

  @override
  String get swDriverOnlineStatusSuspended => 'Suspended';

  @override
  String get swPaymentStatusPending => 'Pending';

  @override
  String get swPaymentStatusAuthorized => 'Authorized';

  @override
  String get swPaymentStatusCaptured => 'Captured';

  @override
  String get swPaymentStatusFailed => 'Failed';

  @override
  String get swPaymentStatusRefunded => 'Refunded';

  @override
  String get swPaymentStatusPartiallyRefunded => 'Partially refunded';

  @override
  String get swFeeStatusPaid => 'Paid';

  @override
  String get swFeeStatusOwed => 'Owed';

  @override
  String get swFeeStatusWaived => 'Waived';

  @override
  String get swPayoutStatusPending => 'Pending';

  @override
  String get swPayoutStatusPaid => 'Paid';

  @override
  String get swDocumentStatusNeeded => 'Needed';

  @override
  String get swDocumentStatusInReview => 'In review';

  @override
  String get swDocumentStatusApproved => 'Approved';

  @override
  String get swDocumentStatusRejected => 'Rejected';

  @override
  String get swDocumentStatusExpired => 'Expired';

  @override
  String get swDocumentStatusExpiring => 'Expiring';

  @override
  String get swDocumentStatusMissing => 'Missing';

  @override
  String get swDocumentStatusWaitingForMovera => 'Waiting for Movera';

  @override
  String get swTicketStatusOpen => 'Open';

  @override
  String get swTicketStatusPending => 'Pending';

  @override
  String get swTicketStatusResolved => 'Resolved';

  @override
  String get swTicketStatusClosed => 'Closed';

  @override
  String get swVehicleReviewStatusInReview => 'In review';

  @override
  String get swVehicleReviewStatusApproved => 'Approved';

  @override
  String get swVehicleReviewStatusRejected => 'Rejected';

  @override
  String get swOfferStatusOpen => 'Open';

  @override
  String get swOfferStatusClaimed => 'Claimed';

  @override
  String get swOfferStatusClaimedElsewhere => 'Claimed elsewhere';

  @override
  String get swOfferStatusDeclined => 'Declined';

  @override
  String get swOfferStatusExpired => 'Expired';

  @override
  String get swOfferStatusWithdrawn => 'Withdrawn';

  @override
  String get swRatingStatusNotRequested => 'Not requested';

  @override
  String get swRatingStatusPending => 'Pending';

  @override
  String get swRatingStatusSubmitted => 'Submitted';

  @override
  String get swRatingStatusSkipped => 'Skipped';

  @override
  String get docFleetOwnerOnly =>
      'Only the fleet owner can upload or open car documents.';

  @override
  String get remNoFleet =>
      'Join a fleet to drive – ask your fleet owner for the Movera code, his name and e-mail';

  @override
  String get remActionJoinFleet => 'Join a fleet';

  @override
  String get remActionStartCompany => 'Start my own company';

  @override
  String get remNoVehicleNotActive => 'Choose a car from your fleet';

  @override
  String get fleetNoApprovedCarOwnerHere =>
      'Add a car below or finish its documents. Drivers can go online once a car is approved.';

  @override
  String get holdAccountChecking =>
      'Your account is being checked. We tell you when you can drive.';

  @override
  String get carExtraNeedsRide =>
      'Booster Seat is an extra: also choose a ride type.';

  @override
  String get carRulesNotMet => 'This car does not meet Movera’s rules:';

  @override
  String carProblemLine(Object category, Object problem) {
    return '$category: $problem';
  }

  @override
  String get carWholeCar => 'The car';

  @override
  String get carProblemYearTooOld => 'the car is too old for Movera';

  @override
  String carProblemYearTooOldBase(int year) {
    return 'the car must be from $year or later';
  }

  @override
  String get carProblemCategoryOff => 'not offered in this country';

  @override
  String get carProblemTooFewSeats => 'too few seats';

  @override
  String get carProblemFuelNotAllowed => 'this fuel is not allowed';

  @override
  String get carProblemFuelRequired => 'choose the fuel';

  @override
  String get carProblemExtraNeedsRide => 'only together with a ride type';

  @override
  String get carProblemOther => 'does not fit';

  @override
  String get pushAskTitle => 'Get notices when the app is closed?';

  @override
  String get pushAskBody =>
      'Movera tells you when a document is about to expire, when Movera has checked your documents or car, about fleet invitations and messages from riders. You can turn this off at any time in your browser or phone settings.';

  @override
  String get pushAskAllow => 'Turn on';

  @override
  String get pushAskLater => 'Not now';

  @override
  String get backgroundLocationTitle => 'Movera is online';

  @override
  String get backgroundLocationBody => 'Your position is sent so you get trips';

  @override
  String get locationRequired => 'Turn on location to go online';

  @override
  String get locationOpenSettings => 'Open Settings';

  @override
  String get batterySaverWarning =>
      'Battery saver is on. Movera may stop sending your position – turn it off to get trips.';

  @override
  String get setOfflineLine => 'You were set offline – tap to go online again';

  @override
  String get outsideAreaTitle => 'You are not eligible to drive in this area';

  @override
  String outsideAreaBody(String zones) {
    return 'You get no trips here. Drive back to $zones to get trips.';
  }

  @override
  String get outsideAreaOk => 'OK';

  @override
  String get anaYourPerformance => 'Your performance · last 30 days';

  @override
  String anaAcceptanceDetail(String rate) {
    return '$rate of offers accepted';
  }

  @override
  String anaCancellationDetail(String rate) {
    return '$rate of accepted trips';
  }

  @override
  String get destRecentAddresses => 'Your recent destinations';

  @override
  String get destSearchUnavailable => 'Address search is not available';

  @override
  String get destSearchTryAgain => 'Check your connection and try again.';

  @override
  String get destSearchStart => 'Search for an address';

  @override
  String get destSearchStartBody =>
      'Type a street, a place or a city. Your last 5 destinations show here.';

  @override
  String get anaNotEnoughData => 'Not enough data yet';

  @override
  String get authSignedOutExpired =>
      'You were signed out – please sign in again';

  @override
  String get authSignedOutRevoked =>
      'You were signed out – please sign in again';

  @override
  String get authSignedOutDetailExpired =>
      'You have not used the app for 30 days.';

  @override
  String get authSignedOutDetailRevoked => 'Movera ended your session.';

  @override
  String get docInvalidFileContent => 'This file is not a photo or PDF';

  @override
  String get docExpiryTooFar => 'Check the end date';

  @override
  String remFleetInvitation(String fleet) {
    return '$fleet invited you';
  }

  @override
  String get remActionAcceptInvitation => 'Accept';

  @override
  String get remActionDeclineInvitation => 'Decline';

  @override
  String get safetyCall112 => 'Call 112';

  @override
  String authPhoneFieldLabel(String dial) {
    return 'Mobile number ($dial)';
  }

  @override
  String get authCodeFieldLabel => '4-digit code from the SMS';

  @override
  String get legalCouldNotLoad =>
      'Couldn’t load the text. Check the connection and try again.';

  @override
  String get docRenewalWaiting => 'New document waiting for review';

  @override
  String get docRenewalRejected => 'New document rejected';

  @override
  String get remRenewalInReview => 'Your new one is being checked';

  @override
  String get remRenewalRejected => 'Your new one was rejected';

  @override
  String get carTypesByMovera =>
      'Movera chooses the ride types when it approves the car.';

  @override
  String get offerAccepting => 'Accepting…';

  @override
  String get offerNoLongerAvailable => 'Offer no longer available';

  @override
  String get riderRatingLabel => 'Rider rating';

  @override
  String get soundOffNotice => 'Sound is off – you may miss offers';

  @override
  String get soundOffTapToAllow => 'Tap to allow sound';

  @override
  String riderRidesOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rides',
      one: '1 ride',
    );
    return '$_temp0';
  }

  @override
  String get eventRunning => 'Happening now';

  @override
  String eventStarts(String time) {
    return 'Starts $time';
  }

  @override
  String get eventPickupNote => 'Pickup';

  @override
  String get offlineCardTitle => 'You\'re offline';

  @override
  String offlineReasonNoPosition(int minutes) {
    return 'Your phone sent no position for $minutes min';
  }

  @override
  String get offlineReasonAppRestart =>
      'The app was restarted while you were online';

  @override
  String offlineReasonMissedOffers(int count) {
    return 'You missed or declined $count offers in a row';
  }

  @override
  String get offlineReasonMovera => 'Movera set you offline';

  @override
  String get offlineCheckPhone => 'Check my phone';

  @override
  String get offlineChecking => 'Checking…';

  @override
  String get offlineCheckLocation => 'Location on and allowed';

  @override
  String get offlineCheckInternet => 'Internet and Movera server';

  @override
  String get offlineCheckBattery => 'Battery saver off';

  @override
  String get offlineCheckNotifications => 'Notifications allowed';

  @override
  String get offlineCheckUnknown => 'Can\'t be checked here';

  @override
  String get offlineCheckBrowser => 'Allow it in the browser\'s site settings';

  @override
  String get offlineFixTurnOn => 'Turn on';

  @override
  String get offlineGoOnline => 'Go online';

  @override
  String get offlineReasonVehicleBlocked => 'Your car cannot be used right now';

  @override
  String get offlineReasonFleetRemoved => 'You are no longer in a fleet';

  @override
  String get offlineReasonAccountStatus =>
      'Your account is paused – contact Movera';

  @override
  String get tripSettings => 'Trip settings';

  @override
  String get navigationApp => 'Navigation app';

  @override
  String get navigationAppHint => 'Opens from the map button during a trip';

  @override
  String get navigateWithWaze => 'Navigate with Waze';

  @override
  String get wazeIsUnavailable => 'Waze is unavailable.';

  @override
  String noShowConfirmYouGet(Object amount) {
    return 'Mark as no-show? You get $amount';
  }

  @override
  String get noShowConfirmNoFee => 'Mark as no-show? No fee';

  @override
  String feeKindNoShow(Object amount) {
    return 'No-show fee $amount';
  }

  @override
  String feeKindCancel(Object amount) {
    return 'Cancellation fee $amount';
  }

  @override
  String etaArrivesIn(Object min, Object distance) {
    return 'Arrives in $min min · $distance';
  }

  @override
  String etaToDropoff(Object min, Object distance) {
    return 'There in $min min · $distance';
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
  String get pickupMovedIsland => 'Pickup moved';

  @override
  String waitingChargedSoFar(Object amount) {
    return 'Waiting charged so far: $amount';
  }

  @override
  String get cancelAfterArrivedNote =>
      'Cancelling after the driver has arrived and the free waiting is over counts as a no-show';

  @override
  String get navigationAppSaveFailed => 'Navigation app not saved. Try again.';

  @override
  String etaLastKnown(Object eta) {
    return 'Last known: $eta';
  }

  @override
  String get feeKindNoShowShort => 'No-show fee';

  @override
  String get feeKindCancelShort => 'Cancellation fee';

  @override
  String noShowFromTime(Object time) {
    return 'Can be applied from $time if the rider has not arrived.';
  }

  @override
  String g6RuleFarPickup(Object km) {
    return 'Pickup over $km km away';
  }

  @override
  String get g6RuleAirport => 'Airport pickup';

  @override
  String get g6RuleScheduled => 'Booked ride';

  @override
  String get g6RuleEvent => 'Event pickup';

  @override
  String get g6PinAsk => 'Ask the rider for the 4-digit code';

  @override
  String g6PinWrong(Object left) {
    return 'Wrong code. $left tries left';
  }

  @override
  String g6PinLocked(Object min) {
    return 'Too many tries. Try again in $min min';
  }

  @override
  String get g6PinTitle => 'Rider’s code';

  @override
  String get g6PinConfirm => 'Confirm and start';

  @override
  String get g6PinFourDigits => 'Enter 4 digits';

  @override
  String get g6PinNeeded => 'This trip needs the rider’s code before it starts';

  @override
  String get g6AlertPaid => 'Paid waiting has started';

  @override
  String get g6AlertNoShow => 'You can now mark a no-show';

  @override
  String g6StopFreeWait(Object min) {
    return 'Free wait at this stop: $min min';
  }

  @override
  String get g6PinBlocked => 'Too many wrong codes. Call Movera support';

  @override
  String get g6PinNotNow =>
      'Enter the code once you have arrived at the pickup';

  @override
  String get g7RouteAsk => 'The rider wants to change the route';

  @override
  String g7RouteEarnings(String earnings, String difference) {
    return 'New earnings $earnings ($difference)';
  }

  @override
  String get g7RouteAccept => 'Accept';

  @override
  String get g7RouteRefuse => 'Refuse';

  @override
  String get g7RouteChanged => 'The route was changed by the rider.';

  @override
  String g7StopPrice(String perMin) {
    return 'Waiting at a stop: $perMin/min';
  }

  @override
  String g7StopFree(int min, String perMin) {
    return '$min min free at each stop, then $perMin/min';
  }

  @override
  String g7MaxStops(int max) {
    return 'You can add at most $max stops.';
  }

  @override
  String g7RouteSecondsLeft(int seconds) {
    return '$seconds s left to answer';
  }

  @override
  String get g7RouteNewDestination => 'New destination';

  @override
  String g7RouteStops(int count, int max) {
    return 'Stops: $count (max $max)';
  }

  @override
  String get g7RouteAcceptedIsland => 'New route accepted';

  @override
  String get g7RouteRefusedIsland =>
      'Route change refused. Continue to the first destination';

  @override
  String get g7RouteExpiredIsland =>
      'No answer in time. The route stays the same';

  @override
  String get g7RouteWithdrawnIsland => 'The rider withdrew the route change';

  @override
  String get g8LineTrip => 'Trip';

  @override
  String get g8LinePickupPay => 'Pickup';

  @override
  String get g8LineBonus => 'Bonus';

  @override
  String get g8LineTip => 'Tip';

  @override
  String get g8LineAdjustment => 'Changed by Movera';

  @override
  String get g8YourShare => 'Your share';

  @override
  String g8TipGot(String amount) {
    return 'Tip from the rider: $amount';
  }

  @override
  String g8TipCash(String amount) {
    return 'The rider gives you a $amount tip in cash.';
  }

  @override
  String g8RiderEndedCollect(String amount) {
    return 'The rider ended the trip. Collect $amount.';
  }

  @override
  String get g8PricedForDriven => 'The price is for the distance driven.';

  @override
  String get g8BookedPriceStands => 'The booked price applies.';

  @override
  String get g8EndedEarly => 'Ended early';

  @override
  String get g8RiderEnded => 'The rider ended the trip early.';

  @override
  String get g8DriverEnded =>
      'The driver ended the trip before the destination.';

  @override
  String get g8DebtLine => 'Earlier unpaid fee (to that trip)';

  @override
  String get g8Continue => 'Continue';
}
