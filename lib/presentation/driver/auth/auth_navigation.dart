import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';

/// The sign-in flow's controller for [context]: the one the app root put
/// in [DriverRuntimeScope], or null in a host without one.
AuthController? authControllerOf(BuildContext context) =>
    DriverRuntimeScope.maybeOf(context)?.auth;

/// The live account for [context] (round 4), or null in the demo and in
/// hosts without one.
DriverAccountSession? accountSessionOf(BuildContext context) =>
    DriverRuntimeScope.maybeOf(context)?.account;

/// Leaves the sign-in flow for the app, clearing it from the back stack.
///
/// The one place that decides what a signed-in driver sees first: the
/// details screen for a new driver (`isNewDriver`, or a live account still
/// `pending`), else Home ([DriverRuntimeScope.homeBuilder]); Home itself
/// shows the hold while the account is not active.
Future<void> enterDriverApp(BuildContext context) async {
  final scope = DriverRuntimeScope.maybeOf(context);
  final home = scope?.homeBuilder;
  final navigator = Navigator.of(context, rootNavigator: true);
  if (home == null) {
    // Isolated hosts (widget tests of one screen): nothing to open.
    navigator.popUntil((route) => route.isFirst);
    return;
  }
  final account = scope?.account;
  final isNew = scope?.auth?.signInResult?.isNewDriver ?? false;
  if (!isNew && account != null && account.account == null) {
    // A returning driver: read the live profile first, so one who never
    // sent the details still lands on the details screen. A failed read
    // opens Home, which shows the hold and retries.
    try {
      await account.refresh();
    } catch (_) {
      // Home handles it.
    }
    if (!context.mounted) return;
  }
  final pending = account?.account?.needsDetails ?? false;
  if (account != null && (isNew || pending)) {
    final auth = scope?.auth;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'driver-details'),
        // Step 3 of the sign-in: the phone just confirmed, and what Apple /
        // Google gave (round 4b).
        builder: (_) => DriverDetailsScreen(
          account: account,
          phone: auth?.signedInPhone,
          prefill: auth?.providerLink,
          onDone: (context) => _openHome(context, home),
        ),
      ),
      (_) => false,
    );
    return;
  }
  _openHome(context, home);
}

void _openHome(BuildContext context, Widget Function() home) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'driver-home'),
      builder: (_) => home(),
    ),
    (_) => false,
  );
}

/// The app's root after a logout or an expired session: Sign in when the
/// build requires a session, else Home (the demo path, unchanged).
Widget Function()? driverRootAfterSignOut(DriverRuntimeScope? scope) {
  final signIn = scope?.signInBuilder;
  if (DriverRuntimeConfig.current.authRequired && signIn != null) {
    return signIn;
  }
  return scope?.homeBuilder;
}

/// Puts the Sign in screen at the root, every other route gone.
void showDriverSignIn(NavigatorState navigator, Widget Function() signIn) {
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'driver-sign-in'),
      builder: (_) => signIn(),
    ),
    (_) => false,
  );
}
