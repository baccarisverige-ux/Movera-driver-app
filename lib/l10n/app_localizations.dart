import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Movera Driver'**
  String get appTitle;

  /// No description provided for @hideReservationRequest.
  ///
  /// In en, this message translates to:
  /// **'Hide reservation request'**
  String get hideReservationRequest;

  /// No description provided for @tripMinutesMinTrip.
  ///
  /// In en, this message translates to:
  /// **'{tripMinutes} min trip'**
  String tripMinutesMinTrip(Object tripMinutes);

  /// No description provided for @n1Stop.
  ///
  /// In en, this message translates to:
  /// **'1 stop'**
  String get n1Stop;

  /// No description provided for @pickupWhenLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup {whenLabel}'**
  String pickupWhenLabel(Object whenLabel);

  /// No description provided for @reservation.
  ///
  /// In en, this message translates to:
  /// **'Reservation'**
  String get reservation;

  /// No description provided for @exclusive.
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get exclusive;

  /// No description provided for @pickupMinutesMin.
  ///
  /// In en, this message translates to:
  /// **' · Pickup {minutes} min'**
  String pickupMinutesMin(Object minutes);

  /// No description provided for @findingTrips.
  ///
  /// In en, this message translates to:
  /// **'Finding trips'**
  String get findingTrips;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @ridePreferences.
  ///
  /// In en, this message translates to:
  /// **'Ride preferences'**
  String get ridePreferences;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @exclusiveForYou.
  ///
  /// In en, this message translates to:
  /// **'Exclusive for you'**
  String get exclusiveForYou;

  /// No description provided for @destinationSet.
  ///
  /// In en, this message translates to:
  /// **'Destination Set'**
  String get destinationSet;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @driverStatus.
  ///
  /// In en, this message translates to:
  /// **'DRIVER STATUS'**
  String get driverStatus;

  /// No description provided for @accountAccessPaused.
  ///
  /// In en, this message translates to:
  /// **'Account access paused'**
  String get accountAccessPaused;

  /// No description provided for @yourDriverStatusIsCurrentlySuspended.
  ///
  /// In en, this message translates to:
  /// **'Your driver status is currently suspended, so new trip requests cannot be accepted and Radar cannot be started.'**
  String get yourDriverStatusIsCurrentlySuspended;

  /// No description provided for @moveraWillUseAuthoritativeAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Movera will use the authoritative account status. This screen does not guess a reason or unlock time.'**
  String get moveraWillUseAuthoritativeAccountStatus;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @stopNumber.
  ///
  /// In en, this message translates to:
  /// **'Stop {number}'**
  String stopNumber(Object number);

  /// No description provided for @arrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get arrive;

  /// No description provided for @backToRequest.
  ///
  /// In en, this message translates to:
  /// **'Back to request'**
  String get backToRequest;

  /// No description provided for @tripMinutesMinDistance.
  ///
  /// In en, this message translates to:
  /// **'{tripMinutes} min · {distance}'**
  String tripMinutesMinDistance(Object tripMinutes, Object distance);

  /// No description provided for @dropOff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get dropOff;

  /// No description provided for @destinationModeUntilUntil.
  ///
  /// In en, this message translates to:
  /// **'Destination mode until {until}'**
  String destinationModeUntilUntil(Object until);

  /// No description provided for @showRoute.
  ///
  /// In en, this message translates to:
  /// **'Show route'**
  String get showRoute;

  /// No description provided for @turnOffDestination.
  ///
  /// In en, this message translates to:
  /// **'Turn off destination'**
  String get turnOffDestination;

  /// No description provided for @versionLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {latestVersion}'**
  String versionLatestVersion(Object latestVersion);

  /// No description provided for @openingUpdateEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Opening update…'**
  String get openingUpdateEllipsis;

  /// No description provided for @couldNotOpenUpdatePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not open the update. Please try again.'**
  String get couldNotOpenUpdatePleaseTry;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'UPDATING'**
  String get updating;

  /// No description provided for @slideToOpen.
  ///
  /// In en, this message translates to:
  /// **'SLIDE TO OPEN'**
  String get slideToOpen;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride history'**
  String get rideHistory;

  /// No description provided for @goOfflineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Go offline?'**
  String get goOfflineQuestion;

  /// No description provided for @youStopGettingTripOffersUntil.
  ///
  /// In en, this message translates to:
  /// **'You stop getting trip offers until you go online again.'**
  String get youStopGettingTripOffersUntil;

  /// No description provided for @stayOnline.
  ///
  /// In en, this message translates to:
  /// **'Stay online'**
  String get stayOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get goOffline;

  /// No description provided for @restUntilTime.
  ///
  /// In en, this message translates to:
  /// **'Rest until {time}'**
  String restUntilTime(Object time);

  /// No description provided for @timeLeftToDrive.
  ///
  /// In en, this message translates to:
  /// **'{time} left to drive'**
  String timeLeftToDrive(Object time);

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @findingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location'**
  String get findingYourLocation;

  /// No description provided for @untilTime.
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String untilTime(Object time);

  /// No description provided for @documentExpired.
  ///
  /// In en, this message translates to:
  /// **'Document expired'**
  String get documentExpired;

  /// No description provided for @skipExclusiveOffer.
  ///
  /// In en, this message translates to:
  /// **'Skip Exclusive offer'**
  String get skipExclusiveOffer;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @tapToAccept.
  ///
  /// In en, this message translates to:
  /// **'Tap here'**
  String get tapToAccept;

  /// No description provided for @headToYourPickupTimePickup.
  ///
  /// In en, this message translates to:
  /// **'Head to your {pickupTime} pickup now: {pickupAddress}.'**
  String headToYourPickupTimePickup(Object pickupTime, Object pickupAddress);

  /// No description provided for @headToYourPickupTimePickup2.
  ///
  /// In en, this message translates to:
  /// **'Head to your {pickupTime} pickup'**
  String headToYourPickupTimePickup2(Object pickupTime);

  /// No description provided for @leaveNowForPickupTimePickup.
  ///
  /// In en, this message translates to:
  /// **'Leave now for {pickupTime} pickup'**
  String leaveNowForPickupTimePickup(Object pickupTime);

  /// No description provided for @scheduledRide.
  ///
  /// In en, this message translates to:
  /// **'Scheduled ride'**
  String get scheduledRide;

  /// No description provided for @pickupAtPickupTimeInLeft.
  ///
  /// In en, this message translates to:
  /// **'Pickup at {pickupTime} in {left}: {pickupAddress}.'**
  String pickupAtPickupTimeInLeft(
    Object pickupTime,
    Object left,
    Object pickupAddress,
  );

  /// No description provided for @pickupTimePickupInLeft.
  ///
  /// In en, this message translates to:
  /// **'{pickupTime} pickup in {left}'**
  String pickupTimePickupInLeft(Object pickupTime, Object left);

  /// No description provided for @goOnlineNowForYourPickup.
  ///
  /// In en, this message translates to:
  /// **'Go online now for your {pickupTime} pickup.'**
  String goOnlineNowForYourPickup(Object pickupTime);

  /// No description provided for @goOnlineForPickupTimePickup.
  ///
  /// In en, this message translates to:
  /// **'Go online for {pickupTime} pickup'**
  String goOnlineForPickupTimePickup(Object pickupTime);

  /// No description provided for @matching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get matching;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @recenter.
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get recenter;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @skipDemo.
  ///
  /// In en, this message translates to:
  /// **'Skip demo'**
  String get skipDemo;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @safetyToolkit.
  ///
  /// In en, this message translates to:
  /// **'Safety toolkit'**
  String get safetyToolkit;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @searchDestination.
  ///
  /// In en, this message translates to:
  /// **'Search destination'**
  String get searchDestination;

  /// No description provided for @lastTrip.
  ///
  /// In en, this message translates to:
  /// **'LAST TRIP'**
  String get lastTrip;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @rightNow.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get rightNow;

  /// No description provided for @cashRides.
  ///
  /// In en, this message translates to:
  /// **'Cash rides'**
  String get cashRides;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @latestWaybill.
  ///
  /// In en, this message translates to:
  /// **'Latest waybill'**
  String get latestWaybill;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get noneYet;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @acceptance.
  ///
  /// In en, this message translates to:
  /// **'Acceptance'**
  String get acceptance;

  /// No description provided for @cancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get cancellation;

  /// No description provided for @drivingTime.
  ///
  /// In en, this message translates to:
  /// **'Driving time'**
  String get drivingTime;

  /// No description provided for @worked.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get worked;

  /// No description provided for @leftBeforeRest.
  ///
  /// In en, this message translates to:
  /// **'Left before rest'**
  String get leftBeforeRest;

  /// No description provided for @restUntil.
  ///
  /// In en, this message translates to:
  /// **'Rest until'**
  String get restUntil;

  /// No description provided for @workLimit.
  ///
  /// In en, this message translates to:
  /// **'Work limit'**
  String get workLimit;

  /// No description provided for @restAfterIt.
  ///
  /// In en, this message translates to:
  /// **'Rest after it'**
  String get restAfterIt;

  /// No description provided for @countsWhileRadarIsOnAfter.
  ///
  /// In en, this message translates to:
  /// **'Counts while Radar is on. After {workHours} h you rest {restHours} h before going online again. A {restHours} h break starts it from zero.'**
  String countsWhileRadarIsOnAfter(Object workHours, Object restHours);

  /// No description provided for @closeSheet.
  ///
  /// In en, this message translates to:
  /// **'Close sheet'**
  String get closeSheet;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @exclusiveReservation.
  ///
  /// In en, this message translates to:
  /// **'Exclusive reservation'**
  String get exclusiveReservation;

  /// No description provided for @exclusiveOffer.
  ///
  /// In en, this message translates to:
  /// **'Exclusive offer'**
  String get exclusiveOffer;

  /// No description provided for @moveraRadar.
  ///
  /// In en, this message translates to:
  /// **'Movera Radar'**
  String get moveraRadar;

  /// No description provided for @rider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get rider;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @islandRadarOffers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 offer · radar} other{{count} offers · radar}}'**
  String islandRadarOffers(int count);

  /// No description provided for @savedTripCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The saved trip could not be opened.'**
  String get savedTripCouldNotBeOpened;

  /// No description provided for @tripStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trip storage on this device could not be opened, so no saved trip can be restored now. You can still go online.'**
  String get tripStorageUnavailable;

  /// No description provided for @unresolvedTrip.
  ///
  /// In en, this message translates to:
  /// **'Unresolved trip'**
  String get unresolvedTrip;

  /// No description provided for @thisSavedTripIsOlderThan.
  ///
  /// In en, this message translates to:
  /// **'This saved trip is older than six hours. Resume it or close it explicitly.'**
  String get thisSavedTripIsOlderThan;

  /// No description provided for @savedRouteCoordinatesAreUnavailableClose.
  ///
  /// In en, this message translates to:
  /// **'Saved route coordinates are unavailable. Close this trip explicitly before accepting another.'**
  String get savedRouteCoordinatesAreUnavailableClose;

  /// No description provided for @closeTrip.
  ///
  /// In en, this message translates to:
  /// **'Close trip'**
  String get closeTrip;

  /// No description provided for @resumeTrip.
  ///
  /// In en, this message translates to:
  /// **'Resume trip'**
  String get resumeTrip;

  /// No description provided for @savedTripCouldNotBeClosed.
  ///
  /// In en, this message translates to:
  /// **'The saved trip could not be closed.'**
  String get savedTripCouldNotBeClosed;

  /// No description provided for @savedTripCannotBeRead.
  ///
  /// In en, this message translates to:
  /// **'Saved trip cannot be read'**
  String get savedTripCannotBeRead;

  /// No description provided for @tripSavedOnThisDeviceIs.
  ///
  /// In en, this message translates to:
  /// **'The trip saved on this device is damaged or from another app version. Close it to continue. A copy is kept on this device for support.'**
  String get tripSavedOnThisDeviceIs;

  /// No description provided for @closeUnreadableTrip.
  ///
  /// In en, this message translates to:
  /// **'Close unreadable trip'**
  String get closeUnreadableTrip;

  /// No description provided for @savedTripCouldNotBeRead.
  ///
  /// In en, this message translates to:
  /// **'A saved trip could not be read. Close it to go online.'**
  String get savedTripCouldNotBeRead;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @unreadableTripCouldNotBeClosed.
  ///
  /// In en, this message translates to:
  /// **'The unreadable trip could not be closed.'**
  String get unreadableTripCouldNotBeClosed;

  /// No description provided for @riderDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rider data unavailable'**
  String get riderDataUnavailable;

  /// No description provided for @finishOrCloseSavedTripBefore.
  ///
  /// In en, this message translates to:
  /// **'Finish or close the saved trip before going online.'**
  String get finishOrCloseSavedTripBefore;

  /// No description provided for @openSavedTrip.
  ///
  /// In en, this message translates to:
  /// **'Open saved trip'**
  String get openSavedTrip;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @radar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get radar;

  /// No description provided for @tapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details'**
  String get tapForDetails;

  /// No description provided for @notActive.
  ///
  /// In en, this message translates to:
  /// **'Not active'**
  String get notActive;

  /// No description provided for @tapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan'**
  String get tapToScan;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @tripFound.
  ///
  /// In en, this message translates to:
  /// **'Trip found'**
  String get tripFound;

  /// No description provided for @tapForAll.
  ///
  /// In en, this message translates to:
  /// **'Tap for all'**
  String get tapForAll;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @currentTrip.
  ///
  /// In en, this message translates to:
  /// **'Current trip'**
  String get currentTrip;

  /// No description provided for @nextTripSecured.
  ///
  /// In en, this message translates to:
  /// **'Next trip secured'**
  String get nextTripSecured;

  /// No description provided for @riderNameIsOnWay.
  ///
  /// In en, this message translates to:
  /// **'{riderName} is on the way'**
  String riderNameIsOnWay(Object riderName);

  /// No description provided for @tripUpdatesCouldNotBeRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Trip updates could not be refreshed.'**
  String get tripUpdatesCouldNotBeRefreshed;

  /// No description provided for @tripUpdateCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip update could not be saved. Retrying automatically.'**
  String get tripUpdateCouldNotBeSaved;

  /// No description provided for @retryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get retryNow;

  /// No description provided for @couldNotSaveRiderCancellationRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not save rider cancellation. Retry.'**
  String get couldNotSaveRiderCancellationRetry;

  /// No description provided for @tripProgressCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip progress could not be saved. Keep this screen open and retry.'**
  String get tripProgressCouldNotBeSaved;

  /// No description provided for @thisStopNeedsVerifiedMapLocation.
  ///
  /// In en, this message translates to:
  /// **'This stop needs a verified map location before arrival.'**
  String get thisStopNeedsVerifiedMapLocation;

  /// No description provided for @locationUnavailableEnableLocationToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable. Enable location to confirm arrival.'**
  String get locationUnavailableEnableLocationToConfirm;

  /// No description provided for @preciseLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Precise location is off. Turn it on in Settings to show your position and confirm arrival.'**
  String get preciseLocationOff;

  /// No description provided for @preciseLocationOffShort.
  ///
  /// In en, this message translates to:
  /// **'Precise location off'**
  String get preciseLocationOffShort;

  /// No description provided for @yourDriverHasArrivedAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Your driver has arrived at the pickup point.'**
  String get yourDriverHasArrivedAtPickup;

  /// No description provided for @locationUpdatingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Location updating…'**
  String get locationUpdatingEllipsis;

  /// No description provided for @stopLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stop location unavailable'**
  String get stopLocationUnavailable;

  /// No description provided for @couldNotFinishSavingThisTrip.
  ///
  /// In en, this message translates to:
  /// **'Could not finish saving this trip. Retry completion; the receipt will not duplicate.'**
  String get couldNotFinishSavingThisTrip;

  /// No description provided for @alongYourDestination.
  ///
  /// In en, this message translates to:
  /// **'Along your destination'**
  String get alongYourDestination;

  /// No description provided for @cancelNextTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel the next trip?'**
  String get cancelNextTripQuestion;

  /// No description provided for @endThisTripEarlyQuestion.
  ///
  /// In en, this message translates to:
  /// **'End this trip early?'**
  String get endThisTripEarlyQuestion;

  /// No description provided for @cancelThisTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel this trip?'**
  String get cancelThisTripQuestion;

  /// No description provided for @reasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason: {title}'**
  String reasonTitle(Object title);

  /// No description provided for @yourCurrentTripContinuesNextTrip.
  ///
  /// In en, this message translates to:
  /// **'Your current trip continues. The next trip goes back to dispatch for another driver.'**
  String get yourCurrentTripContinuesNextTrip;

  /// No description provided for @onlyEndTripAfterYouHave.
  ///
  /// In en, this message translates to:
  /// **'Only end the trip after you have stopped in a safe place and the rider can exit safely.'**
  String get onlyEndTripAfterYouHave;

  /// No description provided for @cancelNextTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel next trip'**
  String get cancelNextTrip;

  /// No description provided for @endTripEarly.
  ///
  /// In en, this message translates to:
  /// **'End trip early'**
  String get endTripEarly;

  /// No description provided for @cancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get cancelTrip;

  /// No description provided for @keepTrip.
  ///
  /// In en, this message translates to:
  /// **'Keep trip'**
  String get keepTrip;

  /// No description provided for @thisTripCannotBeCancelledRight.
  ///
  /// In en, this message translates to:
  /// **'This trip cannot be cancelled right now.'**
  String get thisTripCannotBeCancelledRight;

  /// No description provided for @couldNotSaveCancellationRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not save cancellation. Retry.'**
  String get couldNotSaveCancellationRetry;

  /// No description provided for @firstTripEndedStartingNextOne.
  ///
  /// In en, this message translates to:
  /// **'First trip ended · starting the next one'**
  String get firstTripEndedStartingNextOne;

  /// No description provided for @tripEndedEarlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip ended early · {title}'**
  String tripEndedEarlyTitle(Object title);

  /// No description provided for @tripCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled · {title}'**
  String tripCancelledTitle(Object title);

  /// No description provided for @tripRouteAndOptions.
  ///
  /// In en, this message translates to:
  /// **'Trip route and options'**
  String get tripRouteAndOptions;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get arrival;

  /// No description provided for @arriving.
  ///
  /// In en, this message translates to:
  /// **'Arriving'**
  String get arriving;

  /// No description provided for @turnExclusiveOffersOff.
  ///
  /// In en, this message translates to:
  /// **'Turn Exclusive offers off'**
  String get turnExclusiveOffersOff;

  /// No description provided for @turnExclusiveOffersOn.
  ///
  /// In en, this message translates to:
  /// **'Turn Exclusive offers on'**
  String get turnExclusiveOffersOn;

  /// No description provided for @cashCollectInCar.
  ///
  /// In en, this message translates to:
  /// **'Cash: collect in the car'**
  String get cashCollectInCar;

  /// No description provided for @paidByCard.
  ///
  /// In en, this message translates to:
  /// **'Paid by card'**
  String get paidByCard;

  /// No description provided for @rideCheckDemo.
  ///
  /// In en, this message translates to:
  /// **'Ride check demo'**
  String get rideCheckDemo;

  /// No description provided for @demoValue.
  ///
  /// In en, this message translates to:
  /// **'Demo: {value}'**
  String demoValue(Object value);

  /// No description provided for @routeProgress.
  ///
  /// In en, this message translates to:
  /// **'Route progress'**
  String get routeProgress;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @addressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Address unavailable'**
  String get addressUnavailable;

  /// No description provided for @doesnTCount.
  ///
  /// In en, this message translates to:
  /// **'Doesn’t count'**
  String get doesnTCount;

  /// No description provided for @tripUpdatesDisconnectedReconnectingIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Trip updates disconnected. Reconnecting is required.'**
  String get tripUpdatesDisconnectedReconnectingIsRequired;

  /// No description provided for @pickingUpRiderName.
  ///
  /// In en, this message translates to:
  /// **'Picking up {riderName}'**
  String pickingUpRiderName(Object riderName);

  /// No description provided for @waitingForRiderName.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {riderName}'**
  String waitingForRiderName(Object riderName);

  /// No description provided for @waitingAtStopNumber.
  ///
  /// In en, this message translates to:
  /// **'Waiting at stop {number}'**
  String waitingAtStopNumber(Object number);

  /// No description provided for @headingToStopNumber.
  ///
  /// In en, this message translates to:
  /// **'Heading to stop {number}'**
  String headingToStopNumber(Object number);

  /// No description provided for @droppingOffRiderName.
  ///
  /// In en, this message translates to:
  /// **'Dropping off {riderName}'**
  String droppingOffRiderName(Object riderName);

  /// No description provided for @pickUpRiderName.
  ///
  /// In en, this message translates to:
  /// **'Pick up {riderName}'**
  String pickUpRiderName(Object riderName);

  /// No description provided for @driveToStopNumber.
  ///
  /// In en, this message translates to:
  /// **'Drive to stop {number}'**
  String driveToStopNumber(Object number);

  /// No description provided for @dropOffRiderName.
  ///
  /// In en, this message translates to:
  /// **'Drop off {riderName}'**
  String dropOffRiderName(Object riderName);

  /// No description provided for @enRoute.
  ///
  /// In en, this message translates to:
  /// **'En route'**
  String get enRoute;

  /// No description provided for @paidWaitAtStopNumber.
  ///
  /// In en, this message translates to:
  /// **'Paid wait at stop {number}'**
  String paidWaitAtStopNumber(Object number);

  /// No description provided for @includedWaitThenPaid.
  ///
  /// In en, this message translates to:
  /// **'Included wait · then paid'**
  String get includedWaitThenPaid;

  /// No description provided for @paidWaitRunning.
  ///
  /// In en, this message translates to:
  /// **'Paid wait running'**
  String get paidWaitRunning;

  /// No description provided for @paidWaitNoShowAvailable.
  ///
  /// In en, this message translates to:
  /// **'Paid wait · no-show available'**
  String get paidWaitNoShowAvailable;

  /// No description provided for @nextStop.
  ///
  /// In en, this message translates to:
  /// **'Next stop'**
  String get nextStop;

  /// No description provided for @toDropOff.
  ///
  /// In en, this message translates to:
  /// **'To drop-off'**
  String get toDropOff;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @tripStarted.
  ///
  /// In en, this message translates to:
  /// **'Trip started'**
  String get tripStarted;

  /// No description provided for @tripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get tripCompleted;

  /// No description provided for @holdForRiderName.
  ///
  /// In en, this message translates to:
  /// **'Hold for {riderName}'**
  String holdForRiderName(Object riderName);

  /// No description provided for @thenDropOff.
  ///
  /// In en, this message translates to:
  /// **'Then drop-off'**
  String get thenDropOff;

  /// No description provided for @stop1OfStopAddressesLength.
  ///
  /// In en, this message translates to:
  /// **'Stop 1 of {stopAddressesLength}'**
  String stop1OfStopAddressesLength(Object stopAddressesLength);

  /// No description provided for @actionCouldNotBeCompletedPlease.
  ///
  /// In en, this message translates to:
  /// **'The action could not be completed. Please retry.'**
  String get actionCouldNotBeCompletedPlease;

  /// No description provided for @confirmThisTripActionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Confirm this trip action?'**
  String get confirmThisTripActionQuestion;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @finishSoSoonQuestion.
  ///
  /// In en, this message translates to:
  /// **'Finish so soon?'**
  String get finishSoSoonQuestion;

  /// No description provided for @youPickedUpRiderMinutesMin.
  ///
  /// In en, this message translates to:
  /// **'You picked up the rider {minutes} min ago. Finish only if the trip really ended.'**
  String youPickedUpRiderMinutesMin(Object minutes);

  /// No description provided for @backToRide.
  ///
  /// In en, this message translates to:
  /// **'Back to ride'**
  String get backToRide;

  /// No description provided for @finishTrip.
  ///
  /// In en, this message translates to:
  /// **'Finish trip'**
  String get finishTrip;

  /// No description provided for @isEverythingOkQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is everything OK?'**
  String get isEverythingOkQuestion;

  /// No description provided for @rideCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride check. {title}'**
  String rideCheckTitle(Object title);

  /// No description provided for @rideCheck.
  ///
  /// In en, this message translates to:
  /// **'Ride check'**
  String get rideCheck;

  /// No description provided for @call112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get call112;

  /// No description provided for @iMOk.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK'**
  String get iMOk;

  /// No description provided for @orTellUsWhatSHappening.
  ///
  /// In en, this message translates to:
  /// **'Or tell us what\'s happening'**
  String get orTellUsWhatSHappening;

  /// No description provided for @yourAnswerIsSavedToThis.
  ///
  /// In en, this message translates to:
  /// **'Your answer is saved to this trip.'**
  String get yourAnswerIsSavedToThis;

  /// No description provided for @rideCheckShort.
  ///
  /// In en, this message translates to:
  /// **'Ride check · {short}'**
  String rideCheckShort(Object short);

  /// No description provided for @whatIsHappeningQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is happening?'**
  String get whatIsHappeningQuestion;

  /// No description provided for @thanksThisIsSavedToTrip.
  ///
  /// In en, this message translates to:
  /// **'Thanks, this is saved to the trip.'**
  String get thanksThisIsSavedToTrip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @yourAnswersAreSavedToThis.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved to this trip.'**
  String get yourAnswersAreSavedToThis;

  /// No description provided for @rideCheck112.
  ///
  /// In en, this message translates to:
  /// **'Ride check · 112'**
  String get rideCheck112;

  /// No description provided for @call112OnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Call 112 on your phone'**
  String get call112OnYourPhone;

  /// No description provided for @couldNotOpenDialerDial112.
  ///
  /// In en, this message translates to:
  /// **'Could not open the dialer. Dial 112 manually.'**
  String get couldNotOpenDialerDial112;

  /// No description provided for @yourDialerOpensWith112Movera.
  ///
  /// In en, this message translates to:
  /// **'Your dialer opens with 112. Movera never calls for you.'**
  String get yourDialerOpensWith112Movera;

  /// No description provided for @moveraCouldNotBeAlerted.
  ///
  /// In en, this message translates to:
  /// **'Movera could not be alerted'**
  String get moveraCouldNotBeAlerted;

  /// No description provided for @moveraSafetyTeamAlerted.
  ///
  /// In en, this message translates to:
  /// **'Movera safety team alerted'**
  String get moveraSafetyTeamAlerted;

  /// No description provided for @safetyAlertKeptOnPhoneDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo: alert kept on this phone only. No one at Movera was notified.'**
  String get safetyAlertKeptOnPhoneDemo;

  /// No description provided for @safetyAlertNotSentLive.
  ///
  /// In en, this message translates to:
  /// **'Not sent: Movera cannot receive ride-check alerts yet. In danger, call 112.'**
  String get safetyAlertNotSentLive;

  /// No description provided for @call112IfYouNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'\nCall 112 if you need help now.'**
  String get call112IfYouNeedHelp;

  /// No description provided for @tripDriverAndRiderDetailsWere.
  ///
  /// In en, this message translates to:
  /// **'\nTrip, driver and rider details were sent.'**
  String get tripDriverAndRiderDetailsWere;

  /// No description provided for @call112Now.
  ///
  /// In en, this message translates to:
  /// **'Call 112 now'**
  String get call112Now;

  /// No description provided for @ifSomeoneIsHurtOrIn.
  ///
  /// In en, this message translates to:
  /// **'If someone is hurt or in danger, call emergency services.'**
  String get ifSomeoneIsHurtOrIn;

  /// No description provided for @tellUsInFewWords.
  ///
  /// In en, this message translates to:
  /// **'Tell us in a few words'**
  String get tellUsInFewWords;

  /// No description provided for @recordingTime.
  ///
  /// In en, this message translates to:
  /// **'Recording {time}'**
  String recordingTime(Object time);

  /// No description provided for @savedOnlyOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'saved only on this phone'**
  String get savedOnlyOnThisPhone;

  /// No description provided for @recordAudio.
  ///
  /// In en, this message translates to:
  /// **'Record audio'**
  String get recordAudio;

  /// No description provided for @audioStoppedWhenAppLeft.
  ///
  /// In en, this message translates to:
  /// **'stopped when Movera left the screen'**
  String get audioStoppedWhenAppLeft;

  /// No description provided for @audioSavedTime.
  ///
  /// In en, this message translates to:
  /// **'Audio saved · {time}'**
  String audioSavedTime(Object time);

  /// No description provided for @onlyOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'only on this phone'**
  String get onlyOnThisPhone;

  /// No description provided for @notAvailableOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'not available on this device'**
  String get notAvailableOnThisDevice;

  /// No description provided for @allowMicrophoneFirst.
  ///
  /// In en, this message translates to:
  /// **'allow the microphone first'**
  String get allowMicrophoneFirst;

  /// No description provided for @couldNotRecordTryAgain.
  ///
  /// In en, this message translates to:
  /// **'could not record, try again'**
  String get couldNotRecordTryAgain;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @moveraRecordedThisTripAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Movera recorded this trip as completed.'**
  String get moveraRecordedThisTripAsCompleted;

  /// No description provided for @tripCancelledByMovera.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled by Movera'**
  String get tripCancelledByMovera;

  /// No description provided for @moveraCancelledThisTripStopIn.
  ///
  /// In en, this message translates to:
  /// **'Movera cancelled this trip. Stop in a safe place before leaving this screen.'**
  String get moveraCancelledThisTripStopIn;

  /// No description provided for @moveraClosedThisTripStopIn.
  ///
  /// In en, this message translates to:
  /// **'Movera closed this trip. Stop in a safe place before leaving this screen.'**
  String get moveraClosedThisTripStopIn;

  /// No description provided for @tripCancelled.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled'**
  String get tripCancelled;

  /// No description provided for @thisTripWasCancelledFromYour.
  ///
  /// In en, this message translates to:
  /// **'This trip was cancelled from your account.'**
  String get thisTripWasCancelledFromYour;

  /// No description provided for @riderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Rider cancelled'**
  String get riderCancelled;

  /// No description provided for @riderCancelledThisTrip.
  ///
  /// In en, this message translates to:
  /// **'The rider cancelled this trip.'**
  String get riderCancelledThisTrip;

  /// No description provided for @riderNoShowRecorded.
  ///
  /// In en, this message translates to:
  /// **'Rider no-show recorded'**
  String get riderNoShowRecorded;

  /// No description provided for @thisPickupWasClosedBecauseRider.
  ///
  /// In en, this message translates to:
  /// **'This pickup was closed because the rider did not arrive.'**
  String get thisPickupWasClosedBecauseRider;

  /// No description provided for @tripExpired.
  ///
  /// In en, this message translates to:
  /// **'Trip expired'**
  String get tripExpired;

  /// No description provided for @thisTripIsNoLongerActive.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer active.'**
  String get thisTripIsNoLongerActive;

  /// No description provided for @tripCouldNotContinue.
  ///
  /// In en, this message translates to:
  /// **'Trip could not continue'**
  String get tripCouldNotContinue;

  /// No description provided for @tripWasClosedBecauseOfSystem.
  ///
  /// In en, this message translates to:
  /// **'The trip was closed because of a system problem. Contact support if the rider is still with you.'**
  String get tripWasClosedBecauseOfSystem;

  /// No description provided for @tripRemovedByMovera.
  ///
  /// In en, this message translates to:
  /// **'Trip removed by Movera'**
  String get tripRemovedByMovera;

  /// No description provided for @moveraGaveThisTripBackTo.
  ///
  /// In en, this message translates to:
  /// **'Movera gave this trip back to dispatch. Stop in a safe place before leaving this screen.'**
  String get moveraGaveThisTripBackTo;

  /// No description provided for @tripEnded.
  ///
  /// In en, this message translates to:
  /// **'Trip ended'**
  String get tripEnded;

  /// No description provided for @bodyYourNextTripStartsNow.
  ///
  /// In en, this message translates to:
  /// **'{body} Your next trip starts now.'**
  String bodyYourNextTripStartsNow(Object body);

  /// No description provided for @goToNextTrip.
  ///
  /// In en, this message translates to:
  /// **'Go to next trip'**
  String get goToNextTrip;

  /// No description provided for @holdToStopNextTrips.
  ///
  /// In en, this message translates to:
  /// **'Hold to stop next trips'**
  String get holdToStopNextTrips;

  /// No description provided for @holdToStartNextTrips.
  ///
  /// In en, this message translates to:
  /// **'Hold to start next trips'**
  String get holdToStartNextTrips;

  /// No description provided for @stopRadar.
  ///
  /// In en, this message translates to:
  /// **'Stop radar'**
  String get stopRadar;

  /// No description provided for @startRadar.
  ///
  /// In en, this message translates to:
  /// **'Start radar'**
  String get startRadar;

  /// No description provided for @headingToPickup.
  ///
  /// In en, this message translates to:
  /// **'Heading to pickup'**
  String get headingToPickup;

  /// No description provided for @waitingForFirst.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {first}'**
  String waitingForFirst(Object first);

  /// No description provided for @toNextStop.
  ///
  /// In en, this message translates to:
  /// **'To next stop'**
  String get toNextStop;

  /// No description provided for @onYourWay.
  ///
  /// In en, this message translates to:
  /// **'On your way'**
  String get onYourWay;

  /// No description provided for @afterThisDropOff.
  ///
  /// In en, this message translates to:
  /// **'After this drop-off'**
  String get afterThisDropOff;

  /// No description provided for @availableAfterYourCurrentDropOff.
  ///
  /// In en, this message translates to:
  /// **'Available after your current drop-off'**
  String get availableAfterYourCurrentDropOff;

  /// No description provided for @exclusiveSecondsS.
  ///
  /// In en, this message translates to:
  /// **'Exclusive · {seconds}s'**
  String exclusiveSecondsS(Object seconds);

  /// No description provided for @onThisRide.
  ///
  /// In en, this message translates to:
  /// **'On this ride'**
  String get onThisRide;

  /// No description provided for @pickupMinutesMinAway.
  ///
  /// In en, this message translates to:
  /// **'{pickupMinutes} min away'**
  String pickupMinutesMinAway(Object pickupMinutes);

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @demoOffers.
  ///
  /// In en, this message translates to:
  /// **'Demo offers'**
  String get demoOffers;

  /// No description provided for @demoOffersLiveLocationUnavailableStale.
  ///
  /// In en, this message translates to:
  /// **'Demo offers — live location unavailable/stale'**
  String get demoOffersLiveLocationUnavailableStale;

  /// No description provided for @navigateWithGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Navigate with Google Maps'**
  String get navigateWithGoogleMaps;

  /// No description provided for @googleMapsIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Maps is unavailable.'**
  String get googleMapsIsUnavailable;

  /// No description provided for @callRider.
  ///
  /// In en, this message translates to:
  /// **'Call rider'**
  String get callRider;

  /// No description provided for @messageRider.
  ///
  /// In en, this message translates to:
  /// **'Message rider'**
  String get messageRider;

  /// No description provided for @riderDetailsFromBookingWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Rider details from the booking will appear here when the backend profile is connected.'**
  String get riderDetailsFromBookingWillAppear;

  /// No description provided for @retryRoute.
  ///
  /// In en, this message translates to:
  /// **'Retry route'**
  String get retryRoute;

  /// No description provided for @routeUnavailableYourTripRemainsActive.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable. Your trip remains active.'**
  String get routeUnavailableYourTripRemainsActive;

  /// No description provided for @currentWaybill.
  ///
  /// In en, this message translates to:
  /// **'Current waybill'**
  String get currentWaybill;

  /// No description provided for @currentTripWaybill.
  ///
  /// In en, this message translates to:
  /// **'Current trip waybill'**
  String get currentTripWaybill;

  /// No description provided for @nextTripWaybill.
  ///
  /// In en, this message translates to:
  /// **'Next trip waybill'**
  String get nextTripWaybill;

  /// No description provided for @nextTripsOnYourWay.
  ///
  /// In en, this message translates to:
  /// **'Next trips on your way'**
  String get nextTripsOnYourWay;

  /// No description provided for @shareTripRecordAudioGetHelp.
  ///
  /// In en, this message translates to:
  /// **'Share trip, record audio, get help'**
  String get shareTripRecordAudioGetHelp;

  /// No description provided for @shareTripGetHelp.
  ///
  /// In en, this message translates to:
  /// **'Share trip, get help'**
  String get shareTripGetHelp;

  /// No description provided for @stopSafelyFirstReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Stop safely first · reason required'**
  String get stopSafelyFirstReasonRequired;

  /// No description provided for @whyAreYouCancellingNextTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling the next trip?'**
  String get whyAreYouCancellingNextTripQuestion;

  /// No description provided for @whyAreYouEndingTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you ending the trip?'**
  String get whyAreYouEndingTripQuestion;

  /// No description provided for @whyAreYouCancellingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get whyAreYouCancellingQuestion;

  /// No description provided for @yourCurrentTripContinues.
  ///
  /// In en, this message translates to:
  /// **'Your current trip continues.'**
  String get yourCurrentTripContinues;

  /// No description provided for @stopInSafePlaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Stop in a safe place first.'**
  String get stopInSafePlaceFirst;

  /// No description provided for @pickReasonThatFitsBest.
  ///
  /// In en, this message translates to:
  /// **'Pick the reason that fits best.'**
  String get pickReasonThatFitsBest;

  /// No description provided for @riderEndedTrip.
  ///
  /// In en, this message translates to:
  /// **'Rider ended the trip'**
  String get riderEndedTrip;

  /// No description provided for @riderNameCancelledWhileTripWas.
  ///
  /// In en, this message translates to:
  /// **'{riderName} cancelled while the trip was active. Stop in a safe place before leaving this screen.'**
  String riderNameCancelledWhileTripWas(Object riderName);

  /// No description provided for @riderNameCancelledThisRequestCurrent.
  ///
  /// In en, this message translates to:
  /// **'{riderName} cancelled this request. The current pickup is no longer active.'**
  String riderNameCancelledThisRequestCurrent(Object riderName);

  /// No description provided for @activeTripCancelledByRider.
  ///
  /// In en, this message translates to:
  /// **'Active trip cancelled by rider'**
  String get activeTripCancelledByRider;

  /// No description provided for @pickupCancelledByRider.
  ///
  /// In en, this message translates to:
  /// **'Pickup cancelled by rider'**
  String get pickupCancelledByRider;

  /// No description provided for @tripUpdate.
  ///
  /// In en, this message translates to:
  /// **'TRIP UPDATE'**
  String get tripUpdate;

  /// No description provided for @keepControlOfVehicleAndStop.
  ///
  /// In en, this message translates to:
  /// **'Keep control of the vehicle and stop safely before continuing.'**
  String get keepControlOfVehicleAndStop;

  /// No description provided for @iHaveStoppedSafely.
  ///
  /// In en, this message translates to:
  /// **'I have stopped safely'**
  String get iHaveStoppedSafely;

  /// No description provided for @returnToRequests.
  ///
  /// In en, this message translates to:
  /// **'Return to requests'**
  String get returnToRequests;

  /// No description provided for @waitingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Waiting in progress'**
  String get waitingInProgress;

  /// No description provided for @takeCashBeforeYouFinish.
  ///
  /// In en, this message translates to:
  /// **'Take the cash before you finish.'**
  String get takeCashBeforeYouFinish;

  /// No description provided for @takeCashFromFirstBeforeYou.
  ///
  /// In en, this message translates to:
  /// **'Take the cash from {first} before you finish.'**
  String takeCashFromFirstBeforeYou(Object first);

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @collectAmountInCash.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} in cash'**
  String collectAmountInCash(Object amount);

  /// No description provided for @collect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get collect;

  /// No description provided for @inCash.
  ///
  /// In en, this message translates to:
  /// **'in cash'**
  String get inCash;

  /// No description provided for @yourFare.
  ///
  /// In en, this message translates to:
  /// **'Your fare'**
  String get yourFare;

  /// No description provided for @cashFromRider.
  ///
  /// In en, this message translates to:
  /// **'Cash from rider'**
  String get cashFromRider;

  /// No description provided for @riderPaidMoreThanYourFare.
  ///
  /// In en, this message translates to:
  /// **'The rider paid more than your fare (promotion). It is settled in your next payout.'**
  String get riderPaidMoreThanYourFare;

  /// No description provided for @riderPaidLessThanYourFare.
  ///
  /// In en, this message translates to:
  /// **'The rider paid less than your fare (promotion). Movera adds it to your next payout.'**
  String get riderPaidLessThanYourFare;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get to;

  /// No description provided for @pickupArrived.
  ///
  /// In en, this message translates to:
  /// **'Pickup · arrived'**
  String get pickupArrived;

  /// No description provided for @pickupPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Pickup · picked up'**
  String get pickupPickedUp;

  /// No description provided for @stopNumberDone.
  ///
  /// In en, this message translates to:
  /// **'Stop {number} · done'**
  String stopNumberDone(Object number);

  /// No description provided for @yourTrip.
  ///
  /// In en, this message translates to:
  /// **'Your trip'**
  String get yourTrip;

  /// No description provided for @pickupPickupMinutesMin.
  ///
  /// In en, this message translates to:
  /// **'Pickup · {pickupMinutes} min'**
  String pickupPickupMinutesMin(Object pickupMinutes);

  /// No description provided for @dropOffTripMinutesMinTrip.
  ///
  /// In en, this message translates to:
  /// **'Drop-off · {tripMinutes} min trip'**
  String dropOffTripMinutesMinTrip(Object tripMinutes);

  /// No description provided for @nextTripOptions.
  ///
  /// In en, this message translates to:
  /// **'Next trip options'**
  String get nextTripOptions;

  /// No description provided for @openWaybill.
  ///
  /// In en, this message translates to:
  /// **'Open waybill'**
  String get openWaybill;

  /// No description provided for @contactRider.
  ///
  /// In en, this message translates to:
  /// **'Contact rider'**
  String get contactRider;

  /// No description provided for @yourCurrentTripContinuesReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Your current trip continues · reason required'**
  String get yourCurrentTripContinuesReasonRequired;

  /// No description provided for @nextTripCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Next trip cancelled · {title}'**
  String nextTripCancelledTitle(Object title);

  /// No description provided for @waybill.
  ///
  /// In en, this message translates to:
  /// **'Waybill'**
  String get waybill;

  /// No description provided for @stopWait.
  ///
  /// In en, this message translates to:
  /// **'Stop wait'**
  String get stopWait;

  /// No description provided for @pickupWait.
  ///
  /// In en, this message translates to:
  /// **'Pickup wait'**
  String get pickupWait;

  /// No description provided for @everyMinuteIsPaid.
  ///
  /// In en, this message translates to:
  /// **'Every minute is paid'**
  String get everyMinuteIsPaid;

  /// No description provided for @thisStopHasNoFreeMinutes.
  ///
  /// In en, this message translates to:
  /// **'This stop has no free minutes. The whole wait is added to the fare.'**
  String get thisStopHasNoFreeMinutes;

  /// No description provided for @ruleForThisPickupRule.
  ///
  /// In en, this message translates to:
  /// **'Rule for this pickup: {rule}'**
  String ruleForThisPickupRule(Object rule);

  /// No description provided for @includedTime.
  ///
  /// In en, this message translates to:
  /// **'Included time'**
  String get includedTime;

  /// No description provided for @openingMinutesStayInsideFare.
  ///
  /// In en, this message translates to:
  /// **'The opening minutes stay inside the fare.'**
  String get openingMinutesStayInsideFare;

  /// No description provided for @waitTime.
  ///
  /// In en, this message translates to:
  /// **'Wait time'**
  String get waitTime;

  /// No description provided for @addedFromFirstSecondAtThis.
  ///
  /// In en, this message translates to:
  /// **'Added from the first second at this stop.'**
  String get addedFromFirstSecondAtThis;

  /// No description provided for @addedToFareWhenThisTrip.
  ///
  /// In en, this message translates to:
  /// **'Added to the fare when this trip is completed.'**
  String get addedToFareWhenThisTrip;

  /// No description provided for @perMinuteFormattedMin.
  ///
  /// In en, this message translates to:
  /// **'{perMinuteFormatted} / min'**
  String perMinuteFormattedMin(Object perMinuteFormatted);

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get noShow;

  /// No description provided for @canBeAppliedAfterNoShow.
  ///
  /// In en, this message translates to:
  /// **'Can be applied after {noShowAfterMinutes} min if the rider has not arrived.'**
  String canBeAppliedAfterNoShow(Object noShowAfterMinutes);

  /// No description provided for @riderDidnTShow.
  ///
  /// In en, this message translates to:
  /// **'Rider didn’t show'**
  String get riderDidnTShow;

  /// No description provided for @youGetDriverShareWaitPercent.
  ///
  /// In en, this message translates to:
  /// **'You get {driverShareWaitPercent}% of the wait time.'**
  String youGetDriverShareWaitPercent(Object driverShareWaitPercent);

  /// No description provided for @youGetDriverShareWaitPercent2.
  ///
  /// In en, this message translates to:
  /// **'You get {driverShareWaitPercent}% of the wait time and {driverShareNoShowPercent}% of the no-show fee ({driverNoShowFeeFormatted}).'**
  String youGetDriverShareWaitPercent2(
    Object driverShareWaitPercent,
    Object driverShareNoShowPercent,
    Object driverNoShowFeeFormatted,
  );

  /// No description provided for @amountsCanChangeWithTaxesAnd.
  ///
  /// In en, this message translates to:
  /// **'Amounts can change with taxes and fees.'**
  String get amountsCanChangeWithTaxesAnd;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @waitingFeePerMinuteFormattedMin.
  ///
  /// In en, this message translates to:
  /// **'waiting fee · {perMinuteFormatted} / min'**
  String waitingFeePerMinuteFormattedMin(Object perMinuteFormatted);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @includedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Included minutes'**
  String get includedMinutes;

  /// No description provided for @theseFirstMinutesAreAlreadyPart.
  ///
  /// In en, this message translates to:
  /// **'These first minutes are already part of the fare.'**
  String get theseFirstMinutesAreAlreadyPart;

  /// No description provided for @waitTimeIsRunning.
  ///
  /// In en, this message translates to:
  /// **'Wait time is running'**
  String get waitTimeIsRunning;

  /// No description provided for @eachMinuteAfterIncludedTimeIs.
  ///
  /// In en, this message translates to:
  /// **'Each minute after the included time is added when the trip ends.'**
  String get eachMinuteAfterIncludedTimeIs;

  /// No description provided for @noShowCanBeApplied.
  ///
  /// In en, this message translates to:
  /// **'No-show can be applied'**
  String get noShowCanBeApplied;

  /// No description provided for @riderIsStillNotHereNo.
  ///
  /// In en, this message translates to:
  /// **'The rider is still not here. The no-show amount is now available.'**
  String get riderIsStillNotHereNo;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetails;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @rideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ride completed'**
  String get rideCompleted;

  /// No description provided for @includesFeeWaitingFee.
  ///
  /// In en, this message translates to:
  /// **'Includes {fee} waiting fee'**
  String includesFeeWaitingFee(Object fee);

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @lastWaybill.
  ///
  /// In en, this message translates to:
  /// **'Last waybill'**
  String get lastWaybill;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @tripId.
  ///
  /// In en, this message translates to:
  /// **'Trip ID'**
  String get tripId;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @ratingNotSentDemo.
  ///
  /// In en, this message translates to:
  /// **'Rating not sent (demo)'**
  String get ratingNotSentDemo;

  /// No description provided for @rateRider.
  ///
  /// In en, this message translates to:
  /// **'Rate {rider}'**
  String rateRider(Object rider);

  /// No description provided for @trip.
  ///
  /// In en, this message translates to:
  /// **'Trip #'**
  String get trip;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @passenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// No description provided for @via.
  ///
  /// In en, this message translates to:
  /// **'Via'**
  String get via;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to2.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to2;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'License plate'**
  String get licensePlate;

  /// No description provided for @passengerCapacity.
  ///
  /// In en, this message translates to:
  /// **'Passenger capacity'**
  String get passengerCapacity;

  /// No description provided for @paidByPassenger.
  ///
  /// In en, this message translates to:
  /// **'Paid by the passenger'**
  String get paidByPassenger;

  /// No description provided for @inApp.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get inApp;

  /// No description provided for @basePriceService.
  ///
  /// In en, this message translates to:
  /// **'Base price · {service}'**
  String basePriceService(Object service);

  /// No description provided for @moveraFee.
  ///
  /// In en, this message translates to:
  /// **'Movera fee'**
  String get moveraFee;

  /// No description provided for @moveraBonus.
  ///
  /// In en, this message translates to:
  /// **'Movera bonus'**
  String get moveraBonus;

  /// No description provided for @yourEarnings.
  ///
  /// In en, this message translates to:
  /// **'Your earnings'**
  String get yourEarnings;

  /// No description provided for @riderPays.
  ///
  /// In en, this message translates to:
  /// **'Rider pays'**
  String get riderPays;

  /// No description provided for @roundToNearestWholeKronaIn.
  ///
  /// In en, this message translates to:
  /// **'* Round to the nearest whole krona in the taximeter.'**
  String get roundToNearestWholeKronaIn;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @samplePeriod.
  ///
  /// In en, this message translates to:
  /// **'Sample period'**
  String get samplePeriod;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @earningsPreview.
  ///
  /// In en, this message translates to:
  /// **'Earnings preview'**
  String get earningsPreview;

  /// No description provided for @demoRider.
  ///
  /// In en, this message translates to:
  /// **'Demo rider'**
  String get demoRider;

  /// No description provided for @sampleDistance.
  ///
  /// In en, this message translates to:
  /// **'Sample distance'**
  String get sampleDistance;

  /// No description provided for @sample.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get sample;

  /// No description provided for @pickupFrom.
  ///
  /// In en, this message translates to:
  /// **'Pickup from'**
  String get pickupFrom;

  /// No description provided for @samplePickupStockholm.
  ///
  /// In en, this message translates to:
  /// **'Sample pickup, Stockholm'**
  String get samplePickupStockholm;

  /// No description provided for @dropOffLocation.
  ///
  /// In en, this message translates to:
  /// **'Drop off location'**
  String get dropOffLocation;

  /// No description provided for @sampleDropOffStockholm.
  ///
  /// In en, this message translates to:
  /// **'Sample drop-off, Stockholm'**
  String get sampleDropOffStockholm;

  /// No description provided for @noAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get noAnswer;

  /// No description provided for @answerAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String answerAnswer(Object answer);

  /// No description provided for @audioSavedOnlyOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Audio saved only on this phone · {time}'**
  String audioSavedOnlyOnThisPhone(Object time);

  /// No description provided for @illustrativeMapArchivedRouteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Illustrative map · archived route unavailable'**
  String get illustrativeMapArchivedRouteUnavailable;

  /// No description provided for @rideCost.
  ///
  /// In en, this message translates to:
  /// **'Ride Cost'**
  String get rideCost;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @rideType.
  ///
  /// In en, this message translates to:
  /// **'Ride Type'**
  String get rideType;

  /// No description provided for @cashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get cashCollected;

  /// No description provided for @cashMatchedYourFare.
  ///
  /// In en, this message translates to:
  /// **'Cash matched your fare'**
  String get cashMatchedYourFare;

  /// No description provided for @cashMatchedYourEarnings.
  ///
  /// In en, this message translates to:
  /// **'Cash matched your earnings: nothing to settle'**
  String get cashMatchedYourEarnings;

  /// No description provided for @settledInYourNextPayout.
  ///
  /// In en, this message translates to:
  /// **'Settled in your next payout'**
  String get settledInYourNextPayout;

  /// No description provided for @rideCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'Ride completed on'**
  String get rideCompletedOn;

  /// No description provided for @cancelledByRider.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by rider'**
  String get cancelledByRider;

  /// No description provided for @cancelledByDriver.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by driver'**
  String get cancelledByDriver;

  /// No description provided for @cancelledBySupport.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by support'**
  String get cancelledBySupport;

  /// No description provided for @cancelledByMovera.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by Movera'**
  String get cancelledByMovera;

  /// No description provided for @riderDidNotArrive.
  ///
  /// In en, this message translates to:
  /// **'Rider did not arrive'**
  String get riderDidNotArrive;

  /// No description provided for @tripFailed.
  ///
  /// In en, this message translates to:
  /// **'Trip failed'**
  String get tripFailed;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @loadingRideHistoryEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading ride history…'**
  String get loadingRideHistoryEllipsis;

  /// No description provided for @couldNotLoadRideHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load ride history.'**
  String get couldNotLoadRideHistory;

  /// No description provided for @earningsHistory.
  ///
  /// In en, this message translates to:
  /// **'Earnings & history'**
  String get earningsHistory;

  /// No description provided for @allRides.
  ///
  /// In en, this message translates to:
  /// **'All rides'**
  String get allRides;

  /// No description provided for @yourMoveraActivity.
  ///
  /// In en, this message translates to:
  /// **'Your Movera activity'**
  String get yourMoveraActivity;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @rides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get rides;

  /// No description provided for @earningsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Earnings breakdown'**
  String get earningsBreakdown;

  /// No description provided for @latestRides.
  ///
  /// In en, this message translates to:
  /// **'Latest rides'**
  String get latestRides;

  /// No description provided for @noCompletedRidesInThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'No completed rides in this period.'**
  String get noCompletedRidesInThisPeriod;

  /// No description provided for @viewAllVisibleRideCountRides.
  ///
  /// In en, this message translates to:
  /// **'View all {visibleRideCount} rides'**
  String viewAllVisibleRideCountRides(Object visibleRideCount);

  /// No description provided for @periodRidesRidesInPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'{periodRides} rides in {periodLabel}'**
  String periodRidesRidesInPeriodLabel(Object periodRides, Object periodLabel);

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @recordedFares.
  ///
  /// In en, this message translates to:
  /// **'Recorded earnings'**
  String get recordedFares;

  /// No description provided for @tipsAndFees.
  ///
  /// In en, this message translates to:
  /// **'Tips and fees'**
  String get tipsAndFees;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @otherEarnings.
  ///
  /// In en, this message translates to:
  /// **'Other earnings'**
  String get otherEarnings;

  /// No description provided for @otherEarningsTripsLengthCash.
  ///
  /// In en, this message translates to:
  /// **'Other earnings · {tripsLength} cash'**
  String otherEarningsTripsLengthCash(Object tripsLength);

  /// No description provided for @cashTripsYourFareMinusCash.
  ///
  /// In en, this message translates to:
  /// **'Cash trips: your fare minus the cash you collected.'**
  String get cashTripsYourFareMinusCash;

  /// No description provided for @noCashTripsInThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'No cash trips in this period.'**
  String get noCashTripsInThisPeriod;

  /// No description provided for @totalYouOweMovera.
  ///
  /// In en, this message translates to:
  /// **'Total you owe Movera'**
  String get totalYouOweMovera;

  /// No description provided for @totalMoveraOwesYou.
  ///
  /// In en, this message translates to:
  /// **'Total Movera owes you'**
  String get totalMoveraOwesYou;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @settledInYourNextPayout2.
  ///
  /// In en, this message translates to:
  /// **'Settled in your next payout.'**
  String get settledInYourNextPayout2;

  /// No description provided for @fareFareFormattedCashCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Earnings {fareFormatted} · Cash {cashCollectedFormatted}'**
  String fareFareFormattedCashCashCollected(
    Object fareFormatted,
    Object cashCollectedFormatted,
  );

  /// No description provided for @cashFareFeeLine.
  ///
  /// In en, this message translates to:
  /// **'Fare {fare} · Fee {fee} · Cash {cash}'**
  String cashFareFeeLine(String fare, String fee, String cash);

  /// No description provided for @driver2.
  ///
  /// In en, this message translates to:
  /// **'DRIVER'**
  String get driver2;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @accountVehicleAndDocuments.
  ///
  /// In en, this message translates to:
  /// **'Account, vehicle and documents'**
  String get accountVehicleAndDocuments;

  /// No description provided for @earningsAndWeeklyPayouts.
  ///
  /// In en, this message translates to:
  /// **'Earnings and weekly payouts'**
  String get earningsAndWeeklyPayouts;

  /// No description provided for @completedAndPreviousRides.
  ///
  /// In en, this message translates to:
  /// **'Completed and previous rides'**
  String get completedAndPreviousRides;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @rideAlertsDemandAndAccount.
  ///
  /// In en, this message translates to:
  /// **'Ride alerts, demand and account'**
  String get rideAlertsDemandAndAccount;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get work;

  /// No description provided for @scheduledRides.
  ///
  /// In en, this message translates to:
  /// **'Scheduled rides'**
  String get scheduledRides;

  /// No description provided for @reservationsAndAcceptedTrips.
  ///
  /// In en, this message translates to:
  /// **'Reservations and accepted trips'**
  String get reservationsAndAcceptedTrips;

  /// No description provided for @chooseCategoriesYouWantToReceive.
  ///
  /// In en, this message translates to:
  /// **'Choose categories you want to receive'**
  String get chooseCategoriesYouWantToReceive;

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotions;

  /// No description provided for @bonusesAndCampaignOffers.
  ///
  /// In en, this message translates to:
  /// **'Bonuses and campaign offers'**
  String get bonusesAndCampaignOffers;

  /// No description provided for @drivingLogs.
  ///
  /// In en, this message translates to:
  /// **'Driving logs'**
  String get drivingLogs;

  /// No description provided for @hoursOnlineAndRestRules.
  ///
  /// In en, this message translates to:
  /// **'Hours online and rest rules'**
  String get hoursOnlineAndRestRules;

  /// No description provided for @supportApp.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & APP'**
  String get supportApp;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @messagesAndSupportTickets.
  ///
  /// In en, this message translates to:
  /// **'Messages and support tickets'**
  String get messagesAndSupportTickets;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appAndDriverSettings.
  ///
  /// In en, this message translates to:
  /// **'App and driver settings'**
  String get appAndDriverSettings;

  /// No description provided for @sampleRating.
  ///
  /// In en, this message translates to:
  /// **'Sample rating {rating}'**
  String sampleRating(Object rating);

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @soundVoice.
  ///
  /// In en, this message translates to:
  /// **'Sound & voice'**
  String get soundVoice;

  /// No description provided for @savingPreferencesEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving preferences…'**
  String get savingPreferencesEllipsis;

  /// No description provided for @changesNotSavedRetry.
  ///
  /// In en, this message translates to:
  /// **'Changes not saved — Retry'**
  String get changesNotSavedRetry;

  /// No description provided for @couldNotLoadSavedPreferencesRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved preferences — Retry'**
  String get couldNotLoadSavedPreferencesRetry;

  /// No description provided for @localDemoPreferencesSavedOnThis.
  ///
  /// In en, this message translates to:
  /// **'Local demo preferences — saved on this device; effects are previews.'**
  String get localDemoPreferencesSavedOnThis;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @generalVolume.
  ///
  /// In en, this message translates to:
  /// **'General volume'**
  String get generalVolume;

  /// No description provided for @alwaysPlayTripRequests.
  ///
  /// In en, this message translates to:
  /// **'Always play trip requests'**
  String get alwaysPlayTripRequests;

  /// No description provided for @playsEvenWhenPhoneIsSilent.
  ///
  /// In en, this message translates to:
  /// **'Plays even when the phone is silent'**
  String get playsEvenWhenPhoneIsSilent;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @voiceNavigation.
  ///
  /// In en, this message translates to:
  /// **'Voice navigation'**
  String get voiceNavigation;

  /// No description provided for @spokenTurnsWhileYouDrive.
  ///
  /// In en, this message translates to:
  /// **'Spoken turns while you drive'**
  String get spokenTurnsWhileYouDrive;

  /// No description provided for @readRiderMessages.
  ///
  /// In en, this message translates to:
  /// **'Read rider messages'**
  String get readRiderMessages;

  /// No description provided for @readsNewChatMessagesAloud.
  ///
  /// In en, this message translates to:
  /// **'Reads new chat messages aloud'**
  String get readsNewChatMessagesAloud;

  /// No description provided for @testAlerts.
  ///
  /// In en, this message translates to:
  /// **'Test alerts'**
  String get testAlerts;

  /// No description provided for @testVoice.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get testVoice;

  /// No description provided for @playingAlertSoundMock.
  ///
  /// In en, this message translates to:
  /// **'Playing alert sound (mock)'**
  String get playingAlertSoundMock;

  /// No description provided for @playingVoiceSoundMock.
  ///
  /// In en, this message translates to:
  /// **'Playing voice sound (mock)'**
  String get playingVoiceSoundMock;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @hearing.
  ///
  /// In en, this message translates to:
  /// **'Hearing'**
  String get hearing;

  /// No description provided for @tellRidersIfYouAreDeaf.
  ///
  /// In en, this message translates to:
  /// **'Tell riders if you are deaf or hard of hearing.'**
  String get tellRidersIfYouAreDeaf;

  /// No description provided for @demoPreviewNoInformationIsShared.
  ///
  /// In en, this message translates to:
  /// **'Demo preview — no information is shared with riders.'**
  String get demoPreviewNoInformationIsShared;

  /// No description provided for @closePreview.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get closePreview;

  /// No description provided for @flashForRequests.
  ///
  /// In en, this message translates to:
  /// **'Flash for requests'**
  String get flashForRequests;

  /// No description provided for @screenFlashesWhenRequestArrives.
  ///
  /// In en, this message translates to:
  /// **'The screen flashes when a request arrives.'**
  String get screenFlashesWhenRequestArrives;

  /// No description provided for @vibrationForRequests.
  ///
  /// In en, this message translates to:
  /// **'Vibration for requests'**
  String get vibrationForRequests;

  /// No description provided for @phoneVibratesWhenRequestArrives.
  ///
  /// In en, this message translates to:
  /// **'The phone vibrates when a request arrives.'**
  String get phoneVibratesWhenRequestArrives;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettings;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @unavailableInDemo.
  ///
  /// In en, this message translates to:
  /// **'Unavailable in demo'**
  String get unavailableInDemo;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @pinVerification.
  ///
  /// In en, this message translates to:
  /// **'PIN verification'**
  String get pinVerification;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get emergencyContacts;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @trustedContact.
  ///
  /// In en, this message translates to:
  /// **'Trusted contact'**
  String get trustedContact;

  /// No description provided for @dialerIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Dialer is unavailable.'**
  String get dialerIsUnavailable;

  /// No description provided for @addTrustedContact.
  ///
  /// In en, this message translates to:
  /// **'Add trusted contact'**
  String get addTrustedContact;

  /// No description provided for @couldNotLoadTrustedContactsRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load trusted contacts — Retry'**
  String get couldNotLoadTrustedContactsRetry;

  /// No description provided for @trustedContactsStayOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Trusted contacts stay on this device. Calling opens your dialer.'**
  String get trustedContactsStayOnThisDevice;

  /// No description provided for @callName.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callName(Object name);

  /// No description provided for @contactCouldNotBeSavedRetry.
  ///
  /// In en, this message translates to:
  /// **'Contact could not be saved. Retry.'**
  String get contactCouldNotBeSavedRetry;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @enterValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhoneNumber;

  /// No description provided for @relation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get relation;

  /// No description provided for @savingContactEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving contact…'**
  String get savingContactEllipsis;

  /// No description provided for @saveContact.
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get saveContact;

  /// No description provided for @recentPayouts.
  ///
  /// In en, this message translates to:
  /// **'Recent payouts'**
  String get recentPayouts;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @previewOnly.
  ///
  /// In en, this message translates to:
  /// **'Preview only'**
  String get previewOnly;

  /// No description provided for @noPayoutBalanceUntilPaymentService.
  ///
  /// In en, this message translates to:
  /// **'No payout balance until a payment service is connected.'**
  String get noPayoutBalanceUntilPaymentService;

  /// No description provided for @noAutomaticPayout.
  ///
  /// In en, this message translates to:
  /// **'No automatic payout'**
  String get noAutomaticPayout;

  /// No description provided for @payoutDateIsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Payout date is not available'**
  String get payoutDateIsNotAvailable;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @noPayoutsYetLocalPreviewCannot.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet. Local preview cannot invent earnings.'**
  String get noPayoutsYetLocalPreviewCannot;

  /// No description provided for @payoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Payout account'**
  String get payoutAccount;

  /// No description provided for @noPayoutAccountConnected.
  ///
  /// In en, this message translates to:
  /// **'No payout account connected'**
  String get noPayoutAccountConnected;

  /// No description provided for @ratingRiderTripsTrips.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {riderTrips} trips'**
  String ratingRiderTripsTrips(Object rating, Object riderTrips);

  /// No description provided for @closeOffer.
  ///
  /// In en, this message translates to:
  /// **'Close offer'**
  String get closeOffer;

  /// No description provided for @reservationTime.
  ///
  /// In en, this message translates to:
  /// **'Reservation · {time}'**
  String reservationTime(Object time);

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @demoModeNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — no account'**
  String get demoModeNoAccount;

  /// No description provided for @labelUnavailableInDemo.
  ///
  /// In en, this message translates to:
  /// **'{label} — unavailable in demo'**
  String labelUnavailableInDemo(Object label);

  /// No description provided for @routeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Route updated'**
  String get routeUpdated;

  /// No description provided for @gpsRestored.
  ///
  /// In en, this message translates to:
  /// **'GPS restored'**
  String get gpsRestored;

  /// No description provided for @waitingAtStop.
  ///
  /// In en, this message translates to:
  /// **'Waiting at stop'**
  String get waitingAtStop;

  /// No description provided for @paidWaiting.
  ///
  /// In en, this message translates to:
  /// **'Paid waiting'**
  String get paidWaiting;

  /// No description provided for @waitingTime.
  ///
  /// In en, this message translates to:
  /// **'Waiting time'**
  String get waitingTime;

  /// No description provided for @nearValue.
  ///
  /// In en, this message translates to:
  /// **'Near {value}'**
  String nearValue(Object value);

  /// No description provided for @arrivingSoon.
  ///
  /// In en, this message translates to:
  /// **'Arriving soon'**
  String get arrivingSoon;

  /// No description provided for @trafficAheadValueMin.
  ///
  /// In en, this message translates to:
  /// **'Traffic ahead · +{value} min'**
  String trafficAheadValueMin(Object value);

  /// No description provided for @arrivingInEtaMinTimeTime2.
  ///
  /// In en, this message translates to:
  /// **'Arriving in {eta} min · {time}:{time2}'**
  String arrivingInEtaMinTimeTime2(Object eta, Object time, Object time2);

  /// No description provided for @nextTripSecuredNextTripFare.
  ///
  /// In en, this message translates to:
  /// **'Next trip secured · {nextTripFare}'**
  String nextTripSecuredNextTripFare(Object nextTripFare);

  /// No description provided for @tollAhead.
  ///
  /// In en, this message translates to:
  /// **'Toll ahead'**
  String get tollAhead;

  /// No description provided for @pickupOverKmKm.
  ///
  /// In en, this message translates to:
  /// **'Pickup over {km} km'**
  String pickupOverKmKm(Object km);

  /// No description provided for @assignedByMovera.
  ///
  /// In en, this message translates to:
  /// **'Assigned by Movera'**
  String get assignedByMovera;

  /// No description provided for @inclBonusMoveraBonus.
  ///
  /// In en, this message translates to:
  /// **'incl. +{bonus} Movera bonus'**
  String inclBonusMoveraBonus(Object bonus);

  /// Admin text key island.online (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Radar online'**
  String get islandOnline;

  /// Admin text key island.offline (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Radar offline'**
  String get islandOffline;

  /// Admin text key island.riderCancelled (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Rider cancelled'**
  String get islandRiderCancelled;

  /// Admin text key island.riderEndedTrip (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Rider ended trip'**
  String get islandRiderEndedTrip;

  /// Admin text key island.tripRemoved (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Trip removed by Movera'**
  String get islandTripRemoved;

  /// Admin text key island.cancelFee (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'+{amount}'**
  String islandCancelFee(Object amount);

  /// Admin text key island.cancelNoFee (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'no fee'**
  String get islandCancelNoFee;

  /// Admin text key island.reservationCancelled (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{time} cancelled'**
  String islandReservationCancelled(Object time);

  /// Admin text key island.matching (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Matching…'**
  String get islandMatching;

  /// Admin text key island.matched (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Trip matched'**
  String get islandMatched;

  /// Admin text key island.takenByOther (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Taken by another driver'**
  String get islandTakenByOther;

  /// Admin text key island.tripUnavailable (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Trip unavailable'**
  String get islandTripUnavailable;

  /// Admin text key island.noConnection (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get islandNoConnection;

  /// Admin text key island.contactSupport (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get islandContactSupport;

  /// Admin text key island.accountOnHold (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Account on hold · Contact support'**
  String get islandAccountOnHold;

  /// Admin text key island.accountNotActive (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Account not active · Finish sign-up'**
  String get islandAccountNotActive;

  /// Admin text key island.newReservation (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'New reservation'**
  String get islandNewReservation;

  /// Admin text key island.exclusiveRide (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Exclusive ride'**
  String get islandExclusiveRide;

  /// Admin text key island.exclusiveReservation (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Exclusive reservation'**
  String get islandExclusiveReservation;

  /// Admin text key island.reservationAccepted (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Reservation accepted'**
  String get islandReservationAccepted;

  /// Admin text key island.reservationAcceptedAt (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Accepted · pickup {time}'**
  String islandReservationAcceptedAt(Object time);

  /// Admin text key island.noLongerAvailable (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get islandNoLongerAvailable;

  /// Admin text key island.assignedByMovera (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Assigned by Movera'**
  String get islandAssignedByMovera;

  /// Admin text key island.assignmentAccepted (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Scheduled ride accepted'**
  String get islandAssignmentAccepted;

  /// Admin text key island.assignmentNotAccepted (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Assignment not accepted'**
  String get islandAssignmentNotAccepted;

  /// Admin text key island.pickupIn (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{time} pickup in {left}'**
  String islandPickupIn(Object time, Object left);

  /// Admin text key island.goOnlineFor (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Go online for {time} pickup'**
  String islandGoOnlineFor(Object time);

  /// Admin text key island.leaveNow (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Leave now for {time} pickup'**
  String islandLeaveNow(Object time);

  /// Admin text key island.headToPickup (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Head to your {time} pickup'**
  String islandHeadToPickup(Object time);

  /// Admin text key island.givenToBackup (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Given to backup driver'**
  String get islandGivenToBackup;

  /// Admin text key island.lateReassigned (Content › Driver app texts). The ETA showed the driver would reach the scheduled pickup too late, so the ride went to another driver.
  ///
  /// In en, this message translates to:
  /// **'Given to another driver: {minutes} min late'**
  String islandLateReassigned(Object minutes);

  /// Notification title: a scheduled ride was reassigned because the driver's ETA was too late.
  ///
  /// In en, this message translates to:
  /// **'Ride given to another driver'**
  String get lateEtaReassignedTitle;

  /// Why a scheduled ride was reassigned early: the driver's ETA to the pickup was too late.
  ///
  /// In en, this message translates to:
  /// **'Ride given to another driver — you would reach the {time} pickup about {minutes} min late.'**
  String lateEtaReassignedNote(String time, int minutes);

  /// Admin text key island.cashOn (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Cash rides on'**
  String get islandCashOn;

  /// Admin text key island.cashOff (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Cash rides off'**
  String get islandCashOff;

  /// Admin text key island.lastMissed (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Next missed offer: offline'**
  String get islandLastMissed;

  /// Admin text key island.offlineMissed (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Offline: {count} offers missed'**
  String islandOfflineMissed(Object count);

  /// Admin text key island.drivingLeft (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left to drive'**
  String islandDrivingLeft(Object minutes);

  /// Admin text key island.restUntil (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Rest until {time}'**
  String islandRestUntil(Object time);

  /// Admin text key island.restOver (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Rest over'**
  String get islandRestOver;

  /// Admin text key island.documentExpires (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{document} expires {when}'**
  String islandDocumentExpires(Object document, Object when);

  /// Admin text key island.documentExpired (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{document} expired'**
  String islandDocumentExpired(Object document);

  /// Admin text key island.documentInReview (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'New document in review'**
  String get islandDocumentInReview;

  /// Admin text key island.documentApproved (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Document approved'**
  String get islandDocumentApproved;

  /// Admin text key island.highDemand (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'High demand · {area}'**
  String islandHighDemand(Object area);

  /// Admin text key island.scheduledPaused (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Scheduled rides paused'**
  String get islandScheduledPaused;

  /// Admin text key island.savedTripOpen (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Saved trip open'**
  String get islandSavedTripOpen;

  /// Admin text key island.newerTripKept (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Newer trip kept'**
  String get islandNewerTripKept;

  /// Admin text key island.recordSetAside (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Trip record set aside'**
  String get islandRecordSetAside;

  /// Admin text key island.recoveryFailed (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Recovery failed'**
  String get islandRecoveryFailed;

  /// Admin text key island.tripNotClosed (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Trip not closed'**
  String get islandTripNotClosed;

  /// Admin text key island.closeSavedTrip (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Close saved trip'**
  String get islandCloseSavedTrip;

  /// Admin text key island.seeEarnings (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Tap to see earnings'**
  String get islandSeeEarnings;

  /// Admin text key island.destinationsUsed (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Today\'s destinations used'**
  String get islandDestinationsUsed;

  /// Admin text key island.destinationOff (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Destination mode is off here'**
  String get islandDestinationOff;

  /// Admin text key island.destinationEnded (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Destination mode ended'**
  String get islandDestinationEnded;

  /// Admin text key offer.yourShare (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get offerYourShare;

  /// Admin text key offer.fare (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get offerFare;

  /// Admin text key offer.pickup (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get offerPickup;

  /// Admin text key offer.dropoff (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get offerDropoff;

  /// Admin text key offer.pickupNearby (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Pickup nearby'**
  String get offerPickupNearby;

  /// Admin text key offer.kmAway (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String offerKmAway(Object km);

  /// Admin text key offer.tripLength (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'{minutes} min trip · {km} km'**
  String offerTripLength(Object minutes, Object km);

  /// Admin text key offer.match (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get offerMatch;

  /// Admin text key offer.matching (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Matching…'**
  String get offerMatching;

  /// Admin text key offer.accept (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get offerAccept;

  /// Admin text key offer.onYourWay (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'On your way'**
  String get offerOnYourWay;

  /// Admin text key offer.hide (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Hide offer'**
  String get offerHide;

  /// Admin text key offer.reservationRequest (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Reservation request'**
  String get offerReservationRequest;

  /// Admin text key offer.yourNextRide (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Your next ride'**
  String get offerYourNextRide;

  /// Admin text key offer.viewRoute (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'View route'**
  String get offerViewRoute;

  /// Admin text key offer.newReservation (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'New reservation'**
  String get offerNewReservation;

  /// Admin text key offer.viewDetails (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get offerViewDetails;

  /// Admin text key trip.arrived (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived'**
  String get tripArrived;

  /// Admin text key trip.start (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get tripStart;

  /// Admin text key trip.startFirstStop (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Start first stop'**
  String get tripStartFirstStop;

  /// Admin text key trip.arriveAtStop (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Arrive at the stop'**
  String get tripArriveAtStop;

  /// Admin text key trip.complete (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Complete trip'**
  String get tripComplete;

  /// Admin text key trip.goToStop (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Go to {stop} stop'**
  String tripGoToStop(Object stop);

  /// Admin text key trip.goToDropoff (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Go to drop-off'**
  String get tripGoToDropoff;

  /// Admin text key trip.collectCash (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Collect cash'**
  String get tripCollectCash;

  /// Admin text key trip.completeRide (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Complete ride'**
  String get tripCompleteRide;

  /// Admin text key trip.finishCategory (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Finish {category}'**
  String tripFinishCategory(Object category);

  /// Admin text key trip.finishRide (Content › Driver app texts).
  ///
  /// In en, this message translates to:
  /// **'Finish ride'**
  String get tripFinishRide;

  /// Cancel reason rider_no_show.
  ///
  /// In en, this message translates to:
  /// **'Rider did not arrive'**
  String get cancelReasonRiderNoShow;

  /// Cancel reason rider_no_show, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The no-show time has passed and the rider is not here'**
  String get cancelReasonRiderNoShowDetail;

  /// Cancel reason rider_requested_cancel.
  ///
  /// In en, this message translates to:
  /// **'Rider asked to cancel'**
  String get cancelReasonRiderRequestedCancel;

  /// Cancel reason rider_requested_cancel, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The rider doesn’t want to continue'**
  String get cancelReasonRiderRequestedCancelDetail;

  /// Cancel reason rider_not_at_pickup.
  ///
  /// In en, this message translates to:
  /// **'Rider not at pickup'**
  String get cancelReasonRiderNotAtPickup;

  /// Cancel reason rider_not_at_pickup, the line under it.
  ///
  /// In en, this message translates to:
  /// **'You arrived but couldn’t find the rider'**
  String get cancelReasonRiderNotAtPickupDetail;

  /// Cancel reason unsafe_pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup unsafe'**
  String get cancelReasonUnsafePickup;

  /// Cancel reason unsafe_pickup, the line under it.
  ///
  /// In en, this message translates to:
  /// **'You can’t stop there safely'**
  String get cancelReasonUnsafePickupDetail;

  /// Cancel reason vehicle_issue_before_start.
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get cancelReasonVehicleIssueBeforeStart;

  /// Cancel reason vehicle_issue_before_start, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Your car can’t make the trip'**
  String get cancelReasonVehicleIssueBeforeStartDetail;

  /// Cancel reason driver_emergency_before_start.
  ///
  /// In en, this message translates to:
  /// **'Personal emergency'**
  String get cancelReasonDriverEmergencyBeforeStart;

  /// Cancel reason driver_emergency_before_start, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Something urgent came up'**
  String get cancelReasonDriverEmergencyBeforeStartDetail;

  /// Cancel reason other_before_start.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonOtherBeforeStart;

  /// Cancel reason other_before_start, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Something else stops this pickup'**
  String get cancelReasonOtherBeforeStartDetail;

  /// Cancel reason rider_requested_early_end.
  ///
  /// In en, this message translates to:
  /// **'Rider asked to end the trip'**
  String get cancelReasonRiderRequestedEarlyEnd;

  /// Cancel reason rider_requested_early_end, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The rider wants to leave before the destination'**
  String get cancelReasonRiderRequestedEarlyEndDetail;

  /// Cancel reason safety_concern_on_trip.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get cancelReasonSafetyConcernOnTrip;

  /// Cancel reason safety_concern_on_trip, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Continuing the trip may be unsafe'**
  String get cancelReasonSafetyConcernOnTripDetail;

  /// Cancel reason vehicle_issue_on_trip.
  ///
  /// In en, this message translates to:
  /// **'Vehicle problem'**
  String get cancelReasonVehicleIssueOnTrip;

  /// Cancel reason vehicle_issue_on_trip, the line under it.
  ///
  /// In en, this message translates to:
  /// **'A vehicle issue makes it unsafe to continue'**
  String get cancelReasonVehicleIssueOnTripDetail;

  /// Cancel reason accident_or_road_emergency.
  ///
  /// In en, this message translates to:
  /// **'Accident or road emergency'**
  String get cancelReasonAccidentOrRoadEmergency;

  /// Cancel reason accident_or_road_emergency, the line under it.
  ///
  /// In en, this message translates to:
  /// **'An incident or emergency prevents continuing'**
  String get cancelReasonAccidentOrRoadEmergencyDetail;

  /// Cancel reason rider_behavior.
  ///
  /// In en, this message translates to:
  /// **'Rider behavior'**
  String get cancelReasonRiderBehavior;

  /// Cancel reason rider_behavior, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The rider’s behavior requires the trip to end'**
  String get cancelReasonRiderBehaviorDetail;

  /// Cancel reason trip_or_destination_issue.
  ///
  /// In en, this message translates to:
  /// **'Trip or destination issue'**
  String get cancelReasonTripOrDestinationIssue;

  /// Cancel reason trip_or_destination_issue, the line under it.
  ///
  /// In en, this message translates to:
  /// **'A trip detail or destination problem prevents continuing'**
  String get cancelReasonTripOrDestinationIssueDetail;

  /// Cancel reason other_on_trip.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonOtherOnTrip;

  /// Cancel reason other_on_trip, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Another issue requires the trip to end early'**
  String get cancelReasonOtherOnTripDetail;

  /// Cancel reason scheduled_cannot_make_time.
  ///
  /// In en, this message translates to:
  /// **'I can no longer make the pickup time'**
  String get cancelReasonScheduledCannotMakeTime;

  /// Cancel reason scheduled_vehicle_issue.
  ///
  /// In en, this message translates to:
  /// **'Vehicle issue'**
  String get cancelReasonScheduledVehicleIssue;

  /// Cancel reason scheduled_personal_emergency.
  ///
  /// In en, this message translates to:
  /// **'Personal emergency'**
  String get cancelReasonScheduledPersonalEmergency;

  /// Cancel reason scheduled_pickup_too_far.
  ///
  /// In en, this message translates to:
  /// **'Pickup is too far from me'**
  String get cancelReasonScheduledPickupTooFar;

  /// Cancel reason scheduled_trip_details.
  ///
  /// In en, this message translates to:
  /// **'Trip details no longer work for me'**
  String get cancelReasonScheduledTripDetails;

  /// Cancel reason scheduled_other.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonScheduledOther;

  /// Cancel reason next_trip_current_running_late.
  ///
  /// In en, this message translates to:
  /// **'Current trip is taking longer'**
  String get cancelReasonNextTripCurrentRunningLate;

  /// Cancel reason next_trip_current_running_late, the line under it.
  ///
  /// In en, this message translates to:
  /// **'You can’t reach the next pickup in time'**
  String get cancelReasonNextTripCurrentRunningLateDetail;

  /// Cancel reason next_trip_pickup_too_far.
  ///
  /// In en, this message translates to:
  /// **'Too far from the pickup'**
  String get cancelReasonNextTripPickupTooFar;

  /// Cancel reason next_trip_pickup_too_far, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The next pickup is further than expected'**
  String get cancelReasonNextTripPickupTooFarDetail;

  /// Cancel reason next_trip_rider_requested.
  ///
  /// In en, this message translates to:
  /// **'Rider asked me to cancel'**
  String get cancelReasonNextTripRiderRequested;

  /// Cancel reason next_trip_rider_requested, the line under it.
  ///
  /// In en, this message translates to:
  /// **'The next rider doesn’t want the trip'**
  String get cancelReasonNextTripRiderRequestedDetail;

  /// Cancel reason next_trip_vehicle_issue.
  ///
  /// In en, this message translates to:
  /// **'Problem with the car'**
  String get cancelReasonNextTripVehicleIssue;

  /// Cancel reason next_trip_vehicle_issue, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Your car can’t make the next trip'**
  String get cancelReasonNextTripVehicleIssueDetail;

  /// Cancel reason next_trip_driver_emergency.
  ///
  /// In en, this message translates to:
  /// **'Personal emergency'**
  String get cancelReasonNextTripDriverEmergency;

  /// Cancel reason next_trip_driver_emergency, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Something urgent came up'**
  String get cancelReasonNextTripDriverEmergencyDetail;

  /// Cancel reason next_trip_other.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonNextTripOther;

  /// Cancel reason next_trip_other, the line under it.
  ///
  /// In en, this message translates to:
  /// **'Something else stops the next trip'**
  String get cancelReasonNextTripOtherDetail;

  /// Cancel reason pickup_incorrect.
  ///
  /// In en, this message translates to:
  /// **'Pickup point is incorrect'**
  String get cancelReasonPickupIncorrect;

  /// Cancel reason wrong_ride_option.
  ///
  /// In en, this message translates to:
  /// **'I chose the wrong ride option'**
  String get cancelReasonWrongRideOption;

  /// Cancel reason requested_by_mistake.
  ///
  /// In en, this message translates to:
  /// **'I requested the ride by mistake'**
  String get cancelReasonRequestedByMistake;

  /// Cancel reason wait_too_long.
  ///
  /// In en, this message translates to:
  /// **'The wait is taking too long'**
  String get cancelReasonWaitTooLong;

  /// Cancel reason destination_change.
  ///
  /// In en, this message translates to:
  /// **'Destination needs to be changed'**
  String get cancelReasonDestinationChange;

  /// Cancel reason driver_not_suitable.
  ///
  /// In en, this message translates to:
  /// **'Driver/ride details are not suitable'**
  String get cancelReasonDriverNotSuitable;

  /// Cancel reason plans_changed.
  ///
  /// In en, this message translates to:
  /// **'Plans changed'**
  String get cancelReasonPlansChanged;

  /// Cancel reason something_else.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get cancelReasonSomethingElse;

  /// No description provided for @exclusiveReasonBestMatch.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get exclusiveReasonBestMatch;

  /// No description provided for @exclusiveReasonFavourite.
  ///
  /// In en, this message translates to:
  /// **'Rider\'s favourite'**
  String get exclusiveReasonFavourite;

  /// No description provided for @exclusiveReasonFinishingNearby.
  ///
  /// In en, this message translates to:
  /// **'Finishing nearby'**
  String get exclusiveReasonFinishingNearby;

  /// No description provided for @exclusiveReasonAirportQueue.
  ///
  /// In en, this message translates to:
  /// **'Airport queue'**
  String get exclusiveReasonAirportQueue;

  /// No description provided for @exclusiveReasonPickupSoon.
  ///
  /// In en, this message translates to:
  /// **'Pickup soon'**
  String get exclusiveReasonPickupSoon;

  /// No description provided for @exclusiveReasonNearby.
  ///
  /// In en, this message translates to:
  /// **'Only for you · nearby'**
  String get exclusiveReasonNearby;

  /// No description provided for @waitingRulePickupFarAway.
  ///
  /// In en, this message translates to:
  /// **'Pickup far away'**
  String get waitingRulePickupFarAway;

  /// No description provided for @waitingRuleScheduledRide.
  ///
  /// In en, this message translates to:
  /// **'Scheduled ride'**
  String get waitingRuleScheduledRide;

  /// No description provided for @waitingRuleAirportPickup.
  ///
  /// In en, this message translates to:
  /// **'Airport pickup'**
  String get waitingRuleAirportPickup;

  /// No description provided for @waitingRuleEventPickup.
  ///
  /// In en, this message translates to:
  /// **'Event pickup'**
  String get waitingRuleEventPickup;

  /// No description provided for @riderBags.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rider has 1 bag} other{Rider has {count} bags}}'**
  String riderBags(int count);

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageZoneDefault.
  ///
  /// In en, this message translates to:
  /// **'Default for your zone'**
  String get languageZoneDefault;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Language not saved. Try again.'**
  String get languageSaveFailed;

  /// No description provided for @mapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map unavailable. Check your connection, then reopen Movera.'**
  String get mapUnavailable;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @todayCaps.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayCaps;

  /// No description provided for @statusRest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get statusRest;

  /// No description provided for @statusHold.
  ///
  /// In en, this message translates to:
  /// **'HOLD'**
  String get statusHold;

  /// No description provided for @whenInMinutes.
  ///
  /// In en, this message translates to:
  /// **'In {minutes} min'**
  String whenInMinutes(Object minutes);

  /// No description provided for @whenInHours.
  ///
  /// In en, this message translates to:
  /// **'In {hours} h'**
  String whenInHours(Object hours);

  /// No description provided for @whenToday.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String whenToday(Object time);

  /// No description provided for @whenTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String whenTomorrow(Object time);

  /// Fills {stop} in "Go to {stop} stop".
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get stopOrdinal1;

  /// Fills {stop} in "Go to {stop} stop".
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get stopOrdinal2;

  /// Fills {stop} in "Go to {stop} stop".
  ///
  /// In en, this message translates to:
  /// **'third'**
  String get stopOrdinal3;

  /// Fills {stop} in "Go to {stop} stop".
  ///
  /// In en, this message translates to:
  /// **'fourth'**
  String get stopOrdinal4;

  /// Fills {stop} in "Go to {stop} stop".
  ///
  /// In en, this message translates to:
  /// **'fifth'**
  String get stopOrdinal5;

  /// Fills {stop} in "Go to {stop} stop" from the sixth stop on.
  ///
  /// In en, this message translates to:
  /// **'{number}th'**
  String stopOrdinalN(Object number);

  /// No description provided for @hideRequest.
  ///
  /// In en, this message translates to:
  /// **'Hide request'**
  String get hideRequest;

  /// No description provided for @holdToGoOffline.
  ///
  /// In en, this message translates to:
  /// **'Hold to go offline'**
  String get holdToGoOffline;

  /// No description provided for @tripOptions.
  ///
  /// In en, this message translates to:
  /// **'Trip options'**
  String get tripOptions;

  /// No description provided for @orbMatch.
  ///
  /// In en, this message translates to:
  /// **'MATCH'**
  String get orbMatch;

  /// No description provided for @orbWait.
  ///
  /// In en, this message translates to:
  /// **'WAIT'**
  String get orbWait;

  /// No description provided for @orbOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get orbOff;

  /// No description provided for @orbOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get orbOn;

  /// No description provided for @orbNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get orbNew;

  /// No description provided for @orbLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get orbLive;

  /// No description provided for @orbPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get orbPaused;

  /// No description provided for @orbStarting.
  ///
  /// In en, this message translates to:
  /// **'STARTING'**
  String get orbStarting;

  /// No description provided for @navArrived.
  ///
  /// In en, this message translates to:
  /// **'ARRIVED'**
  String get navArrived;

  /// No description provided for @navNear.
  ///
  /// In en, this message translates to:
  /// **'NEAR'**
  String get navNear;

  /// No description provided for @navNow.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get navNow;

  /// No description provided for @menuOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get menuOnline;

  /// No description provided for @menuOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get menuOffline;

  /// No description provided for @menuReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get menuReady;

  /// No description provided for @menuPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get menuPending;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @tripsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trip} other{{count} trips}}'**
  String tripsCount(int count);

  /// No description provided for @stopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String stopsCount(int count);

  /// No description provided for @navArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get navArrive;

  /// No description provided for @navHeadOut.
  ///
  /// In en, this message translates to:
  /// **'Head out'**
  String get navHeadOut;

  /// No description provided for @navKeepLeft.
  ///
  /// In en, this message translates to:
  /// **'Keep left'**
  String get navKeepLeft;

  /// No description provided for @navKeepRight.
  ///
  /// In en, this message translates to:
  /// **'Keep right'**
  String get navKeepRight;

  /// No description provided for @navTunnelAhead.
  ///
  /// In en, this message translates to:
  /// **'Tunnel ahead'**
  String get navTunnelAhead;

  /// No description provided for @navTollRoadAhead.
  ///
  /// In en, this message translates to:
  /// **'Toll road ahead'**
  String get navTollRoadAhead;

  /// No description provided for @navContinueStraight.
  ///
  /// In en, this message translates to:
  /// **'Continue straight'**
  String get navContinueStraight;

  /// No description provided for @navContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get navContinue;

  /// No description provided for @navRoundabout.
  ///
  /// In en, this message translates to:
  /// **'Roundabout'**
  String get navRoundabout;

  /// No description provided for @navRoundaboutExit.
  ///
  /// In en, this message translates to:
  /// **'Roundabout, exit {exit}'**
  String navRoundaboutExit(String exit);

  /// No description provided for @navRoundaboutUTurn.
  ///
  /// In en, this message translates to:
  /// **'Roundabout, U-turn'**
  String get navRoundaboutUTurn;

  /// No description provided for @navRoundaboutUTurnExit.
  ///
  /// In en, this message translates to:
  /// **'Roundabout, U-turn · exit {exit}'**
  String navRoundaboutUTurnExit(String exit);

  /// No description provided for @navSignedExit.
  ///
  /// In en, this message translates to:
  /// **'Exit {exit}'**
  String navSignedExit(String exit);

  /// No description provided for @navSignedExitTowards.
  ///
  /// In en, this message translates to:
  /// **'Exit {exit} · {place}'**
  String navSignedExitTowards(String exit, String place);

  /// No description provided for @navExitLeft.
  ///
  /// In en, this message translates to:
  /// **'Exit left'**
  String get navExitLeft;

  /// No description provided for @navExitRight.
  ///
  /// In en, this message translates to:
  /// **'Exit right'**
  String get navExitRight;

  /// No description provided for @navTakeExit.
  ///
  /// In en, this message translates to:
  /// **'Take the exit'**
  String get navTakeExit;

  /// No description provided for @navRampOnto.
  ///
  /// In en, this message translates to:
  /// **'Take the ramp onto'**
  String get navRampOnto;

  /// No description provided for @navRampLeft.
  ///
  /// In en, this message translates to:
  /// **'Take the ramp on the left'**
  String get navRampLeft;

  /// No description provided for @navRampRight.
  ///
  /// In en, this message translates to:
  /// **'Take the ramp on the right'**
  String get navRampRight;

  /// No description provided for @navRamp.
  ///
  /// In en, this message translates to:
  /// **'Take the ramp'**
  String get navRamp;

  /// No description provided for @navMergeLeft.
  ///
  /// In en, this message translates to:
  /// **'Merge left'**
  String get navMergeLeft;

  /// No description provided for @navMergeRight.
  ///
  /// In en, this message translates to:
  /// **'Merge right'**
  String get navMergeRight;

  /// No description provided for @navMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get navMerge;

  /// No description provided for @navForkLeft.
  ///
  /// In en, this message translates to:
  /// **'At the fork, go left'**
  String get navForkLeft;

  /// No description provided for @navForkRight.
  ///
  /// In en, this message translates to:
  /// **'At the fork, go right'**
  String get navForkRight;

  /// No description provided for @navContinueAtFork.
  ///
  /// In en, this message translates to:
  /// **'Continue at the fork'**
  String get navContinueAtFork;

  /// No description provided for @navTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get navTurnLeft;

  /// No description provided for @navTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get navTurnRight;

  /// No description provided for @navEndOfRoad.
  ///
  /// In en, this message translates to:
  /// **'End of the road'**
  String get navEndOfRoad;

  /// No description provided for @navUTurn.
  ///
  /// In en, this message translates to:
  /// **'U-turn'**
  String get navUTurn;

  /// No description provided for @navSharpLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp left'**
  String get navSharpLeft;

  /// No description provided for @navSharpRight.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp right'**
  String get navSharpRight;

  /// No description provided for @navSlightLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn slight left'**
  String get navSlightLeft;

  /// No description provided for @navSlightRight.
  ///
  /// In en, this message translates to:
  /// **'Turn slight right'**
  String get navSlightRight;

  /// No description provided for @navDistanceNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get navDistanceNow;

  /// No description provided for @navMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String navMeters(String meters);

  /// No description provided for @navKilometers.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String navKilometers(String km);

  /// No description provided for @navDecimalMark.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get navDecimalMark;

  /// No description provided for @navInDistance.
  ///
  /// In en, this message translates to:
  /// **'in {distance}'**
  String navInDistance(String distance);

  /// No description provided for @navActionIn.
  ///
  /// In en, this message translates to:
  /// **'{action} in {distance}'**
  String navActionIn(String action, String distance);

  /// No description provided for @navActionNow.
  ///
  /// In en, this message translates to:
  /// **'{action} now'**
  String navActionNow(String action);

  /// No description provided for @navActionFor.
  ///
  /// In en, this message translates to:
  /// **'{action} {distance}'**
  String navActionFor(String action, String distance);

  /// No description provided for @navOnto.
  ///
  /// In en, this message translates to:
  /// **'{action} onto {road}'**
  String navOnto(String action, String road);

  /// No description provided for @navArriveAtDestination.
  ///
  /// In en, this message translates to:
  /// **'Arrive at destination'**
  String get navArriveAtDestination;

  /// No description provided for @navHeadOutOn.
  ///
  /// In en, this message translates to:
  /// **'Head out on {road}'**
  String navHeadOutOn(String road);

  /// No description provided for @navContinueOn.
  ///
  /// In en, this message translates to:
  /// **'Continue on {road}'**
  String navContinueOn(String road);

  /// No description provided for @navRoundaboutContinue.
  ///
  /// In en, this message translates to:
  /// **'At the roundabout, continue'**
  String get navRoundaboutContinue;

  /// No description provided for @navRoundaboutTakeExit.
  ///
  /// In en, this message translates to:
  /// **'At roundabout, take exit {exit}'**
  String navRoundaboutTakeExit(String exit);

  /// No description provided for @navExitOnLeft.
  ///
  /// In en, this message translates to:
  /// **'Take the exit on the left'**
  String get navExitOnLeft;

  /// No description provided for @navExitOnRight.
  ///
  /// In en, this message translates to:
  /// **'Take the exit on the right'**
  String get navExitOnRight;

  /// No description provided for @navEndTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left at the end of the road'**
  String get navEndTurnLeft;

  /// No description provided for @navEndTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right at the end of the road'**
  String get navEndTurnRight;

  /// No description provided for @navAtEndOfRoad.
  ///
  /// In en, this message translates to:
  /// **'At the end of the road'**
  String get navAtEndOfRoad;

  /// No description provided for @navMakeUTurn.
  ///
  /// In en, this message translates to:
  /// **'Make a U-turn'**
  String get navMakeUTurn;

  /// No description provided for @navUseLeftLanes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use the left lane} other{Use the {count} left lanes}}'**
  String navUseLeftLanes(int count);

  /// No description provided for @navUseRightLanes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use the right lane} other{Use the {count} right lanes}}'**
  String navUseRightLanes(int count);

  /// No description provided for @navUseMiddleLanes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use the middle lane} other{Use the {count} middle lanes}}'**
  String navUseMiddleLanes(int count);

  /// No description provided for @navTowards.
  ///
  /// In en, this message translates to:
  /// **'towards {place}'**
  String navTowards(String place);

  /// No description provided for @navToDestination.
  ///
  /// In en, this message translates to:
  /// **'To destination'**
  String get navToDestination;

  /// No description provided for @navExitSemantics.
  ///
  /// In en, this message translates to:
  /// **'{cue}, exit {exit}'**
  String navExitSemantics(String cue, String exit);

  /// No description provided for @navPickupAhead.
  ///
  /// In en, this message translates to:
  /// **'Pickup ahead'**
  String get navPickupAhead;

  /// No description provided for @navDropOffAhead.
  ///
  /// In en, this message translates to:
  /// **'Drop-off ahead'**
  String get navDropOffAhead;

  /// No description provided for @navPointAhead.
  ///
  /// In en, this message translates to:
  /// **'{point} ahead'**
  String navPointAhead(String point);

  /// No description provided for @navToPickup.
  ///
  /// In en, this message translates to:
  /// **'Navigate to pickup'**
  String get navToPickup;

  /// No description provided for @navToPoint.
  ///
  /// In en, this message translates to:
  /// **'Navigate to {point}'**
  String navToPoint(String point);

  /// No description provided for @navDropOffLower.
  ///
  /// In en, this message translates to:
  /// **'drop-off'**
  String get navDropOffLower;

  /// No description provided for @navWaitingForRider.
  ///
  /// In en, this message translates to:
  /// **'Waiting for rider'**
  String get navWaitingForRider;

  /// No description provided for @navRouteUpdating.
  ///
  /// In en, this message translates to:
  /// **'Route updating…'**
  String get navRouteUpdating;

  /// No description provided for @navRouteRecalculating.
  ///
  /// In en, this message translates to:
  /// **'Recalculating route…'**
  String get navRouteRecalculating;

  /// No description provided for @navRouteUnavailableRetry.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable — retry'**
  String get navRouteUnavailableRetry;

  /// No description provided for @navRouteUnavailableLocation.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable — check location'**
  String get navRouteUnavailableLocation;

  /// No description provided for @authAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get authAddVehicle;

  /// No description provided for @authAddVehicleDetails.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle details for verification'**
  String get authAddVehicleDetails;

  /// No description provided for @vehicleMake.
  ///
  /// In en, this message translates to:
  /// **'Vehicle make'**
  String get vehicleMake;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle model'**
  String get vehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Vehicle year'**
  String get vehicleYear;

  /// No description provided for @enterModelYear.
  ///
  /// In en, this message translates to:
  /// **'Enter model year'**
  String get enterModelYear;

  /// No description provided for @licensePlateNumber.
  ///
  /// In en, this message translates to:
  /// **'License plate number'**
  String get licensePlateNumber;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicleType;

  /// No description provided for @vehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vehicleColor;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select color'**
  String get selectColor;

  /// No description provided for @tapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get tapToUpload;

  /// No description provided for @openingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get openingEllipsis;

  /// No description provided for @openCamera.
  ///
  /// In en, this message translates to:
  /// **'Open Camera'**
  String get openCamera;

  /// No description provided for @fileSelectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'File selected successfully!'**
  String get fileSelectedSuccessfully;

  /// No description provided for @vehicleDocumentSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Vehicle document selection failed'**
  String get vehicleDocumentSelectionFailed;

  /// No description provided for @couldNotReadSelectedFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file. Please try again.'**
  String get couldNotReadSelectedFile;

  /// No description provided for @photoCapturedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Photo captured successfully!'**
  String get photoCapturedSuccessfully;

  /// No description provided for @couldNotReadCapturedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not read the captured photo. Please try again.'**
  String get couldNotReadCapturedPhoto;

  /// No description provided for @docPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get docPassport;

  /// No description provided for @scanYourPassportPhoto.
  ///
  /// In en, this message translates to:
  /// **'Scan your passport photo'**
  String get scanYourPassportPhoto;

  /// No description provided for @docDrivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving License'**
  String get docDrivingLicense;

  /// No description provided for @scanYourDrivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Scan your driving license'**
  String get scanYourDrivingLicense;

  /// No description provided for @docNationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get docNationalId;

  /// No description provided for @scanYourNationalId.
  ///
  /// In en, this message translates to:
  /// **'Scan your national Id'**
  String get scanYourNationalId;

  /// No description provided for @selectDocumentTypeToScan.
  ///
  /// In en, this message translates to:
  /// **'Select the type of document you wish to scan'**
  String get selectDocumentTypeToScan;

  /// No description provided for @weNeedToDetermineDocument.
  ///
  /// In en, this message translates to:
  /// **'We need to determine  if an identity document is authentic and belongs to you'**
  String get weNeedToDetermineDocument;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @enterValidPhoneForCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number where we will send a verification code'**
  String get enterValidPhoneForCode;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @acceptTermsAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Accept terms and privacy policy'**
  String get acceptTermsAndPrivacy;

  /// No description provided for @byContinuingIAgreeTo.
  ///
  /// In en, this message translates to:
  /// **' By continuing, I agree to the '**
  String get byContinuingIAgreeTo;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @andWord.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andWord;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @phoneVerification.
  ///
  /// In en, this message translates to:
  /// **'Phone verification'**
  String get phoneVerification;

  /// No description provided for @codeDeliveryUnavailableDemo.
  ///
  /// In en, this message translates to:
  /// **'Code delivery is unavailable in this demo'**
  String get codeDeliveryUnavailableDemo;

  /// No description provided for @accountVerificationNeedsService.
  ///
  /// In en, this message translates to:
  /// **' Account verification requires the account service.'**
  String get accountVerificationNeedsService;

  /// No description provided for @didNotGetCode.
  ///
  /// In en, this message translates to:
  /// **'Didn’t get the code?'**
  String get didNotGetCode;

  /// No description provided for @signInUnavailableInPreview.
  ///
  /// In en, this message translates to:
  /// **'Sign in unavailable in preview'**
  String get signInUnavailableInPreview;

  /// No description provided for @verificationUnavailableDemo.
  ///
  /// In en, this message translates to:
  /// **'Verification is unavailable in this demo.'**
  String get verificationUnavailableDemo;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @welcomeBackRiding.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Let’s get you riding'**
  String get welcomeBackRiding;

  /// No description provided for @continueWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get continueWithPhone;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signInWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Sign in with phone number'**
  String get signInWithPhone;

  /// No description provided for @phoneSignInUnavailableDemo.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in is unavailable in this demo. No verification code is sent.'**
  String get phoneSignInUnavailableDemo;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @phoneSignInNeedsService.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in requires the account service.'**
  String get phoneSignInNeedsService;

  /// No description provided for @socialSignInNeedsService.
  ///
  /// In en, this message translates to:
  /// **'Apple and Google sign-in require the account service.'**
  String get socialSignInNeedsService;

  /// No description provided for @idPhotoPreview.
  ///
  /// In en, this message translates to:
  /// **'ID photo preview'**
  String get idPhotoPreview;

  /// No description provided for @idPhotoSampleOnly.
  ///
  /// In en, this message translates to:
  /// **'Sample image only. Camera capture and verification are not connected. No ID is submitted.'**
  String get idPhotoSampleOnly;

  /// No description provided for @returnToHome.
  ///
  /// In en, this message translates to:
  /// **'Return to home'**
  String get returnToHome;

  /// No description provided for @retakeUnavailablePreview.
  ///
  /// In en, this message translates to:
  /// **'Retake unavailable in this preview'**
  String get retakeUnavailablePreview;

  /// No description provided for @enterValidPhoneWeWillSend.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number where we will send'**
  String get enterValidPhoneWeWillSend;

  /// No description provided for @verifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyAction;

  /// No description provided for @stepOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{step} of {total}'**
  String stepOfTotal(String step, String total);

  /// No description provided for @uploadId.
  ///
  /// In en, this message translates to:
  /// **'Upload ID'**
  String get uploadId;

  /// No description provided for @weNeedToVerifyYourId.
  ///
  /// In en, this message translates to:
  /// **'we need to verify your Id'**
  String get weNeedToVerifyYourId;

  /// No description provided for @approveAccountIdentityReason.
  ///
  /// In en, this message translates to:
  /// **'In order to approve your account, we need to be 100% sure that you are who you say you are, for security and transparency purposes.'**
  String get approveAccountIdentityReason;

  /// No description provided for @vehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Registration'**
  String get vehicleRegistration;

  /// No description provided for @uploadVehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Upload vehicle registration document'**
  String get uploadVehicleRegistration;

  /// No description provided for @insurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurance;

  /// No description provided for @uploadCarInsurance.
  ///
  /// In en, this message translates to:
  /// **'Upload car insurance for verification'**
  String get uploadCarInsurance;

  /// No description provided for @todayLower.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get todayLower;

  /// No description provided for @tomorrowLower.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get tomorrowLower;

  /// No description provided for @inDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String inDaysCount(int count);

  /// No description provided for @docInsuranceLetter.
  ///
  /// In en, this message translates to:
  /// **'Insurance letter'**
  String get docInsuranceLetter;

  /// No description provided for @docTaxiDriverLicense.
  ///
  /// In en, this message translates to:
  /// **'Taxi driver license'**
  String get docTaxiDriverLicense;

  /// No description provided for @docTaxiLicenseShort.
  ///
  /// In en, this message translates to:
  /// **'Taxi license'**
  String get docTaxiLicenseShort;

  /// No description provided for @docRegistrationCertificate.
  ///
  /// In en, this message translates to:
  /// **'Registration certificate'**
  String get docRegistrationCertificate;

  /// No description provided for @docRegistrationShort.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get docRegistrationShort;

  /// No description provided for @docDriversLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s License'**
  String get docDriversLicense;

  /// No description provided for @docVehicleVerification.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Verification'**
  String get docVehicleVerification;

  /// No description provided for @docDriversId.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s ID'**
  String get docDriversId;

  /// No description provided for @docExpiredCantGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Expired · You can’t go online'**
  String get docExpiredCantGoOnline;

  /// No description provided for @docExpiresWhenDate.
  ///
  /// In en, this message translates to:
  /// **'Expires {when} · {date}'**
  String docExpiresWhenDate(String when, String date);

  /// No description provided for @docNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New {title}'**
  String docNewTitle(String title);

  /// No description provided for @docTakeClearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of the whole document. Movera checks it before it counts.'**
  String get docTakeClearPhoto;

  /// No description provided for @docSendNew.
  ///
  /// In en, this message translates to:
  /// **'Send new document'**
  String get docSendNew;

  /// No description provided for @docDemoNoFileLeaves.
  ///
  /// In en, this message translates to:
  /// **'Demo: no file leaves the phone.'**
  String get docDemoNoFileLeaves;

  /// No description provided for @docSentForReview.
  ///
  /// In en, this message translates to:
  /// **'Sent for review'**
  String get docSentForReview;

  /// No description provided for @docTitleExpired.
  ///
  /// In en, this message translates to:
  /// **'{title} expired'**
  String docTitleExpired(String title);

  /// No description provided for @youCanGoOnlineNow.
  ///
  /// In en, this message translates to:
  /// **'You can go online now.'**
  String get youCanGoOnlineNow;

  /// No description provided for @docNewInReviewGoOnlineWhenApproved.
  ///
  /// In en, this message translates to:
  /// **'Your new document is in review. You can go online when Movera approves it.'**
  String get docNewInReviewGoOnlineWhenApproved;

  /// No description provided for @docUploadNewGoOnlineWhenApproved.
  ///
  /// In en, this message translates to:
  /// **'Upload a new one. You can go online when Movera approves it.'**
  String get docUploadNewGoOnlineWhenApproved;

  /// No description provided for @approveDemo.
  ///
  /// In en, this message translates to:
  /// **'Approve (demo)'**
  String get approveDemo;

  /// No description provided for @uploadNew.
  ///
  /// In en, this message translates to:
  /// **'Upload new'**
  String get uploadNew;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @docTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get docTermsAndConditions;

  /// No description provided for @docVirtualInfoSession.
  ///
  /// In en, this message translates to:
  /// **'Virtual information session'**
  String get docVirtualInfoSession;

  /// No description provided for @docDriversLicenseLower.
  ///
  /// In en, this message translates to:
  /// **'Driver’s license'**
  String get docDriversLicenseLower;

  /// No description provided for @docProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get docProfilePhoto;

  /// No description provided for @docCompanyRegistration.
  ///
  /// In en, this message translates to:
  /// **'Company registration'**
  String get docCompanyRegistration;

  /// No description provided for @docCompanyRegistrationNote.
  ///
  /// In en, this message translates to:
  /// **'Bolagsverket or Skatteverket extract. Not needed with a Fleet Partner.'**
  String get docCompanyRegistrationNote;

  /// No description provided for @docTaxiTrafficPermit.
  ///
  /// In en, this message translates to:
  /// **'Taxi traffic permit'**
  String get docTaxiTrafficPermit;

  /// No description provided for @docTaxSettings.
  ///
  /// In en, this message translates to:
  /// **'Tax settings'**
  String get docTaxSettings;

  /// No description provided for @docBankStatement.
  ///
  /// In en, this message translates to:
  /// **'Bank statement'**
  String get docBankStatement;

  /// No description provided for @docFrontPage.
  ///
  /// In en, this message translates to:
  /// **'Front page'**
  String get docFrontPage;

  /// No description provided for @docStockholmTrips.
  ///
  /// In en, this message translates to:
  /// **'Stockholm · Trips'**
  String get docStockholmTrips;

  /// No description provided for @docEarnAnywhereSweden.
  ///
  /// In en, this message translates to:
  /// **'Earn anywhere in Sweden'**
  String get docEarnAnywhereSweden;

  /// No description provided for @docSampleListNotice.
  ///
  /// In en, this message translates to:
  /// **'Sample list · Sending these documents is not available in the app yet. Nothing here was uploaded or reviewed.'**
  String get docSampleListNotice;

  /// No description provided for @docApprovedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{approved} of {total} approved'**
  String docApprovedOfTotal(int approved, int total);

  /// No description provided for @docLeftCount.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String docLeftCount(int count);

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @docStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get docStatusApproved;

  /// No description provided for @docStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get docStatusInReview;

  /// No description provided for @docStatusNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get docStatusNeeded;

  /// No description provided for @docPreviewNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet — sample page. Sending this document is not part of the app yet. No document was uploaded or reviewed.'**
  String get docPreviewNotAvailable;

  /// No description provided for @schedRidesHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ride hidden} other{{count} rides hidden}}'**
  String schedRidesHidden(int count);

  /// No description provided for @schedClashBody.
  ///
  /// In en, this message translates to:
  /// **'It clashes with your {time} pickup: not enough time to get there.'**
  String schedClashBody(String time);

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @schedAvailableToday.
  ///
  /// In en, this message translates to:
  /// **'Available today'**
  String get schedAvailableToday;

  /// No description provided for @schedUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get schedUpcoming;

  /// No description provided for @schedPreviewNotBinding.
  ///
  /// In en, this message translates to:
  /// **'Preview — not binding. Decisions last until the app restarts.'**
  String get schedPreviewNotBinding;

  /// No description provided for @schedNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No scheduled rides yet. Reservations from Movera will show up here.'**
  String get schedNoneYet;

  /// No description provided for @schedAcceptedPickupAt.
  ///
  /// In en, this message translates to:
  /// **'Accepted · pickup {time}'**
  String schedAcceptedPickupAt(String time);

  /// No description provided for @laterLower.
  ///
  /// In en, this message translates to:
  /// **'later'**
  String get laterLower;

  /// No description provided for @schedReservationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Reservation cancelled'**
  String get schedReservationCancelled;

  /// No description provided for @schedPlanAhead.
  ///
  /// In en, this message translates to:
  /// **'Plan ahead and choose your next trip'**
  String get schedPlanAhead;

  /// No description provided for @schedRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get schedRequestsTab;

  /// No description provided for @schedAcceptedTab.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get schedAcceptedTab;

  /// No description provided for @schedSeedTime.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String schedSeedTime(String day, String time);

  /// No description provided for @schedPickupTomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Pickup tomorrow at {time}'**
  String schedPickupTomorrowAt(String time);

  /// No description provided for @schedBackupNote.
  ///
  /// In en, this message translates to:
  /// **'Your {time} pickup was given to a backup driver.'**
  String schedBackupNote(String time);

  /// No description provided for @schedSampleReservation.
  ///
  /// In en, this message translates to:
  /// **'Sample reservation'**
  String get schedSampleReservation;

  /// No description provided for @schedReservationDetails.
  ///
  /// In en, this message translates to:
  /// **'Reservation details'**
  String get schedReservationDetails;

  /// No description provided for @schedIllustrativeRoute.
  ///
  /// In en, this message translates to:
  /// **'Illustrative route — sample data'**
  String get schedIllustrativeRoute;

  /// No description provided for @schedViewRoute.
  ///
  /// In en, this message translates to:
  /// **'View reservation route'**
  String get schedViewRoute;

  /// No description provided for @schedDemoAccepted.
  ///
  /// In en, this message translates to:
  /// **'Demo accepted'**
  String get schedDemoAccepted;

  /// No description provided for @schedAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get schedAvailable;

  /// No description provided for @rideTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride type'**
  String get rideTypeLabel;

  /// No description provided for @trip2.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get trip2;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @schedBeforeThisRide.
  ///
  /// In en, this message translates to:
  /// **'Before this ride'**
  String get schedBeforeThisRide;

  /// No description provided for @goodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get goodToKnow;

  /// No description provided for @schedBeReadyEarly.
  ///
  /// In en, this message translates to:
  /// **'Be ready early'**
  String get schedBeReadyEarly;

  /// No description provided for @schedGoOnlineMinBefore.
  ///
  /// In en, this message translates to:
  /// **'Go online {minutes} min before pickup so the app can guide you in time.'**
  String schedGoOnlineMinBefore(String minutes);

  /// No description provided for @schedTripsOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Trips on the way'**
  String get schedTripsOnTheWay;

  /// No description provided for @schedOnlyTripsToward.
  ///
  /// In en, this message translates to:
  /// **'Before pickup you only get trips that head toward it and leave time to get there.'**
  String get schedOnlyTripsToward;

  /// No description provided for @schedStillReceiveRides.
  ///
  /// In en, this message translates to:
  /// **'You can still receive suitable rides before the scheduled pickup.'**
  String get schedStillReceiveRides;

  /// No description provided for @schedPlansChanged.
  ///
  /// In en, this message translates to:
  /// **'Plans changed?'**
  String get schedPlansChanged;

  /// No description provided for @schedDriversNeverPay.
  ///
  /// In en, this message translates to:
  /// **'{line} Drivers never pay to cancel.'**
  String schedDriversNeverPay(String line);

  /// No description provided for @schedLocalPreviewCancel.
  ///
  /// In en, this message translates to:
  /// **'This is a local preview. Cancelling removes the sample reservation until the app restarts.'**
  String get schedLocalPreviewCancel;

  /// No description provided for @schedReservedForYou.
  ///
  /// In en, this message translates to:
  /// **'Reserved for you'**
  String get schedReservedForYou;

  /// No description provided for @schedKeepInAccepted.
  ///
  /// In en, this message translates to:
  /// **'We’ll keep this ride in your Accepted list. If you cancel, you’ll be asked for a reason before anything changes.'**
  String get schedKeepInAccepted;

  /// No description provided for @schedCancelReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel reservation'**
  String get schedCancelReservation;

  /// No description provided for @schedAcceptPrice.
  ///
  /// In en, this message translates to:
  /// **'Accept  •  {price}'**
  String schedAcceptPrice(String price);

  /// No description provided for @chooseBestReason.
  ///
  /// In en, this message translates to:
  /// **'Choose the reason that best matches.'**
  String get chooseBestReason;

  /// No description provided for @schedCancelThisReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel this reservation?'**
  String get schedCancelThisReservation;

  /// No description provided for @schedReasonDoesntCount.
  ///
  /// In en, this message translates to:
  /// **'This reason doesn’t count against you.'**
  String get schedReasonDoesntCount;

  /// No description provided for @schedRemovesSample.
  ///
  /// In en, this message translates to:
  /// **'This removes the sample reservation from this session. It does not cancel a real booking or change account access.'**
  String get schedRemovesSample;

  /// No description provided for @schedKeepReservation.
  ///
  /// In en, this message translates to:
  /// **'Keep reservation'**
  String get schedKeepReservation;

  /// No description provided for @tomorrowAtClock.
  ///
  /// In en, this message translates to:
  /// **'tomorrow {clock}'**
  String tomorrowAtClock(String clock);

  /// No description provided for @schedFreeCancelHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'Free cancel until {hours} h before pickup.'**
  String schedFreeCancelHoursBefore(String hours);

  /// No description provided for @schedLateCancelUnder.
  ///
  /// In en, this message translates to:
  /// **'Late cancel: under {hours} h to pickup.'**
  String schedLateCancelUnder(String hours);

  /// No description provided for @schedFreeCancelUntil.
  ///
  /// In en, this message translates to:
  /// **'Free cancel until {time}.'**
  String schedFreeCancelUntil(String time);

  /// No description provided for @schedRidesAreOff.
  ///
  /// In en, this message translates to:
  /// **'Scheduled rides are off'**
  String get schedRidesAreOff;

  /// No description provided for @schedRidesOffUntil.
  ///
  /// In en, this message translates to:
  /// **'Scheduled rides off until {date}'**
  String schedRidesOffUntil(String date);

  /// No description provided for @schedRidesPausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Scheduled rides paused until {date}'**
  String schedRidesPausedUntil(String date);

  /// No description provided for @schedOffInYourArea.
  ///
  /// In en, this message translates to:
  /// **'Movera paused new scheduled rides in your area. Rides you already accepted still go ahead.'**
  String get schedOffInYourArea;

  /// No description provided for @schedTurnedOffByMovera.
  ///
  /// In en, this message translates to:
  /// **'Movera turned off Scheduled rides for your account. Contact support if you have questions.'**
  String get schedTurnedOffByMovera;

  /// No description provided for @schedLateCancelsInDays.
  ///
  /// In en, this message translates to:
  /// **'You had {count} late cancels in {days} days. Your accepted rides stay.'**
  String schedLateCancelsInDays(String count, String days);

  /// No description provided for @schedNeverPayLateCounts.
  ///
  /// In en, this message translates to:
  /// **'You never pay to cancel, but this late cancel counts.'**
  String get schedNeverPayLateCounts;

  /// No description provided for @schedNeverPayUnderHours.
  ///
  /// In en, this message translates to:
  /// **'You never pay to cancel. Under {hours} h to pickup a cancel is late and counts toward a pause.'**
  String schedNeverPayUnderHours(String hours);

  /// No description provided for @schedLateCancelPauses.
  ///
  /// In en, this message translates to:
  /// **'This is a late cancel ({count} in {days} days). Scheduled rides pause until {date}.'**
  String schedLateCancelPauses(String count, String days, String date);

  /// No description provided for @schedLateCancelCounts.
  ///
  /// In en, this message translates to:
  /// **'This is a late cancel and it counts. You never pay.'**
  String get schedLateCancelCounts;

  /// No description provided for @schedAcceptedBadge.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get schedAcceptedBadge;

  /// No description provided for @supportCatTripRider.
  ///
  /// In en, this message translates to:
  /// **'Trip & rider'**
  String get supportCatTripRider;

  /// No description provided for @supportCatWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet & payments'**
  String get supportCatWallet;

  /// No description provided for @supportCatAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & documents'**
  String get supportCatAccount;

  /// No description provided for @supportCatTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical issue'**
  String get supportCatTechnical;

  /// No description provided for @supportLocalDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'LOCAL DRAFT'**
  String get supportLocalDraftBadge;

  /// No description provided for @supportCouldNotRecover.
  ///
  /// In en, this message translates to:
  /// **'Could not recover local support. Retry.'**
  String get supportCouldNotRecover;

  /// No description provided for @supportCouldNotSaveConversation.
  ///
  /// In en, this message translates to:
  /// **'Could not save local conversation. Retry.'**
  String get supportCouldNotSaveConversation;

  /// No description provided for @supportCouldNotLoadDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not load the local draft.'**
  String get supportCouldNotLoadDraft;

  /// No description provided for @supportCouldNotSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not save local draft.'**
  String get supportCouldNotSaveDraft;

  /// No description provided for @supportLocalTicketDraft.
  ///
  /// In en, this message translates to:
  /// **'Local ticket draft'**
  String get supportLocalTicketDraft;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @enterSubject.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject'**
  String get enterSubject;

  /// No description provided for @tellUsWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get tellUsWhatHappened;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a message'**
  String get enterMessage;

  /// No description provided for @supportCouldNotSaveTicket.
  ///
  /// In en, this message translates to:
  /// **'Could not save local ticket. Retry.'**
  String get supportCouldNotSaveTicket;

  /// No description provided for @supportSavingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving local draft…'**
  String get supportSavingDraft;

  /// No description provided for @supportSaveDraftDemo.
  ///
  /// In en, this message translates to:
  /// **'Save draft in demo'**
  String get supportSaveDraftDemo;

  /// No description provided for @supportTicketSavedDraftNotCleared.
  ///
  /// In en, this message translates to:
  /// **'Ticket saved locally, but the composer draft could not be cleared.'**
  String get supportTicketSavedDraftNotCleared;

  /// No description provided for @supportDemo.
  ///
  /// In en, this message translates to:
  /// **'Support demo'**
  String get supportDemo;

  /// No description provided for @supportDraftLocalTicket.
  ///
  /// In en, this message translates to:
  /// **'Draft local ticket'**
  String get supportDraftLocalTicket;

  /// No description provided for @supportLocalPreview.
  ///
  /// In en, this message translates to:
  /// **'Local support preview'**
  String get supportLocalPreview;

  /// No description provided for @supportLocalDraftsNoService.
  ///
  /// In en, this message translates to:
  /// **'Local drafts on this device — no support service.'**
  String get supportLocalDraftsNoService;

  /// No description provided for @supportCouldNotLoadRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load local support — Retry'**
  String get supportCouldNotLoadRetry;

  /// No description provided for @supportRecoverPreserve.
  ///
  /// In en, this message translates to:
  /// **'Recover local support (preserve unreadable data)'**
  String get supportRecoverPreserve;

  /// No description provided for @supportYourConversations.
  ///
  /// In en, this message translates to:
  /// **'Your conversations'**
  String get supportYourConversations;

  /// No description provided for @supportLocalDraftSubject.
  ///
  /// In en, this message translates to:
  /// **'Local draft: {subject}'**
  String supportLocalDraftSubject(String subject);

  /// No description provided for @supportWriteLocalDraft.
  ///
  /// In en, this message translates to:
  /// **'Write a local draft'**
  String get supportWriteLocalDraft;

  /// No description provided for @supportSaveLocalReply.
  ///
  /// In en, this message translates to:
  /// **'Save local reply'**
  String get supportSaveLocalReply;

  /// No description provided for @promoWeekdayPeak.
  ///
  /// In en, this message translates to:
  /// **'Weekday peak'**
  String get promoWeekdayPeak;

  /// No description provided for @promoWeekdayPeakDetail.
  ///
  /// In en, this message translates to:
  /// **'Complete 8 trips between 07:00 and 09:00.'**
  String get promoWeekdayPeakDetail;

  /// No description provided for @promoWeekdayPeakWindow.
  ///
  /// In en, this message translates to:
  /// **'Mon–Fri · this week'**
  String get promoWeekdayPeakWindow;

  /// No description provided for @promoAirportRuns.
  ///
  /// In en, this message translates to:
  /// **'Airport runs'**
  String get promoAirportRuns;

  /// No description provided for @promoAirportRunsDetail.
  ///
  /// In en, this message translates to:
  /// **'Two airport trips in the same day.'**
  String get promoAirportRunsDetail;

  /// No description provided for @promoUntilSunday.
  ///
  /// In en, this message translates to:
  /// **'Until Sunday'**
  String get promoUntilSunday;

  /// No description provided for @promoEveningHours.
  ///
  /// In en, this message translates to:
  /// **'Evening hours'**
  String get promoEveningHours;

  /// No description provided for @promoEveningHoursDetail.
  ///
  /// In en, this message translates to:
  /// **'Stay online for 3 hours after 18:00.'**
  String get promoEveningHoursDetail;

  /// No description provided for @promoTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get promoTonight;

  /// No description provided for @promoDemoCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Demo code {code} copied'**
  String promoDemoCodeCopied(String code);

  /// No description provided for @promoCouldNotCopy.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the code. Please try again.'**
  String get promoCouldNotCopy;

  /// No description provided for @promoPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Promotions preview'**
  String get promoPreviewTitle;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @promoSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get promoSavedTab;

  /// No description provided for @promoNothingSaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get promoNothingSaved;

  /// No description provided for @promoSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get promoSave;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get addVehicle;

  /// No description provided for @vehCouldNotLoadDrafts.
  ///
  /// In en, this message translates to:
  /// **'Could not load local vehicle drafts — Retry'**
  String get vehCouldNotLoadDrafts;

  /// No description provided for @vehLocalDraftsNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Local vehicle drafts — not activated or verified'**
  String get vehLocalDraftsNotVerified;

  /// No description provided for @vehTripsOnly.
  ///
  /// In en, this message translates to:
  /// **'Trips only'**
  String get vehTripsOnly;

  /// No description provided for @vehManageVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage vehicles'**
  String get vehManageVehicles;

  /// No description provided for @vehExploreOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Explore vehicle opportunities'**
  String get vehExploreOpportunities;

  /// No description provided for @vehConnectFleetPartner.
  ///
  /// In en, this message translates to:
  /// **'Connect with a fleet partner or browse rental or purchase offers if you need another vehicle.'**
  String get vehConnectFleetPartner;

  /// No description provided for @vehCouldNotSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not save local vehicle draft. Retry.'**
  String get vehCouldNotSaveDraft;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @vehRequirements.
  ///
  /// In en, this message translates to:
  /// **'Vehicle requirements'**
  String get vehRequirements;

  /// No description provided for @vehRequirementsBody.
  ///
  /// In en, this message translates to:
  /// **'To drive with Movera, you need a vehicle that is 1990 or newer, and not salvaged.'**
  String get vehRequirementsBody;

  /// No description provided for @vehEnterInformation.
  ///
  /// In en, this message translates to:
  /// **'Enter your vehicle information'**
  String get vehEnterInformation;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @searchByMake.
  ///
  /// In en, this message translates to:
  /// **'Search by make'**
  String get searchByMake;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @searchByModel.
  ///
  /// In en, this message translates to:
  /// **'Search by model'**
  String get searchByModel;

  /// No description provided for @selectEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Select...'**
  String get selectEllipsis;

  /// No description provided for @requiredMark.
  ///
  /// In en, this message translates to:
  /// **'* Required'**
  String get requiredMark;

  /// No description provided for @vehPhotoCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Photo could not be saved locally. Retry.'**
  String get vehPhotoCouldNotSave;

  /// No description provided for @vehRemoveDraftQ.
  ///
  /// In en, this message translates to:
  /// **'Remove local vehicle draft?'**
  String get vehRemoveDraftQ;

  /// No description provided for @vehRemovesNameAndPhotos.
  ///
  /// In en, this message translates to:
  /// **'This removes {name} and its saved document photos from this device.'**
  String vehRemovesNameAndPhotos(String name);

  /// No description provided for @vehKeepVehicle.
  ///
  /// In en, this message translates to:
  /// **'Keep vehicle'**
  String get vehKeepVehicle;

  /// No description provided for @vehRemoveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Remove vehicle'**
  String get vehRemoveVehicle;

  /// No description provided for @vehCouldNotRemoveDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not remove local draft. Retry.'**
  String get vehCouldNotRemoveDraft;

  /// No description provided for @vehPhotosStayOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Document photos stay on this device. No upload or verification service is connected.'**
  String get vehPhotosStayOnDevice;

  /// No description provided for @vehCouldNotLoadDocuments.
  ///
  /// In en, this message translates to:
  /// **'Could not load local vehicle documents.'**
  String get vehCouldNotLoadDocuments;

  /// No description provided for @vehDraftNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This local vehicle draft is no longer available.'**
  String get vehDraftNoLongerAvailable;

  /// No description provided for @vehRegistrationCertFront.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Registration Certificate (Front Page)'**
  String get vehRegistrationCertFront;

  /// No description provided for @vehSavedLocallyNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Saved locally — not verified'**
  String get vehSavedLocallyNotVerified;

  /// No description provided for @vehRecommendedNextStep.
  ///
  /// In en, this message translates to:
  /// **'Recommended next step'**
  String get vehRecommendedNextStep;

  /// No description provided for @vehTakePhotoRegistration.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your Vehicle Registration Certificate (Front Page)'**
  String get vehTakePhotoRegistration;

  /// No description provided for @vehDocBlueBlackWhite.
  ///
  /// In en, this message translates to:
  /// **'The document should be blue, black and white.'**
  String get vehDocBlueBlackWhite;

  /// No description provided for @vehAllFourCorners.
  ///
  /// In en, this message translates to:
  /// **'All four corners are visible.'**
  String get vehAllFourCorners;

  /// No description provided for @vehInsuranceLetter.
  ///
  /// In en, this message translates to:
  /// **'Insurance Letter'**
  String get vehInsuranceLetter;

  /// No description provided for @vehTakePhotoInsurance.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your Insurance Letter'**
  String get vehTakePhotoInsurance;

  /// No description provided for @vehInsuranceShowsTaxi.
  ///
  /// In en, this message translates to:
  /// **'The document shows the car’s registration number and that it is registered as a taxi.'**
  String get vehInsuranceShowsTaxi;

  /// No description provided for @vehInsuranceDatesVisible.
  ///
  /// In en, this message translates to:
  /// **'The start and end dates of the insurance are visible.'**
  String get vehInsuranceDatesVisible;

  /// No description provided for @vehSavedPhotoCannotDisplay.
  ///
  /// In en, this message translates to:
  /// **'Saved photo cannot be displayed. Retake this document photo.'**
  String get vehSavedPhotoCannotDisplay;

  /// No description provided for @vehPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Photo is too large to keep on this device. Retake it closer and with less detail.'**
  String get vehPhotoTooLarge;

  /// No description provided for @vehCameraNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available in this preview.'**
  String get vehCameraNotAvailable;

  /// No description provided for @vehBeforeSavingCheck.
  ///
  /// In en, this message translates to:
  /// **'Before saving the local photo, check the following:'**
  String get vehBeforeSavingCheck;

  /// No description provided for @takingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Taking photo…'**
  String get takingPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @promoSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get promoSaved;

  /// No description provided for @prefStandardEveryday.
  ///
  /// In en, this message translates to:
  /// **'Standard • Everyday ride'**
  String get prefStandardEveryday;

  /// No description provided for @prefExtraComfort.
  ///
  /// In en, this message translates to:
  /// **'Extra comfort • Plush'**
  String get prefExtraComfort;

  /// No description provided for @prefLuxuryPremium.
  ///
  /// In en, this message translates to:
  /// **'Luxury • Premium service'**
  String get prefLuxuryPremium;

  /// No description provided for @prefFasterPickup.
  ///
  /// In en, this message translates to:
  /// **'Faster pickup • Priority'**
  String get prefFasterPickup;

  /// No description provided for @prefSixSeat.
  ///
  /// In en, this message translates to:
  /// **'6 seat • Spacious'**
  String get prefSixSeat;

  /// No description provided for @prefLowEmissions.
  ///
  /// In en, this message translates to:
  /// **'Low emissions • Eco'**
  String get prefLowEmissions;

  /// No description provided for @prefPetFriendly.
  ///
  /// In en, this message translates to:
  /// **'Pet friendly • Carrier OK'**
  String get prefPetFriendly;

  /// No description provided for @prefChildSeat.
  ///
  /// In en, this message translates to:
  /// **'Child seat • Kids safe'**
  String get prefChildSeat;

  /// No description provided for @prefCategoriesSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ride category saved} other{{count} ride categories saved}}'**
  String prefCategoriesSaved(int count);

  /// No description provided for @prefActiveOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{active} of {total} active'**
  String prefActiveOfTotal(int active, int total);

  /// No description provided for @prefChooseRideOptions.
  ///
  /// In en, this message translates to:
  /// **'Choose your ride options'**
  String get prefChooseRideOptions;

  /// No description provided for @prefSelectRideTypes.
  ///
  /// In en, this message translates to:
  /// **'Select the ride types you\'d like available for your trips'**
  String get prefSelectRideTypes;

  /// No description provided for @prefMoveraSetsFromCar.
  ///
  /// In en, this message translates to:
  /// **'Movera sets these from your car. Switch off any you don’t want.'**
  String get prefMoveraSetsFromCar;

  /// No description provided for @prefSave.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get prefSave;

  /// No description provided for @safetyContactEmergencyQ.
  ///
  /// In en, this message translates to:
  /// **'Contact emergency services?'**
  String get safetyContactEmergencyQ;

  /// No description provided for @safetyUse112Only.
  ///
  /// In en, this message translates to:
  /// **'Use 112 only when you or someone else needs immediate help.'**
  String get safetyUse112Only;

  /// No description provided for @safetyDialerOpened.
  ///
  /// In en, this message translates to:
  /// **'Emergency dialer opened — confirm the call on your device.'**
  String get safetyDialerOpened;

  /// No description provided for @safetyDialerAskedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Your browser was asked to call 112. If no call starts, dial 112 on your phone.'**
  String get safetyDialerAskedBrowser;

  /// No description provided for @safetyAudioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio recording is unavailable in this demo.'**
  String get safetyAudioUnavailable;

  /// No description provided for @safetyTripSharingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Trip sharing is unavailable in this demo.'**
  String get safetyTripSharingUnavailable;

  /// No description provided for @safetyPreferences.
  ///
  /// In en, this message translates to:
  /// **'Safety preferences'**
  String get safetyPreferences;

  /// No description provided for @safetyRideCheckOnOthersPreview.
  ///
  /// In en, this message translates to:
  /// **'Ride check is on. The others are preview only.'**
  String get safetyRideCheckOnOthersPreview;

  /// No description provided for @safetyUnavailableWithoutVerification.
  ///
  /// In en, this message translates to:
  /// **'Unavailable without account verification'**
  String get safetyUnavailableWithoutVerification;

  /// No description provided for @safetyAutoTripSharing.
  ///
  /// In en, this message translates to:
  /// **'Automatic trip sharing'**
  String get safetyAutoTripSharing;

  /// No description provided for @safetyUnavailableWithoutSharing.
  ///
  /// In en, this message translates to:
  /// **'Unavailable without a sharing service'**
  String get safetyUnavailableWithoutSharing;

  /// No description provided for @safetyOnSetByMovera.
  ///
  /// In en, this message translates to:
  /// **'On · set by Movera for every trip'**
  String get safetyOnSetByMovera;

  /// No description provided for @safetyOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get safetyOn;

  /// No description provided for @safetyRideCheckExplained.
  ///
  /// In en, this message translates to:
  /// **'On for every trip. Asks \"Is everything OK?\" after a long stop, a drop-off far from the destination, a big detour or a very hard stop.'**
  String get safetyRideCheckExplained;

  /// No description provided for @safetyTools.
  ///
  /// In en, this message translates to:
  /// **'Safety tools'**
  String get safetyTools;

  /// No description provided for @safetyQuickTools.
  ///
  /// In en, this message translates to:
  /// **'Quick tools designed to protect you during every ride.'**
  String get safetyQuickTools;

  /// No description provided for @safetyContact112.
  ///
  /// In en, this message translates to:
  /// **'Contact 112'**
  String get safetyContact112;

  /// No description provided for @safetyShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get safetyShareTrip;

  /// No description provided for @safetyRideCheckOnPreviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Ride check on · the others are preview only'**
  String get safetyRideCheckOnPreviewOnly;

  /// No description provided for @destChooseOneAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose one address'**
  String get destChooseOneAddress;

  /// No description provided for @destTripsInYourDirection.
  ///
  /// In en, this message translates to:
  /// **'Trips in your direction'**
  String get destTripsInYourDirection;

  /// No description provided for @destMoveraPrioritizes.
  ///
  /// In en, this message translates to:
  /// **'Movera will prioritize requests that keep you moving toward this address.'**
  String get destMoveraPrioritizes;

  /// No description provided for @destAddAddress.
  ///
  /// In en, this message translates to:
  /// **'Add destination address'**
  String get destAddAddress;

  /// No description provided for @destSuggestedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Suggested addresses'**
  String get destSuggestedAddresses;

  /// No description provided for @destResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get destResults;

  /// No description provided for @destNoAddressFound.
  ///
  /// In en, this message translates to:
  /// **'No address found'**
  String get destNoAddressFound;

  /// No description provided for @destTryAnother.
  ///
  /// In en, this message translates to:
  /// **'Try another street, place, or area.'**
  String get destTryAnother;

  /// No description provided for @destFastestRoute.
  ///
  /// In en, this message translates to:
  /// **'Fastest route to your destination'**
  String get destFastestRoute;

  /// No description provided for @destOnlyTripsYourWay.
  ///
  /// In en, this message translates to:
  /// **'You\'ll only get trips heading your way, so every ride takes you closer to {place}.'**
  String destOnlyTripsYourWay(String place);

  /// No description provided for @destArriveBy.
  ///
  /// In en, this message translates to:
  /// **'Arrive by {time}'**
  String destArriveBy(String time);

  /// No description provided for @destConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm destination'**
  String get destConfirm;

  /// No description provided for @waybillLocalDemo.
  ///
  /// In en, this message translates to:
  /// **'Local demo'**
  String get waybillLocalDemo;

  /// No description provided for @waybillDemoRadar.
  ///
  /// In en, this message translates to:
  /// **'Demo Radar'**
  String get waybillDemoRadar;

  /// No description provided for @demoDriverIdentityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Demo driver — identity unavailable'**
  String get demoDriverIdentityUnavailable;

  /// No description provided for @vehicleDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Vehicle data unavailable'**
  String get vehicleDataUnavailable;

  /// No description provided for @plateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plate unavailable'**
  String get plateUnavailable;

  /// No description provided for @positionOfCount.
  ///
  /// In en, this message translates to:
  /// **'{position} of {count}'**
  String positionOfCount(int position, int count);

  /// No description provided for @rrMatchingTrip.
  ///
  /// In en, this message translates to:
  /// **'Matching trip'**
  String get rrMatchingTrip;

  /// No description provided for @rrConfirmingRealTime.
  ///
  /// In en, this message translates to:
  /// **'Confirming this request in real time…'**
  String get rrConfirmingRealTime;

  /// No description provided for @rrCouldNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Could not match trip. Try again.'**
  String get rrCouldNotMatch;

  /// No description provided for @rrConnectionInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted. You can retry this request.'**
  String get rrConnectionInterrupted;

  /// No description provided for @rrAssignedOpening.
  ///
  /// In en, this message translates to:
  /// **'You’re assigned to this request. Opening trip…'**
  String get rrAssignedOpening;

  /// No description provided for @rrAnotherMatchedFirst.
  ///
  /// In en, this message translates to:
  /// **'Another driver matched this trip first.'**
  String get rrAnotherMatchedFirst;

  /// No description provided for @rrNoLongerOnRadar.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer on Radar.'**
  String get rrNoLongerOnRadar;

  /// No description provided for @rrTripsTowardPickup.
  ///
  /// In en, this message translates to:
  /// **'Trips toward your {time} pickup'**
  String rrTripsTowardPickup(String time);

  /// No description provided for @rrLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get rrLive;

  /// No description provided for @rrFreshNew.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String rrFreshNew(int count);

  /// No description provided for @rrNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get rrNew;

  /// No description provided for @rrDestinationRoute.
  ///
  /// In en, this message translates to:
  /// **'Destination route'**
  String get rrDestinationRoute;

  /// No description provided for @rrTripsToward.
  ///
  /// In en, this message translates to:
  /// **'Trips toward {place}'**
  String rrTripsToward(String place);

  /// No description provided for @rrScanningNearby.
  ///
  /// In en, this message translates to:
  /// **'Scanning nearby'**
  String get rrScanningNearby;

  /// No description provided for @rrNewTripsAppear.
  ///
  /// In en, this message translates to:
  /// **'New trips will appear here when the radar finds requests around you.'**
  String get rrNewTripsAppear;

  /// No description provided for @moveraDriver.
  ///
  /// In en, this message translates to:
  /// **'Movera Driver'**
  String get moveraDriver;

  /// No description provided for @legalPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Movera Driver uses location, trip and vehicle data to assign rides, show routes and keep a waybill on this device.\n\nDemo builds keep this information in memory on the phone. Nothing is sold to advertisers. You can log out at any time from Profile.\n\nWhen a live backend is connected, the same screens will keep using this policy text until a signed version is published.'**
  String get legalPrivacyBody;

  /// No description provided for @legalTermsBody.
  ///
  /// In en, this message translates to:
  /// **'You agree to drive only with a valid licence, insurance and a vehicle that matches the documents in this app.\n\nRadar offers are first-come. Matching another order while on a trip is optional. Completing a trip creates a waybill you can reopen from Home.\n\nMovera may suspend a demo account that misuses Safety tools or emergency calling.'**
  String get legalTermsBody;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @profSampleDriver.
  ///
  /// In en, this message translates to:
  /// **'Sample driver profile'**
  String get profSampleDriver;

  /// No description provided for @profDemoNoVerified.
  ///
  /// In en, this message translates to:
  /// **'Demo — no verified account'**
  String get profDemoNoVerified;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @myBank.
  ///
  /// In en, this message translates to:
  /// **'My bank'**
  String get myBank;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get helpCenter;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutQ.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQ;

  /// No description provided for @profLogOutClears.
  ///
  /// In en, this message translates to:
  /// **'Local preview data on this device will be cleared, including trip history, contacts, and drafts. You will return to the sign-in screen offline.'**
  String get profLogOutClears;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @profCouldNotClear.
  ///
  /// In en, this message translates to:
  /// **'Could not clear local data. You are still signed in. Please retry.'**
  String get profCouldNotClear;

  /// No description provided for @anaPreview.
  ///
  /// In en, this message translates to:
  /// **'Analytics preview'**
  String get anaPreview;

  /// No description provided for @anaSample3Rides.
  ///
  /// In en, this message translates to:
  /// **'Sample: 3 rides completed'**
  String get anaSample3Rides;

  /// No description provided for @anaSampleLastTrip.
  ///
  /// In en, this message translates to:
  /// **'Sample last trip'**
  String get anaSampleLastTrip;

  /// No description provided for @anaSamplePerformance.
  ///
  /// In en, this message translates to:
  /// **'Sample performance'**
  String get anaSamplePerformance;

  /// No description provided for @anaCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get anaCancel;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @anaSamePeriodHome.
  ///
  /// In en, this message translates to:
  /// **'Same period as the home sheet'**
  String get anaSamePeriodHome;

  /// No description provided for @acceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'Acceptance rate'**
  String get acceptanceRate;

  /// No description provided for @anaSampleAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Sample · {rate} of offers accepted'**
  String anaSampleAcceptance(String rate);

  /// No description provided for @cancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation rate'**
  String get cancellationRate;

  /// No description provided for @anaSampleCancellation.
  ///
  /// In en, this message translates to:
  /// **'Sample · {rate} of accepted trips'**
  String anaSampleCancellation(String rate);

  /// No description provided for @anaSampleStrongestArea.
  ///
  /// In en, this message translates to:
  /// **'Sample strongest area'**
  String get anaSampleStrongestArea;

  /// No description provided for @bankAddHolderName.
  ///
  /// In en, this message translates to:
  /// **'Add the account holder’s name.'**
  String get bankAddHolderName;

  /// No description provided for @bankCheckIban.
  ///
  /// In en, this message translates to:
  /// **'Check the IBAN format and check digits against your bank statement.'**
  String get bankCheckIban;

  /// No description provided for @bankBicFormat.
  ///
  /// In en, this message translates to:
  /// **'BIC / SWIFT has 8 or 11 letters and digits.'**
  String get bankBicFormat;

  /// No description provided for @bankCheckClearing.
  ///
  /// In en, this message translates to:
  /// **'Check the clearing number: 4 digits, or 5 starting with 8 for Swedbank.'**
  String get bankCheckClearing;

  /// No description provided for @bankAccountDigits.
  ///
  /// In en, this message translates to:
  /// **'The account number has 6 to 10 digits.'**
  String get bankAccountDigits;

  /// No description provided for @bankPreviewNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Preview only — account not saved.'**
  String get bankPreviewNotSaved;

  /// No description provided for @countrySweden.
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get countrySweden;

  /// No description provided for @international.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get international;

  /// No description provided for @bankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get bankAccount;

  /// No description provided for @bankHolder.
  ///
  /// In en, this message translates to:
  /// **'Holder'**
  String get bankHolder;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @bank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// No description provided for @clearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing'**
  String get clearing;

  /// No description provided for @bankUseIban.
  ///
  /// In en, this message translates to:
  /// **'Use the IBAN on your bank statement. Foreign IBANs show a country code; no bank connection is verified.'**
  String get bankUseIban;

  /// No description provided for @bankFoundFromClearing.
  ///
  /// In en, this message translates to:
  /// **'The bank is found from the clearing number.'**
  String get bankFoundFromClearing;

  /// No description provided for @checkDetails.
  ///
  /// In en, this message translates to:
  /// **'Check details'**
  String get checkDetails;

  /// No description provided for @bankDemoNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Demo: account not saved or sent to a bank'**
  String get bankDemoNotSaved;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String hoursAgo(int hours);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDemand.
  ///
  /// In en, this message translates to:
  /// **'Demand'**
  String get filterDemand;

  /// No description provided for @logsPreview.
  ///
  /// In en, this message translates to:
  /// **'Driving log preview'**
  String get logsPreview;

  /// No description provided for @logsSampleNotLive.
  ///
  /// In en, this message translates to:
  /// **'Sample driving-time data · not live'**
  String get logsSampleNotLive;

  /// No description provided for @logsSampleWeek.
  ///
  /// In en, this message translates to:
  /// **'Sample week'**
  String get logsSampleWeek;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @logsOnlineFromTo.
  ///
  /// In en, this message translates to:
  /// **'Online {from} – {to}'**
  String logsOnlineFromTo(String from, String to);

  /// No description provided for @logsSampleOnlineState.
  ///
  /// In en, this message translates to:
  /// **'Sample online state'**
  String get logsSampleOnlineState;

  /// No description provided for @logsDemoCompliance.
  ///
  /// In en, this message translates to:
  /// **'Demo compliance copy only. Driving and break limits are not connected to live account or regulatory data.'**
  String get logsDemoCompliance;

  /// No description provided for @pinVerifyAll.
  ///
  /// In en, this message translates to:
  /// **'Verify all trips'**
  String get pinVerifyAll;

  /// No description provided for @pinAskEveryPickup.
  ///
  /// In en, this message translates to:
  /// **'Ask for the rider PIN on every pickup.'**
  String get pinAskEveryPickup;

  /// No description provided for @pinVerifySession.
  ///
  /// In en, this message translates to:
  /// **'Verify this session'**
  String get pinVerifySession;

  /// No description provided for @pinAskUntilOffline.
  ///
  /// In en, this message translates to:
  /// **'Ask until you go offline.'**
  String get pinAskUntilOffline;

  /// No description provided for @pinDontVerify.
  ///
  /// In en, this message translates to:
  /// **'Don’t verify'**
  String get pinDontVerify;

  /// No description provided for @pinSkipOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Skip the PIN on this device.'**
  String get pinSkipOnDevice;

  /// No description provided for @pinPreviewNotSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN verification preview - this preference is not saved or enforced in the demo.'**
  String get pinPreviewNotSaved;

  /// No description provided for @pinNotConnected.
  ///
  /// In en, this message translates to:
  /// **'PIN verification is not connected in this demo.'**
  String get pinNotConnected;

  /// No description provided for @bankPreviewAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Preview account details'**
  String get bankPreviewAccountDetails;

  /// No description provided for @bankLocalPreviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Local preview only. No bank is connected, nothing is verified, and no payout is scheduled.'**
  String get bankLocalPreviewOnly;

  /// No description provided for @bankCheckInPreview.
  ///
  /// In en, this message translates to:
  /// **'You can check account details in the preview form. Details are discarded when you leave the form; no payout account is connected.'**
  String get bankCheckInPreview;

  /// No description provided for @emEmergencyServices112.
  ///
  /// In en, this message translates to:
  /// **'Emergency services — 112'**
  String get emEmergencyServices112;

  /// No description provided for @emEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emEmergency;

  /// No description provided for @emAlreadyInContacts.
  ///
  /// In en, this message translates to:
  /// **'This number is already in your contacts.'**
  String get emAlreadyInContacts;

  /// No description provided for @emFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get emFamily;

  /// No description provided for @chatLocalDemo.
  ///
  /// In en, this message translates to:
  /// **'Local demo chat · messages are not sent to the rider.'**
  String get chatLocalDemo;

  /// No description provided for @chatSendMessageHint.
  ///
  /// In en, this message translates to:
  /// **'send message...'**
  String get chatSendMessageHint;

  /// No description provided for @chatSaveLocally.
  ///
  /// In en, this message translates to:
  /// **'Save message locally'**
  String get chatSaveLocally;

  /// No description provided for @chatLocalNotSent.
  ///
  /// In en, this message translates to:
  /// **'Local preview · not sent'**
  String get chatLocalNotSent;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSend;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// No description provided for @chatNotSentTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Not sent · Tap to retry'**
  String get chatNotSentTapToRetry;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Movera could not send your message. Try again.'**
  String get chatSendFailed;

  /// No description provided for @chatHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Earlier messages could not be loaded.'**
  String get chatHistoryFailed;

  /// No description provided for @chatNewMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message from the rider} other{{count} new messages from the rider}}'**
  String chatNewMessages(int count);

  /// No description provided for @queueAirportPreview.
  ///
  /// In en, this message translates to:
  /// **'Airport queue preview'**
  String get queueAirportPreview;

  /// No description provided for @queueSample10Ahead.
  ///
  /// In en, this message translates to:
  /// **'Sample: 10 drivers ahead'**
  String get queueSample10Ahead;

  /// No description provided for @queueViewSampleDetails.
  ///
  /// In en, this message translates to:
  /// **'view sample details'**
  String get queueViewSampleDetails;

  /// No description provided for @queueClose.
  ///
  /// In en, this message translates to:
  /// **'Close queue position'**
  String get queueClose;

  /// No description provided for @queueMyPosition.
  ///
  /// In en, this message translates to:
  /// **'My Queue position'**
  String get queueMyPosition;

  /// No description provided for @queueMediumWait.
  ///
  /// In en, this message translates to:
  /// **'Medium Wait'**
  String get queueMediumWait;

  /// No description provided for @queueSampleRank.
  ///
  /// In en, this message translates to:
  /// **'Sample Rank'**
  String get queueSampleRank;

  /// No description provided for @queueUnavailablePreview.
  ///
  /// In en, this message translates to:
  /// **'Queue unavailable — preview'**
  String get queueUnavailablePreview;

  /// No description provided for @queueRanks.
  ///
  /// In en, this message translates to:
  /// **'Ranks'**
  String get queueRanks;

  /// No description provided for @earnTypeTab.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get earnTypeTab;

  /// No description provided for @earnMoveraDemo.
  ///
  /// In en, this message translates to:
  /// **'Movera demo'**
  String get earnMoveraDemo;

  /// No description provided for @cancelRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelation Rate'**
  String get cancelRateTitle;

  /// No description provided for @notYourRealRateYet.
  ///
  /// In en, this message translates to:
  /// **'not your real rate yet'**
  String get notYourRealRateYet;

  /// No description provided for @tripsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Trips confirmed'**
  String get tripsConfirmed;

  /// No description provided for @completedTripsLower.
  ///
  /// In en, this message translates to:
  /// **'completed trips'**
  String get completedTripsLower;

  /// No description provided for @canceledTrips.
  ///
  /// In en, this message translates to:
  /// **'Canceled trips'**
  String get canceledTrips;

  /// No description provided for @sampleNumbersNotReal.
  ///
  /// In en, this message translates to:
  /// **'Sample numbers for this preview, not your real rate.'**
  String get sampleNumbersNotReal;

  /// No description provided for @cancelRateKeepLow.
  ///
  /// In en, this message translates to:
  /// **'Keep your cancel rate low to keep full access to trips'**
  String get cancelRateKeepLow;

  /// No description provided for @cancelRateEveryCancelCounts.
  ///
  /// In en, this message translates to:
  /// **'Every cancel counts, except reasons marked “Doesn’t count”, such as a rider no-show or a safety issue.'**
  String get cancelRateEveryCancelCounts;

  /// No description provided for @moreInformation.
  ///
  /// In en, this message translates to:
  /// **'More Information'**
  String get moreInformation;

  /// No description provided for @cancelRateHowCalculated.
  ///
  /// In en, this message translates to:
  /// **'How your cancelation is calculated'**
  String get cancelRateHowCalculated;

  /// No description provided for @cancelRateHowBody.
  ///
  /// In en, this message translates to:
  /// **'Your cancellation rate is calculated based on the number of trips you cancel compared to the total trips you confirm. We use your last 100 confirmed trip requests to determine this percentage.'**
  String get cancelRateHowBody;

  /// No description provided for @cancelRateWhyMatters.
  ///
  /// In en, this message translates to:
  /// **'Why cancelation rate matters'**
  String get cancelRateWhyMatters;

  /// No description provided for @cancelRateWhyBody.
  ///
  /// In en, this message translates to:
  /// **'A high cancellation rate affects the reliability of our service and can impact your ability to get ride requests. Maintaining a low cancellation rate helps ensure better service for all users.'**
  String get cancelRateWhyBody;

  /// No description provided for @acceptRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Acceptance Rate'**
  String get acceptRateTitle;

  /// No description provided for @exclusiveOffers.
  ///
  /// In en, this message translates to:
  /// **'Exclusive offers'**
  String get exclusiveOffers;

  /// No description provided for @acceptedOffersLower.
  ///
  /// In en, this message translates to:
  /// **'accepted offers'**
  String get acceptedOffersLower;

  /// No description provided for @declinedOrMissed.
  ///
  /// In en, this message translates to:
  /// **'declined or missed'**
  String get declinedOrMissed;

  /// No description provided for @acceptRateOnlyExclusive.
  ///
  /// In en, this message translates to:
  /// **'Only Exclusive offers count'**
  String get acceptRateOnlyExclusive;

  /// No description provided for @acceptRateExclusiveBody.
  ///
  /// In en, this message translates to:
  /// **'Exclusive offers and other offers sent only to you count. Radar trips never count.'**
  String get acceptRateExclusiveBody;

  /// No description provided for @acceptRateHowCalculated.
  ///
  /// In en, this message translates to:
  /// **'How your acceptance rate is calculated'**
  String get acceptRateHowCalculated;

  /// No description provided for @acceptRateHowBody.
  ///
  /// In en, this message translates to:
  /// **'Your acceptance rate is the Exclusive offers you accept compared with all the Exclusive offers you receive. Radar trips never count. We use your last 100 Exclusive offers.'**
  String get acceptRateHowBody;

  /// No description provided for @acceptRateWhyMatters.
  ///
  /// In en, this message translates to:
  /// **'Why acceptance rate matters'**
  String get acceptRateWhyMatters;

  /// No description provided for @acceptRateWhyBody.
  ///
  /// In en, this message translates to:
  /// **'A low acceptance rate reduces your chances of receiving ride requests and may affect your standing on the platform. Maintaining a high acceptance rate helps you get more trips and ensures a reliable experience for riders.'**
  String get acceptRateWhyBody;

  /// No description provided for @rcTriggerDroppedFar.
  ///
  /// In en, this message translates to:
  /// **'Finished far from drop-off'**
  String get rcTriggerDroppedFar;

  /// No description provided for @rcTriggerLongStop.
  ///
  /// In en, this message translates to:
  /// **'Long stop'**
  String get rcTriggerLongStop;

  /// No description provided for @rcTriggerOffRoute.
  ///
  /// In en, this message translates to:
  /// **'Off the route'**
  String get rcTriggerOffRoute;

  /// No description provided for @rcTriggerPossibleCrash.
  ///
  /// In en, this message translates to:
  /// **'Possible crash'**
  String get rcTriggerPossibleCrash;

  /// No description provided for @rcTopicAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident or collision'**
  String get rcTopicAccident;

  /// No description provided for @rcTopicHurt.
  ///
  /// In en, this message translates to:
  /// **'Someone is hurt or feels ill'**
  String get rcTopicHurt;

  /// No description provided for @rcTopicUnsafe.
  ///
  /// In en, this message translates to:
  /// **'I feel unsafe'**
  String get rcTopicUnsafe;

  /// No description provided for @rcTopicCarProblem.
  ///
  /// In en, this message translates to:
  /// **'Car problem'**
  String get rcTopicCarProblem;

  /// No description provided for @rcTopicRiderAskedStop.
  ///
  /// In en, this message translates to:
  /// **'The rider asked for a stop'**
  String get rcTopicRiderAskedStop;

  /// No description provided for @rcTopicTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic or road works'**
  String get rcTopicTraffic;

  /// No description provided for @rcTopicRiderStopHere.
  ///
  /// In en, this message translates to:
  /// **'The rider asked to stop here'**
  String get rcTopicRiderStopHere;

  /// No description provided for @rcTopicRiderChangedDestination.
  ///
  /// In en, this message translates to:
  /// **'The rider changed destination'**
  String get rcTopicRiderChangedDestination;

  /// No description provided for @rcTopicRoadClosed.
  ///
  /// In en, this message translates to:
  /// **'Road closed or no access'**
  String get rcTopicRoadClosed;

  /// No description provided for @rcTopicRiderOtherRoute.
  ///
  /// In en, this message translates to:
  /// **'The rider asked for another route'**
  String get rcTopicRiderOtherRoute;

  /// No description provided for @rcShortAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get rcShortAccident;

  /// No description provided for @rcShortHurt.
  ///
  /// In en, this message translates to:
  /// **'Someone hurt'**
  String get rcShortHurt;

  /// No description provided for @rcShortUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Unsafe'**
  String get rcShortUnsafe;

  /// No description provided for @rcShortRiderStop.
  ///
  /// In en, this message translates to:
  /// **'Rider stop'**
  String get rcShortRiderStop;

  /// No description provided for @rcShortTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get rcShortTraffic;

  /// No description provided for @rcShortNewDestination.
  ///
  /// In en, this message translates to:
  /// **'New destination'**
  String get rcShortNewDestination;

  /// No description provided for @rcShortRoadClosed.
  ///
  /// In en, this message translates to:
  /// **'Road closed'**
  String get rcShortRoadClosed;

  /// No description provided for @rcShortOtherRoute.
  ///
  /// In en, this message translates to:
  /// **'Other route'**
  String get rcShortOtherRoute;

  /// No description provided for @rcQuestionAnyoneHurt.
  ///
  /// In en, this message translates to:
  /// **'Is anyone hurt?'**
  String get rcQuestionAnyoneHurt;

  /// No description provided for @rcQuestionCarSafe.
  ///
  /// In en, this message translates to:
  /// **'Is the car in a safe place?'**
  String get rcQuestionCarSafe;

  /// No description provided for @rcQuestionOtherPersonOk.
  ///
  /// In en, this message translates to:
  /// **'Is the other person OK?'**
  String get rcQuestionOtherPersonOk;

  /// No description provided for @rcQuestionWhoNeedsHelp.
  ///
  /// In en, this message translates to:
  /// **'Who needs help?'**
  String get rcQuestionWhoNeedsHelp;

  /// No description provided for @rcQuestionInDanger.
  ///
  /// In en, this message translates to:
  /// **'Are you in danger right now?'**
  String get rcQuestionInDanger;

  /// No description provided for @rcQuestionCanContinue.
  ///
  /// In en, this message translates to:
  /// **'Can you continue the trip?'**
  String get rcQuestionCanContinue;

  /// No description provided for @rcAnswerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get rcAnswerYes;

  /// No description provided for @rcAnswerNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get rcAnswerNo;

  /// No description provided for @rcAnswerNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get rcAnswerNotSure;

  /// No description provided for @rcAnswerMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get rcAnswerMe;

  /// No description provided for @rcAnswerTheRider.
  ///
  /// In en, this message translates to:
  /// **'The rider'**
  String get rcAnswerTheRider;

  /// No description provided for @rcAnswerSomeoneElse.
  ///
  /// In en, this message translates to:
  /// **'Someone else'**
  String get rcAnswerSomeoneElse;

  /// No description provided for @rcLongerLead.
  ///
  /// In en, this message translates to:
  /// **'This trip is '**
  String get rcLongerLead;

  /// No description provided for @rcPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String rcPercent(int percent);

  /// No description provided for @rcLongerTrail.
  ///
  /// In en, this message translates to:
  /// **' longer than expected'**
  String get rcLongerTrail;

  /// No description provided for @rcStoppedLead.
  ///
  /// In en, this message translates to:
  /// **'Your car has stopped for '**
  String get rcStoppedLead;

  /// No description provided for @rcMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String rcMinutes(int minutes);

  /// No description provided for @rcEndedLead.
  ///
  /// In en, this message translates to:
  /// **'Your trip ended '**
  String get rcEndedLead;

  /// No description provided for @rcEndedFromTrail.
  ///
  /// In en, this message translates to:
  /// **' from {place}'**
  String rcEndedFromTrail(String place);

  /// No description provided for @rcOffRouteLead.
  ///
  /// In en, this message translates to:
  /// **'You are '**
  String get rcOffRouteLead;

  /// No description provided for @rcOffRouteTrail.
  ///
  /// In en, this message translates to:
  /// **' off the route'**
  String get rcOffRouteTrail;

  /// No description provided for @rcOffRouteToTrail.
  ///
  /// In en, this message translates to:
  /// **' off the route to {place}'**
  String rcOffRouteToTrail(String place);

  /// No description provided for @rcCrashLead.
  ///
  /// In en, this message translates to:
  /// **'A '**
  String get rcCrashLead;

  /// No description provided for @rcCrashBold.
  ///
  /// In en, this message translates to:
  /// **'very hard stop'**
  String get rcCrashBold;

  /// No description provided for @rcCrashTrail.
  ///
  /// In en, this message translates to:
  /// **' was detected'**
  String get rcCrashTrail;

  /// No description provided for @rcCrashTrailAt.
  ///
  /// In en, this message translates to:
  /// **' was detected · {place}'**
  String rcCrashTrailAt(String place);

  /// No description provided for @tipHighBoostNearby.
  ///
  /// In en, this message translates to:
  /// **'High boost nearby'**
  String get tipHighBoostNearby;

  /// No description provided for @tipHighBoostIn.
  ///
  /// In en, this message translates to:
  /// **'High boost · +{kr} kr in {zone}'**
  String tipHighBoostIn(String kr, String zone);

  /// No description provided for @tipExpectTrip.
  ///
  /// In en, this message translates to:
  /// **'Expect a trip in 2–5 min'**
  String get tipExpectTrip;

  /// No description provided for @tipPromotionRides.
  ///
  /// In en, this message translates to:
  /// **'Promotion · {rides} rides = {kr} kr'**
  String tipPromotionRides(String rides, String kr);

  /// No description provided for @tipBusyArea.
  ///
  /// In en, this message translates to:
  /// **'Busy area · trips expected soon'**
  String get tipBusyArea;

  /// No description provided for @tipAirportQueue.
  ///
  /// In en, this message translates to:
  /// **'Airport queue: {count} drivers'**
  String tipAirportQueue(String count);

  /// No description provided for @tipGoodStreak.
  ///
  /// In en, this message translates to:
  /// **'Good streak · {count} trips in a row'**
  String tipGoodStreak(String count);

  /// No description provided for @tipDemandRising.
  ///
  /// In en, this message translates to:
  /// **'Demand rising near you'**
  String get tipDemandRising;

  /// No description provided for @tipPeakStart.
  ///
  /// In en, this message translates to:
  /// **'Peak hours start at {time}'**
  String tipPeakStart(String time);

  /// No description provided for @tipTopZone.
  ///
  /// In en, this message translates to:
  /// **'You\'re in a top zone right now'**
  String get tipTopZone;

  /// No description provided for @noticeNewScheduledRide.
  ///
  /// In en, this message translates to:
  /// **'New scheduled ride'**
  String get noticeNewScheduledRide;

  /// No description provided for @noticeScheduledBody.
  ///
  /// In en, this message translates to:
  /// **'{day} {time} · {fare} · Tap to view'**
  String noticeScheduledBody(String day, String time, String fare);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @noticeSecondsToAccept.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s to accept'**
  String noticeSecondsToAccept(int seconds);

  /// No description provided for @noticeHighDemandIn.
  ///
  /// In en, this message translates to:
  /// **'High demand in {area}'**
  String noticeHighDemandIn(String area);

  /// No description provided for @noticeGoOnlineNow.
  ///
  /// In en, this message translates to:
  /// **'Go online now'**
  String get noticeGoOnlineNow;

  /// No description provided for @noticeDocExpires.
  ///
  /// In en, this message translates to:
  /// **'{title} expires {when}'**
  String noticeDocExpires(String title, String when);

  /// No description provided for @noticeUploadNewKeepDriving.
  ///
  /// In en, this message translates to:
  /// **'Upload a new one so you can keep driving.'**
  String get noticeUploadNewKeepDriving;

  /// No description provided for @noticeDocApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'{title} approved. You can go online.'**
  String noticeDocApprovedBody(String title);

  /// No description provided for @noticeCanGoOnlineAgain.
  ///
  /// In en, this message translates to:
  /// **'You can go online again.'**
  String get noticeCanGoOnlineAgain;

  /// No description provided for @noticeTooManyLateCancels.
  ///
  /// In en, this message translates to:
  /// **'Too many late cancels. Back on {date}.'**
  String noticeTooManyLateCancels(String date);

  /// No description provided for @rcWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get rcWhatHappened;

  /// No description provided for @rcCalled112.
  ///
  /// In en, this message translates to:
  /// **'Called 112'**
  String get rcCalled112;

  /// No description provided for @rcDialer112.
  ///
  /// In en, this message translates to:
  /// **'112 dialer:'**
  String get rcDialer112;

  /// No description provided for @rcDialerOpened.
  ///
  /// In en, this message translates to:
  /// **'opened'**
  String get rcDialerOpened;

  /// No description provided for @rcDialerDidNotOpen.
  ///
  /// In en, this message translates to:
  /// **'did not open'**
  String get rcDialerDidNotOpen;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search Country'**
  String get searchCountry;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get colorSilver;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @chooseVehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Choose vehicle color'**
  String get chooseVehicleColor;

  /// No description provided for @closeColorPicker.
  ///
  /// In en, this message translates to:
  /// **'Close color picker'**
  String get closeColorPicker;

  /// No description provided for @mapCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map camera unavailable — tap recenter to retry'**
  String get mapCameraUnavailable;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @ratingAndRides.
  ///
  /// In en, this message translates to:
  /// **'{rating} ★ · {count, plural, =1{1 ride} other{{count} rides}}'**
  String ratingAndRides(String rating, int count);

  /// No description provided for @mapOfArea.
  ///
  /// In en, this message translates to:
  /// **'Map of {area}'**
  String mapOfArea(String area);

  /// No description provided for @cashYouOweMovera.
  ///
  /// In en, this message translates to:
  /// **'You owe Movera'**
  String get cashYouOweMovera;

  /// No description provided for @cashMoveraOwesYou.
  ///
  /// In en, this message translates to:
  /// **'Movera owes you'**
  String get cashMoveraOwesYou;

  /// No description provided for @cashSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get cashSettled;

  /// No description provided for @stopNext.
  ///
  /// In en, this message translates to:
  /// **'{stop} next'**
  String stopNext(String stop);

  /// No description provided for @pickupOnLeftSide.
  ///
  /// In en, this message translates to:
  /// **'Pickup on the left side'**
  String get pickupOnLeftSide;

  /// No description provided for @pickupOnRightSide.
  ///
  /// In en, this message translates to:
  /// **'Pickup on the right side'**
  String get pickupOnRightSide;

  /// No description provided for @moveWithin100MOfPickup.
  ///
  /// In en, this message translates to:
  /// **'Move within 100 m of the pickup to arrive.'**
  String get moveWithin100MOfPickup;

  /// No description provided for @moveWithin100MOfStop.
  ///
  /// In en, this message translates to:
  /// **'Move within 100 m of the stop to arrive.'**
  String get moveWithin100MOfStop;

  /// No description provided for @riderPhoneNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Rider phone contact is not connected in this demo.'**
  String get riderPhoneNotConnected;

  /// No description provided for @recordAudioStarting.
  ///
  /// In en, this message translates to:
  /// **'starting…'**
  String get recordAudioStarting;

  /// No description provided for @photoTooLargeForDevice.
  ///
  /// In en, this message translates to:
  /// **'Photo is too large to keep on this device.'**
  String get photoTooLargeForDevice;

  /// No description provided for @photoStorageFull.
  ///
  /// In en, this message translates to:
  /// **'Photo storage on this device is full. Remove photos from another vehicle first.'**
  String get photoStorageFull;

  /// No description provided for @demoDataBadge.
  ///
  /// In en, this message translates to:
  /// **'DEMO DATA'**
  String get demoDataBadge;

  /// No description provided for @drivingInHeader.
  ///
  /// In en, this message translates to:
  /// **'DRIVING IN'**
  String get drivingInHeader;

  /// No description provided for @anaSampleTripRoute.
  ///
  /// In en, this message translates to:
  /// **'Central Station → Södermalm'**
  String get anaSampleTripRoute;

  /// No description provided for @demandBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get demandBusy;

  /// No description provided for @demandSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get demandSteady;

  /// No description provided for @demandQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get demandQuiet;

  /// No description provided for @aroundStockholm.
  ///
  /// In en, this message translates to:
  /// **'Around Stockholm'**
  String get aroundStockholm;

  /// No description provided for @noticeBonusProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Bonus progress'**
  String get noticeBonusProgressTitle;

  /// No description provided for @noticeBonusProgressBody.
  ///
  /// In en, this message translates to:
  /// **'{done} of {goal} trips this week. {left} more for {amount}.'**
  String noticeBonusProgressBody(
    String done,
    String goal,
    String left,
    String amount,
  );

  /// No description provided for @noticePayoutSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout sent'**
  String get noticePayoutSentTitle;

  /// No description provided for @noticePayoutSentBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} is on its way to your bank.'**
  String noticePayoutSentBody(String amount);

  /// Divider word between the sign-in options.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signInOr;

  /// How many places match the destination search.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 found} other{{count} found}}'**
  String destResultsFound(int count);

  /// Estimated wait in the queue position preview.
  ///
  /// In en, this message translates to:
  /// **'About 15–30 min wait'**
  String get queueEstimatedWait;

  /// Label above the sample count of drivers ahead in the queue.
  ///
  /// In en, this message translates to:
  /// **'Drivers ahead'**
  String get queueDriversAhead;

  /// Payment method: paid by card in the app.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// Label after the live offer count on the Radar list.
  ///
  /// In en, this message translates to:
  /// **'OFFERS'**
  String get offersBadge;

  /// Section header above the bank account fields.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get bankAccountSection;

  /// No description provided for @locationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Movera can\'t see your location, so trips can\'t reach you.'**
  String get locationNotAllowed;

  /// Snackbar action: show the system location prompt again (driver-r5-51).
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allowLocation;

  /// No description provided for @locationBlockedSettings.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for Movera. Allow it in Settings to get trips.'**
  String get locationBlockedSettings;

  /// Under the Movera wordmark on the sign-in screens: this is the driver app.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get authDriverWord;

  /// No description provided for @authBrandTagline.
  ///
  /// In en, this message translates to:
  /// **'Moving to a new era.'**
  String get authBrandTagline;

  /// No description provided for @authEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get authEnterPhone;

  /// No description provided for @authTextFourDigitCode.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text you a 4-digit code.'**
  String get authTextFourDigitCode;

  /// No description provided for @authInvalidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number.'**
  String get authInvalidMobileNumber;

  /// No description provided for @authConsentLabel.
  ///
  /// In en, this message translates to:
  /// **'I agree to the terms of service and the privacy policy'**
  String get authConsentLabel;

  /// No description provided for @authConsentPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our '**
  String get authConsentPrefix;

  /// No description provided for @authConsentTerms.
  ///
  /// In en, this message translates to:
  /// **'terms of service'**
  String get authConsentTerms;

  /// No description provided for @authAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authAnd;

  /// No description provided for @authConsentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get authConsentPrivacy;

  /// No description provided for @authConsentTickFirst.
  ///
  /// In en, this message translates to:
  /// **'Tick the box to agree before you continue.'**
  String get authConsentTickFirst;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String authStepOf(Object step, Object total);

  /// No description provided for @authChangeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get authChangeLanguage;

  /// No description provided for @authChooseCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose your country'**
  String get authChooseCountry;

  /// No description provided for @authSearchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country or code'**
  String get authSearchCountry;

  /// No description provided for @authNoCountryFound.
  ///
  /// In en, this message translates to:
  /// **'No country matches your search.'**
  String get authNoCountryFound;

  /// No description provided for @authPhoneCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code: {country}, {dial}'**
  String authPhoneCountryCode(Object country, Object dial);

  /// No description provided for @authChangeCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Change country'**
  String get authChangeCountryCode;

  /// No description provided for @authEnterYourCodeHead.
  ///
  /// In en, this message translates to:
  /// **'Enter your '**
  String get authEnterYourCodeHead;

  /// No description provided for @authEnterYourCodeAccent.
  ///
  /// In en, this message translates to:
  /// **'code'**
  String get authEnterYourCodeAccent;

  /// No description provided for @authCodeSentToPhone.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a code to your phone.'**
  String get authCodeSentToPhone;

  /// No description provided for @authSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to '**
  String get authSentTo;

  /// No description provided for @authNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent.'**
  String get authNewCodeSent;

  /// No description provided for @authReenterPhone.
  ///
  /// In en, this message translates to:
  /// **'Go back and enter your phone number again.'**
  String get authReenterPhone;

  /// No description provided for @authRequestNewCode.
  ///
  /// In en, this message translates to:
  /// **'Go back and request a new code.'**
  String get authRequestNewCode;

  /// No description provided for @authNeverAskCode.
  ///
  /// In en, this message translates to:
  /// **'Movera will never call or text you asking for this code.'**
  String get authNeverAskCode;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authResendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in '**
  String get authResendCodeIn;

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResendCode;

  /// No description provided for @authErrOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authErrOffline;

  /// No description provided for @authErrTooManyWait.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a moment and try again.'**
  String get authErrTooManyWait;

  /// No description provided for @authErrTooManyIn.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in {wait}.'**
  String authErrTooManyIn(Object wait);

  /// No description provided for @authRetrySeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String authRetrySeconds(int count);

  /// No description provided for @authErrServer.
  ///
  /// In en, this message translates to:
  /// **'Movera is having trouble right now. Try again in a moment.'**
  String get authErrServer;

  /// No description provided for @authErrWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check it and try again.'**
  String get authErrWrongCode;

  /// No description provided for @authCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Tap Resend code for a new one.'**
  String get authCodeExpired;

  /// No description provided for @authErrSendCode.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the code. Try again.'**
  String get authErrSendCode;

  /// No description provided for @authErrCheckCode.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the code. Try again.'**
  String get authErrCheckCode;

  /// No description provided for @authSignInRestricted.
  ///
  /// In en, this message translates to:
  /// **'This number isn\'t on the driver test list yet. Contact Movera to get access.'**
  String get authSignInRestricted;

  /// No description provided for @acctDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get acctDetailsTitle;

  /// No description provided for @acctDetailsIntro.
  ///
  /// In en, this message translates to:
  /// **'Movera checks these before you can drive. Fill them in once.'**
  String get acctDetailsIntro;

  /// No description provided for @acctFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get acctFirstName;

  /// No description provided for @acctLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get acctLastName;

  /// No description provided for @acctDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get acctDateOfBirth;

  /// No description provided for @acctPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get acctPickDate;

  /// No description provided for @acctEmail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get acctEmail;

  /// No description provided for @acctCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get acctCountry;

  /// No description provided for @acctCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get acctCity;

  /// No description provided for @acctChooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose your city'**
  String get acctChooseCity;

  /// No description provided for @acctLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get acctLanguage;

  /// No description provided for @acctAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get acctAccountType;

  /// No description provided for @acctComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get acctComingSoon;

  /// No description provided for @acctCountrySweden.
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get acctCountrySweden;

  /// No description provided for @acctCountryFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get acctCountryFrance;

  /// No description provided for @acctCountryTunisia.
  ///
  /// In en, this message translates to:
  /// **'Tunisia'**
  String get acctCountryTunisia;

  /// No description provided for @acctTypeDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get acctTypeDriverTitle;

  /// No description provided for @acctTypeDriverBody.
  ///
  /// In en, this message translates to:
  /// **'I drive for a fleet'**
  String get acctTypeDriverBody;

  /// No description provided for @acctTypeFleetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get acctTypeFleetTitle;

  /// No description provided for @acctTypeFleetBody.
  ///
  /// In en, this message translates to:
  /// **'I run a company with cars and drivers'**
  String get acctTypeFleetBody;

  /// No description provided for @acctCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get acctCompanyName;

  /// No description provided for @acctOrgNumberSe.
  ///
  /// In en, this message translates to:
  /// **'Organisation number'**
  String get acctOrgNumberSe;

  /// No description provided for @acctOrgNumberFr.
  ///
  /// In en, this message translates to:
  /// **'SIREN'**
  String get acctOrgNumberFr;

  /// No description provided for @acctCompanyAddress.
  ///
  /// In en, this message translates to:
  /// **'Company address'**
  String get acctCompanyAddress;

  /// No description provided for @acctJoinNow.
  ///
  /// In en, this message translates to:
  /// **'Join your fleet now'**
  String get acctJoinNow;

  /// No description provided for @acctJoinNowBody.
  ///
  /// In en, this message translates to:
  /// **'Your fleet owner shares a Movera code with you. You can also do this later from Profile › My fleet.'**
  String get acctJoinNowBody;

  /// No description provided for @acctFleetCode.
  ///
  /// In en, this message translates to:
  /// **'Fleet code'**
  String get acctFleetCode;

  /// No description provided for @acctOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Owner’s full name'**
  String get acctOwnerName;

  /// No description provided for @acctOwnerEmail.
  ///
  /// In en, this message translates to:
  /// **'Owner’s e-mail'**
  String get acctOwnerEmail;

  /// No description provided for @acctRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get acctRequired;

  /// No description provided for @acctUnderAge.
  ///
  /// In en, this message translates to:
  /// **'You must be at least {age} to drive with Movera.'**
  String acctUnderAge(int age);

  /// No description provided for @acctInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get acctInvalidDate;

  /// No description provided for @acctInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail.'**
  String get acctInvalidEmail;

  /// No description provided for @acctCountryNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Movera is not open in this country yet.'**
  String get acctCountryNotOpen;

  /// No description provided for @acctInvalidCity.
  ///
  /// In en, this message translates to:
  /// **'Choose a city of your country.'**
  String get acctInvalidCity;

  /// No description provided for @acctTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to continue.'**
  String get acctTermsRequired;

  /// No description provided for @acctCompanyRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in your company’s details.'**
  String get acctCompanyRequired;

  /// No description provided for @acctDetailsLocked.
  ///
  /// In en, this message translates to:
  /// **'Your details are already approved. Contact support to change them.'**
  String get acctDetailsLocked;

  /// No description provided for @acctCouldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send your details. Try again.'**
  String get acctCouldNotSend;

  /// No description provided for @acctTooManyTriesHour.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait about an hour and try again.'**
  String get acctTooManyTriesHour;

  /// No description provided for @acctChangedReload.
  ///
  /// In en, this message translates to:
  /// **'Your account changed meanwhile. Pull to refresh and try again.'**
  String get acctChangedReload;

  /// No description provided for @acctCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your account.'**
  String get acctCouldNotLoad;

  /// No description provided for @acctTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get acctTryAgain;

  /// No description provided for @holdBeingChecked.
  ///
  /// In en, this message translates to:
  /// **'Your account is being checked. Upload your documents; we tell you when you can drive.'**
  String get holdBeingChecked;

  /// No description provided for @holdWaitingFleetVehicle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your fleet’s vehicle details'**
  String get holdWaitingFleetVehicle;

  /// No description provided for @myFleet.
  ///
  /// In en, this message translates to:
  /// **'My fleet'**
  String get myFleet;

  /// No description provided for @docYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get docYou;

  /// No description provided for @docCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get docCompany;

  /// No description provided for @docCar.
  ///
  /// In en, this message translates to:
  /// **'Car {plate}'**
  String docCar(Object plate);

  /// No description provided for @docStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get docStatusRejected;

  /// No description provided for @docStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get docStatusExpired;

  /// No description provided for @docMoveraBooks.
  ///
  /// In en, this message translates to:
  /// **'Movera books this with you'**
  String get docMoveraBooks;

  /// No description provided for @docTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get docTakePhoto;

  /// No description provided for @docChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get docChoosePhoto;

  /// No description provided for @docChoosePdf.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get docChoosePdf;

  /// No description provided for @docUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get docUploading;

  /// No description provided for @docUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded. Movera checks it.'**
  String get docUploaded;

  /// No description provided for @docUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t upload. Try again.'**
  String get docUploadFailed;

  /// No description provided for @docFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 10 MB.'**
  String get docFileTooLarge;

  /// No description provided for @docUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Send a JPEG, PNG, HEIC or PDF.'**
  String get docUnsupportedFile;

  /// No description provided for @docEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get docEmptyFile;

  /// No description provided for @docTypeNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'This document can’t be uploaded here.'**
  String get docTypeNotAccepted;

  /// No description provided for @docCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your documents.'**
  String get docCouldNotLoad;

  /// No description provided for @docNoneYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to upload yet.'**
  String get docNoneYet;

  /// No description provided for @docUploadNew.
  ///
  /// In en, this message translates to:
  /// **'Upload a new one'**
  String get docUploadNew;

  /// No description provided for @fleetJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join your fleet'**
  String get fleetJoinTitle;

  /// No description provided for @fleetJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Your fleet owner shares the Movera code with you. Enter it with the owner’s name and e-mail as registered with Movera.'**
  String get fleetJoinBody;

  /// No description provided for @fleetJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get fleetJoin;

  /// No description provided for @fleetJoined.
  ///
  /// In en, this message translates to:
  /// **'You’re in {name}.'**
  String fleetJoined(Object name);

  /// No description provided for @fleetJoinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The code, the owner’s name and e-mail don’t match a fleet. Check them with your fleet owner.'**
  String get fleetJoinMismatch;

  /// No description provided for @fleetAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'You’re already in a fleet. Leave it first.'**
  String get fleetAlreadyIn;

  /// No description provided for @fleetAccountHasOwn.
  ///
  /// In en, this message translates to:
  /// **'A fleet account has its own fleet.'**
  String get fleetAccountHasOwn;

  /// No description provided for @fleetOnTrip.
  ///
  /// In en, this message translates to:
  /// **'Finish the trip first.'**
  String get fleetOnTrip;

  /// No description provided for @fleetOwnerCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'The owner can’t leave the fleet.'**
  String get fleetOwnerCannotLeave;

  /// No description provided for @fleetNotInOne.
  ///
  /// In en, this message translates to:
  /// **'You’re not in a fleet.'**
  String get fleetNotInOne;

  /// No description provided for @fleetOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the fleet owner can do that.'**
  String get fleetOwnerOnly;

  /// No description provided for @fleetYourCompany.
  ///
  /// In en, this message translates to:
  /// **'Your company'**
  String get fleetYourCompany;

  /// No description provided for @fleetYourFleet.
  ///
  /// In en, this message translates to:
  /// **'Your fleet'**
  String get fleetYourFleet;

  /// No description provided for @fleetCode.
  ///
  /// In en, this message translates to:
  /// **'Fleet code'**
  String get fleetCode;

  /// No description provided for @fleetCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Share it with your drivers together with your name and e-mail.'**
  String get fleetCodeHint;

  /// No description provided for @fleetCodeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Movera’s approval'**
  String get fleetCodeWaiting;

  /// No description provided for @fleetCodeShareText.
  ///
  /// In en, this message translates to:
  /// **'Join {name} on Movera Driver. Code: {code}. Owner: {owner}, {email}.'**
  String fleetCodeShareText(
    Object name,
    Object code,
    Object owner,
    Object email,
  );

  /// No description provided for @fleetShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get fleetShare;

  /// No description provided for @fleetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fleetCopy;

  /// No description provided for @fleetCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get fleetCodeCopied;

  /// No description provided for @fleetDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get fleetDrivers;

  /// No description provided for @fleetNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers yet. Share your code.'**
  String get fleetNoDrivers;

  /// No description provided for @fleetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get fleetRemove;

  /// No description provided for @fleetRemoveDriverQ.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your fleet?'**
  String fleetRemoveDriverQ(Object name);

  /// No description provided for @fleetCars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get fleetCars;

  /// No description provided for @fleetNoCars.
  ///
  /// In en, this message translates to:
  /// **'No cars yet.'**
  String get fleetNoCars;

  /// No description provided for @fleetNoCarsMember.
  ///
  /// In en, this message translates to:
  /// **'Your fleet has no approved car yet.'**
  String get fleetNoCarsMember;

  /// No description provided for @fleetAddCar.
  ///
  /// In en, this message translates to:
  /// **'Add car'**
  String get fleetAddCar;

  /// No description provided for @fleetChooseCar.
  ///
  /// In en, this message translates to:
  /// **'Choose this car'**
  String get fleetChooseCar;

  /// No description provided for @fleetYourCar.
  ///
  /// In en, this message translates to:
  /// **'Your car'**
  String get fleetYourCar;

  /// No description provided for @fleetInUse.
  ///
  /// In en, this message translates to:
  /// **'In use by another driver'**
  String get fleetInUse;

  /// No description provided for @fleetPickedBy.
  ///
  /// In en, this message translates to:
  /// **'Picked by {name}'**
  String fleetPickedBy(Object name);

  /// No description provided for @fleetLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave fleet'**
  String get fleetLeave;

  /// No description provided for @fleetLeaveQ.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}? You can join another fleet with a new code.'**
  String fleetLeaveQ(Object name);

  /// No description provided for @fleetCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your fleet.'**
  String get fleetCouldNotLoad;

  /// No description provided for @fleetStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get fleetStatusPending;

  /// No description provided for @fleetStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get fleetStatusApproved;

  /// No description provided for @fleetStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get fleetStatusRejected;

  /// No description provided for @fleetStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get fleetStatusBlocked;

  /// No description provided for @fleetVehicleInUse.
  ///
  /// In en, this message translates to:
  /// **'Another driver is driving this car right now.'**
  String get fleetVehicleInUse;

  /// No description provided for @fleetVehicleNotApproved.
  ///
  /// In en, this message translates to:
  /// **'This car isn’t approved yet.'**
  String get fleetVehicleNotApproved;

  /// No description provided for @fleetVehicleNotYours.
  ///
  /// In en, this message translates to:
  /// **'This car isn’t your fleet’s.'**
  String get fleetVehicleNotYours;

  /// No description provided for @fleetPlateTaken.
  ///
  /// In en, this message translates to:
  /// **'A car with this plate is already registered.'**
  String get fleetPlateTaken;

  /// No description provided for @fleetCarAdded.
  ///
  /// In en, this message translates to:
  /// **'Car added. Movera checks it.'**
  String get fleetCarAdded;

  /// No description provided for @fleetCouldNotAddCar.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add the car. Try again.'**
  String get fleetCouldNotAddCar;

  /// No description provided for @fleetCouldNotPick.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t choose the car. Try again.'**
  String get fleetCouldNotPick;

  /// No description provided for @fleetColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get fleetColour;

  /// No description provided for @fleetPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get fleetPlate;

  /// No description provided for @fleetSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get fleetSeats;

  /// No description provided for @fleetCarTypes.
  ///
  /// In en, this message translates to:
  /// **'Car types'**
  String get fleetCarTypes;

  /// No description provided for @fleetMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 driver} other{{count} drivers}}'**
  String fleetMemberCount(int count);

  /// No description provided for @fleetCarCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 car} other{{count} cars}}'**
  String fleetCarCount(int count);

  /// No description provided for @fleetOrgNumber.
  ///
  /// In en, this message translates to:
  /// **'Org. no. {number}'**
  String fleetOrgNumber(Object number);

  /// No description provided for @fleetOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get fleetOnline;

  /// No description provided for @fleetOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get fleetOffline;

  /// No description provided for @vehStatusPending.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get vehStatusPending;

  /// No description provided for @vehStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get vehStatusApproved;

  /// No description provided for @vehStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get vehStatusRejected;

  /// No description provided for @vehStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get vehStatusBlocked;

  /// No description provided for @vehDocumentsOnDocs.
  ///
  /// In en, this message translates to:
  /// **'Upload the car’s documents under Documents.'**
  String get vehDocumentsOnDocs;

  /// No description provided for @fleetCarSeatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{count} seats}}'**
  String fleetCarSeatsCount(int count);

  /// No description provided for @fleetJoinLink.
  ///
  /// In en, this message translates to:
  /// **'Join a fleet'**
  String get fleetJoinLink;

  /// No description provided for @docChooseHow.
  ///
  /// In en, this message translates to:
  /// **'How do you want to add it?'**
  String get docChooseHow;

  /// No description provided for @fleetVehiclesAwait.
  ///
  /// In en, this message translates to:
  /// **'Your fleet adds its cars; you pick the one you drive here.'**
  String get fleetVehiclesAwait;

  /// No description provided for @liveOnlineFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not go online. Try again.'**
  String get liveOnlineFailed;

  /// No description provided for @liveOfflineFailed.
  ///
  /// In en, this message translates to:
  /// **'Movera could not record that you went offline. Try again.'**
  String get liveOfflineFailed;

  /// No description provided for @liveOnlineNotActive.
  ///
  /// In en, this message translates to:
  /// **'Your account is not active yet, so you can\'t go online.'**
  String get liveOnlineNotActive;

  /// No description provided for @liveOnlineNoFleet.
  ///
  /// In en, this message translates to:
  /// **'Join a fleet before you go online.'**
  String get liveOnlineNoFleet;

  /// No description provided for @liveOnlineFleetNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Your fleet is not approved yet, so you can\'t go online.'**
  String get liveOnlineFleetNotApproved;

  /// No description provided for @liveOnlineNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'Choose an approved car before you go online.'**
  String get liveOnlineNoVehicle;

  /// No description provided for @liveOnlineVehicleNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Your car is not approved yet, so you can\'t go online.'**
  String get liveOnlineVehicleNotApproved;

  /// No description provided for @liveOnlineVehicleInUse.
  ///
  /// In en, this message translates to:
  /// **'Another driver has this car now. Choose your car again.'**
  String get liveOnlineVehicleInUse;

  /// No description provided for @liveOnlineNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No ride type is set for your car yet.'**
  String get liveOnlineNoCategory;

  /// No description provided for @liveOfflineOnTrip.
  ///
  /// In en, this message translates to:
  /// **'Finish your trip before you go offline.'**
  String get liveOfflineOnTrip;

  /// No description provided for @liveTripNotAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Movera doesn\'t see you at the pickup yet. Drive closer and try again.'**
  String get liveTripNotAtPickup;

  /// No description provided for @liveTripNoShowTooEarly.
  ///
  /// In en, this message translates to:
  /// **'It\'s too early for a no-show. Wait a little longer.'**
  String get liveTripNoShowTooEarly;

  /// No description provided for @liveTripChanged.
  ///
  /// In en, this message translates to:
  /// **'This trip changed meanwhile. Check it and try again.'**
  String get liveTripChanged;

  /// Waybill: the trip's own part of the driver's earnings, without the waiting fee and the Movera bonus.
  ///
  /// In en, this message translates to:
  /// **'Base · {service}'**
  String earningsBaseService(String service);

  /// No description provided for @liveTripFailed.
  ///
  /// In en, this message translates to:
  /// **'Movera could not record this step. Try again.'**
  String get liveTripFailed;

  /// No description provided for @authProviderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign-in with Apple and Google is coming soon. Use your phone number.'**
  String get authProviderComingSoon;

  /// No description provided for @authErrProvider.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t sign in that way. Try again, or use your phone number.'**
  String get authErrProvider;

  /// No description provided for @authLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'That sign-in took too long. Start again with Apple or Google, or use your phone number.'**
  String get authLinkExpired;

  /// No description provided for @authContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Continue with {provider}'**
  String authContinueWith(String provider);

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @authProviderPhoneOnce.
  ///
  /// In en, this message translates to:
  /// **'Confirm your phone number once to finish signing in with {provider}. We’ll text you a 4-digit code.'**
  String authProviderPhoneOnce(String provider);

  /// No description provided for @authUsePhoneInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in with my phone number only'**
  String get authUsePhoneInstead;

  /// No description provided for @acctDetailsHead.
  ///
  /// In en, this message translates to:
  /// **'Your '**
  String get acctDetailsHead;

  /// No description provided for @acctDetailsAccent.
  ///
  /// In en, this message translates to:
  /// **'details'**
  String get acctDetailsAccent;

  /// No description provided for @acctDetailsEditIntro.
  ///
  /// In en, this message translates to:
  /// **'Movera is checking your account. You can still change these until it is approved.'**
  String get acctDetailsEditIntro;

  /// No description provided for @acctPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get acctPhone;

  /// No description provided for @acctTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get acctTapToChange;

  /// No description provided for @acctChooseCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose your country'**
  String get acctChooseCountry;

  /// No description provided for @acctChooseCountryBody.
  ///
  /// In en, this message translates to:
  /// **'Where you will drive.'**
  String get acctChooseCountryBody;

  /// No description provided for @acctChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get acctChooseLanguage;

  /// No description provided for @acctChooseLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'The app’s language. You can change it later.'**
  String get acctChooseLanguageBody;

  /// No description provided for @acctCityStockholmHint.
  ///
  /// In en, this message translates to:
  /// **'Stockholm, Södertälje and the whole county'**
  String get acctCityStockholmHint;

  /// No description provided for @acctCityParisHint.
  ///
  /// In en, this message translates to:
  /// **'Paris and the Île-de-France region'**
  String get acctCityParisHint;

  /// No description provided for @acctFromProvider.
  ///
  /// In en, this message translates to:
  /// **'from {provider}'**
  String acctFromProvider(String provider);

  /// No description provided for @acctOrgNumberSeRule.
  ///
  /// In en, this message translates to:
  /// **'Enter the 10 digits of your organisation number.'**
  String get acctOrgNumberSeRule;

  /// No description provided for @acctOrgNumberFrRule.
  ///
  /// In en, this message translates to:
  /// **'Enter a SIREN (9 digits) or a SIRET (14 digits).'**
  String get acctOrgNumberFrRule;

  /// No description provided for @acctCompanyAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Street, postcode, town'**
  String get acctCompanyAddressHint;

  /// No description provided for @acctOwnerEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@company.com'**
  String get acctOwnerEmailHint;

  /// No description provided for @acctJoinNowShort.
  ///
  /// In en, this message translates to:
  /// **'Your fleet owner shares a Movera code with you.'**
  String get acctJoinNowShort;

  /// No description provided for @acctLeaveSignUpQ.
  ///
  /// In en, this message translates to:
  /// **'Leave the sign-up?'**
  String get acctLeaveSignUpQ;

  /// No description provided for @acctLeaveSignUpBody.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out and back at the first step. What you typed stays on this phone until you sign in again.'**
  String get acctLeaveSignUpBody;

  /// No description provided for @acctSaveDetails.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get acctSaveDetails;

  /// No description provided for @acctDetailsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your details are saved. Movera checks them.'**
  String get acctDetailsSaved;

  /// No description provided for @fleetRequestPending.
  ///
  /// In en, this message translates to:
  /// **'You already asked a fleet. Wait for its answer or cancel that request.'**
  String get fleetRequestPending;

  /// No description provided for @fleetInvitePending.
  ///
  /// In en, this message translates to:
  /// **'That number already has an open invitation.'**
  String get fleetInvitePending;

  /// No description provided for @fleetOwnPhone.
  ///
  /// In en, this message translates to:
  /// **'That is your own number.'**
  String get fleetOwnPhone;

  /// No description provided for @fleetInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter the number in international form, e.g. +46 70 123 45 67.'**
  String get fleetInvalidPhone;

  /// No description provided for @fleetNotApprovedYet.
  ///
  /// In en, this message translates to:
  /// **'Movera has not approved your fleet yet. You can invite drivers after that.'**
  String get fleetNotApprovedYet;

  /// No description provided for @fleetInvitationExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired.'**
  String get fleetInvitationExpired;

  /// No description provided for @fleetInvitationGone.
  ///
  /// In en, this message translates to:
  /// **'This invitation is no longer open.'**
  String get fleetInvitationGone;

  /// No description provided for @fleetADriver.
  ///
  /// In en, this message translates to:
  /// **'A driver'**
  String get fleetADriver;

  /// No description provided for @fleetRequestBodyOwner.
  ///
  /// In en, this message translates to:
  /// **'Wants to join your fleet with your code.'**
  String get fleetRequestBodyOwner;

  /// No description provided for @fleetInviteWaitsSignUp.
  ///
  /// In en, this message translates to:
  /// **'Invited. Waiting for this number to sign up in Movera Driver.'**
  String get fleetInviteWaitsSignUp;

  /// No description provided for @fleetInviteWaitsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Invited. Waiting for the driver’s answer.'**
  String get fleetInviteWaitsAnswer;

  /// No description provided for @fleetInviteBodyDriver.
  ///
  /// In en, this message translates to:
  /// **'Invites you to its fleet. Accept to drive its cars; Movera then checks your documents.'**
  String get fleetInviteBodyDriver;

  /// No description provided for @fleetRequestWaitsOwner.
  ///
  /// In en, this message translates to:
  /// **'Your request is sent. The fleet owner accepts it in the app.'**
  String get fleetRequestWaitsOwner;

  /// No description provided for @fleetInviteNew.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get fleetInviteNew;

  /// No description provided for @fleetInviteExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String fleetInviteExpires(String date);

  /// No description provided for @fleetAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get fleetAccept;

  /// No description provided for @fleetDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get fleetDecline;

  /// No description provided for @fleetCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get fleetCancelling;

  /// No description provided for @fleetPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invitation waiting for your answer} other{{count} invitations waiting for your answer}}'**
  String fleetPendingInvitations(int count);

  /// No description provided for @fleetInviteDriver.
  ///
  /// In en, this message translates to:
  /// **'Invite driver'**
  String get fleetInviteDriver;

  /// No description provided for @fleetInviteDriverBody.
  ///
  /// In en, this message translates to:
  /// **'The driver’s phone number, the one he signs in with. He accepts in his app; a number without an account gets an SMS with the app link.'**
  String get fleetInviteDriverBody;

  /// No description provided for @fleetInviteDriverHint.
  ///
  /// In en, this message translates to:
  /// **'The invitation is valid for 7 days.'**
  String get fleetInviteDriverHint;

  /// No description provided for @fleetSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get fleetSendInvite;

  /// No description provided for @fleetAskToJoin.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get fleetAskToJoin;

  /// No description provided for @fleetAskToJoinHint.
  ///
  /// In en, this message translates to:
  /// **'The fleet owner accepts your request in his app.'**
  String get fleetAskToJoinHint;

  /// No description provided for @fleetCancelInviteQ.
  ///
  /// In en, this message translates to:
  /// **'Take back this invitation?'**
  String get fleetCancelInviteQ;

  /// No description provided for @fleetDeclineInviteQ.
  ///
  /// In en, this message translates to:
  /// **'Decline {name}?'**
  String fleetDeclineInviteQ(String name);

  /// No description provided for @fleetCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get fleetCancelInvite;

  /// No description provided for @fleetDriverJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} is now in your fleet.'**
  String fleetDriverJoined(String name);

  /// No description provided for @fleetInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {who}.'**
  String fleetInviteSent(String who);

  /// No description provided for @fleetRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests to join'**
  String get fleetRequests;

  /// No description provided for @fleetInvitationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending} other{{count} pending}}'**
  String fleetInvitationCount(int count);

  /// No description provided for @fleetInvites.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get fleetInvites;

  /// No description provided for @fleetNoInvites.
  ///
  /// In en, this message translates to:
  /// **'No open invitation. Invite a driver by phone number, or share your code.'**
  String get fleetNoInvites;

  /// No description provided for @fleetYourRequest.
  ///
  /// In en, this message translates to:
  /// **'Your request'**
  String get fleetYourRequest;

  /// No description provided for @fleetRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {name}. The owner answers in the app.'**
  String fleetRequestSent(String name);

  /// No description provided for @notifCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your notifications.'**
  String get notifCouldNotLoad;

  /// No description provided for @notifNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet. Fleet invitations and answers show here.'**
  String get notifNone;

  /// Profile header (live): profLiveNoNameYet
  ///
  /// In en, this message translates to:
  /// **'Your details are not sent yet'**
  String get profLiveNoNameYet;

  /// Profile header (live): profStatusActive
  ///
  /// In en, this message translates to:
  /// **'Active account'**
  String get profStatusActive;

  /// Profile header (live): profStatusOnHold
  ///
  /// In en, this message translates to:
  /// **'Waiting for Movera’s approval'**
  String get profStatusOnHold;

  /// Profile header (live): profStatusPending
  ///
  /// In en, this message translates to:
  /// **'Details not sent yet'**
  String get profStatusPending;

  /// Profile header (live): profStatusSuspended
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get profStatusSuspended;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
