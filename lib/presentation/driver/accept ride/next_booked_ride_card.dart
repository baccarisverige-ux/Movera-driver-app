import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/scheduled/next_booked_ride.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// Fix job 5 (contract v0.18.33, owner Q7): during the current trip, the
/// booked ride the driver holds next: "Next: booked ride at 14:05", its
/// pickup and a hint to drive there after this trip. Reads the driver's
/// accepted booked rides from the server (`GET /driver/reservations`) and
/// again every minute; shows nothing without one (and in the demo build).
class NextBookedRideCard extends StatefulWidget {
  const NextBookedRideCard({
    super.key,
    this.currentTripId,
    this.load,
    this.now = DateTime.now,
  });

  /// The trip being driven: never shown as its own "next".
  final String? currentTripId;

  /// The driver's booked rides; the live app's server list by default.
  final Future<ServerReservations> Function()? load;
  final DateTime Function() now;

  @override
  State<NextBookedRideCard> createState() => _NextBookedRideCardState();
}

class _NextBookedRideCardState extends State<NextBookedRideCard> {
  ServerReservation? _next;
  Timer? _timer;

  Future<ServerReservations> Function()? get _load =>
      widget.load ?? LiveDriverServices.instance?.reservations.load;

  @override
  void initState() {
    super.initState();
    if (_load == null) return;
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final load = _load;
    if (load == null) return;
    try {
      final rides = await load();
      if (!mounted) return;
      setState(
        () => _next = nextBookedRide(
          rides.accepted,
          widget.now(),
          currentTripId: widget.currentTripId,
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
    final time = ServerReservation.clockOf(next.scheduledAt);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey<String>('next-booked-ride-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E0FF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: Color(0xFF3B5BDB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.nextBookedRideAt(time),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontSize: 13),
                  ),
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
