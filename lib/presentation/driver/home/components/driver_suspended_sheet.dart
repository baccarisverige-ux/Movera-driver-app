import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

const Color _ink = Color(0xFF202A31);
const Color _muted = Color(0xFF667177);
const Color _warning = Color(0xFF9A6414);
const Color _warningSoft = Color(0xFFFFF3DE);

Future<void> showDriverSuspendedSheet(BuildContext context) {
  return showMoveraModalSheet<void>(
    context: context,
    heightFactor: 0.48,
    barrierColor: const Color(0x730D1519),
    builder: (sheetContext) => DriverSuspendedSheet(
      onAcknowledge: () => popOwned(sheetContext),
    ),
  );
}

/// Presentation for the authoritative DriverOnlineStatus.suspended state.
///
/// It deliberately does not invent a suspension reason, duration or appeal
/// result. Those fields must come from the future backend contract.
class DriverSuspendedSheet extends StatelessWidget {
  const DriverSuspendedSheet({
    super.key,
    required this.onAcknowledge,
  });

  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return MoveraModalSheet(
      color: const Color(0xFFF8FAF9),
      radius: 30,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            key: const ValueKey<String>('driver-suspended-state'),
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
                      color: _warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: _warning,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.driverStatus,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          tr.accountAccessPaused,
                          style: TextStyle(
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
                tr.yourDriverStatusIsCurrentlySuspended,
                style: TextStyle(
                  color: _muted,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 20,
                      color: Color(0xFF526168),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr.moveraWillUseAuthoritativeAccountStatus,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>('driver-suspended-acknowledge'),
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
                    tr.gotIt,
                    style: TextStyle(
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
