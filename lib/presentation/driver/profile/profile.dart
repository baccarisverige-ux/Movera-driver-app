import 'dart:async';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:movera/presentation/driver/account/fleet_invitations.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/vehicles/vehicles.dart';
import 'package:movera/widgets/navigation_transition.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final _vehicles = LocalVehicleStore();
  late Future<({String vehicle, String plate})?> _identity;
  bool _logoutBusy = false;

  bool _liveRead = false;

  @override
  void initState() {
    super.initState();
    _identity = _vehicles.primaryIdentity();
    LocalVehicleStore.changes.addListener(_vehicleChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Round 4b (live): the picked fleet car, read through the server (the
    // scope is only reachable here, not in initState).
    final live = _liveSession;
    if (!_liveRead && live != null) {
      _liveRead = true;
      _identity = _readIdentity();
      // The header follows the account; a session opened without a profile
      // read yet (a restored token) reads it now.
      live.addListener(_accountChanged);
      if (live.account == null) {
        unawaited(
          live.refresh().then((_) => _vehicleChanged(), onError: (_) {}),
        );
      }
    }
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  Future<({String vehicle, String plate})?> _readIdentity() {
    final live = _liveSession;
    return live == null ? _vehicles.primaryIdentity() : _liveIdentity(live);
  }

  /// The car this account has picked (`Driver.vehicleId`) among the fleet's.
  Future<({String vehicle, String plate})?> _liveIdentity(
    DriverAccountSession live,
  ) async {
    final id = live.account?.vehicleId;
    if (id == null) return null;
    try {
      for (final car in await live.repository.vehicles()) {
        if (car.vehicleId == id) {
          return (vehicle: '${car.make} ${car.model}'.trim(), plate: car.plate);
        }
      }
    } catch (_) {
      // Offline: the line stays blank rather than wrong.
    }
    return null;
  }

  /// Round 4b (live): the signed-in driver's name and account status instead
  /// of the demo's sample profile.
  String get _headerName {
    final account = _liveAccount;
    if (account == null) return tr.profSampleDriver;
    final name = account.fullName.trim();
    return name.isEmpty ? tr.profLiveNoNameYet : name;
  }

  String get _headerStatus {
    final account = _liveAccount;
    if (account == null) return tr.profDemoNoVerified;
    return switch (account.accountStatus) {
      'active' => tr.profStatusActive,
      'on_hold' => tr.profStatusOnHold,
      'suspended' => tr.profStatusSuspended,
      _ => tr.profStatusPending,
    };
  }

  void _vehicleChanged() {
    if (mounted && !_logoutBusy) {
      setState(() {
        _identity = _readIdentity();
      });
    }
  }

  @override
  void dispose() {
    LocalVehicleStore.changes.removeListener(_vehicleChanged);
    if (_liveRead) _liveSession?.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _openPage(
    BuildContext context,
    Widget page, {
    bool refreshVehicle = false,
  }) async {
    if (_logoutBusy || !mounted) {
      return;
    }
    await pushSingle(context, RightToLeftTransition(page));
    if (mounted && refreshVehicle) {
      setState(() {
        _identity = _readIdentity();
      });
    }
  }

  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  /// Round 4: the live account session, when the build requires one.
  DriverAccountSession? get _liveSession =>
      DriverRuntimeConfig.current.authRequired
      ? accountSessionOf(context)
      : null;

  DriverAccount? get _liveAccount => _liveSession?.account;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_logoutBusy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F7),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: tr.back,
            onPressed: _logoutBusy ? null : () => maybePopOwned(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          ),
          titleSpacing: 0,
          title: Text(
            tr.profile,
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            IconButton(
              tooltip: tr.settings,
              onPressed: _logoutBusy
                  ? null
                  : () => _openPage(context, const Settings()),
              icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage(AppAssets.profileImg),
                    backgroundColor: Color(0xFFECECEC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerName,
                          key: const ValueKey('profile-header-name'),
                          style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _headerStatus,
                          key: const ValueKey('profile-header-status'),
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<({String vehicle, String plate})?>(
              future: _identity,
              builder: (context, snapshot) => _link(
                context,
                icon: Icons.directions_car_outlined,
                title: tr.vehicles,
                // driver-81: blank while reading; "unavailable" only when the
                // read ended without a vehicle.
                // Round 4 (live): a driver account without a fleet waits
                // for the fleet's cars.
                detail: _liveAccount?.awaitsFleet == true
                    ? tr.holdWaitingFleetVehicle
                    : snapshot.data?.vehicle ??
                          (snapshot.connectionState == ConnectionState.done
                              ? tr.vehicleDataUnavailable
                              : ''),
                page: const DriverVehicles(),
                refreshVehicle: true,
              ),
            ),
            const SizedBox(height: 12),
            _group(context, [
              // Round 4b: the details may be changed while Movera still
              // checks the account (a resend replaces them).
              if (_liveAccount?.canSendDetails == true)
                _item(
                  Icons.badge_outlined,
                  tr.acctDetailsTitle,
                  DriverDetailsScreen(
                    key: const ValueKey('profile-details'),
                    account: _liveSession!,
                    editing: true,
                    onBack: () => maybePopOwned(context),
                    onDone: (context) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr.acctDetailsSaved)),
                      );
                      maybePopOwned(context);
                    },
                  ),
                ),
              if (_liveSession != null)
                _item(
                  Icons.groups_outlined,
                  tr.myFleet,
                  MyFleetScreen(account: _liveSession!),
                  badge: _liveAccount?.pendingFleetInvitations ?? 0,
                ),
              _item(Icons.insights_outlined, tr.analytics, const Analytics()),
              _item(Icons.account_balance_outlined, tr.myBank, const MyBank()),
              _item(
                Icons.description_outlined,
                tr.documents,
                const DriverDocuments(),
              ),
            ]),
            const SizedBox(height: 12),
            _group(context, [
              _item(
                Icons.privacy_tip_outlined,
                tr.privacyPolicyTitle,
                LegalDocumentScreen.privacy,
              ),
              _item(
                Icons.article_outlined,
                tr.termsOfService,
                LegalDocumentScreen.terms,
              ),
              _item(
                Icons.help_outline_rounded,
                tr.helpCenter,
                const SupportInboxScreen(),
              ),
            ]),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: _logoutBusy ? null : () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFB84F3D),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        tr.logOut,
                        style: TextStyle(
                          color: Color(0xFFB84F3D),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required Widget page,
    bool refreshVehicle = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _logoutBusy
            ? null
            : () => _openPage(context, page, refreshVehicle: refreshVehicle),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Icon(icon, color: _ink, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8BC)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, List<_ProfileItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          for (final item in items)
            InkWell(
              onTap: _logoutBusy ? null : () => _openPage(context, item.page),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(
                  children: [
                    Icon(item.icon, color: _ink, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.badge > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InvitationBadge(item.badge, small: true),
                      ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB0B8BC),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _ProfileItem _item(
    IconData icon,
    String title,
    Widget page, {
    int badge = 0,
  }) {
    return _ProfileItem(icon, title, page, badge: badge);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    if (_logoutBusy || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    setState(() => _logoutBusy = true);
    try {
      await _performLogout(context);
    } finally {
      if (mounted) setState(() => _logoutBusy = false);
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        void close(bool result) {
          if (!dialogContext.mounted ||
              ModalRoute.of(dialogContext)?.isCurrent != true) {
            return;
          }
          popOwned(dialogContext, result);
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(tr.logOutQ),
          content: Text(tr.profLogOutClears),
          actions: [
            TextButton(onPressed: () => close(false), child: Text(tr.stay)),
            FilledButton(
              onPressed: () => close(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF252E3A),
              ),
              child: Text(tr.logOut),
            ),
          ],
        );
      },
    );
    if (leave == true &&
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      final runtime = DriverRuntimeScope.maybeOf(context);
      try {
        if (runtime?.logout != null) {
          await runtime!.logout!();
        } else {
          await clearLocalUserData();
          ScheduledRideStore.reset();
          IslandMessages.clear(); // driver-r5-27
          runtime?.session.reset();
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr.profCouldNotClear)));
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      // uat-d2: the demo landing screen is gone; a logged-out driver is
      // back on Home (demo mode). Round 4: a build that requires a session
      // lands on Sign in instead (driverRootAfterSignOut).
      final home = driverRootAfterSignOut(runtime);
      if (home == null) {
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        return;
      }
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => home()),
        (route) => false,
      );
    }
  }
}

class _ProfileItem {
  const _ProfileItem(this.icon, this.title, this.page, {this.badge = 0});
  final IconData icon;
  final String title;
  final Widget page;

  /// Round 4b: invitations waiting in My fleet.
  final int badge;
}
