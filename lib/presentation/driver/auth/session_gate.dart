import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/support/support_contact.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';

/// The app's first route when a session is required
/// (`MOVERA_AUTH_REQUIRED=true`): Sign in without tokens; with them the
/// live profile is read and a `pending` account (no details yet) gets the
/// details screen, every other one Home (which shows the hold until the
/// account is active). Sign-in and sign-out then replace the root
/// themselves (`enterDriverApp`, `driverRootAfterSignOut`).
class DriverSessionGate extends StatefulWidget {
  const DriverSessionGate({
    super.key,
    required this.auth,
    required this.homeBuilder,
    required this.signInBuilder,
    this.account,
    this.support,
  });

  /// Owner 2026-10-29, decision 2: how long the start waits in silence
  /// before a spinner shows.
  static const spinnerAfter = Duration(seconds: 2);

  /// "Contact support" on the error view; null: the build's address.
  final SupportContact? support;

  final AuthController auth;
  final Widget Function() homeBuilder;
  final Widget Function() signInBuilder;

  /// The live account; null skips the profile read (Home at once).
  final DriverAccountSession? account;

  @override
  State<DriverSessionGate> createState() => _DriverSessionGateState();
}

enum _Root { signIn, details, home }

class _DriverSessionGateState extends State<DriverSessionGate> {
  late Future<_Root> _root = _decide();

  /// Owner decision 2: the spinner appears only when the start takes more
  /// than [DriverSessionGate.spinnerAfter].
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _armSpinner();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _armSpinner() {
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(DriverSessionGate.spinnerAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  Future<_Root> _decide() async {
    final bool signedIn;
    try {
      signedIn = await widget.auth.hasSession();
    } catch (_) {
      return _Root.signIn;
    }
    if (!signedIn) return _Root.signIn;
    final account = widget.account;
    if (account == null) return _Root.home;
    // The profile: a network failure here is shown with a retry (the
    // account's state decides the first screen, so no guess).
    final DriverAccount profile = await account.refresh();
    return profile.needsDetails ? _Root.details : _Root.home;
  }

  void _retry() => setState(() {
    _root = _decide();
    _armSpinner();
  });

  /// Owner decision 2: a way out when the account cannot be read.
  Future<void> _signOut() async {
    try {
      await widget.auth.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _root = Future.value(_Root.signIn);
          _armSpinner();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Root>(
      future: _root,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateError(
            onRetry: _retry,
            onSignOut: _signOut,
            support: widget.support ?? const SupportContact(),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          // The store answers within a frame or two; the sign-in ground
          // meanwhile, so nothing flashes. A slow profile read (a sleeping
          // server) gets a spinner after 2 s.
          return ColoredBox(
            color: AuthColors.ground,
            child: _slow
                ? const Center(
                    key: ValueKey('gate-spinner'),
                    child: CircularProgressIndicator(color: AuthColors.ink),
                  )
                : null,
          );
        }
        return switch (snapshot.data) {
          _Root.home => widget.homeBuilder(),
          _Root.details => DriverDetailsScreen(
            account: widget.account!,
            phone: widget.auth.signedInPhone,
            prefill: widget.auth.providerLink,
            onDone: (context) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => widget.homeBuilder()),
              (_) => false,
            ),
          ),
          _ => widget.signInBuilder(),
        };
      },
    );
  }
}

/// The profile could not be read: say so, offer to try again, to sign out
/// or to write to support (owner 2026-10-29, decision 2).
class _GateError extends StatefulWidget {
  const _GateError({
    required this.onRetry,
    required this.onSignOut,
    required this.support,
  });

  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;
  final SupportContact support;

  @override
  State<_GateError> createState() => _GateErrorState();
}

class _GateErrorState extends State<_GateError> {
  bool _supportFailed = false;
  bool _signingOut = false;

  Future<void> _contact() async {
    final opened = await widget.support.openEmail(subject: tr.acctCouldNotLoad);
    if (mounted) setState(() => _supportFailed = !opened);
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final outline = OutlinedButton.styleFrom(
      foregroundColor: AuthColors.ink,
      side: const BorderSide(color: AuthColors.ink),
    );
    return Scaffold(
      backgroundColor: AuthColors.ground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr.acctCouldNotLoad,
                textAlign: TextAlign.center,
                style: AuthText.cardTitle(),
              ),
              const SizedBox(height: 8),
              Text(
                tr.authErrOffline,
                textAlign: TextAlign.center,
                style: AuthText.cardSub(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('gate-retry'),
                onPressed: widget.onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.ink,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr.gateTryAgain),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('gate-sign-out'),
                onPressed: _signingOut ? null : _signOut,
                style: outline,
                child: Text(tr.gateSignOut),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('gate-support'),
                onPressed: _contact,
                style: outline,
                child: Text(tr.contactSupport),
              ),
              if (_supportFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    tr.gateSupportUnavailable,
                    key: const ValueKey('gate-support-failed'),
                    textAlign: TextAlign.center,
                    style: AuthText.small(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
