/// Driver app texts (Q30): every island, offer and main trip button text
/// that admin can change in Content › Driver app texts, per language.
/// An empty text there means the app's own text in that language
/// (lib/l10n, Round 4), and the English default below for a language the
/// app has no texts for.
library;

import 'package:movera/core/content/driver_text_l10n.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Where a text shows in the app.
enum DriverTextArea { island, offer, trip }

/// One text admin can change: its key, its English default and where it
/// shows. A default may hold values in braces, e.g. "{time}".
class DriverTextKey {
  const DriverTextKey(this.id, this.english, this.area);

  final String id;
  final String english;
  final DriverTextArea area;
}

/// Changed texts from admin Content, by language ("en", "sv", "fr",
/// "ar"), then by key. A backend sends them; the demo has none, so every
/// text is the app's default.
class DriverAppTextOverrides {
  const DriverAppTextOverrides([this.byLanguage = const {}]);

  final Map<String, Map<String, String>> byLanguage;

  String? textFor(String language, String key) {
    final text = byLanguage[language]?[key]?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Looks up a text: admin's text for [language] when there is one, the
/// default otherwise.
class DriverAppTexts {
  DriverAppTexts._();

  /// The languages admin writes texts in.
  static const List<String> languages = <String>['en', 'sv', 'fr', 'ar'];

  /// The app's language ("en", "fr" or "sv"); [DriverLanguage] sets it.
  static String language = 'en';

  /// From admin Content.
  static DriverAppTextOverrides overrides = const DriverAppTextOverrides();

  /// Admin's text for the language wins; then the app's own text.
  static String of(DriverTextKey key, [Map<String, Object> values = const {}]) {
    var text = overrides.textFor(language, key.id) ??
        driverTextTemplate(tr, key.id) ??
        key.english;
    values.forEach((name, value) {
      text = text.replaceAll('{$name}', '$value');
    });
    return text;
  }

  /// Back to the defaults.
  static void reset() {
    language = 'en';
    overrides = const DriverAppTextOverrides();
  }
}

/// Shorthand for [DriverAppTexts.of].
String driverText(DriverTextKey key, [Map<String, Object> values = const {}]) =>
    DriverAppTexts.of(key, values);

/// Every key admin can change, with the app's default text.
class DriverTexts {
  DriverTexts._();

  // Island notices on Home.
  static const islandOnline =
      DriverTextKey('island.online', 'Radar online', DriverTextArea.island);
  static const islandOffline =
      DriverTextKey('island.offline', 'Radar offline', DriverTextArea.island);
  static const islandRiderCancelled = DriverTextKey(
      'island.riderCancelled', 'Rider cancelled', DriverTextArea.island);
  static const islandRiderEndedTrip = DriverTextKey(
      'island.riderEndedTrip', 'Rider ended trip', DriverTextArea.island);
  /// X5: the trip went back to dispatch (admin reassign, released booking).
  static const islandTripRemoved = DriverTextKey(
      'island.tripRemoved', 'Trip removed by Movera', DriverTextArea.island);
  /// R15-7: after "Rider cancelled", the driver's cancel fee or none.
  static const islandCancelFee =
      DriverTextKey('island.cancelFee', '+{amount}', DriverTextArea.island);
  static const islandCancelNoFee =
      DriverTextKey('island.cancelNoFee', 'no fee', DriverTextArea.island);
  /// R15-7: the rider cancelled a reservation this driver had accepted,
  /// e.g. "14:00 cancelled" (short, so the fee still fits the island).
  static const islandReservationCancelled = DriverTextKey(
      'island.reservationCancelled', '{time} cancelled',
      DriverTextArea.island);
  static const islandMatching =
      DriverTextKey('island.matching', 'Matching…', DriverTextArea.island);
  static const islandMatched =
      DriverTextKey('island.matched', 'Trip matched', DriverTextArea.island);
  static const islandTakenByOther = DriverTextKey(
      'island.takenByOther', 'Taken by another driver', DriverTextArea.island);
  static const islandTripUnavailable = DriverTextKey(
      'island.tripUnavailable', 'Trip unavailable', DriverTextArea.island);
  static const islandNoConnection = DriverTextKey(
      'island.noConnection', 'No connection', DriverTextArea.island);
  static const islandContactSupport = DriverTextKey(
      'island.contactSupport', 'Contact support', DriverTextArea.island);
  /// R10-7: the hold reasons the island keeps while going online waits.
  static const islandAccountOnHold = DriverTextKey('island.accountOnHold',
      'Account on hold · Contact support', DriverTextArea.island);
  static const islandAccountNotActive = DriverTextKey('island.accountNotActive',
      'Account not active · Finish sign-up', DriverTextArea.island);
  static const islandNewReservation = DriverTextKey(
      'island.newReservation', 'New reservation', DriverTextArea.island);
  static const islandExclusiveRide = DriverTextKey(
      'island.exclusiveRide', 'Exclusive ride', DriverTextArea.island);
  static const islandExclusiveReservation = DriverTextKey(
      'island.exclusiveReservation',
      'Exclusive reservation',
      DriverTextArea.island);
  static const islandReservationAccepted = DriverTextKey(
      'island.reservationAccepted',
      'Reservation accepted',
      DriverTextArea.island);
  static const islandReservationAcceptedAt = DriverTextKey(
      'island.reservationAcceptedAt',
      'Accepted · pickup {time}',
      DriverTextArea.island);
  static const islandNoLongerAvailable = DriverTextKey(
      'island.noLongerAvailable', 'No longer available', DriverTextArea.island);
  static const islandAssignedByMovera = DriverTextKey(
      'island.assignedByMovera', 'Assigned by Movera', DriverTextArea.island);
  static const islandAssignmentAccepted = DriverTextKey(
      'island.assignmentAccepted',
      'Scheduled ride accepted',
      DriverTextArea.island);
  static const islandAssignmentNotAccepted = DriverTextKey(
      'island.assignmentNotAccepted',
      'Assignment not accepted',
      DriverTextArea.island);
  static const islandPickupIn = DriverTextKey(
      'island.pickupIn', '{time} pickup in {left}', DriverTextArea.island);
  static const islandGoOnlineFor = DriverTextKey(
      'island.goOnlineFor', 'Go online for {time} pickup', DriverTextArea.island);
  static const islandLeaveNow = DriverTextKey(
      'island.leaveNow', 'Leave now for {time} pickup', DriverTextArea.island);
  static const islandHeadToPickup = DriverTextKey(
      'island.headToPickup', 'Head to your {time} pickup', DriverTextArea.island);
  static const islandGivenToBackup = DriverTextKey(
      'island.givenToBackup', 'Given to backup driver', DriverTextArea.island);
  /// Late ETA: the driver would reach the scheduled pickup too late.
  static const islandLateReassigned = DriverTextKey('island.lateReassigned',
      'Given to another driver: {minutes} min late', DriverTextArea.island);
  static const islandCashOn =
      DriverTextKey('island.cashOn', 'Cash rides on', DriverTextArea.island);
  static const islandCashOff =
      DriverTextKey('island.cashOff', 'Cash rides off', DriverTextArea.island);
  static const islandLastMissed = DriverTextKey(
      'island.lastMissed', 'Next missed offer: offline', DriverTextArea.island);
  static const islandOfflineMissed = DriverTextKey('island.offlineMissed',
      'Offline: {count} offers missed', DriverTextArea.island);
  static const islandDrivingLeft = DriverTextKey(
      'island.drivingLeft', '{minutes} min left to drive', DriverTextArea.island);
  static const islandRestUntil =
      DriverTextKey('island.restUntil', 'Rest until {time}', DriverTextArea.island);
  static const islandRestOver =
      DriverTextKey('island.restOver', 'Rest over', DriverTextArea.island);
  static const islandDocumentExpires = DriverTextKey('island.documentExpires',
      '{document} expires {when}', DriverTextArea.island);
  static const islandDocumentExpired = DriverTextKey(
      'island.documentExpired', '{document} expired', DriverTextArea.island);
  static const islandDocumentInReview = DriverTextKey(
      'island.documentInReview', 'New document in review', DriverTextArea.island);
  static const islandDocumentApproved = DriverTextKey(
      'island.documentApproved', 'Document approved', DriverTextArea.island);
  static const islandHighDemand = DriverTextKey(
      'island.highDemand', 'High demand · {area}', DriverTextArea.island);
  static const islandScheduledPaused = DriverTextKey('island.scheduledPaused',
      'Scheduled rides paused', DriverTextArea.island);
  static const islandSavedTripOpen = DriverTextKey(
      'island.savedTripOpen', 'Saved trip open', DriverTextArea.island);
  static const islandNewerTripKept = DriverTextKey(
      'island.newerTripKept', 'Newer trip kept', DriverTextArea.island);
  static const islandRecordSetAside = DriverTextKey(
      'island.recordSetAside', 'Trip record set aside', DriverTextArea.island);
  static const islandRecoveryFailed = DriverTextKey(
      'island.recoveryFailed', 'Recovery failed', DriverTextArea.island);
  static const islandTripNotClosed = DriverTextKey(
      'island.tripNotClosed', 'Trip not closed', DriverTextArea.island);
  static const islandCloseSavedTrip = DriverTextKey(
      'island.closeSavedTrip', 'Close saved trip', DriverTextArea.island);
  static const islandSeeEarnings = DriverTextKey(
      'island.seeEarnings', 'Tap to see earnings', DriverTextArea.island);

  /// R13-9: admin's destinations per day are used up, or the mode is off
  /// in this zone, or its time limit ended it.
  static const islandDestinationsUsed = DriverTextKey('island.destinationsUsed',
      "Today's destinations used", DriverTextArea.island);
  static const islandDestinationOff = DriverTextKey(
      'island.destinationOff', 'Destination mode is off here', DriverTextArea.island);
  static const islandDestinationEnded = DriverTextKey(
      'island.destinationEnded', 'Destination mode ended', DriverTextArea.island);

  // Offer cards: Radar, Exclusive and the reservation popup.
  static const offerYourShare =
      DriverTextKey('offer.yourShare', 'Your share', DriverTextArea.offer);
  static const offerPickup =
      DriverTextKey('offer.pickup', 'Pickup', DriverTextArea.offer);
  static const offerDropoff =
      DriverTextKey('offer.dropoff', 'Drop-off', DriverTextArea.offer);
  static const offerPickupNearby =
      DriverTextKey('offer.pickupNearby', 'Pickup nearby', DriverTextArea.offer);
  static const offerKmAway =
      DriverTextKey('offer.kmAway', '{km} km away', DriverTextArea.offer);
  static const offerTripLength = DriverTextKey(
      'offer.tripLength', '{minutes} min trip · {km} km', DriverTextArea.offer);
  static const offerMatch =
      DriverTextKey('offer.match', 'Match', DriverTextArea.offer);
  static const offerMatching =
      DriverTextKey('offer.matching', 'Matching…', DriverTextArea.offer);
  static const offerAccept =
      DriverTextKey('offer.accept', 'Accept', DriverTextArea.offer);
  static const offerOnYourWay =
      DriverTextKey('offer.onYourWay', 'On your way', DriverTextArea.offer);

  // Main trip buttons.
  static const tripArrived =
      DriverTextKey('trip.arrived', "I've arrived", DriverTextArea.trip);
  static const tripStart =
      DriverTextKey('trip.start', 'Start trip', DriverTextArea.trip);
  static const tripStartFirstStop = DriverTextKey(
      'trip.startFirstStop', 'Start first stop', DriverTextArea.trip);
  static const tripArriveAtStop = DriverTextKey(
      'trip.arriveAtStop', 'Arrive at the stop', DriverTextArea.trip);
  static const tripComplete =
      DriverTextKey('trip.complete', 'Complete trip', DriverTextArea.trip);
  static const tripGoToStop =
      DriverTextKey('trip.goToStop', 'Go to {stop} stop', DriverTextArea.trip);
  static const tripGoToDropoff =
      DriverTextKey('trip.goToDropoff', 'Go to drop-off', DriverTextArea.trip);
  static const tripCollectCash =
      DriverTextKey('trip.collectCash', 'Collect cash', DriverTextArea.trip);

  /// R8-4: the Collect cash sheet's button, e.g. "Finish Comfort".
  static const tripFinishCategory = DriverTextKey(
      'trip.finishCategory', 'Finish {category}', DriverTextArea.trip);
  static const tripFinishRide =
      DriverTextKey('trip.finishRide', 'Finish ride', DriverTextArea.trip);

  /// Every key, for admin's list. Only texts a screen shows: a key no
  /// screen reads would be an edit with no effect (driver-u9).
  static const List<DriverTextKey> all = <DriverTextKey>[
    islandOnline,
    islandOffline,
    islandRiderCancelled,
    islandRiderEndedTrip,
    islandTripRemoved,
    islandCancelFee,
    islandCancelNoFee,
    islandReservationCancelled,
    islandMatching,
    islandMatched,
    islandTakenByOther,
    islandTripUnavailable,
    islandNoConnection,
    islandContactSupport,
    islandAccountOnHold,
    islandAccountNotActive,
    islandNewReservation,
    islandExclusiveRide,
    islandExclusiveReservation,
    islandReservationAccepted,
    islandReservationAcceptedAt,
    islandNoLongerAvailable,
    islandAssignedByMovera,
    islandAssignmentAccepted,
    islandAssignmentNotAccepted,
    islandPickupIn,
    islandGoOnlineFor,
    islandLeaveNow,
    islandHeadToPickup,
    islandGivenToBackup,
    islandLateReassigned,
    islandCashOn,
    islandCashOff,
    islandLastMissed,
    islandOfflineMissed,
    islandDrivingLeft,
    islandRestUntil,
    islandRestOver,
    islandDocumentExpires,
    islandDocumentExpired,
    islandDocumentInReview,
    islandDocumentApproved,
    islandHighDemand,
    islandScheduledPaused,
    islandSavedTripOpen,
    islandNewerTripKept,
    islandRecordSetAside,
    islandRecoveryFailed,
    islandTripNotClosed,
    islandCloseSavedTrip,
    islandSeeEarnings,
    islandDestinationsUsed,
    islandDestinationOff,
    islandDestinationEnded,
    offerYourShare,
    offerPickup,
    offerDropoff,
    offerPickupNearby,
    offerKmAway,
    offerTripLength,
    offerMatch,
    offerMatching,
    offerAccept,
    offerOnYourWay,
    tripArrived,
    tripStart,
    tripStartFirstStop,
    tripArriveAtStop,
    tripComplete,
    tripGoToStop,
    tripGoToDropoff,
    tripCollectCash,
    tripFinishCategory,
    tripFinishRide,
  ];
}
