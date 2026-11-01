import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/ride/trip_live_details.dart';

// The trip screen's part file reads the zone's on-trip settings with it.
export 'package:movera/core/admin/on_trip_config.dart';
export 'package:movera/core/admin/ride_check_admin_config.dart';

/// Contract v0.18.9 (owner G7 decision 3, `onTrip.routeChange`): the rider
/// asked for a new drop-off or other stops. The driver reads the new route
/// and the new earnings and answers Accept or Refuse before the time is up;
/// no answer keeps the old route (the server's `expired`).
class RouteChangeSheet extends StatefulWidget {
  const RouteChangeSheet({
    super.key,
    required this.change,
    required this.maxStops,
    required this.onAnswer,
    this.canRefuse = true,
    this.now = DateTime.now,
  });

  final TripRouteChange change;

  /// `booking.maxStops` of the zone, shown next to the stop count.
  final int maxStops;

  /// `routeChange.driverCanRefuse`: off hides Refuse.
  final bool canRefuse;

  /// Accept (true) or Refuse (false); the sheet waits while it runs.
  final Future<void> Function(bool accept) onAnswer;
  final DateTime Function() now;

  @override
  State<RouteChangeSheet> createState() => _RouteChangeSheetState();
}

class _RouteChangeSheetState extends State<RouteChangeSheet> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _answer(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAnswer(accept);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = widget.change;
    final left = change.secondsLeft(widget.now().toUtc());
    final earnings = change.driverEarnings;
    final difference = change.earningsDifference;
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey<String>('route-change-sheet'),
      color: Colors.white,
      elevation: 12,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.alt_route_rounded, color: Color(0xFF146B45)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr.g7RouteAsk,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (change.dropoff case final drop?) ...[
              Text(
                tr.g7RouteNewDestination,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              Text(
                drop.address ?? '',
                key: const ValueKey<String>('route-change-dropoff'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 6),
            ],
            for (final stop in change.stops)
              if (stop.address case final address?)
                Text('• $address', style: theme.textTheme.bodyMedium),
            Text(
              tr.g7RouteStops(change.stops.length, widget.maxStops),
              key: const ValueKey<String>('route-change-stops'),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            if (earnings != null) ...[
              const SizedBox(height: 10),
              Text(
                tr.g7RouteEarnings(
                  earnings.formatted,
                  difference == null ? '' : signedMoneyLabel(difference),
                ),
                key: const ValueKey<String>('route-change-earnings'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF146B45),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              tr.g7RouteSecondsLeft(left),
              key: const ValueKey<String>('route-change-timer'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.canRefuse) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('route-change-refuse'),
                      onPressed: _busy || left == 0
                          ? null
                          : () => unawaited(_answer(false)),
                      child: Text(tr.g7RouteRefuse),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('route-change-accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF146B45),
                    ),
                    onPressed: _busy || left == 0
                        ? null
                        : () => unawaited(_answer(true)),
                    child: Text(tr.g7RouteAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Contract v0.18.9: the island's one line once the rider's route change
/// has an answer (accepted, refused, expired, withdrawn); null while it
/// still waits for the driver.
String? routeChangeIslandLine(TripRouteChange change) =>
    switch (change.status) {
      'accepted' =>
        change.answeredBy == 'system'
            ? tr.g7RouteChanged
            : tr.g7RouteAcceptedIsland,
      'refused' => tr.g7RouteRefusedIsland,
      'expired' => tr.g7RouteExpiredIsland,
      'withdrawn' => tr.g7RouteWithdrawnIsland,
      _ => null,
    };

/// The waybill's "To" after a route change: the stops on the way, then the
/// drop-off ("Fridhemsplan → Brommaplan").
String waybillRouteLabel(String dropoff, List<String> stops) =>
    stops.isEmpty ? dropoff : [...stops, dropoff].join(' → ');
