/// Reservation rules the driver app follows, the same ones admin sets in
/// Dispatch › Reservations. The app uses [ScheduledRideRules.current],
/// whose defaults mirror the admin defaults; `DriverAppConfig.reservations`
/// ([ScheduledRideRules.fromJson]) replaces it when a zone's config is
/// applied.
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
/// type"). Their names are the `reservations.rideTypes` keys.
enum ScheduledRideKind { normal, airport, longTrip, comfortPremium, event }

/// Where a reservation goes when its online driver would reach the pickup
/// too late (`reservations.lateEta.reassignTo`).
enum LateEtaReassignTo {
  /// The nearest available driver, as an Exclusive offer.
  exclusive,

  /// The Radar trips.
  radar,

  /// Back to dispatch, which decides.
  dispatch,
}

/// `reservations.lateEta`: an online driver who accepted a reservation is
/// watched from "Leave now" until they arrive at the pickup. When now plus
/// their ETA is later than the pickup time plus [toleranceMinutes], the ride
/// goes to another driver at once, not at the pickup time.
class LateEtaRule {
  const LateEtaRule({
    this.on = true,
    this.toleranceMinutes = 3,
    this.checkEverySeconds = 60,
    this.reassignTo = LateEtaReassignTo.exclusive,
  });

  final bool on;

  /// 0..30. Minutes past the pickup time still counted as on time.
  final int toleranceMinutes;

  /// 15..600. How often the ETA is checked.
  final int checkEverySeconds;

  final LateEtaReassignTo reassignTo;

  Duration get tolerance => Duration(minutes: toleranceMinutes);
  Duration get checkEvery => Duration(seconds: checkEverySeconds);

  /// Every field optional; a missing or invalid one (wrong type, out of
  /// the schema's range) keeps the default, as does an unknown
  /// [reassignTo] (CONTRACT.md §6.1).
  factory LateEtaRule.fromJson(Object? json) {
    const seed = LateEtaRule();
    if (json is! Map) return seed;
    return LateEtaRule(
      on: _bool(json['on']) ?? seed.on,
      toleranceMinutes:
          _intIn(json['toleranceMin'], 0, 30) ?? seed.toleranceMinutes,
      checkEverySeconds:
          _intIn(json['checkEverySeconds'], 15, 600) ?? seed.checkEverySeconds,
      reassignTo:
          _enum(json['reassignTo'], LateEtaReassignTo.values) ??
          seed.reassignTo,
    );
  }
}

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

  /// `{onlineBeforeMin, spareMin, reminderMin}`; what is missing or
  /// invalid stays as in [seed]; a reminder out of range is left out.
  factory ScheduledRideKindRule.fromJson(
    Object? json,
    ScheduledRideKindRule seed,
  ) {
    if (json is! Map) return seed;
    final reminders = json['reminderMin'];
    return ScheduledRideKindRule(
      onlineBeforeMinutes:
          _intIn(json['onlineBeforeMin'], 5, 240) ?? seed.onlineBeforeMinutes,
      spareMinutes: _intIn(json['spareMin'], 0, 60) ?? seed.spareMinutes,
      reminderMinutes: reminders is List
          ? List<int>.unmodifiable(
              {
                for (final minutes in reminders)
                  if (_intIn(minutes, 1, 1440) case final value?) value,
              }.toList()..sort((a, b) => b.compareTo(a)),
            )
          : seed.reminderMinutes,
    );
  }
}

class ScheduledRideRules {
  const ScheduledRideRules({
    this.enabled = true,
    this.lateWarning = true,
    this.homePopupAfterMinutes = 10,
    this.exclusiveBeforeMinutes = 20,
    this.radarBeforeMinutes = 15,
    this.onDriverCancel = ReservationCancelReturn.byTime,
    this.removeClashing = true,
    this.towardPickupBeforeRide = true,
    this.towardPickupBeforeMinutes = 60,
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
    this.lateEta = const LateEtaRule(),
  });

  /// The rules in use. Mirrors the admin defaults until a zone's config
  /// sets it (`DriverAppConfig.apply`).
  static ScheduledRideRules current = const ScheduledRideRules();

  /// `reservations.on`: reservations in this zone.
  final bool enabled;

  /// `reservations.lateWarn`: "Head to your 07:40 pickup" when "Leave now"
  /// cannot start the trip. "Leave now" itself always opens the trip: there
  /// is no switch for it (owner decision 1, contract v0.4.2).
  final bool lateWarning;

  /// `reservations.towardPickupBeforeMin`.
  final int towardPickupBeforeMinutes;

  /// `reservations.lateEta`: an online driver's ETA to the pickup.
  final LateEtaRule lateEta;

  /// `DriverAppConfig.reservations`. Every field optional: a missing or
  /// invalid value (wrong type, not a whole number where the schema wants
  /// one, out of the schema's range) keeps the default, and so does an
  /// unknown choice (CONTRACT.md §6.1). [includedWaitingMinutes] is not part
  /// of it and keeps its default. A `leaveNow` field from an older document
  /// is ignored (contract v0.4.2).
  factory ScheduledRideRules.fromJson(Object? json) {
    const seed = ScheduledRideRules();
    if (json is! Map) return seed;
    final types = json['rideTypes'];
    final kinds = <ScheduledRideKind, ScheduledRideKindRule>{
      for (final kind in ScheduledRideKind.values)
        kind: ScheduledRideKindRule.fromJson(
          types is Map ? types[kind.name] : null,
          seed.ruleFor(kind),
        ),
    };
    final assign = _intIn(json['assignAcceptSeconds'], 10, 600);
    return ScheduledRideRules(
      enabled: _bool(json['on']) ?? seed.enabled,
      lateWarning: _bool(json['lateWarn']) ?? seed.lateWarning,
      backupAfterMinutes:
          _intIn(json['offlineBackupAfterMin'], 1, 60) ??
          seed.backupAfterMinutes,
      homePopupAfterMinutes:
          _intIn(json['homePopupAfterMin'], 1, 1440) ??
          seed.homePopupAfterMinutes,
      exclusiveBeforeMinutes:
          _intIn(json['exclusiveBeforeMin'], 1, 180) ??
          seed.exclusiveBeforeMinutes,
      radarBeforeMinutes:
          _intIn(json['radarBeforeMin'], 1, 180) ?? seed.radarBeforeMinutes,
      onDriverCancel:
          _enum(json['onDriverCancel'], ReservationCancelReturn.values) ??
          seed.onDriverCancel,
      removeClashing: _bool(json['hideClashing']) ?? seed.removeClashing,
      towardPickupBeforeRide:
          _bool(json['towardPickup']) ?? seed.towardPickupBeforeRide,
      towardPickupBeforeMinutes:
          _intIn(json['towardPickupBeforeMin'], 15, 240) ??
          seed.towardPickupBeforeMinutes,
      longTripKm: _numIn(json['longTripKm'], 10, 500) ?? seed.longTripKm,
      kinds: kinds,
      // A number in the contract (0.5 to 72): 1.5 is 90 minutes, not 2 h
      // (driver-r3-4).
      driverLateCancelHours:
          _numIn(json['driverLateCancelHours'], 0.5, 72) ??
          seed.driverLateCancelHours,
      lateCancelLimit:
          _intIn(json['lateCancelLimit'], 1, 20) ?? seed.lateCancelLimit,
      lateCancelPeriodDays:
          _intIn(json['lateCancelPeriodDays'], 1, 90) ??
          seed.lateCancelPeriodDays,
      pauseDays: _intIn(json['pauseDays'], 1, 365) ?? seed.pauseDays,
      assignAcceptTime: assign == null
          ? seed.assignAcceptTime
          : Duration(seconds: assign),
      lateEta: LateEtaRule.fromJson(json['lateEta']),
    );
  }

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
  final double driverLateCancelHours;

  /// [driverLateCancelHours] as a duration, to the minute.
  Duration get driverLateCancel =>
      Duration(minutes: (driverLateCancelHours * 60).round());

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

bool? _bool(Object? json) => json is bool ? json : null;

/// A whole number in [min]..[max] (the schema's `integer` range); null
/// otherwise, so the field keeps its default.
int? _intIn(Object? json, int min, int max) =>
    json is num &&
        json.isFinite &&
        json == json.roundToDouble() &&
        json >= min &&
        json <= max
    ? json.toInt()
    : null;

/// A number in [min]..[max]; null otherwise.
double? _numIn(Object? json, double min, double max) =>
    json is num && json.isFinite && json >= min && json <= max
    ? json.toDouble()
    : null;

T? _enum<T extends Enum>(Object? json, List<T> values) {
  for (final value in values) {
    if (value.name == json) return value;
  }
  return null;
}
