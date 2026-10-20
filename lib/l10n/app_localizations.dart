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
  /// **'Tap to accept'**
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

  /// No description provided for @allOffers.
  ///
  /// In en, this message translates to:
  /// **'ALL OFFERS'**
  String get allOffers;

  /// No description provided for @savedTripCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The saved trip could not be opened.'**
  String get savedTripCouldNotBeOpened;

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

  /// No description provided for @moveWithin100MOfWhere.
  ///
  /// In en, this message translates to:
  /// **'Move within 100 m of the {where} to arrive.'**
  String moveWithin100MOfWhere(Object where);

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
  /// **'Recorded fares'**
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
  /// **'Fare {fareFormatted} · Cash {cashCollectedFormatted}'**
  String fareFareFormattedCashCashCollected(
    Object fareFormatted,
    Object cashCollectedFormatted,
  );

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
  /// **'Pin verification'**
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

  /// No description provided for @showTrafficOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show traffic on map'**
  String get showTrafficOnMap;

  /// No description provided for @trafficColoursOnTripMap.
  ///
  /// In en, this message translates to:
  /// **'Traffic colours on the trip map'**
  String get trafficColoursOnTripMap;

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

  /// No description provided for @pickupOnPickupSideSide.
  ///
  /// In en, this message translates to:
  /// **'Pickup on the {pickupSide} side'**
  String pickupOnPickupSideSide(Object pickupSide);

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
