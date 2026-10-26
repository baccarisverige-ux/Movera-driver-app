/// The time scheduled rides are measured against: reminders, "leave now",
/// late cancels, the near-pickup steps.
///
/// The demo has no server time, so it reads the phone's real clock and
/// books its reservations relative to now (see `DemoReservations`). A
/// backend build reads the server time instead.
///
/// A fast day ([ScheduledClock.fastDay]: 07:00 at the first reading, 30
/// times faster) exists only for tests and behind the explicit demo switch
/// `--dart-define=MOVERA_DEMO_FAST_CLOCK=true`.
class ScheduledClock {
  ScheduledClock({this.startTime, this.speed = 1});

  /// 07:00 at the first reading and 30 times faster than real time.
  factory ScheduledClock.fastDay() =>
      ScheduledClock(startTime: const Duration(hours: 7), speed: 30);

  /// The explicit demo/test switch for the fast day.
  static const bool fastDemo = bool.fromEnvironment('MOVERA_DEMO_FAST_CLOCK');

  /// The real clock; the fast day only behind [fastDemo]. Tests set their
  /// own clock here.
  static ScheduledClock instance = fastDemo
      ? ScheduledClock.fastDay()
      : ScheduledClock();

  /// Where real time comes from. Tests point it at their fake clock.
  static DateTime Function() realNow = DateTime.now;

  /// Time of day at the first reading; null follows the real time.
  final Duration? startTime;

  /// How much faster than real time the clock runs.
  final int speed;

  DateTime? _realStart;
  DateTime? _start;

  DateTime now() {
    final real = realNow();
    final startTime = this.startTime;
    if (startTime == null && speed == 1) {
      return real;
    }
    final realStart = _realStart ??= real;
    final start = _start ??= startTime == null
        ? realStart
        : DateTime(real.year, real.month, real.day).add(startTime);
    return start.add(real.difference(realStart) * speed);
  }

  /// Real time until the clock reads [at]; zero once it has.
  Duration realUntil(DateTime at) {
    final left = at.difference(now());
    if (left <= Duration.zero) {
      return Duration.zero;
    }
    return Duration(microseconds: (left.inMicroseconds / speed).ceil());
  }

  /// Starts the day again at the next reading.
  void reset() {
    _realStart = null;
    _start = null;
  }
}

/// "07:05" for [time].
String clockLabel(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}
