import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
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
  });

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

  void _retry() => setState(() => _root = _decide());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Root>(
      future: _root,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateError(onRetry: _retry);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          // The store answers within a frame or two; the sign-in ground
          // meanwhile, so nothing flashes.
          return const ColoredBox(color: AuthColors.ground);
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

/// The profile could not be read: say so, offer to try again.
class _GateError extends StatelessWidget {
  const _GateError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.ground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.ink,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
