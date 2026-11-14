import 'package:flutter/foundation.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// Time the driver has worked, against the admin rest rule (Q25): after
/// 12 h online the driver rests 6 h before going online again.
///
/// BQ-V21 (decisions/driving-time-limits.md:2-4): the SERVER counts only
/// driving (to the pickup + on trip) and owns the numbers; once it sent
/// `Driver.drivingTime` the limit, the offline reset and "Rest until" shown
/// are its own (see [loadServer]); the 12 h / 6 h here are only the fallback.
///
/// It runs only while the driver drives to the pickup or is on the trip
/// ([syncDriving], fed by the ride stage), never while he is just online or
/// waits at the pickup (owner: "It's 12 hours driving … not online time");
/// going offline starts the rest. A full rest starts the count from zero
/// again. Every server read ([loadServer]) corrects it.
/// SV: a [ChangeNotifier] that tells listeners (Home's limit timers) when
/// the count starts or stops, since a ride stage can start it.
class DrivingTimeClock extends ChangeNotifier {
  DrivingTimeClock({DateTime Function()? now, DrivingRestRule? rule})
    : _now = now ?? (() => ScheduledClock.realNow()),
      _rule = rule;

  static final DrivingTimeClock instance = DrivingTimeClock();

  final DateTime Function() _now;
  final DrivingRestRule? _rule;

  /// The country's rule; [DriverAccountRules.current] unless given.
  DrivingRestRule get rule => _rule ?? DriverAccountRules.current.rest;
  Duration get workLimit => _serverLimit ?? rule.work;

  /// Contract v0.18.13 `Driver.drivingTime.maxMinutes` once the server sent
  /// it (0 = no limit is kept as the country rule).
  Duration? _serverLimit;

  /// BQ-V21 (decisions/driving-time-limits.md:4, owner "6 hours offline so
  /// reset all time"): `Driver.drivingTime.resetAfterOfflineHours`, the
  /// admin's per-country number, once the server sent it.
  Duration? _serverRest;

  /// BQ-V21: `Driver.drivingTime.canDriveAt`, the server's "Rest until"
  /// (only when the server said the limit is reached).
  DateTime? _serverCanDriveAt;

  Duration get restLength => _serverRest ?? rule.rest;

  Duration _banked = Duration.zero;
  DateTime? _since;
  DateTime? _offSince;

  /// BQ-V21: `Driver.drivingTime.reached` of the last server read (null =
  /// no server count yet, or the driver went online since).
  bool? _serverReached;

  bool get running => _since != null;

  /// SV: the driver's availability ([sync]) and whether a ride is in a
  /// driving stage ([syncDriving]); the clock counts only when both hold.
  bool _online = false;
  bool _driving = false;

  /// A full rest clears the count.
  void _settleRest(DateTime now) {
    final off = _offSince;
    if (off != null && now.difference(off) >= restLength) {
      _banked = Duration.zero;
    }
  }

  void start() {
    if (_since != null) {
      return;
    }
    final now = _now();
    _settleRest(now);
    _offSince = null;
    _since = now;
    _serverReached = null;
    _serverCanDriveAt = null;
    notifyListeners();
  }

  /// Stops the count and starts the offline rest.
  void stop() {
    final now = _now();
    _pause(now);
    _offSince ??= now;
  }

  /// Stops the count without starting a rest (online, not driving).
  void _pause(DateTime now) {
    final since = _since;
    if (since == null) {
      return;
    }
    _banked += now.difference(since);
    _since = null;
    notifyListeners();
  }

  /// Follow the driver's availability. Online alone does not count (SV):
  /// it ends an offline rest, and the count runs only while [syncDriving]
  /// says a ride is in a driving stage.
  void sync({required bool online}) {
    _online = online;
    if (!online) {
      stop();
      return;
    }
    final now = _now();
    _settleRest(now);
    _offSince = null;
    if (_driving) {
      start();
    }
  }

  /// SV: true while the driver drives to the pickup or is on the trip
  /// (ActiveRideController's stage), false while he waits at the pickup or
  /// has no ride.
  void syncDriving(bool driving) {
    _driving = driving;
    if (driving && _online) {
      start();
    } else {
      _pause(_now());
    }
  }

  /// Sets the count, e.g. from a backend: [worked] since the last full
  /// rest, offline since [offlineSince] (now when null).
  void load({required Duration worked, DateTime? offlineSince}) {
    _banked = worked;
    _since = null;
    _offSince = offlineSince ?? _now();
  }

  /// Contract v0.18.13 `Driver.drivingTime` (`GET /driver/profile`): the
  /// SERVER's count wins, so a reload never starts again from zero (live
  /// sweep 2026-11-02 M-10). A running count keeps running from now.
  ///
  /// BQ-V21: the row and the sheet show the SERVER's numbers: its offline
  /// reset ([resetAfterOfflineHours]) and, at the limit, its [canDriveAt]
  /// for "Rest until"; not reached = no rest line, whatever the phone thinks.
  void loadServer({
    required int drivenMinutes,
    int? maxMinutes,
    bool? reached,
    DateTime? canDriveAt,
    double? resetAfterOfflineHours,
  }) {
    _banked = Duration(minutes: drivenMinutes < 0 ? 0 : drivenMinutes);
    if (maxMinutes != null && maxMinutes > 0) {
      _serverLimit = Duration(minutes: maxMinutes);
    }
    if (resetAfterOfflineHours != null && resetAfterOfflineHours > 0) {
      _serverRest = Duration(minutes: (resetAfterOfflineHours * 60).round());
    }
    _serverReached = reached;
    _serverCanDriveAt = reached == true ? canDriveAt?.toLocal() : null;
    if (_since != null) {
      _since = _now();
    }
    _offSince = null;
  }

  /// Back to zero and offline.
  void reset() {
    _online = false;
    _driving = false;
    _serverLimit = null;
    _serverRest = null;
    _serverReached = null;
    _serverCanDriveAt = null;
    _banked = Duration.zero;
    _since = null;
    _offSince = null;
  }

  /// Time worked since the last full rest.
  Duration get worked {
    final now = _now();
    final since = _since;
    if (since != null) {
      return _banked + now.difference(since);
    }
    _settleRest(now);
    return _banked;
  }

  /// Time left before the rest.
  Duration get left {
    final left = workLimit - worked;
    return left.isNegative ? Duration.zero : left;
  }

  /// When the driver may go online again, or null while they may. Online
  /// at the limit (finishing a trip), the rest starts when they stop.
  DateTime? get restUntil {
    final rule = this.rule;
    final now = _now();
    // BQ-V21: offline, the server's answer wins (its count and its time).
    final server = _serverCanDriveAt;
    if (_since == null && _serverReached != null) {
      if (server == null) {
        return null;
      }
      return now.isBefore(server) ? server : null;
    }
    if (!rule.on || !rule.blockAtLimit || worked < workLimit) {
      return null;
    }
    final until = (_since == null ? _offSince ?? now : now).add(restLength);
    return now.isBefore(until) ? until : null;
  }

  /// 0..1 of the work limit already used.
  double get usedFraction {
    final limit = workLimit.inSeconds;
    if (limit <= 0) {
      return 1;
    }
    return (worked.inSeconds / limit).clamp(0.0, 1.0);
  }

  /// "5 h 47 min"
  static String hoursMinutes(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$h h $m min';
  }

  /// "4:12:36"
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
