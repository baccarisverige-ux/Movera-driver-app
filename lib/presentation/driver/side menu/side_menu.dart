import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';

class DriverSideMenu extends StatelessWidget {
  const DriverSideMenu({
    super.key,
    this.isOnline = false,
    this.accountActive = true,
    this.dispatchRepository,
  });

  final bool isOnline;
  final bool accountActive;

  /// Scheduled rides claims open reservations through it.
  final DispatchRepository? dispatchRepository;

  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _green = Color(0xFF19865C);
  static const Color _canvas = Colors.white;
  static const Color _gap = Color(0xFFF1F2F2);

  // Deliberately keep the Drawer open under the destination route.
  // When the driver presses Back, Flutter reveals the menu again instead of
  // dropping them directly onto the map.
  //
  // Uses a non-[PageRoute] so [HeroController] cannot park the page offstage
  // (which would make Back / [Navigator.pop] a no-op in widget tests).
  void _open(BuildContext context, Widget page) {
    pushSingle(context, _DriverMenuRoute(page), rootNavigator: true);
  }

  static String? _unreadBadge() {
    final unread = DriverNotificationFeed.instance.unread;
    return unread == 0 ? null : '$unread';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Drawer(
      key: const ValueKey<String>('driver-side-menu'),
      width: width * 0.90,
      elevation: 0,
      backgroundColor: _canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: ColoredBox(
        color: _canvas,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const PageStorageKey<String>('driver-menu-list'),
                padding: const EdgeInsets.only(bottom: 14),
                physics: const BouncingScrollPhysics(),
                children: [
                  _groupGap(),
                  _sectionLabel(tr.driver2),
                  _menuCard(
                    children: [
                      _MenuAction(
                        asset: AppAssets.menuProfile,
                        title: tr.profile,
                        subtitle: tr.accountVehicleAndDocuments,
                        onTap: () => _open(context, const DriverProfile()),
                      ),
                      _MenuAction(
                        asset: AppAssets.menuWallet,
                        title: tr.wallet,
                        subtitle: tr.earningsAndWeeklyPayouts,
                        onTap: () => _open(context, const WalletScreen()),
                      ),
                      _MenuAction(
                        asset: AppAssets.menuHistory,
                        title: tr.rideHistory,
                        subtitle: tr.completedAndPreviousRides,
                        onTap: () => _open(context, const DriverRideHistory()),
                      ),
                      // Q31: ride alerts, demand and account messages.
                      _MenuAction(
                        asset: AppAssets.solarBellBing,
                        badge: _unreadBadge(),
                        title: tr.notifications,
                        subtitle: tr.rideAlertsDemandAndAccount,
                        onTap: () => _open(
                          context,
                          DriverNotificationsScreen(
                            dispatchRepository: dispatchRepository,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _groupGap(),
                  _sectionLabel(tr.work),
                  _menuCard(
                    children: [
                      _MenuAction(
                        asset: AppAssets.menuScheduledRide,
                        highlight: true,
                        title: tr.scheduledRides,
                        subtitle: tr.reservationsAndAcceptedTrips,
                        onTap: () => _open(
                          context,
                          ScheduledRidesScreen(
                            dispatchRepository: dispatchRepository,
                          ),
                        ),
                      ),
                      _MenuAction(
                        asset: AppAssets.navMenuBranch,
                        title: tr.ridePreferences,
                        subtitle: tr.chooseCategoriesYouWantToReceive,
                        onTap: () => _open(context, const Preferences()),
                      ),
                      _MenuAction(
                        asset: AppAssets.menuTag,
                        badge: tr.orbNew,
                        title: tr.promotions,
                        subtitle: tr.bonusesAndCampaignOffers,
                        onTap: () => _open(context, const Promotions()),
                      ),
                      _MenuAction(
                        asset: AppAssets.menuTimer,
                        title: tr.drivingLogs,
                        subtitle: tr.hoursOnlineAndRestRules,
                        onTap: () => _open(context, const DrivingLogs()),
                      ),
                    ],
                  ),
                  _groupGap(),
                  _sectionLabel(tr.supportApp),
                  _menuCard(
                    children: [
                      _MenuAction(
                        asset: AppAssets.menuSupport,
                        title: tr.support,
                        subtitle: tr.messagesAndSupportTickets,
                        onTap: () =>
                            _open(context, const SupportInboxScreen()),
                      ),
                      _MenuAction(
                        asset: AppAssets.menuSettings,
                        title: tr.settings,
                        subtitle: tr.appAndDriverSettings,
                        onTap: () => _open(context, const Settings()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset + 12),
              child: _buildMoveraFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    const orange = Color(0xFFF08C2B);
    const green = Color(0xFF1FA463);
    final statusColor = isOnline
        ? MoveraRadarOrb.onlineGreen
        : const Color(0xFF8A9390);
    // The pill's word in a darker tone of its tint: 4.5:1 or more.
    final statusInk = isOnline
        ? const Color(0xFF1C6B45)
        : const Color(0xFF5F6B72);
    final statusText = isOnline ? tr.menuOnline : tr.menuOffline;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 310;
        final photo = compact ? 60.0 : 72.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 20,
            16,
            compact ? 10 : 16,
            10,
          ),
          child: Row(
            children: [
              // The ring tells the account state: orange while pending or on
              // hold, white once active.
              InkWell(
                key: const ValueKey<String>('menu-profile-avatar'),
                onTap: () => _open(context, const DriverProfile()),
                customBorder: const CircleBorder(),
                child: Container(
                  key: ValueKey<String>(
                    accountActive ? 'menu-ring-active' : 'menu-ring-pending',
                  ),
                  height: photo,
                  width: photo,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: accountActive ? Colors.white : orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF172027)
                            .withValues(alpha: accountActive ? 0.18 : 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C2421),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'MD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 19 : 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 16),
              Expanded(
                child: InkWell(
                  key: const ValueKey<String>('menu-profile-header'),
                  onTap: () => _open(context, const DriverProfile()),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Movera Driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF111614),
                            fontSize: compact ? 19 : 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        // Wraps to two lines when the drawer is narrow.
                        Wrap(
                          spacing: compact ? 10 : 16,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // The demo's sample rating, as on Home (UI-10).
                            Semantics(
                              label: tr.sampleRating(
                                  DriverPerformanceConfig.sample.ratingLabel),
                              excludeSemantics: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: Color(0xFF111614),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DriverPerformanceConfig.sample.ratingLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF111614),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 8,
                                  width: 8,
                                  decoration: BoxDecoration(
                                    color: accountActive ? green : orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    accountActive ? tr.active : tr.pending,
                                    key: const ValueKey<String>('menu-account-state'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: accountActive
                                          ? green
                                          : const Color(0xFFB8661A),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Container(
                key: const ValueKey<String>('menu-live-status'),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? statusColor.withValues(alpha: 0.10)
                      : const Color(0xFFF1F2F2),
                  borderRadius: BorderRadius.circular(99),
                ),
                // Round 4: "EN LIGNE" / "HORS LIGNE" are longer than
                // "ONLINE"; the pill keeps its size and the word shrinks.
                constraints: BoxConstraints(maxWidth: compact ? 64 : 84),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    compact
                        ? (isOnline ? tr.orbOn : tr.orbOff)
                        : statusText,
                    maxLines: 1,
                    style: TextStyle(
                      color: statusInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: compact ? 0.4 : 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 8, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9AA4A9),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.15,
        ),
      ),
    );
  }

  Widget _groupGap() {
    return Container(
      height: 8,
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      color: _gap,
    );
  }

  Widget _menuCard({required List<_MenuAction> children}) {
    return Column(
      children: [for (final action in children) _buildMenuAction(action)],
    );
  }

  Widget _buildMenuAction(_MenuAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 11, 18, 11),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: action.highlight
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: action.asset.endsWith('.png')
                              ? Image.asset(
                                  action.asset,
                                  width: 21,
                                  height: 21,
                                  color: Colors.white,
                                )
                              : SvgPicture.asset(
                                action.asset,
                                width: 19,
                                height: 19,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                          ),
                        ),
                      )
                    : Center(
                        child: SvgPicture.asset(
                          action.asset,
                          width: 25,
                          height: 25,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF3B4246),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (action.badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0474C),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    action.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoveraFooter() {
    final ready = accountActive;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: _gap,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              color: _green,
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Movera Driver',
              style: TextStyle(
                color: _ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            ready ? tr.menuReady : tr.menuPending,
            style: TextStyle(
              color: ready ? _green : const Color(0xFFB9801F),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
    this.badge,
  });

  final String asset;

  /// The one coloured icon in the menu (green tile).
  final bool highlight;

  /// Small red pill after the text, e.g. "NEW".
  final String? badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _DriverMenuRoute extends ModalRoute<void> {
  _DriverMenuRoute(this.page);

  final Widget page;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
