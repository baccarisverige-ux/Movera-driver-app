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
    // v0.18.17 (owner Q5 2026-11-03): the first reminder 2 h before.
    // Owner M6-a: one reminder, 2 h before (no 15-min one).
    this.reminderMinutes = const [120],
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
      // v0.18.17 (owner Q5): online 60 min before (the zone may set 30).
      ScheduledRideKind.normal: ScheduledRideKindRule(onlineBeforeMinutes: 60),
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
    this.bookLater = const BookLaterRules(),
  });

  /// Contract v0.18.17 Book later: the zone's booking policy and who sees
  /// a booked ride (the server applies them; the app shows them).
  final BookLaterRules bookLater;

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
      bookLater: BookLaterRules.fromJson(json),
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

/// Contract v0.18.17 Book later (`contract.json#bookLater`, owner
/// 2026-11-03 Q1–Q6): the zone's `DriverAppConfig.reservations` fields of
/// the booking policy. Every field optional; a bad one keeps the default.
class BookLaterRules {
  const BookLaterRules({
    this.minAheadMin = 15,
    this.maxAheadDays = 90,
    this.soonBeforeMin = 30,
    this.listTo = 'all',
    this.listMinRating = 4.5,
    this.listGroupSize = 10,
    this.listNearKm = 5,
    this.listAreaTrips = 5,
    this.listGroupId,
    this.listOpenAll = true,
    this.listOpenAllAfterMin = 30,
    this.noticeOn = true,
    this.noticeMaxDrivers = 20,
    this.homePopup = true,
    this.noDriverAlertMin = 10,
    this.riderReminderMin = 60,
    this.freeChangeBeforeMin = 60,
    this.maxTripKm,
    this.dispatchBeforeMin = 30,
    this.listHomeKm = 5,
    this.listAtTimeKm = 5,
    this.listAtTimeMin = 30,
    this.changeAnswerMin = 15,
    this.arriveEarlyMin = 10,
    this.raiseFare = true,
    this.raiseMax,
    this.takeBackLateMin = 5,
    this.takeBackKeepIfDriveMin = 10,
    this.takeBackUntilMinBeforePickup = 15,
  });

  /// FIX JOB 4 (contract v0.18.35 §59, owner Q2): the server takes a held
  /// booked ride back only when the driver would be more than
  /// [takeBackLateMin] late, is more than [takeBackKeepIfDriveMin] minutes'
  /// drive away, and the pickup is at least [takeBackUntilMinBeforePickup]
  /// minutes away. The app only shows the rule; the server decides.
  final int takeBackLateMin;
  final int takeBackKeepIfDriveMin;
  final int takeBackUntilMinBeforePickup;

  final int dispatchBeforeMin;
  final double listHomeKm;
  final double listAtTimeKm;
  final int listAtTimeMin;
  final int changeAnswerMin;

  /// v0.18.19 (owner leave on time): arrive this many minutes early.
  final int arriveEarlyMin;

  /// v0.18.19 (owner C): an admin may raise a booked ride's fare; the
  /// highest raise in the zone's money (null: the live-ride limit only).
  final bool raiseFare;
  final double? raiseMax;

  final int minAheadMin;
  final int maxAheadDays;

  /// Booked closer than this to pickup: sent at once like a live ride.
  final int soonBeforeMin;
  final String listTo;
  final double listMinRating;
  final int listGroupSize;
  final double listNearKm;
  final int listAreaTrips;
  final String? listGroupId;
  final bool listOpenAll;
  final int listOpenAllAfterMin;
  final bool noticeOn;
  final int noticeMaxDrivers;
  final bool homePopup;
  final int noDriverAlertMin;
  final int riderReminderMin;
  final int freeChangeBeforeMin;

  /// Null: no limit (owner BL-Q5).
  final double? maxTripKm;

  static const listToValues = [
    'all',
    'category',
    'rating',
    'random',
    'nearNow',
    'group',
    'areaRegulars',
    'homeNear',
    'favourites',
    'nearAtTime',
  ];

  factory BookLaterRules.fromJson(Map<dynamic, dynamic> json) {
    const seed = BookLaterRules();
    final listTo = json['listTo'];
    final group = json['listGroupId'];
    return BookLaterRules(
      minAheadMin: _intIn(json['minAheadMin'], 5, 240) ?? seed.minAheadMin,
      maxAheadDays: _intIn(json['maxAheadDays'], 1, 365) ?? seed.maxAheadDays,
      soonBeforeMin:
          _intIn(json['soonBeforeMin'], 0, 240) ?? seed.soonBeforeMin,
      listTo: listTo is String && listToValues.contains(listTo)
          ? listTo
          : seed.listTo,
      listMinRating: _numIn(json['listMinRating'], 1, 5) ?? seed.listMinRating,
      listGroupSize:
          _intIn(json['listGroupSize'], 1, 500) ?? seed.listGroupSize,
      listNearKm: _numIn(json['listNearKm'], 0.5, 50) ?? seed.listNearKm,
      listAreaTrips:
          _intIn(json['listAreaTrips'], 1, 200) ?? seed.listAreaTrips,
      listGroupId: group is String && group.isNotEmpty ? group : null,
      listOpenAll: _bool(json['listOpenAll']) ?? seed.listOpenAll,
      listOpenAllAfterMin:
          _intIn(json['listOpenAllAfterMin'], 1, 1440) ??
          seed.listOpenAllAfterMin,
      noticeOn: _bool(json['noticeOn']) ?? seed.noticeOn,
      noticeMaxDrivers:
          _intIn(json['noticeMaxDrivers'], 1, 500) ?? seed.noticeMaxDrivers,
      homePopup: _bool(json['homePopup']) ?? seed.homePopup,
      noDriverAlertMin:
          _intIn(json['noDriverAlertMin'], 1, 120) ?? seed.noDriverAlertMin,
      riderReminderMin:
          _intIn(json['riderReminderMin'], 0, 1440) ?? seed.riderReminderMin,
      freeChangeBeforeMin:
          _intIn(json['freeChangeBeforeMin'], 0, 1440) ??
          seed.freeChangeBeforeMin,
      maxTripKm: _numIn(json['maxTripKm'], 1, 1000),
      dispatchBeforeMin:
          _intIn(json['dispatchBeforeMin'], 5, 240) ?? seed.dispatchBeforeMin,
      listHomeKm: _numIn(json['listHomeKm'], 0.5, 50) ?? seed.listHomeKm,
      listAtTimeKm: _numIn(json['listAtTimeKm'], 0.5, 50) ?? seed.listAtTimeKm,
      listAtTimeMin:
          _intIn(json['listAtTimeMin'], 5, 240) ?? seed.listAtTimeMin,
      changeAnswerMin:
          _intIn(json['changeAnswerMin'], 1, 120) ?? seed.changeAnswerMin,
      arriveEarlyMin:
          _intIn(json['arriveEarlyMin'], 0, 60) ?? seed.arriveEarlyMin,
      raiseFare: json['raiseFare'] is bool
          ? json['raiseFare'] as bool
          : seed.raiseFare,
      raiseMax: json['raiseMax'] is num
          ? (json['raiseMax'] as num).toDouble()
          : json.containsKey('raiseMax')
          ? null
          : seed.raiseMax,
      takeBackLateMin:
          _intIn(json['takeBackLateMin'], 1, 60) ?? seed.takeBackLateMin,
      takeBackKeepIfDriveMin:
          _intIn(json['takeBackKeepIfDriveMin'], 0, 60) ??
          seed.takeBackKeepIfDriveMin,
      takeBackUntilMinBeforePickup:
          _intIn(json['takeBackUntilMinBeforePickup'], 0, 180) ??
          seed.takeBackUntilMinBeforePickup,
    );
  }

  /// The contract's keys, as the zone document sends them.
  Map<String, Object?> toJson() => {
    'minAheadMin': minAheadMin,
    'maxAheadDays': maxAheadDays,
    'soonBeforeMin': soonBeforeMin,
    'listTo': listTo,
    'listMinRating': listMinRating,
    'listGroupSize': listGroupSize,
    'listNearKm': listNearKm,
    'listAreaTrips': listAreaTrips,
    'listGroupId': listGroupId,
    'listOpenAll': listOpenAll,
    'listOpenAllAfterMin': listOpenAllAfterMin,
    'noticeOn': noticeOn,
    'noticeMaxDrivers': noticeMaxDrivers,
    'homePopup': homePopup,
    'noDriverAlertMin': noDriverAlertMin,
    'riderReminderMin': riderReminderMin,
    'freeChangeBeforeMin': freeChangeBeforeMin,
    'maxTripKm': maxTripKm,
    'dispatchBeforeMin': dispatchBeforeMin,
    'listHomeKm': listHomeKm,
    'listAtTimeKm': listAtTimeKm,
    'listAtTimeMin': listAtTimeMin,
    'changeAnswerMin': changeAnswerMin,
    'arriveEarlyMin': arriveEarlyMin,
    'raiseFare': raiseFare,
    'raiseMax': raiseMax,
    'takeBackLateMin': takeBackLateMin,
    'takeBackKeepIfDriveMin': takeBackKeepIfDriveMin,
    'takeBackUntilMinBeforePickup': takeBackUntilMinBeforePickup,
  };
}
