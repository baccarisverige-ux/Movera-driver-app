part of 'scheduled_rides.dart';

// Notes on the Scheduled rides screen: paused or off (Q11), clashing rides
// left out (Q9), reminders and backup (Q10), and the cancel rules (Q11).

/// "22 Oct" ("22 oct.", "22 okt.").
String _dayMonth(DateTime time) => DriverDates.dayMonth(time);

/// "07:15", "tomorrow 07:15" or "22 Oct 07:15", seen from [now].
String _timeFrom(DateTime time, DateTime now) {
  final days = DateTime(time.year, time.month, time.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  final clock = clockLabel(time);
  return days == 0
      ? clock
      : days == 1
      ? tr.tomorrowAtClock(clock)
      : '${_dayMonth(time)} $clock';
}

/// "Free cancel until 06:40." or "Late cancel: under 1 h to pickup."
String _freeCancelLine(ReservationRequestPreview? ride) {
  final until = ScheduledRideStore.freeCancelUntil(ride);
  final hours = ScheduledRideRules.current.driverLateCancelHours;
  if (until == null) {
    return tr.schedFreeCancelHoursBefore('$hours');
  }
  if (ScheduledRideStore.isLateCancel(ride)) {
    return tr.schedLateCancelUnder('$hours');
  }
  return tr.schedFreeCancelUntil(_timeFrom(until, ScheduledRideStore._now));
}

/// A short note with a Solar icon, in the card style of the list.
class _ScheduledNote extends StatelessWidget {
  const _ScheduledNote({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tone = const Color(0xFF425058),
    this.background = Colors.white,
  });

  final String icon;
  final String title;
  final String body;
  final Color tone;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7E9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _solar(icon, tone, 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF5F6B72),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scheduled rides are paused by the late-cancel rule, or admin turned
/// them off for this driver: no requests are listed.
class _BlockNotice extends StatelessWidget {
  const _BlockNotice({required this.block});

  final ScheduledRidesBlock block;

  @override
  Widget build(BuildContext context) {
    final until = block.until;
    final rules = ScheduledRideRules.current;
    final title = block.byAdmin
        ? until == null
              ? tr.schedRidesAreOff
              : tr.schedRidesOffUntil(_dayMonth(until))
        : tr.schedRidesPausedUntil(until == null ? '' : _dayMonth(until));
    final body = block.byAdmin
        ? tr.schedTurnedOffByMovera
        : tr.schedLateCancelsInDays('${rules.lateCancelLimit}', '${rules.lateCancelPeriodDays}');
    return _ScheduledNote(
      key: const ValueKey<String>('scheduled-block-notice'),
      icon: block.byAdmin
          ? AppAssets.solarForbiddenCircle
          : AppAssets.solarPauseCircle,
      title: title,
      body: body,
      tone: const Color(0xFF9A4B1F),
      background: const Color(0xFFFFF8F1),
    );
  }
}

/// In the cancel sheet: until when it is free and that a late cancel
/// counts. Drivers never pay.
class _CancelRulesBox extends StatelessWidget {
  const _CancelRulesBox({this.ride});

  final ReservationRequestPreview? ride;

  @override
  Widget build(BuildContext context) {
    final late = ScheduledRideStore.isLateCancel(ride);
    final hours = ScheduledRideRules.current.driverLateCancelHours;
    return Container(
      key: const ValueKey<String>('scheduled-cancel-rules'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: late ? const Color(0xFFFFF8F1) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: late ? const Color(0xFFF1DCC6) : const Color(0xFFE3E7E9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _solar(
            AppAssets.solarClockCircle,
            late ? const Color(0xFF9A4B1F) : const Color(0xFF19865C),
            19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _freeCancelLine(ride).replaceAll(RegExp(r'\.$'), ''),
                  style: const TextStyle(
                    color: Color(0xFF252E3A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  late
                      ? tr.schedNeverPayLateCounts
                      : tr.schedNeverPayUnderHours('$hours'),
                  style: const TextStyle(
                    color: Color(0xFF5F6B72),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// In the confirmation: this cancel is late, and whether it pauses
/// Scheduled rides.
class _LateCancelWarning extends StatelessWidget {
  const _LateCancelWarning({this.ride});

  final ReservationRequestPreview? ride;

  @override
  Widget build(BuildContext context) {
    final rules = ScheduledRideRules.current;
    final count = ScheduledRideStore.lateCancelsInPeriod() + 1;
    final pauses = count >= rules.lateCancelLimit &&
        ScheduledRideStore.pausedUntil(ScheduledRideStore._now) == null;
    final until = ScheduledRideStore._now.add(Duration(days: rules.pauseDays));
    return Text(
      pauses
          ? tr.schedLateCancelPauses('$count', '${rules.lateCancelPeriodDays}', _dayMonth(until))
          : tr.schedLateCancelCounts,
      key: const ValueKey<String>('scheduled-late-cancel'),
      style: const TextStyle(
        color: Color(0xFF9A4B1F),
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// "Doesn't count" next to a cancel reason that does not hurt the cancel
/// rate or the late-cancel rule (Q21).
class _NotCountedTag extends StatelessWidget {
  const _NotCountedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        tr.doesnTCount,
        style: TextStyle(
          color: Color(0xFF19865C),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
