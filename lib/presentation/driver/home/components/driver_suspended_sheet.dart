import 'package:movera/presentation/driver/deferred_screens.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/driver_sign_out.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

const Color _ink = Color(0xFF202A31);
const Color _muted = Color(0xFF667177);
const Color _warning = Color(0xFF9A6414);
const Color _warningSoft = Color(0xFFFFF3DE);

/// G16 Q16-3: a paused account sees a short message with Contact support
/// and Sign out. The sheet cannot be closed: no barrier tap, no back.
Future<void> showDriverSuspendedSheet(BuildContext context) {
  return showMoveraModalSheet<void>(
    context: context,
    heightFactor: 0.48,
    fitContent: true,
    barrierDismissible: false,
    barrierColor: const Color(0x730D1519),
    builder: (sheetContext) => PopScope(
      canPop: false,
      child: DriverSuspendedSheet(
        onContactSupport: () => unawaited(
          Navigator.of(
            sheetContext,
          ).push(MaterialPageRoute<void>(builder: (_) => supportInboxScreen())),
        ),
        onSignOut: () => unawaited(signOutDriver(sheetContext)),
      ),
    ),
  );
}

/// Presentation for the authoritative DriverOnlineStatus.suspended state.
///
/// It deliberately does not invent a suspension reason, duration or appeal
/// result.
class DriverSuspendedSheet extends StatelessWidget {
  const DriverSuspendedSheet({
    super.key,
    required this.onContactSupport,
    required this.onSignOut,
  });

  final VoidCallback onContactSupport;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return MoveraModalSheet(
      color: const Color(0xFFF8FAF9),
      radius: 30,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            key: const ValueKey<String>('driver-suspended-state'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Text(
                      tr.accountAccessPaused,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tr.suspendedShortBody,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>('driver-suspended-support'),
                  onPressed: onContactSupport,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    tr.contactSupport,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  key: const ValueKey<String>('driver-suspended-sign-out'),
                  onPressed: onSignOut,
                  style: TextButton.styleFrom(foregroundColor: _ink),
                  child: Text(
                    tr.logOut,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
