/// Reservation rules the driver app follows, the same ones admin sets in
/// Dispatch › Reservations. Today the app uses [ScheduledRideRules.current],
/// whose defaults mirror the admin defaults; a backend feeds it later.
library;

/// The steps an untaken reservation goes through, in this order.
enum ReservationStep {
  /// Listed in Scheduled rides.
  list,

  /// Also sent as the Home popup.
  home,

  /// Close to pickup: an Exclusive offer.
  exclusive,

  /// Closer still: also a Radar trip (never labelled Exclusive there).
  radar,
}

/// Where a reservation goes back to when the driver who took it cancels
/// (admin "After a driver cancels").
enum ReservationCancelReturn {
  /// The step the time left before pickup says.
  byTime,

  /// Scheduled rides; the Home popup waits again from the cancel.
  list,

  /// The Home popup at once.
  home,

  /// An Exclusive offer at once.
  exclusive,
}

/// Kinds of scheduled ride, each with its own times (admin "Rules per ride
/// type").
enum ScheduledRideKind { normal, airport, longTrip, comfortPremium, event }

/// Times for one kind of scheduled ride.
class ScheduledRideKindRule {
  const ScheduledRideKindRule({
    required this.onlineBeforeMinutes,
    this.spareMinutes = 15,
    this.reminderMinutes = const [60, 15],
  });

  /// The driver should be online this long before pickup.
  final int onlineBeforeMinutes;

  /// Spare minutes in the smart gap: added to the drive to the pickup.
  final int spareMinutes;

  /// Reminders, in minutes before pickup.
  final List<int> reminderMinutes;
}

class ScheduledRideRules {
  const ScheduledRideRules({
    this.homePopupAfterMinutes = 10,
    this.exclusiveBeforeMinutes = 20,
    this.radarBeforeMinutes = 15,
    this.onDriverCancel = ReservationCancelReturn.byTime,
    this.removeClashing = true,
    this.towardPickupBeforeRide = true,
    this.backupAfterMinutes = 5,
    this.longTripKm = 50,
    this.kinds = const {
      ScheduledRideKind.normal: ScheduledRideKindRule(onlineBeforeMinutes: 30),
      ScheduledRideKind.airport: ScheduledRideKindRule(onlineBeforeMinutes: 60),
      ScheduledRideKind.longTrip: ScheduledRideKindRule(
        onlineBeforeMinutes: 60,
      ),
      ScheduledRideKind.comfortPremium: ScheduledRideKindRule(
        onlineBeforeMinutes: 45,
      ),
      ScheduledRideKind.event: ScheduledRideKindRule(onlineBeforeMinutes: 45),
    },
    this.driverLateCancelHours = 1,
    this.lateCancelLimit = 2,
    this.lateCancelPeriodDays = 7,
    this.pauseDays = 7,
    this.assignAcceptTime = const Duration(seconds: 30),
    this.includedWaitingMinutes = 5,
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static ScheduledRideRules current = const ScheduledRideRules();

  /// Untaken this many minutes after booking, it is also the Home popup.
  final int homePopupAfterMinutes;

  /// It becomes an Exclusive offer this many minutes before pickup.
  final int exclusiveBeforeMinutes;

  /// It also joins the Radar trips this many minutes before pickup.
  final int radarBeforeMinutes;

  final ReservationCancelReturn onDriverCancel;

  /// Rides whose times clash leave the driver's list once one is taken.
  final bool removeClashing;

  /// Before a scheduled ride, only trips toward its pickup are offered.
  final bool towardPickupBeforeRide;

  /// After "leave now" passes and the driver is not on the way, the ride
  /// goes to a backup driver this many minutes later.
  final int backupAfterMinutes;

  /// A ride longer than this is a long trip.
  final double longTripKm;

  final Map<ScheduledRideKind, ScheduledRideKindRule> kinds;

  /// A driver cancel with less than this left to pickup is a late cancel.
  /// Drivers never pay to cancel.
  final int driverLateCancelHours;

  /// This many late cancels within [lateCancelPeriodDays] pause Scheduled
  /// rides for [pauseDays].
  final int lateCancelLimit;
  final int lateCancelPeriodDays;
  final int pauseDays;

  /// How long the driver has to accept a ride Movera assigned to them.
  final Duration assignAcceptTime;

  /// Reservation policy "Included waiting": free waiting at the pickup of
  /// a booked ride. The waiting rules read it for scheduled rides.
  final int includedWaitingMinutes;

  ScheduledRideKindRule ruleFor(ScheduledRideKind kind) =>
      kinds[kind] ??
      kinds[ScheduledRideKind.normal] ??
      const ScheduledRideKindRule(onlineBeforeMinutes: 30);

  /// Where an untaken reservation is: [sinceBookedMinutes] after booking,
  /// [beforePickupMinutes] before pickup.
  ReservationStep stepAt({
    required int sinceBookedMinutes,
    required int beforePickupMinutes,
  }) {
    if (beforePickupMinutes <= radarBeforeMinutes) {
      return ReservationStep.radar;
    }
    if (beforePickupMinutes <= exclusiveBeforeMinutes) {
      return ReservationStep.exclusive;
    }
    if (sinceBookedMinutes >= homePopupAfterMinutes) {
      return ReservationStep.home;
    }
    return ReservationStep.list;
  }

  /// Where it goes back to when the driver who took it cancels. A step
  /// closer to pickup always wins over the chosen one.
  ReservationStep stepAfterDriverCancel({
    required int sinceBookedMinutes,
    required int beforePickupMinutes,
  }) {
    // Back to the list: the Home popup waits its minutes again, counted
    // from the cancel; Exclusive and Radar still follow the time left.
    if (onDriverCancel == ReservationCancelReturn.list) {
      return stepAt(
        sinceBookedMinutes: 0,
        beforePickupMinutes: beforePickupMinutes,
      );
    }
    final byTime = stepAt(
      sinceBookedMinutes: sinceBookedMinutes,
      beforePickupMinutes: beforePickupMinutes,
    );
    final chosen = switch (onDriverCancel) {
      ReservationCancelReturn.home => ReservationStep.home,
      ReservationCancelReturn.exclusive => ReservationStep.exclusive,
      _ => byTime,
    };
    return chosen.index >= byTime.index ? chosen : byTime;
  }
}
