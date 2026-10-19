import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';

const Color _ink = Color(0xFF202A31);
const Color _muted = Color(0xFF6D797F);
const Color _danger = Color(0xFF9B3B34);
const Color _dangerSoft = Color(0xFFF9E9E7);

/// Presents an authoritative rider-cancelled event to the driver.
///
/// The fee follows the backend's decision ([fee], R15-7): "+45 kr",
/// "no fee", or nothing while it is not decided.
Future<void> showRiderCancelledSheet(
  BuildContext context, {
  required String riderName,
  required bool wasOnTrip,
  Money? fee,
}) {
  return showMoveraModalSheet<void>(
    context: context,
    heightFactor: 0.9,
    minHeightFactor: wasOnTrip ? 0.56 : 0.50,
    fitContent: true,
    barrierColor: const Color(0x730D1519),
    barrierDismissible: false,
    builder: (sheetContext) => RiderCancelledSheet(
      riderName: riderName,
      wasOnTrip: wasOnTrip,
      fee: fee,
      onAcknowledge: () => popOwned(sheetContext),
    ),
  );
}

class RiderCancelledSheet extends StatelessWidget {
  const RiderCancelledSheet({
    super.key,
    required this.riderName,
    required this.wasOnTrip,
    required this.onAcknowledge,
    this.fee,
  });

  final String riderName;
  final bool wasOnTrip;
  final Money? fee;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final title = wasOnTrip ? 'Rider ended the trip' : 'Rider cancelled';
    final body = wasOnTrip
        ? '$riderName cancelled while the trip was active. Stop in a safe place before leaving this screen.'
        : '$riderName cancelled this request. The current pickup is no longer active.';
    final status = (wasOnTrip
            ? 'Active trip cancelled by rider'
            : 'Pickup cancelled by rider') +
        HomeIslandNotices.feeSuffix(fee);

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            key: ValueKey<String>(
              wasOnTrip
                  ? 'rider-cancelled-mid-trip'
                  : 'rider-cancelled-pre-pickup',
            ),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey<String>('rider-cancelled-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8DEDC),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: _dangerSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_off_outlined,
                              color: _danger,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TRIP UPDATE',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 22,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        body,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE3E9E6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 20,
                              color: Color(0xFF247254),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wasOnTrip) ...[
                        const SizedBox(height: 12),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.health_and_safety_outlined,
                              size: 19,
                              color: Color(0xFF526168),
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Keep control of the vehicle and stop safely before continuing.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>(
                    'rider-cancelled-acknowledge',
                  ),
                  onPressed: onAcknowledge,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    wasOnTrip ? 'I have stopped safely' : 'Return to requests',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
