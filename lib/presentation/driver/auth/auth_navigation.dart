import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';

/// The sign-in flow's controller for [context]: the one the app root put
/// in [DriverRuntimeScope], or null in a host without one.
AuthController? authControllerOf(BuildContext context) =>
    DriverRuntimeScope.maybeOf(context)?.auth;

/// Leaves the sign-in flow for the app, clearing it from the back stack.
///
/// The one place that decides what a signed-in driver sees first. For now
/// that is always Home ([DriverRuntimeScope.homeBuilder]). Round 5 hook:
/// `authControllerOf(context)?.signInResult?.isNewDriver` (and the
/// account's pending state) choose the details screen here instead.
void enterDriverApp(BuildContext context) {
  final scope = DriverRuntimeScope.maybeOf(context);
  final home = scope?.homeBuilder;
  final navigator = Navigator.of(context, rootNavigator: true);
  if (home == null) {
    // Isolated hosts (widget tests of one screen): nothing to open.
    navigator.popUntil((route) => route.isFirst);
    return;
  }
  navigator.pushAndRemoveUntil(
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
