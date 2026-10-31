import 'package:flutter/material.dart';
import 'package:movera/core/events/driver_events.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/movera_event_marker.dart';

/// G4-F6 (owner "when clic see all details"): what a tap on an event's
/// icon on the Home map shows: the title, whether it is on now or when it
/// starts, the time on the phone's clock, the place, the description and
/// the pickup note. The texts come from the server in the driver's
/// language; the labels are the app's (sv / fr / en, contract v0.18.6
/// `dispatchTools.events.texts`).
Future<void> showEventDetails(
  BuildContext context,
  DriverEvent event, {
  DateTime? now,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => EventDetailsSheet(event: event, now: now),
);

class EventDetailsSheet extends StatelessWidget {
  const EventDetailsSheet({super.key, required this.event, this.now});

  final DriverEvent event;

  /// "Now" for the status line; the phone's clock by default.
  final DateTime? now;

  static const Color _ink = Color(0xFF111315);
  static const Color _muted = Color(0xFF66727A);

  /// "18:00" on the phone's clock.
  static String clock(DateTime time) => DriverDates.time(time.toLocal());

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "18:00" today, else "Fri 31 Oct 18:00" in the app's language.
  static String startLabel(DateTime start, DateTime now) {
    final local = start.toLocal();
    if (_sameDay(local, now.toLocal())) return clock(local);
    return '${DriverDates.weekdayDayMonth(local)} ${clock(local)}';
  }

  /// "Fri 31 Oct · 18:00–22:30" (both days when it ends on another day).
  static String timeRange(DriverEvent event) {
    final start = event.startsAt.toLocal();
    final end = event.endsAt.toLocal();
    final from = '${DriverDates.weekdayDayMonth(start)} · ${clock(start)}';
    return _sameDay(start, end)
        ? '$from–${clock(end)}'
        : '$from – ${DriverDates.weekdayDayMonth(end)} · ${clock(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final at = now ?? DateTime.now();
    final running = event.runningAt(at);
    final status = running
        ? tr.eventRunning
        : tr.eventStarts(startLabel(event.startsAt, at));
    final note = event.pickupNote;
    return Container(
      key: ValueKey<String>('event-details-${event.eventId}'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9DC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CustomPaint(
                    size: MoveraEventMarker.size,
                    painter: _EventMarkPainter(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey<String>('event-details-status'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: running ? _ink : const Color(0xFFF4F1E8),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: MoveraEventMarker.gold),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: running ? MoveraEventMarker.goldLight : _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _line(Icons.schedule_rounded, timeRange(event)),
              if (event.name != event.title)
                _line(Icons.place_outlined, event.name),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  event.description,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const ValueKey<String>('event-details-pickup'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.eventPickupNote,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EventMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => MoveraEventMarker.paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
