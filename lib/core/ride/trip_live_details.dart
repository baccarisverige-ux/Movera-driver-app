import 'dart:math' as math;

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart'
    show validCoordinate;
import 'package:movera/core/ride/waiting_rules.dart';

/// Contract v0.18.7 (`contract.json#pickupWaiting`, driver group 5): what
/// the trip screen reads from a `TripProjection` on top of its status.
///
/// - `rider` (Q1): the rider's first name and, while the zone shows it,
///   their rating; never a surname or phone.
/// - `terms`: the rules this trip is charged by (waiting, no-show, cancel,
///   pickup move), from the booking snapshot: the only waiting numbers the
///   screen shows (owner rule 16, nothing hard-coded).
/// - `eta` (Q4): the server's road-route ETA, refreshed every 30 s.
/// - `waiting.noShowFee` / `noShowDriverShare` (Q6) at arrive, and
///   `chargedSecondsNow` / `chargedSoFar` (Q5) on every read while arrived.
/// - `cancellation.fee` / `feeKind` / `driverShare` after a rider cancel.
/// - `pickup`: where the rider waits now (status item 4, `pickup_moved`).
class TripLiveDetails {
  const TripLiveDetails({
    this.status,
    this.version,
    this.rider,
    this.terms,
    this.eta,
    this.waiting,
    this.cancellation,
    this.pickup,
  });

  /// Reads the fields it knows; anything missing or broken is simply
  /// absent (an older server, a partial projection).
  factory TripLiveDetails.fromProjection(Map<String, dynamic> json) {
    final version = json['version'];
    final status = json['status'];
    return TripLiveDetails(
      status: status is String ? status : null,
      version: version is num ? version.toInt() : null,
      rider: TripRiderSummary.tryParse(json['rider']),
      terms: TripTerms.tryParse(json['terms']),
      eta: TripEta.tryParse(json['eta']),
      waiting: TripWaitingNow.tryParse(json['waiting']),
      cancellation: TripCancellationInfo.tryParse(json['cancellation']),
      pickup: TripPlace.tryParse(json['pickup']),
    );
  }

  final String? status;
  final int? version;
  final TripRiderSummary? rider;
  final TripTerms? terms;
  final TripEta? eta;
  final TripWaitingNow? waiting;
  final TripCancellationInfo? cancellation;
  final TripPlace? pickup;

  bool get isEmpty =>
      rider == null &&
      terms == null &&
      eta == null &&
      waiting == null &&
      cancellation == null &&
      pickup == null;

  /// This on top of [older]: every field the new projection carries wins;
  /// a field it leaves out keeps the older value (an ETA stays until the
  /// next tick, the terms never leave).
  TripLiveDetails merge(TripLiveDetails? older) => older == null
      ? this
      : TripLiveDetails(
          status: status ?? older.status,
          version: version ?? older.version,
          rider: rider ?? older.rider,
          terms: terms ?? older.terms,
          eta: eta ?? older.eta,
          waiting: waiting ?? older.waiting,
          cancellation: cancellation ?? older.cancellation,
          pickup: pickup ?? older.pickup,
        );

  TripLiveDetails withEta(TripEta? eta) => TripLiveDetails(
    status: status,
    version: version,
    rider: rider,
    terms: terms,
    eta: eta ?? this.eta,
    waiting: waiting,
    cancellation: cancellation,
    pickup: pickup,
  );
}

/// `RiderSummary { firstName, rating? }` (Q1).
class TripRiderSummary {
  const TripRiderSummary({required this.firstName, this.rating});

  static TripRiderSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    final name = json['firstName'];
    if (name is! String || name.trim().isEmpty) return null;
    final rating = json['rating'];
    return TripRiderSummary(
      firstName: name.trim(),
      rating: rating is num && rating.isFinite && rating >= 0 && rating <= 5
          ? rating.toDouble()
          : null,
    );
  }

  final String firstName;

  /// The rider's average; null when the zone hides it or they have none.
  final double? rating;

  /// "4.9": one decimal, as the G4 offer card shows it; null without one.
  String? get shownRating => rating?.toStringAsFixed(1);
}

/// `TripTerms` (contract v0.18.7): the rules the trip is charged by.
class TripTerms {
  const TripTerms({
    required this.waiting,
    required this.currency,
    this.cancelFreeMinutes,
    this.cancelDriverSharePercent = 100,
    this.cancelAfterArrivedIsNoShow = true,
    this.maxPickupMoveMeters = 200,
  });

  static TripTerms? tryParse(Object? json) {
    if (json is! Map) return null;
    final currency = json['currency'];
    if (currency is! String || currency.isEmpty) return null;
    final perMin = _money(json['waitPerMin'], currency);
    final noShowFee = _money(json['noShowFee'], currency);
    final free = _minutes(json['freeWaitMin']);
    final noShowAfter = _minutes(json['noShowAfterMin']);
    if (perMin == null || noShowFee == null || free == null) return null;
    final cancelRule = json['cancelRule'];
    final freeCancel = cancelRule is Map ? cancelRule['freeMin'] : null;
    final move = json['maxPickupMoveMeters'];
    return TripTerms(
      currency: currency,
      waiting: WaitingTerms(
        freeMinutes: free,
        perMinute: perMin,
        // Never a no-show before the free wait is over (owner Q41).
        noShowAfterMinutes: math.max(free, noShowAfter ?? free),
        noShowFee: noShowFee,
        driverShareWaitPercent: 100,
        driverShareNoShowPercent: _percent(json['noShowDriverSharePct']) ?? 100,
      ),
      cancelFreeMinutes: freeCancel is num && freeCancel >= 0
          ? freeCancel.toDouble()
          : null,
      cancelDriverSharePercent: _percent(json['cancelDriverSharePct']) ?? 100,
      cancelAfterArrivedIsNoShow: json['cancelAfterArrivedIsNoShow'] != false,
      maxPickupMoveMeters: move is num && move >= 0 ? move.toInt() : 200,
    );
  }

  /// Free wait, price per minute, no-show time and fee and the driver's
  /// share, for the waiting sheet and the island.
  final WaitingTerms waiting;
  final String currency;

  /// `cancelRule.freeMin`: minutes after accept in which the rider always
  /// cancels free; null when the trip has no cancel rule.
  final double? cancelFreeMinutes;
  final int cancelDriverSharePercent;

  /// Q2: a rider cancel after the driver arrived is charged as a no-show.
  final bool cancelAfterArrivedIsNoShow;

  /// Status item 4: how far the rider may move the pickup (default 200 m).
  final int maxPickupMoveMeters;
}

/// `TripEta` (Q4): the server's road-route ETA to the pickup or drop-off.
class TripEta {
  const TripEta({
    required this.etaSeconds,
    required this.distanceMeters,
    required this.target,
    this.at,
    this.source = 'estimate',
  });

  static TripEta? tryParse(Object? json) {
    if (json is! Map) return null;
    final seconds = json['etaSeconds'];
    final meters = json['distanceMeters'];
    final target = json['target'];
    if (seconds is! num || meters is! num || target is! String) return null;
    if (!seconds.isFinite || !meters.isFinite || seconds < 0 || meters < 0) {
      return null;
    }
    if (target != 'pickup' && target != 'dropoff') return null;
    final at = json['at'];
    final source = json['source'];
    return TripEta(
      etaSeconds: seconds.toInt(),
      distanceMeters: meters.toInt(),
      target: target,
      at: at is String ? DateTime.tryParse(at)?.toUtc() : null,
      source: source is String ? source : 'estimate',
    );
  }

  final int etaSeconds;
  final int distanceMeters;

  /// `pickup` until boarding, `dropoff` on board.
  final String target;
  final DateTime? at;

  /// `osrm` (a road route), `estimate` (straight line) or `stale`.
  final String source;

  bool get toPickup => target == 'pickup';

  /// `source: stale` (contract 0.18.7 final): the server kept its last ETA
  /// because the driver sent no position for 2 min.
  bool get isStale => source == 'stale';

  /// Whole minutes rounded up, at least 1.
  int get minutes => math.max(1, (etaSeconds / 60).ceil());

  /// "4 min": what the island's strip reads.
  String get minutesLabel => '$minutes min';

  /// `pickupWaiting.eta.distanceDisplay`: ≥ 1 km → one decimal km;
  /// 100 m steps under 1 km; 10 m steps under 100 m; rounded down, never
  /// under 10 m. Returns the unit and the value (`3.4` km / `800` m).
  static ({String unit, num value}) distanceDisplay(int meters) {
    final m = math.max(0, meters);
    if (m >= 1000) {
      return (unit: 'km', value: (m ~/ 100) / 10);
    }
    if (m >= 100) {
      return (unit: 'm', value: (m ~/ 100) * 100);
    }
    return (unit: 'm', value: math.max(10, (m ~/ 10) * 10));
  }

  /// The distance as the driver reads it ("3,4 km" in Swedish, "800 m").
  String get distanceLabel => formatDistance(distanceMeters);

  static String formatDistance(int meters) {
    final shown = distanceDisplay(meters);
    if (shown.unit == 'km') {
      final text = (shown.value as double).toStringAsFixed(1);
      return tr.distanceKm(text.replaceAll('.', tr.navDecimalMark));
    }
    return tr.distanceM(shown.value.toInt());
  }

  /// `pickupWaiting.eta.texts.arrivesIn` / `toDropoff`.
  String get line => toPickup
      ? tr.etaArrivesIn(minutes, distanceLabel)
      : tr.etaToDropoff(minutes, distanceLabel);
}

/// `Waiting` fields of v0.18.7: the no-show fee and the driver's share of
/// it (Q6, set at arrive), the paid waiting so far (Q5, read time).
class TripWaitingNow {
  const TripWaitingNow({
    this.arrivedAt,
    this.freeUntil,
    this.noShowAt,
    this.noShowFee,
    this.noShowDriverShare,
    this.chargedSecondsNow,
    this.chargedSoFar,
  });

  static TripWaitingNow? tryParse(Object? json) {
    if (json is! Map) return null;
    final arrived = json['arrivedAt'];
    final seconds = json['chargedSecondsNow'];
    DateTime? at(String key) => json[key] is String
        ? DateTime.tryParse(json[key] as String)?.toUtc()
        : null;
    return TripWaitingNow(
      arrivedAt: arrived is String ? DateTime.tryParse(arrived)?.toUtc() : null,
      freeUntil: at('freeUntil'),
      noShowAt: at('noShowAt'),
      noShowFee: _money(json['noShowFee']),
      noShowDriverShare: _money(json['noShowDriverShare']),
      chargedSecondsNow: seconds is num && seconds >= 0
          ? seconds.toInt()
          : null,
      chargedSoFar: _money(json['chargedSoFar']),
    );
  }

  final DateTime? arrivedAt;

  /// The server's moments: paid waiting starts at [freeUntil]; the driver
  /// may mark a no-show from [noShowAt] (a reservation: its booked time).
  final DateTime? freeUntil;
  final DateTime? noShowAt;

  /// Seconds after arrival, for the waiting clocks; null without both.
  int? secondsAfterArrival(DateTime? moment) {
    final arrived = arrivedAt;
    if (arrived == null || moment == null) return null;
    return math.max(0, moment.difference(arrived).inSeconds);
  }

  final Money? noShowFee;

  /// What the driver gets for a no-show ("Mark as no-show? You get 52 kr").
  final Money? noShowDriverShare;
  final int? chargedSecondsNow;

  /// The rider's waiting cost so far while the driver waits.
  final Money? chargedSoFar;
}

/// `Cancellation` of v0.18.7: the fee, which rule set it and the driver's
/// part (credited at once).
class TripCancellationInfo {
  const TripCancellationInfo({
    this.actor,
    this.fee,
    this.feeKind,
    this.driverShare,
  });

  static TripCancellationInfo? tryParse(Object? json) {
    if (json is! Map) return null;
    final actor = json['actor'];
    final kind = json['feeKind'];
    return TripCancellationInfo(
      actor: actor is String ? actor : null,
      fee: _money(json['fee']),
      feeKind: kind == 'cancel' || kind == 'no_show' ? kind as String : null,
      driverShare: _money(json['driverShare']),
    );
  }

  final String? actor;

  /// Null: no fee, or not decided yet.
  final Money? fee;

  /// `cancel` or `no_show` (absent when [fee] is null).
  final String? feeKind;
  final Money? driverShare;

  bool get isNoShowFee => feeKind == 'no_show';

  /// What the island says the driver earns: the driver's share when the
  /// server sent it; a zero in the fee's currency when the fee is decided
  /// and nothing is owed; null while undecided.
  Money? get driverEarns {
    if (driverShare != null) return driverShare;
    final fee = this.fee;
    if (fee == null) return null;
    return fee.isZero ? fee : null;
  }
}

/// A `Place` with coordinates (`{lat, lng, address?}`).
class TripPlace {
  const TripPlace({required this.point, this.address});

  static TripPlace? tryParse(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (!validCoordinate(lat, latitude: true) ||
        !validCoordinate(lng, latitude: false)) {
      return null;
    }
    final address = json['address'];
    return TripPlace(
      point: GeoPoint((lat as num).toDouble(), (lng as num).toDouble()),
      address: address is String && address.trim().isNotEmpty
          ? address.trim()
          : null,
    );
  }

  final GeoPoint point;
  final String? address;
}

Money? _money(Object? json, [String? currency]) {
  if (json is! Map) return null;
  try {
    final money = Money.fromJson(Map<String, dynamic>.from(json));
    if (currency != null && money.currency != currency) return null;
    return money.minorUnits >= 0 ? money : null;
  } on Object {
    return null;
  }
}

int? _minutes(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.round() : null;

int? _percent(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 100
    ? value.round()
    : null;
