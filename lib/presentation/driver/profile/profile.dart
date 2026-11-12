import 'package:movera/presentation/driver/deferred_screens.dart';
import 'package:movera/widgets/initials_avatar.dart';
import 'package:movera/widgets/movera_dialog_theme.dart';
import 'dart:async';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/contracts/status_words.g.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/presentation/driver/account/contact_change_screen.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:movera/presentation/driver/account/fleet_invitations.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/driver_sign_out.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/profile/app_version_line.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
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

  /// The session listened to; dispose may not look it up again (the
  /// tree is gone by then).
  DriverAccountSession? _listened;

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
      _listened = live..addListener(_accountChanged);
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
    // v0.10.4: the contract word (statusWords driverAccountStatus).
    return statusWord(tr, 'driverAccountStatus', account.accountStatus) ??
        tr.swDriverAccountStatusPending;
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
    _listened?.removeListener(_accountChanged);
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
                  : () => _openPage(context, settingsScreen()),
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
                  // L-a Q1 (owner 2026-11-06): initials, no stock photo.
                  InitialsAvatar(
                    key: const ValueKey('profile-header-initials'),
                    name: _liveAccount?.fullName ?? '',
                    radius: 28,
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
              if (_liveSession != null) ...[
                _item(
                  Icons.phone_outlined,
                  tr.contactChangePhone,
                  ContactChangeScreen(
                    account: _liveSession!,
                    kind: ContactKind.phone,
                  ),
                ),
                _emailItem(_liveSession!),
              ],
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
                driverDocumentsScreen(),
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
              _item(Icons.help_outline_rounded, tr.helpCenter, supportScreen()),
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
            const AppVersionLine(),
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
              key: item.key,
              onTap: _logoutBusy ? null : () => _openPage(context, item.page),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Row(
                  children: [
                    Icon(item.icon, color: _ink, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.detail case final detail?) ...[
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              style: TextStyle(
                                color: item.detailColor ?? _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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

  /// G30 (contract v0.18.76 `emailVerified.apps.driver`, owner Q2 "Keep,
  /// show Not verified"): "E-mail" with the address and Verified / Not
  /// verified ("No e-mail" without one). A Not verified address opens the
  /// code check with it filled; otherwise the normal change.
  _ProfileItem _emailItem(DriverAccountSession session) {
    final account = session.account;
    final email = account?.email;
    final verified = account?.emailVerified == true;
    return _ProfileItem(
      Icons.alternate_email_rounded,
      tr.acctEmail,
      ContactChangeScreen(
        account: session,
        kind: ContactKind.email,
        verifyCurrent: email != null && !verified ? email : null,
      ),
      key: const ValueKey('profile-email'),
      detail: email == null
          ? tr.contactEmailNone
          : verified
          ? tr.contactEmailVerified(email)
          : tr.contactEmailNotVerified(email),
      detailColor: email != null && !verified ? _notVerified : null,
    );
  }

  /// G30: the "Not verified" detail (the reminders' orange).
  static const Color _notVerified = Color(0xFFE08A00);

  Future<void> _confirmLogout(BuildContext context) async {
    if (_logoutBusy || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    // Finder A3 (2026-11-07): the trip drawer reaches Profile. A log out
    // mid-trip left the trip live on the server and the rider with a
    // frozen car, so it waits until the trip has ended (no sign-out, the
    // saved trip stays).
    if (DriverRuntimeScope.maybeOf(context)?.session.activeTripId != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.fleetOnTrip)));
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

        return MoveraDialogTheme(
          child: AlertDialog(
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
          ),
        );
      },
    );
    if (leave == true &&
        context.mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      if (!await signOutDriver(context) && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.profCouldNotClear)));
      }
    }
  }
}

class _ProfileItem {
  const _ProfileItem(
    this.icon,
    this.title,
    this.page, {
    this.badge = 0,
    this.key,
    this.detail,
    this.detailColor,
  });
  final IconData icon;
  final String title;
  final Widget page;

  /// G30: the row's key (`profile-email`).
  final Key? key;

  /// G30: a second line under the title (the e-mail and its state).
  final String? detail;
  final Color? detailColor;

  /// Round 4b: invitations waiting in My fleet.
  final int badge;
}
