import 'package:flutter/widgets.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/session/driver_session_controller.dart';

class DriverRuntimeScope extends InheritedWidget {
  const DriverRuntimeScope({
    super.key,
    required this.session,
    required this.homeBuilder,
    this.logout,
    this.auth,
    this.signInBuilder,
    this.account,
    required super.child,
  });
  final DriverSessionController session;
  final Widget Function() homeBuilder;

  /// Round 4: the sign-in flow's controller (tokens, codes). Null in
  /// hosts without one (isolated widget tests).
  final AuthController? auth;

  /// The Sign in screen, the app's root when auth is required and there
  /// is no session (see `enterDriverApp` / `leaveDriverApp`).
  final Widget Function()? signInBuilder;

  /// Round 4 (live): the account as the server keeps it, with its fleet,
  /// cars and documents. Null in the demo and in hosts without one.
  final DriverAccountSession? account;

  /// App-level logout: drains storage, clears local data and resets every
  /// long-lived demo service owned by the composition root.
  final Future<void> Function()? logout;
  static DriverRuntimeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DriverRuntimeScope>();
  @override
  bool updateShouldNotify(DriverRuntimeScope oldWidget) =>
      oldWidget.session != session ||
      oldWidget.homeBuilder != homeBuilder ||
      oldWidget.logout != logout ||
      oldWidget.auth != auth ||
      oldWidget.signInBuilder != signInBuilder ||
      oldWidget.account != account;
}
