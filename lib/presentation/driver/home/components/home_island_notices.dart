import 'package:flutter/material.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';

/// What the island says, in one place. Kept to the essential words so the
/// island stays about its normal size: same or a little longer. Each text
/// comes from Driver app texts (Q30): admin's text or the default.
class HomeIslandNotices {
  const HomeIslandNotices._();

  static IslandMessage get online => IslandMessage(
    title: driverText(DriverTexts.islandOnline),
    tone: IslandTone.success,
    priority: IslandPriority.low,
    live: true,
    group: 'online',
  );

  static IslandMessage get offline => IslandMessage(
    title: driverText(DriverTexts.islandOffline),
    priority: IslandPriority.low,
    group: 'online',
  );

  static IslandMessage get riderCancelled => IslandMessage(
    title: driverText(DriverTexts.islandRiderCancelled),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static IslandMessage get riderEndedTrip => IslandMessage(
    title: driverText(DriverTexts.islandRiderEndedTrip),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static IslandMessage get matching => IslandMessage(
    title: driverText(DriverTexts.islandMatching),
    priority: IslandPriority.low,
    group: 'radar-match',
  );

  static IslandMessage get matched => IslandMessage(
    title: driverText(DriverTexts.islandMatched),
    tone: IslandTone.success,
    priority: IslandPriority.low,
    group: 'radar-match',
  );

  static IslandMessage get takenByOther => IslandMessage(
    title: driverText(DriverTexts.islandTakenByOther),
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static IslandMessage get tripUnavailable => IslandMessage(
    title: driverText(DriverTexts.islandTripUnavailable),
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static IslandMessage get noConnection => IslandMessage(
    title: driverText(DriverTexts.islandNoConnection),
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static IslandMessage get accountOnHold => IslandMessage(
    title: driverText(DriverTexts.islandContactSupport),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static IslandMessage get newReservation => IslandMessage(
    title: driverText(DriverTexts.islandNewReservation),
    group: 'reservation',
  );

  /// An Exclusive offer arrives on Home: info blue, with a bolt.
  static IslandMessage get exclusiveRide => IslandMessage(
    title: driverText(DriverTexts.islandExclusiveRide),
    icon: Icons.bolt_rounded,
    group: 'exclusive',
  );

  /// The Exclusive offer is a reservation close to pickup.
  static IslandMessage get exclusiveReservation => IslandMessage(
    title: driverText(DriverTexts.islandExclusiveReservation),
    icon: Icons.bolt_rounded,
    group: 'exclusive',
  );

  static IslandMessage get reservationAccepted => IslandMessage(
    title: driverText(DriverTexts.islandReservationAccepted),
    tone: IslandTone.success,
    group: 'reservation',
  );

  /// Taken for later: it waits in Scheduled rides › Accepted until its
  /// time, e.g. "Accepted · pickup 19:30".
  static IslandMessage reservationAcceptedAt(String time) => IslandMessage(
    title: driverText(DriverTexts.islandReservationAcceptedAt, {'time': time}),
    tone: IslandTone.success,
    group: 'reservation',
  );

  /// The driver tapped Accept on the radar; the server picks one driver.
  static IslandMessage get reservationMatching => IslandMessage(
    title: driverText(DriverTexts.islandMatching),
    priority: IslandPriority.low,
    group: 'reservation',
  );

  /// This driver's claim lost (R25): another driver was first, or was
  /// picked at the same moment; or it was cancelled or expired.
  static IslandMessage get reservationUnavailable => IslandMessage(
    title: driverText(DriverTexts.islandNoLongerAvailable),
    tone: IslandTone.warning,
    group: 'reservation',
  );

  static IslandMessage get reservationNoConnection => IslandMessage(
    title: driverText(DriverTexts.islandNoConnection),
    tone: IslandTone.warning,
    group: 'reservation',
  );

  /// Q29: Movera assigned a scheduled ride; it needs Accept in time.
  static IslandMessage get assignedRide => IslandMessage(
    title: driverText(DriverTexts.islandAssignedByMovera),
    group: 'exclusive',
  );

  static IslandMessage get assignmentAccepted => IslandMessage(
    title: driverText(DriverTexts.islandAssignmentAccepted),
    tone: IslandTone.success,
    group: 'reservation',
  );

  /// The assigned ride was not accepted in time; Movera picks another
  /// driver.
  static IslandMessage get assignmentNotAccepted => IslandMessage(
    title: driverText(DriverTexts.islandAssignmentNotAccepted),
    tone: IslandTone.warning,
    group: 'reservation',
  );

  /// Q10: a reminder before a scheduled pickup, e.g. "07:40 pickup in 15
  /// min".
  static IslandMessage scheduledReminder(String time, String left) =>
      IslandMessage(
        title: driverText(
          DriverTexts.islandPickupIn,
          {'time': time, 'left': left},
        ),
        group: 'scheduled',
      );

  /// The "be online before" time of a scheduled ride, while offline.
  static IslandMessage goOnlineFor(String time) => IslandMessage(
    title: driverText(DriverTexts.islandGoOnlineFor, {'time': time}),
    tone: IslandTone.warning,
    group: 'scheduled',
  );

  /// "Leave now": the scheduled ride is on screen as the active trip.
  static IslandMessage leaveNow(String time) => IslandMessage(
    title: driverText(DriverTexts.islandLeaveNow, {'time': time}),
    tone: IslandTone.success,
    priority: IslandPriority.high,
    group: 'scheduled',
  );

  /// "Leave now" passed and the driver is not on the way.
  static IslandMessage headToPickup(String time) => IslandMessage(
    title: driverText(DriverTexts.islandHeadToPickup, {'time': time}),
    tone: IslandTone.warning,
    priority: IslandPriority.high,
    group: 'scheduled',
  );

  /// Still not on the way: the ride went to a backup driver.
  static IslandMessage get givenToBackup => IslandMessage(
    title: driverText(DriverTexts.islandGivenToBackup),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
    group: 'scheduled',
  );

  /// Q23: the driver's Cash switch in the Home sheet.
  static IslandMessage get cashOn => IslandMessage(
    title: driverText(DriverTexts.islandCashOn),
    tone: IslandTone.success,
    priority: IslandPriority.low,
    group: 'cash',
  );

  static IslandMessage get cashOff => IslandMessage(
    title: driverText(DriverTexts.islandCashOff),
    priority: IslandPriority.low,
    group: 'cash',
  );

  /// Q16: one more missed Exclusive offer takes the driver offline.
  static IslandMessage get lastMissedBeforeOffline => IslandMessage(
    title: driverText(DriverTexts.islandLastMissed),
    tone: IslandTone.warning,
    group: 'missed',
  );

  /// Q16: [count] Exclusive offers in a row went without Accept.
  static IslandMessage offlineAfterMissed(int count) => IslandMessage(
    title: driverText(DriverTexts.islandOfflineMissed, {'count': count}),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
    group: 'missed',
  );

  /// Q25: [minutes] left before the rest (the admin's 30 and 10).
  static IslandMessage drivingLeft(int minutes) => IslandMessage(
        title: driverText(DriverTexts.islandDrivingLeft, {'minutes': minutes}),
        tone: IslandTone.warning,
        priority: minutes <= 10 ? IslandPriority.high : IslandPriority.normal,
        group: 'driving-limit',
      );

  /// Q25: the limit is reached, or the driver tried to go online before
  /// the rest is over.
  static IslandMessage restUntil(String time) => IslandMessage(
        title: driverText(DriverTexts.islandRestUntil, {'time': time}),
        tone: IslandTone.alert,
        priority: IslandPriority.high,
        group: 'driving-limit',
      );

  /// Q26: a document expired; going online waits for the new one.
  static IslandMessage documentExpired(String document) => IslandMessage(
        title: driverText(DriverTexts.islandDocumentExpired, {'document': document}),
        tone: IslandTone.alert,
        priority: IslandPriority.high,
        group: 'documents',
      );

  /// Q26: the new document is with Movera; going online waits for it.
  static IslandMessage get documentInReview => IslandMessage(
        title: driverText(DriverTexts.islandDocumentInReview),
        tone: IslandTone.warning,
        priority: IslandPriority.high,
        group: 'documents',
      );

  /// Q31: a notification popup, in its own few words. Tapping it opens
  /// what it is about.
  static IslandMessage notice(
    String title, {
    IslandTone tone = IslandTone.info,
    VoidCallback? onTap,
  }) =>
      IslandMessage(title: title, tone: tone, onTap: onTap);

  static IslandMessage get recoveryPending => IslandMessage(
    title: driverText(DriverTexts.islandSavedTripOpen),
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static IslandMessage get newerTripKept => IslandMessage(
    title: driverText(DriverTexts.islandNewerTripKept),
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static IslandMessage get recordSetAside => IslandMessage(
    title: driverText(DriverTexts.islandRecordSetAside),
    tone: IslandTone.warning,
  );

  static IslandMessage get recoveryFailed => IslandMessage(
    title: driverText(DriverTexts.islandRecoveryFailed),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static IslandMessage get savedTripNotClosed => IslandMessage(
    title: driverText(DriverTexts.islandTripNotClosed),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static IslandMessage get unreadableTripOpen => IslandMessage(
    title: driverText(DriverTexts.islandCloseSavedTrip),
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static IslandMessage get unreadableTripNotClosed => IslandMessage(
    title: driverText(DriverTexts.islandTripNotClosed),
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  /// First launch only. The one message whose tap does more than close
  /// it: it shows the earnings, as its words say.
  static IslandMessage earningsHint(VoidCallback show) => IslandMessage(
        title: driverText(DriverTexts.islandSeeEarnings),
        priority: IslandPriority.high,
        onTap: show,
      );
}
