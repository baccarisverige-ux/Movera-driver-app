import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Owner 2026-11-27 (approved mockup online-strip-mockup-v2): the black
/// strip at the top of a live build, with white status-bar icons. While
/// the driver is online it is 18pt taller and shows "Du är online" under
/// the clock on every screen; a tap returns to the home map (not while
/// the SOS screen is open). Offline: the plain strip.
class DriverOnlineStrip extends StatelessWidget {
  const DriverOnlineStrip({
    super.key,
    required this.session,
    required this.navigatorKey,
    required this.sosOpen,
  });

  final DriverSessionController session;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueListenable<bool> sosOpen;

  /// Set by DriverContentGate while its SOS screen is pushed.
  static final ValueNotifier<bool> sosScreenOpen = ValueNotifier<bool>(false);

  static const double onlineExtra = 18;
  static const Color _dot = Color(0xFF2FBF5B);

  /// About where the iOS clock starts on a notched iPhone.
  static const double _clockInset = 24;

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  );

  void _home() {
    if (sosOpen.value) return;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              if (!session.isOnline) {
                return const SizedBox(width: double.infinity);
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _home,
                child: SizedBox(
                  height: onlineExtra,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(left: _clockInset),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context).statusStripOnline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 12 * 0.02,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
