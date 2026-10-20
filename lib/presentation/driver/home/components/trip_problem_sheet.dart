import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';

/// A saved-trip problem the driver has to act on. The island only flashes
/// a heads-up; this sheet stays until the driver retries or closes it.
Future<void> showTripProblemSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
}) {
  const ink = Color(0xFF111614);
  const muted = Color(0xFF5E6461);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          key: const ValueKey<String>('trip-problem-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: muted, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('trip-problem-action'),
              onPressed: () {
                if (!popOwned(sheetContext)) return;
                onAction();
              },
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => popOwned(sheetContext),
              style: TextButton.styleFrom(
                foregroundColor: muted,
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(tr.notNow),
            ),
          ],
        ),
      ),
    ),
  );
}
