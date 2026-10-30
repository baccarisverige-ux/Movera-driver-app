import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/keep_above_keyboard.dart';

/// A driver account without a fleet asks to join one (`POST
/// /driver/fleet/join`, round 4b): the owner's code, name and e-mail must
/// all match (one message covers any mismatch, ten tries an hour), and
/// the owner then accepts or declines the request.
class JoinFleetScreen extends StatelessWidget {
  const JoinFleetScreen({super.key, required this.account, this.onRequested});

  final DriverAccountSession account;

  /// After the request went out; the default pops the screen.
  final void Function(BuildContext context, FleetInvitation invitation)?
  onRequested;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.myFleet,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            JoinFleetForm(
              account: account,
              onRequested:
                  onRequested ?? (context, _) => maybePopOwned(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The join form itself; My fleet shows it in place for a driver without
/// a fleet and no open request.
class JoinFleetForm extends StatefulWidget {
  const JoinFleetForm({
    super.key,
    required this.account,
    required this.onRequested,
  });

  final DriverAccountSession account;
  final void Function(BuildContext context, FleetInvitation invitation)
  onRequested;

  @override
  State<JoinFleetForm> createState() => _JoinFleetFormState();
}

class _JoinFleetFormState extends State<JoinFleetForm> {
  final _code = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    for (final c in [_code, _owner, _email]) {
      c.addListener(() {
        if (_error != null) setState(() => _error = null);
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _owner.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _complete =>
      _code.text.trim().length >= 5 &&
      _owner.text.trim().isNotEmpty &&
      _emailPattern.hasMatch(_email.text.trim());

  Future<void> _join() async {
    if (_busy || !_complete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invitation = await widget.account.repository.joinFleet(
        _code.text,
        _owner.text,
        _email.text,
      );
      if (!mounted) return;
      widget.onRequested(context, invitation);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.fleetJoinTitle, style: AccountStyle.title()),
        const SizedBox(height: 8),
        Text(tr.fleetJoinBody, style: AccountStyle.hint()),
        const SizedBox(height: 20),
        _field(
          'join-code',
          tr.acctFleetCode,
          _code,
          hint: 'MV-',
          capitalization: TextCapitalization.characters,
        ),
        _field(
          'join-owner',
          tr.acctOwnerName,
          _owner,
          capitalization: TextCapitalization.words,
        ),
        _field(
          'join-email',
          tr.acctOwnerEmail,
          _email,
          keyboard: TextInputType.emailAddress,
        ),
        if (_error != null) AccountErrorLine(_error!),
        const SizedBox(height: 12),
        KeepAboveKeyboard(
          child: ListenableBuilder(
            listenable: Listenable.merge([_code, _owner, _email]),
            builder: (context, _) => AccountButton(
              key: const ValueKey('join-submit'),
              label: tr.fleetAskToJoin,
              busy: _busy,
              onPressed: _complete ? _join : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr.fleetAskToJoinHint,
          textAlign: TextAlign.center,
          style: AccountStyle.hint(),
        ),
      ],
    );
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: AccountStyle.label()),
          ),
          TextField(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            keyboardType: keyboard,
            textCapitalization: capitalization,
            style: AuthText.urbanist(size: 15),
            cursorColor: AccountStyle.ink,
            decoration: AccountStyle.decoration(hint: hint),
          ),
        ],
      ),
    );
  }
}
