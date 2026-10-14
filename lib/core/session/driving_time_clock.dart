/// Time the driver has been online today, against a daily limit.
///
/// It runs while the driver is online (on a trip too) and stops when they
/// go offline. A new day starts from zero. This demo keeps it in memory; a
/// backend would own the real count.
class DrivingTimeClock {
  DrivingTimeClock({
    DateTime Function()? now,
    this.dailyLimit = const Duration(hours: 10),
  }) : _now = now ?? DateTime.now {
    _day = _dayOf(_now());
  }

  static final DrivingTimeClock instance = DrivingTimeClock();

  final DateTime Function() _now;
  final Duration dailyLimit;
  late DateTime _day;
  Duration _banked = Duration.zero;
  DateTime? _since;

  bool get running => _since != null;

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  void _rollDay(DateTime now) {
    final today = _dayOf(now);
    if (today == _day) { return; }
    _day = today;
    _banked = Duration.zero;
    if (_since != null) { _since = today; }
  }

  void start() {
    final now = _now();
    _rollDay(now);
    _since ??= now;
  }

  void stop() {
    final now = _now();
    _rollDay(now);
    final since = _since;
    if (since == null) { return; }
    _banked += now.difference(since);
    _since = null;
  }

  /// Follow the driver's availability.
  void sync({required bool online}) => online ? start() : stop();

  Duration get drivenToday {
    final now = _now();
    _rollDay(now);
    final since = _since;
    return since == null ? _banked : _banked + now.difference(since);
  }

  Duration get leftToday {
    final left = dailyLimit - drivenToday;
    return left.isNegative ? Duration.zero : left;
  }

  /// 0..1 of the daily limit already used.
  double get usedFraction {
    final limit = dailyLimit.inSeconds;
    if (limit <= 0) { return 1; }
    return (drivenToday.inSeconds / limit).clamp(0.0, 1.0);
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
