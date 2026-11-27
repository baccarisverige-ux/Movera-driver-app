import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Owner 2026-11-27 (approved mockup online-strip-mockup-v2): the black
/// strip at the top of a live build, with white status-bar icons. While
/// the driver is online (a trip included) it is 18pt taller and shows
/// "Du är online" under the clock on every screen; a tap returns to the
/// home map. The tap never closes a live trip (it does nothing then),
/// never answers a dialog or bottom sheet, and does nothing while the
/// safety sheet / SOS screen is open. Offline: the plain strip.
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

  /// True while any SafetyToolKits (the safety sheet or the SOS screen)
  /// is mounted; set through [safetyOpened] / [safetyClosed].
  static final ValueNotifier<bool> sosScreenOpen = ValueNotifier<bool>(false);
  static int _safetyCount = 0;

  /// Routes the tap never pops (the ride-completed screen registers here).
  static final Set<Route<dynamic>> _stops = <Route<dynamic>>{};

  static void stopAt(Route<dynamic>? route) {
    if (route != null) _stops.add(route);
  }

  static void releaseStop(Route<dynamic>? route) {
    if (route != null) _stops.remove(route);
  }

  static void safetyOpened() {
    _safetyCount++;
    sosScreenOpen.value = true;
  }

  static void safetyClosed() {
    if (_safetyCount > 0) _safetyCount--;
    sosScreenOpen.value = _safetyCount > 0;
  }

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
    // A live trip: the trip screen is never popped (popUntil would skip
    // its PopScope), so the tap does nothing.
    if (session.activeTripId != null) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Read the top route without popping anything.
    Route<dynamic>? top;
    nav.popUntil((r) {
      top = r;
      return true;
    });
    // A dialog or bottom sheet is open: never answer it (a null result
    // means "close" for some, e.g. "Unresolved trip").
    if (top is PopupRoute) return;
    // Pages and side-menu routes (_DriverMenuRoute is a ModalRoute) all
    // close back to Home; never past a popup or a protected route.
    nav.popUntil((r) => r.isFirst || r is PopupRoute || _stops.contains(r));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final online = session.isOnline;
          final strip = ColoredBox(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: online
                  ? _label(context)
                  : const SizedBox(width: double.infinity),
            ),
          );
          if (!online) return strip;
          // The whole strip (status bar included) is the button.
          return Semantics(
            button: true,
            container: true,
            label: AppLocalizations.of(context).statusStripOnline,
            excludeSemantics: true,
            onTap: _home,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _home,
              child: strip,
            ),
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context) {
    // At least 18pt; grows with large text instead of clipping.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: onlineExtra),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(left: _clockInset, bottom: 2),
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
              Flexible(
                child: Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
