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
  String get tapToAccept => 'Tap to accept';

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
  String get allOffers => 'ALL OFFERS';

  @override
  String get savedTripCouldNotBeOpened => 'The saved trip could not be opened.';

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
  String moveWithin100MOfWhere(Object where) {
    return 'Move within 100 m of the $where to arrive.';
  }

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
  String get moveraSafetyTeamAlerted => 'Movera safety team alerted';

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
  String includesFeeWaitingFee(Object fee) {
    return 'Includes $fee waiting fee';
  }

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
  String get moveraBonus => 'Movera bonus';

  @override
  String get yourEarnings => 'Your earnings';

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
  String get illustrativeMapArchivedRouteUnavailable =>
      'Illustrative map · archived route unavailable';

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
  String get recordedFares => 'Recorded fares';

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
    return 'Fare $fareFormatted · Cash $cashCollectedFormatted';
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
  String get pinVerification => 'Pin verification';

  @override
  String get emergencyContacts => 'Emergency contacts';

  @override
  String get safety => 'Safety';

  @override
  String get showTrafficOnMap => 'Show traffic on map';

  @override
  String get trafficColoursOnTripMap => 'Traffic colours on the trip map';

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
  String pickupOnPickupSideSide(Object pickupSide) {
    return 'Pickup on the $pickupSide side';
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
  String inclBonusMoveraBonus(Object bonus) {
    return 'incl. +$bonus Movera bonus';
  }

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
  String get islandCashOn => 'Cash rides on';

  @override
  String get islandCashOff => 'Cash rides off';

  @override
  String get islandLastMissed => 'Next missed offer: offline';

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
  String get tripCollectCash => 'Collect cash';

  @override
  String get tripCompleteRide => 'Complete ride';

  @override
  String tripFinishCategory(Object category) {
    return 'Finish $category';
  }

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
}
