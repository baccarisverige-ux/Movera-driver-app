import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

/// Round 4b (contract v0.5.3 §14, "Joining is an invitation"): the cards
/// My fleet shows for a pending invitation, and the owner's "Invite
/// driver" sheet.

/// One pending invitation: who, what, until when; Accept / Decline when
/// it waits for this account's answer, Cancel when this account sent it.
class FleetInvitationCard extends StatelessWidget {
  const FleetInvitationCard({
    super.key,
    required this.invitation,
    required this.owner,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final FleetInvitation invitation;

  /// The viewer is the fleet's owner.
  final bool owner;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final incoming = invitation.awaitsAnswerFrom(owner: owner);
    final String title;
    final String body;
    if (owner) {
      if (invitation.isDriverRequest) {
        title = invitation.driverName ?? tr.fleetADriver;
        body = tr.fleetRequestBodyOwner;
      } else {
        title =
            invitation.driverName ??
            (invitation.phone == null
                ? tr.fleetADriver
                : displayPhoneNumber(invitation.phone!));
        body = invitation.driverId == null
            ? tr.fleetInviteWaitsSignUp
            : tr.fleetInviteWaitsAnswer;
      }
    } else {
      title = invitation.fleetName;
      body = invitation.isOwnerInvite
          ? tr.fleetInviteBodyDriver
          : tr.fleetRequestWaitsOwner;
    }
    final expires = invitation.expiresAt;
    return Container(
      key: ValueKey('invitation-${invitation.invitationId}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: incoming ? const Color(0xFFF1F6F2) : AccountStyle.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: incoming ? AuthColors.green : AccountStyle.line,
          width: incoming ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AuthText.urbanist(size: 16, weight: FontWeight.w800),
                ),
              ),
              StatusChip(
                incoming ? tr.fleetInviteNew : tr.fleetStatusPending,
                color: incoming ? AuthColors.green : AccountStyle.amber,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: AccountStyle.hint()),
          if (expires != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr.fleetInviteExpires(DriverDates.dayMonth(expires.toLocal())),
                style: AuthText.urbanist(size: 12, color: AuthColors.muted),
              ),
            ),
          const SizedBox(height: 12),
          if (incoming)
            Row(
              children: [
                Expanded(
                  child: AccountButton(
                    key: ValueKey(
                      'invitation-accept-${invitation.invitationId}',
                    ),
                    label: tr.fleetAccept,
                    busy: busy,
                    onPressed: busy ? null : onAccept,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AccountButton(
                    key: ValueKey(
                      'invitation-decline-${invitation.invitationId}',
                    ),
                    label: tr.fleetDecline,
                    outlined: true,
                    onPressed: busy ? null : onDecline,
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('invitation-cancel-${invitation.invitationId}'),
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AccountStyle.error,
                ),
                child: Text(
                  busy ? tr.fleetCancelling : tr.cancel,
                  style: AuthText.urbanist(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: AccountStyle.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The count of invitations waiting for an answer, as a small red badge.
class InvitationBadge extends StatelessWidget {
  const InvitationBadge(this.count, {super.key, this.small = false});

  final int count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final size = small ? 18.0 : 22.0;
    return Semantics(
      label: tr.fleetPendingInvitations(count),
      child: Container(
        key: const ValueKey('invitation-badge'),
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6),
        decoration: BoxDecoration(
          color: const Color(0xFFD03A2B),
          borderRadius: BorderRadius.circular(size),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 11 : 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// The owner invites a phone number (`POST /driver/fleet/invite`). The
/// field starts with the fleet country's dial code (+46 Sweden, +33
/// France); the number goes as E.164. The invitation, or null when
/// dismissed.
Future<FleetInvitation?> showInviteDriverSheet(
  BuildContext context, {
  required DriverAccountSession account,
  required String fleetCountry,
}) {
  return showMoveraModalSheet<FleetInvitation>(
    context: context,
    fitContent: true,
    builder: (sheet) => Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: _InviteDriverForm(account: account, fleetCountry: fleetCountry),
      ),
    ),
  );
}

class _InviteDriverForm extends StatefulWidget {
  const _InviteDriverForm({required this.account, required this.fleetCountry});

  final DriverAccountSession account;
  final String fleetCountry;

  @override
  State<_InviteDriverForm> createState() => _InviteDriverFormState();
}

class _InviteDriverFormState extends State<_InviteDriverForm> {
  late final PhoneCountry _country =
      PhoneCountries.byIso(widget.fleetCountry) ?? PhoneCountries.sweden;
  late final _phone = TextEditingController(text: '${_country.dialLabel} ');
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      if (_error != null) setState(() => _error = null);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// E.164 from what was typed: the dial code stays unless the owner
  /// typed another one; a national "07…" after it loses its zero.
  String? get _e164 {
    var text = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (text.startsWith('00')) text = '+${text.substring(2)}';
    if (!text.startsWith('+')) {
      final national = text.startsWith('0') ? text.substring(1) : text;
      text = '${_country.dialLabel}$national';
    }
    final body = text.substring(1);
    final dial = _country.dial;
    if (body.startsWith('${dial}0') && body.length > dial.length + 1) {
      text = '+$dial${body.substring(dial.length + 1)}';
    }
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(text) ? text : null;
  }

  Future<void> _send() async {
    final phone = _e164;
    if (_busy || phone == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invitation = await widget.account.repository.inviteDriver(phone);
      if (!mounted) return;
      Navigator.of(context).pop(invitation);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(error, fallback: tr.acctTryAgain),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _e164 != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3DE),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              tr.fleetInviteDriver,
              style: AuthText.urbanist(size: 20, weight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(tr.fleetInviteDriverBody, style: AuthText.cardSub()),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('invite-phone'),
            controller: _phone,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-()]')),
              LengthLimitingTextInputFormatter(22),
            ],
            style: AuthText.urbanist(
              size: 17,
              weight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            cursorColor: AccountStyle.ink,
            onSubmitted: (_) => _send(),
            decoration:
                AccountStyle.decoration(
                  hint: '${_country.dialLabel} ${phoneHintOf(_country)}',
                  error: _error,
                ).copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Text(
                      _country.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
          ),
          const SizedBox(height: 8),
          Text(tr.fleetInviteDriverHint, style: AccountStyle.hint()),
          const SizedBox(height: 16),
          AccountButton(
            key: const ValueKey('invite-send'),
            label: tr.fleetSendInvite,
            busy: _busy,
            onPressed: ready ? _send : null,
          ),
        ],
      ),
    );
  }
}
