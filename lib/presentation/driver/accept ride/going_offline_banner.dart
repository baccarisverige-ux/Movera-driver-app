import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/offline_after_trips.dart';

/// Contract v0.18.37 §61 (go offline after trips): under the trip sheet's
/// header, full width, "Going offline after this trip" with Undo while the
/// server holds the plan (`Driver.offlineAfterTrip`). Nothing while it does
/// not. Screenshot review 2026-11-05: never beside the header (it cut the
/// header text at 390 px).
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          key: const ValueKey('trip-bar-going-offline'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
          decoration: BoxDecoration(
            color: _amberBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.power_settings_new_rounded,
                size: 18,
                color: _amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr.goingOfflineAfterTrip,
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UndoButton(
                key: const ValueKey('trip-bar-going-offline-undo'),
                onPressed: () =>
                    unawaited(_undo(context, OfflineAfterTrips.undoAction)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Undo of "Going offline after this trip": a real button (accent colour,
/// at least 48 × 48 px to tap).
class UndoButton extends StatelessWidget {
  const UndoButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.primary,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    onPressed: onPressed,
    // Weight on the Text (merged with the theme font), not styleFrom textStyle (it drops the font family).
    child: Text(
      tr.goingOfflineUndo,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );
}

Future<void> _undo(
  BuildContext context,
  Future<String?> Function()? run,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = await run?.call();
  if (failed != null) messenger?.showSnackBar(SnackBar(content: Text(failed)));
}

/// Trip settings row: "Go offline after this trip" (live build, on a trip),
/// in the same white card and text style as the other rows. He keeps the
/// trip; the server stops new offers at once.
class GoOfflineAfterTripRow extends StatelessWidget {
  const GoOfflineAfterTripRow({super.key});

  static const _ink = Color(0xFF252E3A);
  static const _line = Color(0xFFE6E8EA);

  @override
  Widget build(BuildContext context) {
    final live = LiveDriverServices.instance?.presence;
    if (live == null || !live.onTrip) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineAfterTrips.pending,
      builder: (context, pending, _) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: InkWell(
          key: const ValueKey('trip-settings-go-offline'),
          borderRadius: BorderRadius.circular(18),
          onTap: pending
              ? null
              : () => unawaited(_undo(context, live.goOffline)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 18,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pending ? tr.goingOfflineAfterTrip : tr.goOfflineAfterTrip,
                    key: const ValueKey('trip-settings-go-offline-title'),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (pending)
                  UndoButton(
                    key: const ValueKey('trip-settings-go-offline-undo'),
                    onPressed: () =>
                        unawaited(_undo(context, live.undoGoOffline)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
