/// The time scheduled rides are measured against: reminders, "leave now",
/// late cancels, the near-pickup steps.
///
/// The demo has no server time and its rides are booked for fixed times
/// (the main one at 07:40 today). So it runs its own day: the first reading
/// is [startTime] on today's date, and from there it runs [speed] times
/// faster than real time. A backend build reads the server time instead.
class ScheduledClock {
  ScheduledClock({required this.startTime, this.speed = 1});

  /// The demo day: 07:00 at the first reading, 30 times faster, so the
  /// 07:40 reservation is 20 minutes before pickup (its Exclusive step)
  /// after 40 seconds.
  static ScheduledClock instance = ScheduledClock(
    startTime: const Duration(hours: 7),
    speed: 30,
  );

  /// Where real time comes from. Tests point it at their fake clock.
  static DateTime Function() realNow = DateTime.now;

  /// Time of day at the first reading.
  final Duration startTime;

  /// How much faster than real time the clock runs.
  final int speed;

  DateTime? _realStart;
  DateTime? _start;

  DateTime now() {
    final real = realNow();
    final realStart = _realStart ??= real;
    final start = _start ??=
        DateTime(real.year, real.month, real.day).add(startTime);
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
