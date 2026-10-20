import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// "Finish so soon?": asked when the driver finishes a trip right after
/// pickup. A compact sheet that fits its content. True finishes the trip.
Future<bool?> showFinishSoonSheet(
  BuildContext context, {
  required int minutesSincePickup,
}) {
  return showMoveraModalSheet<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    // Sized to its content; the room up to 0.9 is for long words and
    // large text (Round 4: French and Swedish at 130 %).
    heightFactor: 0.9,
    fitContent: true,
    builder: (sheetContext) => FinishSoonSheet(
      minutesSincePickup: minutesSincePickup,
      onBack: () => popOwned(sheetContext, false),
      onFinish: () => popOwned(sheetContext, true),
    ),
  );
}

class FinishSoonSheet extends StatelessWidget {
  const FinishSoonSheet({
    super.key = const ValueKey<String>('short-trip-finish-sheet'),
    required this.minutesSincePickup,
    required this.onBack,
    required this.onFinish,
  });

  final int minutesSincePickup;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  static const Color _ink = Color(0xFF111518);
  static const Color _muted = Color(0xFF6E767C);
  static const Color _grey = Color(0xFFF1F2F4);

  @override
  Widget build(BuildContext context) {
    final minutes = minutesSincePickup < 1 ? 1 : minutesSincePickup;
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DDDB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: _grey,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      AppAssets.solarClockCircle,
                      width: 23,
                      height: 23,
                      colorFilter: const ColorFilter.mode(
                        _ink,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.finishSoSoonQuestion,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr.youPickedUpRiderMinutesMin(minutes),
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey<String>('finish-soon-back'),
                        onPressed: onBack,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _grey,
                          foregroundColor: _ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr.backToRide,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey<String>('finish-soon-finish'),
                        onPressed: onFinish,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          tr.finishTrip,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
