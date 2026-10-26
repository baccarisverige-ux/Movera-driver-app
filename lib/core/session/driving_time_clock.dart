import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// Time the driver has worked, against the admin rest rule (Q25): after
/// 12 h online the driver rests 6 h before going online again.
///
/// It runs while the driver is online (on a trip too) and stops when they
/// go offline. A full rest starts the count from zero again. This demo
/// keeps it in memory; a backend would own the real count.
class DrivingTimeClock {
  DrivingTimeClock({DateTime Function()? now, DrivingRestRule? rule})
    : _now = now ?? (() => ScheduledClock.realNow()),
      _rule = rule;

  static final DrivingTimeClock instance = DrivingTimeClock();

  final DateTime Function() _now;
  final DrivingRestRule? _rule;

  /// The country's rule; [DriverAccountRules.current] unless given.
  DrivingRestRule get rule => _rule ?? DriverAccountRules.current.rest;
  Duration get workLimit => rule.work;
  Duration get restLength => rule.rest;

  Duration _banked = Duration.zero;
  DateTime? _since;
  DateTime? _offSince;

  bool get running => _since != null;

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
  }

  void stop() {
    final since = _since;
    if (since == null) {
      return;
    }
    final now = _now();
    _banked += now.difference(since);
    _since = null;
    _offSince = now;
  }

  /// Follow the driver's availability.
  void sync({required bool online}) => online ? start() : stop();

  /// Sets the count, e.g. from a backend: [worked] since the last full
  /// rest, offline since [offlineSince] (now when null).
  void load({required Duration worked, DateTime? offlineSince}) {
    _banked = worked;
    _since = null;
    _offSince = offlineSince ?? _now();
  }

  /// Back to zero and offline.
  void reset() {
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
    if (!rule.on || !rule.blockAtLimit || worked < workLimit) {
      return null;
    }
    final now = _now();
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
