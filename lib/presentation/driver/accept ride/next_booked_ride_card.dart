import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/ride/next_trip.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

export 'package:movera/core/ride/next_trip.dart'
    show NextTrip, openNextTripAfter;

/// Fix job 5 (contract v0.18.33, owner 2026-11-05): during the current trip,
/// the trip the driver does next — a live trip he accepted as an Exclusive
/// ("Next: Anna · after this trip") or a booked ride whose time to drive is
/// near ("Next: booked ride at 14:05"). Read again every minute; nothing
/// without one (and nothing in the demo build).
class NextTripCard extends StatefulWidget {
  const NextTripCard({
    super.key,
    required this.currentTripId,
    this.load,
    this.queued,
    this.now = DateTime.now,
  });

  /// The trip being driven.
  final String currentTripId;

  /// The driver's booked rides; the live app's server list by default.
  final Future<ServerReservations> Function()? load;

  /// The live trip queued behind [currentTripId]; the live app's by default.
  final Map<String, dynamic>? Function(String tripId)? queued;
  final DateTime Function() now;

  @override
  State<NextTripCard> createState() => _NextTripCardState();
}

class _NextTripCardState extends State<NextTripCard> {
  NextTrip? _next;
  Timer? _timer;

  Future<ServerReservations> Function()? get _load =>
      widget.load ?? LiveDriverServices.instance?.reservations.load;
  Map<String, dynamic>? Function(String)? get _queued =>
      widget.queued ?? LiveDriverServices.instance?.trips.queuedAfter;

  @override
  void initState() {
    super.initState();
    if (_load == null && _queued == null) return;
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final queued = _queued?.call(widget.currentTripId);
      final load = _load;
      final accepted = queued == null && load != null
          ? (await load()).accepted
          : const <ServerReservation>[];
      if (!mounted) return;
      setState(
        () => _next = nextTripAfter(
          widget.currentTripId,
          queued: queued,
          accepted: accepted,
          now: widget.now(),
        ),
      );
    } catch (_) {
      // A failed read keeps what was shown; the next minute tries again.
    }
  }

  static const _ink = Color(0xFF303A3F);
  static const _muted = Color(0xFF7D898F);

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next == null) return const SizedBox.shrink();
    final at = next.pickupAt;
    final title = next.booked && at != null
        ? tr.nextBookedRideAt(ServerReservation.clockOf(at))
        : tr.nextTripAfterThis(
            next.riderName.isEmpty ? tr.rider : next.riderName,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey<String>('next-trip-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E0FF)),
        ),
        child: Row(
          children: [
            Icon(
              next.booked ? Icons.event_available : Icons.directions_car,
              color: const Color(0xFF3B5BDB),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (next.pickupAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      next.pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    tr.nextBookedRideHint,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fix job 5 (owner 2026-11-05): the next trip's screen, opened right after
/// Complete, with an information popup on top — "Your next trip" and one OK
/// button that only closes it (it accepts or declines nothing).
class NextTripPopupHost extends StatefulWidget {
  const NextTripPopupHost({super.key, required this.next, required this.child});

  final NextTrip next;
  final Widget child;

  @override
  State<NextTripPopupHost> createState() => _NextTripPopupHostState();
}

class _NextTripPopupHostState extends State<NextTripPopupHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_show());
    });
  }

  Future<void> _show() async {
    final next = widget.next;
    final at = next.pickupAt;
    final body = next.booked && at != null
        ? tr.nextTripPopupBooked(
            ServerReservation.clockOf(at),
            next.pickupAddress,
          )
        : tr.nextTripPopupLive(
            next.riderName.isEmpty ? tr.rider : next.riderName,
            next.pickupAddress,
          );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('next-trip-popup'),
        title: Text(tr.nextTripPopupTitle),
        content: Text(body),
        actions: [
          TextButton(
            key: const ValueKey<String>('next-trip-popup-ok'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
