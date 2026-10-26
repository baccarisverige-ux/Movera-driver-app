import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/fleet_actions.dart';
import 'package:movera/presentation/driver/account/fleet_car_card.dart';
import 'package:movera/presentation/driver/account/fleet_invitations.dart';
import 'package:movera/presentation/driver/account/join_fleet_screen.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:share_plus/share_plus.dart';

/// Profile › My fleet (live, contract v0.5.3 §14). A driver account
/// without a fleet answers the owners' invites here, sees his own open
/// request (Cancel) or asks to join one; a member sees the company, its
/// approved cars (picks the one he drives) and can leave; the owner sees
/// the company with its code to share, the pending requests (Accept /
/// Decline) and his invites (Cancel, and Invite driver by phone), every
/// driver (with Remove) and every car (with Add car). The profile and the
/// invitations are read again when the screen opens or the app comes back
/// (round 4b).
class MyFleetScreen extends StatefulWidget {
  const MyFleetScreen({super.key, required this.account, this.share});

  final DriverAccountSession account;

  /// The share sheet; tests hand in a recorder.
  final Future<void> Function(String text)? share;

  @override
  State<MyFleetScreen> createState() => _MyFleetScreenState();
}

class _MyFleetScreenState extends State<MyFleetScreen>
    with WidgetsBindingObserver {
  FleetView? _view;

  /// Round 4b: a driver account's incoming invites and own request.
  List<FleetInvitation> _invitations = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  DriverAccount? get _me => widget.account.account;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.account.addListener(_accountChanged);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.account.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: an invitation may have come or been
    // answered meanwhile.
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_me?.awaitsFleet ?? false) {
        final invitations = await widget.account.repository.invitations();
        if (!mounted) return;
        setState(() {
          _view = null;
          _invitations = invitations;
        });
      } else {
        final view = await widget.account.repository.fleet();
        if (!mounted) return;
        setState(() {
          _view = view;
          _invitations = const [];
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _error = accountErrorMessage(error, fallback: tr.fleetCouldNotLoad),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The profile first (the fleet, the badge), then the fleet view or
  /// the invitations.
  Future<void> _refreshAll() async {
    try {
      await widget.account.refresh();
    } catch (_) {
      // The fleet view below says what failed.
    }
    if (mounted) await _load();
  }

  /// Round 4b: accept, decline or cancel one invitation, then read
  /// everything again (an accept links the driver: the fleet shows).
  Future<void> _decide(FleetInvitation invitation, String action) async {
    if (action == 'decline' || action == 'cancel') {
      final yes = await confirmAccountAction(
        context,
        question: action == 'cancel'
            ? tr.fleetCancelInviteQ
            : tr.fleetDeclineInviteQ(
                _me?.fleet?.isOwner == true
                    ? (invitation.driverName ?? tr.fleetADriver)
                    : invitation.fleetName,
              ),
        yes: action == 'cancel' ? tr.fleetCancelInvite : tr.fleetDecline,
      );
      if (!yes || !mounted) return;
    }
    setState(() => _busyId = invitation.invitationId);
    try {
      final repository = widget.account.repository;
      final result = await switch (action) {
        'accept' => repository.acceptInvitation(invitation.invitationId),
        'decline' => repository.declineInvitation(invitation.invitationId),
        _ => repository.cancelInvitation(invitation.invitationId),
      };
      if (!mounted) return;
      if (action == 'accept' && result.status == 'accepted') {
        _snack(
          _me?.fleet?.isOwner == true
              ? tr.fleetDriverJoined(result.driverName ?? tr.fleetADriver)
              : tr.fleetJoined(result.fleetName),
        );
      }
      await _refreshAll();
    } catch (error) {
      if (mounted) {
        _snack(accountErrorMessage(error, fallback: tr.acctTryAgain));
        await _refreshAll();
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _invite(Fleet fleet) async {
    final invitation = await showInviteDriverSheet(
      context,
      account: widget.account,
      fleetCountry: fleet.country,
    );
    if (invitation == null || !mounted) return;
    _snack(
      tr.fleetInviteSent(
        invitation.phone == null
            ? invitation.driverName ?? ''
            : displayPhoneNumber(invitation.phone!),
      ),
    );
    await _refreshAll();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _share(Fleet fleet) async {
    final text = tr.fleetCodeShareText(
      fleet.name,
      fleet.code ?? '',
      fleet.ownerName,
      fleet.ownerEmail ?? _me?.email ?? '',
    );
    final share = widget.share;
    if (share != null) {
      await share(text);
    } else {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _snack(tr.fleetCodeCopied);
  }

  Future<void> _pick(FleetVehicle vehicle) async {
    setState(() => _busyId = vehicle.vehicleId);
    try {
      if (await pickFleetCar(context, widget.account, vehicle)) await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _leave(Fleet fleet) async {
    final yes = await confirmAccountAction(
      context,
      question: tr.fleetLeaveQ(fleet.name),
      yes: tr.fleetLeave,
    );
    if (!yes || !mounted) return;
    setState(() => _busyId = 'leave');
    try {
      widget.account.replace(await widget.account.repository.leaveFleet());
      await _load();
    } catch (error) {
      if (mounted) {
        _snack(accountErrorMessage(error, fallback: tr.acctTryAgain));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(FleetDriver driver) async {
    final yes = await confirmAccountAction(
      context,
      question: tr.fleetRemoveDriverQ(driver.fullName),
      yes: tr.fleetRemove,
    );
    if (!yes || !mounted) return;
    setState(() => _busyId = driver.driverId);
    try {
      await widget.account.repository.removeFleetDriver(driver.driverId);
      await _load();
    } catch (error) {
      if (mounted) {
        _snack(accountErrorMessage(error, fallback: tr.acctTryAgain));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _addCar() async {
    await pushSingle(
      context,
      RightToLeftTransition(AddCarScreen(account: widget.account)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _me?.pendingFleetInvitations ?? 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.myFleet,
        onBack: () => maybePopOwned(context),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: InvitationBadge(pending)),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final me = _me;
    if (me != null && me.awaitsFleet) {
      return _awaitingFleet(me);
    }
    if (_loading && _view == null) {
      return const Center(
        child: CircularProgressIndicator(color: AccountStyle.ink),
      );
    }
    final view = _view;
    if (view == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_error ?? tr.fleetNotInOne, style: AccountStyle.body()),
          const SizedBox(height: 16),
          AccountButton(label: tr.retry, outlined: true, onPressed: _load),
        ],
      );
    }
    final owner = me?.fleet?.isOwner ?? false;
    final requests = [
      for (final i in view.invitations)
        if (i.isPending && i.isDriverRequest) i,
    ];
    final invites = [
      for (final i in view.invitations)
        if (i.isPending && i.isOwnerInvite) i,
    ];
    return RefreshIndicator(
      color: AccountStyle.ink,
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (_error != null) AccountErrorLine(_error!),
          _FleetCard(fleet: view.fleet, owner: owner),
          if (owner) ...[
            const SizedBox(height: 14),
            _CodeCard(
              fleet: view.fleet,
              onShare: () => _share(view.fleet),
              onCopy: view.fleet.code == null
                  ? null
                  : () => _copy(view.fleet.code!),
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: 22),
              _section(
                tr.fleetRequests,
                tr.fleetInvitationCount(requests.length),
              ),
              for (final invitation in requests) ...[
                FleetInvitationCard(
                  invitation: invitation,
                  owner: true,
                  busy: _busyId == invitation.invitationId,
                  onAccept: () => _decide(invitation, 'accept'),
                  onDecline: () => _decide(invitation, 'decline'),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 22),
            _section(tr.fleetInvites, tr.fleetInvitationCount(invites.length)),
            if (invites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(tr.fleetNoInvites, style: AccountStyle.hint()),
              ),
            for (final invitation in invites) ...[
              FleetInvitationCard(
                invitation: invitation,
                owner: true,
                busy: _busyId == invitation.invitationId,
                onCancel: () => _decide(invitation, 'cancel'),
              ),
              const SizedBox(height: 10),
            ],
            AccountButton(
              key: const ValueKey('fleet-invite-driver'),
              label: tr.fleetInviteDriver,
              outlined: true,
              onPressed: view.fleet.isApproved
                  ? () => _invite(view.fleet)
                  : () => _snack(tr.fleetNotApprovedYet),
            ),
            const SizedBox(height: 22),
            _section(tr.fleetDrivers, tr.fleetMemberCount(view.drivers.length)),
            if (view.drivers.isEmpty)
              Text(tr.fleetNoDrivers, style: AccountStyle.hint())
            else
              for (final driver in view.drivers)
                _DriverRow(
                  driver: driver,
                  isMe: driver.driverId == me?.driverId,
                  busy: _busyId == driver.driverId,
                  onRemove: driver.driverId == me?.driverId
                      ? null
                      : () => _remove(driver),
                ),
          ],
          const SizedBox(height: 22),
          _section(tr.fleetCars, tr.fleetCarCount(view.vehicles.length)),
          if (view.vehicles.isEmpty)
            Text(
              owner ? tr.fleetNoCars : tr.fleetNoCarsMember,
              style: AccountStyle.hint(),
            ),
          for (final vehicle in view.vehicles) ...[
            FleetCarCard(
              vehicle: vehicle,
              myDriverId: me?.driverId ?? '',
              pickedByName: owner
                  ? view.drivers
                        .where((d) => d.driverId == vehicle.driverId)
                        .map((d) => d.fullName)
                        .firstOrNull
                  : null,
              busy: _busyId == vehicle.vehicleId,
              onPick: () => _pick(vehicle),
            ),
            const SizedBox(height: 10),
          ],
          if (owner) ...[
            const SizedBox(height: 6),
            AccountButton(
              key: const ValueKey('fleet-add-car'),
              label: tr.fleetAddCar,
              onPressed: _addCar,
            ),
          ] else ...[
            const SizedBox(height: 18),
            AccountButton(
              key: const ValueKey('fleet-leave'),
              label: tr.fleetLeave,
              outlined: true,
              busy: _busyId == 'leave',
              onPressed: () => _leave(view.fleet),
            ),
          ],
        ],
      ),
    );
  }

  /// Round 4b: a driver account without a fleet. The owners' invites
  /// first (Accept / Decline), then his own open request (Cancel), else
  /// the join form.
  Widget _awaitingFleet(DriverAccount me) {
    final incoming = [
      for (final i in _invitations)
        if (i.isPending && i.isOwnerInvite) i,
    ];
    final own = [
      for (final i in _invitations)
        if (i.isPending && i.isDriverRequest) i,
    ];
    return RefreshIndicator(
      color: AccountStyle.ink,
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (_error != null) AccountErrorLine(_error!),
          if (incoming.isNotEmpty) ...[
            _section(tr.fleetInvites, tr.fleetInvitationCount(incoming.length)),
            for (final invitation in incoming) ...[
              FleetInvitationCard(
                invitation: invitation,
                owner: false,
                busy: _busyId == invitation.invitationId,
                onAccept: () => _decide(invitation, 'accept'),
                onDecline: () => _decide(invitation, 'decline'),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],
          if (own.isNotEmpty) ...[
            _section(tr.fleetYourRequest, ''),
            for (final invitation in own) ...[
              FleetInvitationCard(
                invitation: invitation,
                owner: false,
                busy: _busyId == invitation.invitationId,
                onCancel: () => _decide(invitation, 'cancel'),
              ),
              const SizedBox(height: 10),
            ],
          ] else if (_loading && _invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AccountStyle.ink),
              ),
            )
          else
            JoinFleetForm(
              account: widget.account,
              onRequested: (context, invitation) {
                _snack(tr.fleetRequestSent(invitation.fleetName));
                _refreshAll();
              },
            ),
        ],
      ),
    );
  }

  Widget _section(String title, String count) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title.toUpperCase(), style: AccountStyle.section()),
        ),
        Text(count, style: AccountStyle.hint()),
      ],
    ),
  );
}

(String, Color) fleetStatusOf(String status) => switch (status) {
  'approved' => (tr.fleetStatusApproved, AccountStyle.green),
  'rejected' => (tr.fleetStatusRejected, AccountStyle.error),
  'blocked' => (tr.fleetStatusBlocked, AccountStyle.error),
  _ => (tr.fleetStatusPending, AccountStyle.amber),
};

class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.fleet, required this.owner});

  final Fleet fleet;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final (label, color) = fleetStatusOf(fleet.status);
    return Container(
      key: const ValueKey('fleet-card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AccountStyle.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AccountStyle.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (owner ? tr.fleetYourCompany : tr.fleetYourFleet).toUpperCase(),
            style: AccountStyle.section(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  fleet.name,
                  style: AuthText.urbanist(size: 20, weight: FontWeight.w800),
                ),
              ),
              StatusChip(label, color: color),
            ],
          ),
          if (owner) ...[
            const SizedBox(height: 4),
            Text(
              tr.fleetOrgNumber(fleet.orgNumber),
              style: AccountStyle.hint(),
            ),
            if (fleet.address != null)
              Text(fleet.address!, style: AccountStyle.hint()),
          ] else ...[
            const SizedBox(height: 4),
            Text(fleet.ownerName, style: AccountStyle.hint()),
          ],
        ],
      ),
    );
  }
}

/// The owner's join code, large, with Share and Copy; before approval a
/// line says Movera has not approved the fleet yet.
class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.fleet,
    required this.onShare,
    required this.onCopy,
  });

  final Fleet fleet;
  final VoidCallback onShare;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final code = fleet.isApproved ? fleet.code : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AccountStyle.ink, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr.fleetCode.toUpperCase(), style: AccountStyle.section()),
          const SizedBox(height: 8),
          if (code == null)
            Text(
              tr.fleetCodeWaiting,
              key: const ValueKey('fleet-code-waiting'),
              style: AuthText.urbanist(
                size: 16,
                weight: FontWeight.w600,
                color: AccountStyle.amber,
              ),
            )
          else ...[
            SelectableText(
              code,
              key: const ValueKey('fleet-code'),
              style: AuthText.urbanist(
                size: 36,
                weight: FontWeight.w800,
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(tr.fleetCodeHint, style: AccountStyle.hint()),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AccountButton(
                    key: const ValueKey('fleet-share'),
                    label: tr.fleetShare,
                    onPressed: onShare,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AccountButton(
                    key: const ValueKey('fleet-copy'),
                    label: tr.fleetCopy,
                    outlined: true,
                    onPressed: onCopy,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.driver,
    required this.isMe,
    required this.busy,
    required this.onRemove,
  });

  final FleetDriver driver;
  final bool isMe;
  final bool busy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final online = driver.onlineStatus != 'offline';
    return Container(
      key: ValueKey('fleet-driver-${driver.driverId}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AccountStyle.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? AccountStyle.green : AccountStyle.line,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.fullName, style: AccountStyle.rowTitle()),
                Text(
                  '${online ? tr.fleetOnline : tr.fleetOffline} · '
                  '${driver.accountStatus == 'active' ? tr.fleetStatusApproved : tr.fleetStatusPending}',
                  style: AccountStyle.hint(),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            TextButton(
              key: ValueKey('fleet-remove-${driver.driverId}'),
              onPressed: busy ? null : onRemove,
              style: TextButton.styleFrom(foregroundColor: AccountStyle.error),
              child: Text(
                tr.fleetRemove,
                style: AuthText.urbanist(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: AccountStyle.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
