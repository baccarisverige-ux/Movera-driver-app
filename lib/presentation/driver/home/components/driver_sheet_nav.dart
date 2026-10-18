import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

/// Collapsed / expanded bottom-sheet navigation chrome for driver home.
class DriverSheetNav {
  DriverSheetNav._();

  static Widget collapsedDock({
    required BuildContext context,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required bool isOnline,
    required bool hasRideOffers,
    required bool hasScheduledRideOffers,
    required AnimationController goOnlinePulseController,
    required VoidCallback onOpenScheduledRides,
    double notchDepth = 58,
    double elevation = 8,
    // Outline and online dash along the notch; they fade as the sheet
    // opens over the dock.
    double edgeOpacity = 1,
    // Thin line on top once the open sheet sits above the dock.
    double topRuleOpacity = 0,
    // The account-on-hold sheet. Going online or offline never tints the
    // sheet (R13-6): it stays white.
    bool inactive = false,
    // A plain contour in this colour instead of the grey outline and the
    // online dash, e.g. black while a reservation sits on the dock.
    Color? contourColor,
    // Its width.
    double contourWidth = 1,
  }) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const sheetRed = MoveraRadarOrb.holdSheet;
    final iconTint = inactive ? Colors.white : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PhysicalShape(
          clipper: RadarSheetClipper(
            notchWidth: 126,
            notchDepth: notchDepth,
            cornerRadius: 24,
          ),
          color: inactive ? sheetRed : Colors.white,
          elevation: elevation,
          shadowColor: const Color(0x3311181C),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: inactive
                    ? MoveraRadarOrb.holdSheetGradient
                    : const [Colors.white, Colors.white],
              ),
            ),
            child: Stack(
              children: [
                Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                15,
                10,
                safeBottom > 0 ? safeBottom + 4 : 9,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _dockAction(
                          asset: AppAssets.navMenuBranch,
                          tooltip: 'Ride preferences',
                          onTap: () => _openRidePreferences(context),
                          iconColor: iconTint,
                        ),
                        _dockAction(
                          asset: AppAssets.navCreditCard,
                          tooltip: 'Wallet',
                          onTap: () {
                            pushSingle(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          },
                          iconColor: iconTint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 126),
                  Expanded(
                    child: Row(
                      children: [
                        _dockAction(
                          asset: AppAssets.navMessagesSquare,
                          tooltip: 'Inbox',
                          onTap: () {
                            pushSingle(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportInboxScreen(),
                              ),
                            );
                          },
                          iconColor: iconTint,
                        ),
                        AnimatedBuilder(
                          animation: goOnlinePulseController,
                          builder: (context, child) {
                            return _dockAction(
                              customIcon: _ScheduledRideIcon(
                                pulse: goOnlinePulseController.value,
                                animateClock: hasScheduledRideOffers,
                              ),
                              tooltip: 'Scheduled',
                              onTap: onOpenScheduledRides,
                              pulse: goOnlinePulseController.value,
                              iconColor: iconTint,
                              animateAlertIndicator: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ],
            ),
          ),
        ),
        if (topRuleOpacity > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: const Color(0xFFEEF0F2)
                    .withValues(alpha: topRuleOpacity.clamp(0.0, 1.0)),
              ),
            ),
          ),
        if (!inactive && edgeOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: edgeOpacity.clamp(0.0, 1.0),
                child: RadarSheetOutline(
                  key: contourColor == null
                      ? null
                      : const ValueKey<String>('dock-contour-custom'),
                  notchDepth: notchDepth,
                  color: contourColor ?? const Color(0xFFCDD2D6),
                  strokeWidth: contourColor == null ? 1 : contourWidth,
                ),
              ),
            ),
          ),
        if (isOnline && edgeOpacity > 0 && contourColor == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
              opacity: edgeOpacity.clamp(0.0, 1.0),
              child: RadarEdgeDash(
                notchWidth: 126,
                notchDepth: notchDepth,
                cornerRadius: 24,
                color: hasRideOffers
                    ? MoveraRadarOrb.offerAccent
                    : MoveraRadarOrb.onlineGreen,
              ),
              ),
            ),
          ),
      ],
    );
  }

  static Widget sheetQuickActionsBar({
    required BuildContext context,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required bool hasScheduledRideOffers,
    required AnimationController goOnlinePulseController,
    required VoidCallback onOpenScheduledRides,
  }) {
    return Container(
      height: MediaQuery.paddingOf(context).bottom + 66,
      padding: EdgeInsets.fromLTRB(
        18,
        4,
        18,
        MediaQuery.paddingOf(context).bottom + 5,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          _sheetQuickAction(
            asset: AppAssets.navMenuBranch,
            tooltip: 'Ride preferences',
            onTap: () => _openRidePreferences(context),
          ),
          _sheetQuickAction(
            asset: AppAssets.navCreditCard,
            tooltip: 'Wallet',
            onTap: () {
              pushSingle(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          _sheetQuickAction(
            asset: AppAssets.navMessagesSquare,
            tooltip: 'Inbox',
            onTap: () {
              pushSingle(
                context,
                MaterialPageRoute(builder: (_) => const SupportInboxScreen()),
              );
            },
          ),
          AnimatedBuilder(
            animation: goOnlinePulseController,
            builder: (context, child) {
              return _sheetQuickAction(
                customIcon: _ScheduledRideIcon(
                  pulse: goOnlinePulseController.value,
                  animateClock: hasScheduledRideOffers,
                ),
                tooltip: 'Scheduled',
                onTap: onOpenScheduledRides,
                pulse: goOnlinePulseController.value,
                animateAlertIndicator: false,
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget onlineEdgeDashOverlay({
    required bool isOnline,
    required bool hasRideOffers,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            const Positioned.fill(child: RadarSheetOutline()),
            if (isOnline)
              Positioned.fill(
                child: RadarEdgeDash(
                  notchWidth: 126,
                  notchDepth: 58,
                  cornerRadius: 24,
                  color: hasRideOffers
                      ? MoveraRadarOrb.offerAccent
                      : MoveraRadarOrb.onlineGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _openRidePreferences(BuildContext context) {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const Preferences()),
    );
  }

  static Widget _dockAction({
    String? asset,
    Widget? customIcon,
    required String tooltip,
    required VoidCallback onTap,
    bool hasAlert = false,
    double pulse = 0,
    Color? iconColor,
    bool animateAlertIndicator = true,
  }) {
    final resolvedIcon =
        iconColor ?? (hasAlert ? const Color(0xFF19865C) : const Color(0xFF303A3F));
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: const Color(0xFF19865C).withValues(alpha: 0.08),
            highlightColor: const Color(0xFF19865C).withValues(alpha: 0.04),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // Image logos (scheduled rides) sit directly on the sheet;
                  // only line icons get the tinted alert tile.
                  color: hasAlert && customIcon == null
                      ? const Color(0xFFF0F8F4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    customIcon ??
                        SvgPicture.asset(
                          asset!,
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            resolvedIcon,
                            BlendMode.srcIn,
                          ),
                        ),
                    if (hasAlert)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2FBE7B),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2FBE7B).withValues(
                                  alpha: animateAlertIndicator
                                      ? 0.28 + pulse * 0.35
                                      : 0.28,
                                ),
                                blurRadius: animateAlertIndicator ? 6 : 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sheetQuickAction({
    String? asset,
    Widget? customIcon,
    required String tooltip,
    required VoidCallback onTap,
    bool hasAlert = false,
    double pulse = 0,
    bool animateAlertIndicator = true,
  }) {
    final alertStrength = hasAlert
        ? (animateAlertIndicator ? (0.55 + (pulse * 0.45)) : 1.0)
        : 0.0;
    final iconColor =
        hasAlert ? const Color(0xFF16895B) : const Color(0xFF354047);

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Center(
          child: Material(
            color: customIcon != null
                ? Colors.transparent
                : hasAlert
                    ? const Color(0xFFE9F7F1)
                    : const Color(0xFFF1F3F4),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: const Color(0xFF2FBE7B).withValues(alpha: 0.12),
              child: SizedBox(
                height: 43,
                width: 43,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    customIcon ??
                        SvgPicture.asset(
                          asset!,
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                    if (hasAlert)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Opacity(
                          opacity: alertStrength,
                          child: Container(
                            height: 7,
                            width: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2FBE7B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduledRideIcon extends StatelessWidget {
  const _ScheduledRideIcon({
    required this.pulse,
    required this.animateClock,
  });

  final double pulse;
  final bool animateClock;

  @override
  Widget build(BuildContext context) {
    final motionAllowed = !MediaQuery.disableAnimationsOf(context);
    final shouldAnimate = animateClock && motionAllowed;
    final rawPhase = pulse <= 0.5 ? pulse * 2 : (1 - pulse) * 2;
    final phase = Curves.easeInOutCubic.transform(
      rawPhase.clamp(0.0, 1.0).toDouble(),
    );
    // New reservations: the whole calendar breathes gently. Still when
    // there is nothing new or the platform asks for reduced motion.
    final scale = shouldAnimate ? 1 + (0.045 * phase) : 1.0;

    return SizedBox(
      width: 31,
      height: 31,
      child: Transform.scale(
        scale: scale,
        // The icon carries its own green dot for new reservations.
        child: Image.asset(
          animateClock
              ? AppAssets.navScheduledRideAlert
              : AppAssets.navScheduledRide,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// Public copy of the radar sheet clipper so nav chrome can share the path.
class RadarSheetClipper extends CustomClipper<Path> {
  final double notchWidth;
  final double notchDepth;
  final double cornerRadius;

  const RadarSheetClipper({
    required this.notchWidth,
    required this.notchDepth,
    required this.cornerRadius,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final notchLeft = centerX - (notchWidth / 2);
    final notchRight = centerX + (notchWidth / 2);
    final radius = cornerRadius.clamp(0.0, size.width / 2).toDouble();

    path.moveTo(radius, 0);
    path.lineTo(notchLeft, 0);
    path.cubicTo(
      notchLeft + 9,
      0,
      centerX - 54,
      notchDepth,
      centerX,
      notchDepth,
    );
    path.cubicTo(
      centerX + 54,
      notchDepth,
      notchRight - 9,
      0,
      notchRight,
      0,
    );
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant RadarSheetClipper oldClipper) {
    return oldClipper.notchWidth != notchWidth ||
        oldClipper.notchDepth != notchDepth ||
        oldClipper.cornerRadius != cornerRadius;
  }
}
