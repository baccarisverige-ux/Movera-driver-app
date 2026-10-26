import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// When a reservation is, in a few words, seen from now: the reservation
/// sheet's bottom button and the island both say it.
///
/// - under 3 hours away: "In 2 h" (whole hours; under 1 h "In 45 min");
/// - later today: "Today 13:45";
/// - tomorrow: "Tomorrow 11:55";
/// - within the next 6 days: "Saturday 14:33";
/// - further: "19-10 11:44" (day-month).
class ReservationWhen {
  const ReservationWhen._(this.label, this.time, {required this.soon});

  /// "In 2 h", "Today 13:45", "Saturday 14:33"…
  final String label;

  /// The pickup clock time, "15:45".
  final String time;

  /// Under 3 hours away: [label] has no clock time.
  final bool soon;

  /// The island adds the time when it is soon: "In 2 h · 15:45".
  String get island => soon ? '$label · $time' : label;

  static const Duration soonWithin = Duration(hours: 3);

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// [pickup] seen from [now].
  static ReservationWhen of(DateTime pickup, DateTime now) {
    final time = '${_two(pickup.hour)}:${_two(pickup.minute)}';
    final left = pickup.difference(now);
    if (left < soonWithin) {
      // Whole minutes, rounded up; 0 or less is now.
      final minutes = left.isNegative ? 0 : (left.inSeconds + 59) ~/ 60;
      final label = minutes < 60
          ? tr.whenInMinutes(minutes)
          : tr.whenInHours((minutes / 60).round());
      return ReservationWhen._(label, time, soon: true);
    }
    // Rounded, as a day across a clock change is 23 or 25 hours.
    final dayGap =
        (DateTime.utc(pickup.year, pickup.month, pickup.day)
                    .difference(DateTime.utc(now.year, now.month, now.day))
                    .inHours /
                24)
            .round();
    final String label;
    if (dayGap <= 0) {
      label = tr.whenToday(time);
    } else if (dayGap == 1) {
      label = tr.whenTomorrow(time);
    } else if (dayGap <= 6) {
      label = '${DriverDates.weekday(pickup)} $time';
    } else {
      label = '${_two(pickup.day)}-${_two(pickup.month)} $time';
    }
    return ReservationWhen._(label, time, soon: false);
  }

  /// [request]'s pickup seen from [now]; when its day cannot be read, its
  /// own day and time ("Mon 20 Oct 06:35").
  static ReservationWhen ofRequest(
    ReservationRequestPreview request,
    DateTime now,
  ) {
    final at = pickupOf(request, now);
    if (at != null) return of(at, now);
    final day = request.pickupDay.trim();
    final label = day.isEmpty
        ? request.pickupTime
        : '${dayWord(day)} ${request.pickupTime}';
    return ReservationWhen._(label, request.pickupTime, soon: false);
  }

  /// A reservation's day as the driver reads it: "Today" and "Tomorrow"
  /// in the app's language, any other day as written.
  static String dayWord(String day) => switch (day.trim().toLowerCase()) {
    'today' => tr.today,
    'tomorrow' => tr.tomorrow,
    _ => day,
  };

  static const List<String> _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// When [request] is picked up: "Today" / "Tomorrow", a date such as
  /// "Mon 20 Oct", "20 Oct" or "2026-10-20", or a weekday ("Saturday", the
  /// next one); null when neither its day nor its time can be read.
  static DateTime? pickupOf(ReservationRequestPreview request, DateTime now) {
    final known = request.pickupAt(now);
    if (known != null) return known;
    final minute = request.minuteOfDay;
    if (minute == null) return null;
    final day = request.pickupDay.trim().toLowerCase();
    DateTime? date;
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(day);
    final named = RegExp(r'(\d{1,2})\s+([a-z]{3})').firstMatch(day);
    if (iso != null) {
      date = DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    } else if (named != null) {
      final month = _months.indexOf(named.group(2)!) + 1;
      if (month > 0) {
        final dayOfMonth = int.parse(named.group(1)!);
        date = DateTime(now.year, month, dayOfMonth);
        // "5 Jan" seen in December is next year.
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year + 1, month, dayOfMonth);
        }
      }
    } else {
      for (var i = 0; i < _weekdays.length; i++) {
        final name = _weekdays[i].toLowerCase();
        if (day == name || day == name.substring(0, 3)) {
          final ahead = (i + 1 - now.weekday) % 7;
          date = DateTime(now.year, now.month, now.day + ahead);
          break;
        }
      }
    }
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day, 0, minute);
  }
}
