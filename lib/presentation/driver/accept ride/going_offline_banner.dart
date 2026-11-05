import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/offline_after_trips.dart';

/// Contract v0.18.37 §61 (go offline after trips): on the trip sheet,
/// "Going offline after this trip" with Undo while the server holds the
/// plan (`Driver.offlineAfterTrip`). Nothing while it does not.
class GoingOfflineBanner extends StatelessWidget {
  const GoingOfflineBanner({super.key});

  static const _amber = Color(0xFF8A5A00);
  static const _amberBg = Color(0xFFFFF4DC);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: OfflineAfterTrips.pending,
    builder: (context, pending, _) {
      if (!pending) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Container(
          key: const ValueKey('trip-bar-going-offline'),
          constraints: const BoxConstraints(maxWidth: 170),
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: BoxDecoration(
            color: _amberBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tr.goingOfflineAfterTrip,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('trip-bar-going-offline-undo'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: _amber,
                ),
                onPressed: () => unawaited(_undo(context)),
                child: Text(tr.goingOfflineUndo),
              ),
            ],
          ),
        ),
      );
    },
  );

  static Future<void> _undo(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = await OfflineAfterTrips.undoAction?.call();
    if (failed != null) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

/// Trip settings row: "Go offline after this trip" (live build, on a trip).
/// He keeps the trip; the server stops new offers at once.
class GoOfflineAfterTripRow extends StatelessWidget {
  const GoOfflineAfterTripRow({super.key});

  @override
  Widget build(BuildContext context) {
    final live = LiveDriverServices.instance?.presence;
    if (live == null || !live.onTrip) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineAfterTrips.pending,
      builder: (context, pending, _) => ListTile(
        key: const ValueKey('trip-settings-go-offline'),
        leading: const Icon(Icons.power_settings_new_rounded),
        title: Text(pending ? tr.goingOfflineAfterTrip : tr.goOfflineAfterTrip),
        trailing: pending ? Text(tr.goingOfflineUndo) : null,
        onTap: () async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          final failed = pending
              ? await live.undoGoOffline()
              : await live.goOffline();
          if (failed != null) {
            messenger?.showSnackBar(SnackBar(content: Text(failed)));
          }
        },
      ),
    );
  }
}
