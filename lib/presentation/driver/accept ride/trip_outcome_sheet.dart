import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

const Color _ink = Color(0xFF202A31);
const Color _muted = Color(0xFF6D797F);

/// Driver-facing copy for an authoritative terminal outcome.
///
/// Rider cancellation keeps its dedicated [RiderCancelledSheet]. No fee or
/// payout promises are made here: those belong to backend policy.
({String title, String body}) tripOutcomeCopy(TripStatus status) =>
    switch (status) {
      TripStatus.completed => (
        title: 'Trip completed',
        body: 'Movera recorded this trip as completed.',
      ),
      TripStatus.cancelledByAdmin => (
        title: 'Trip cancelled by Movera',
        body: 'Movera cancelled this trip. Stop in a safe place before leaving this screen.',
      ),
      TripStatus.cancelledBySystem => (
        title: 'Trip cancelled by Movera',
        body: 'Movera closed this trip. Stop in a safe place before leaving this screen.',
      ),
      TripStatus.cancelledByDriver => (
        title: 'Trip cancelled',
        body: 'This trip was cancelled from your account.',
      ),
      TripStatus.cancelledByRider => (
        title: 'Rider cancelled',
        body: 'The rider cancelled this trip.',
      ),
      TripStatus.noShow => (
        title: 'Rider no-show recorded',
        body: 'This pickup was closed because the rider did not arrive.',
      ),
      TripStatus.expired => (
        title: 'Trip expired',
        body: 'This trip is no longer active.',
      ),
      TripStatus.failed => (
        title: 'Trip could not continue',
        body: 'The trip was closed because of a system problem. Contact support if the rider is still with you.',
      ),
      TripStatus.searching || TripStatus.requested => (
        title: 'Trip removed by Movera',
        body: 'Movera gave this trip back to dispatch. Stop in a safe place before leaving this screen.',
      ),
      _ => (
        title: 'Trip ended',
        body: 'This trip is no longer active.',
      ),
    };

Future<void> showTripOutcomeSheet(
  BuildContext context, {
  required TripStatus status,
  required bool hasNext,
}) {
  return showMoveraModalSheet<void>(
    context: context,
    heightFactor: 0.9,
    minHeightFactor: 0.46,
    fitContent: true,
    barrierColor: const Color(0x730D1519),
    barrierDismissible: false,
    builder: (sheetContext) => TripOutcomeSheet(
      status: status,
      hasNext: hasNext,
      onAcknowledge: () => popOwned(sheetContext),
    ),
  );
}

class TripOutcomeSheet extends StatelessWidget {
  const TripOutcomeSheet({
    super.key,
    required this.status,
    required this.hasNext,
    required this.onAcknowledge,
  });

  final TripStatus status;
  final bool hasNext;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final copy = tripOutcomeCopy(status);
    // Sized by the sheet route: its usual height, taller only when the
    // text needs it. The text scrolls when even that is not enough, so the
    // only exit of this non-dismissible sheet stays on screen (UI-01).
    return Material(
      color: const Color(0xFFF8FAF9),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: const ValueKey<String>('trip-outcome-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey<String>('trip-outcome-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          copy.title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasNext ? '${copy.body} Your next trip starts now.' : copy.body,
                        style: const TextStyle(color: _muted, fontSize: 15, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>('trip-outcome-acknowledge'),
                  onPressed: onAcknowledge,
                  style: FilledButton.styleFrom(backgroundColor: _ink),
                  child: Text(hasNext ? 'Go to next trip' : 'OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
