import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';

/// The app's first route when a session is required
/// (`MOVERA_AUTH_REQUIRED=true`): Home with both tokens on this device,
/// Sign in without. Decided once, from the token store; sign-in and
/// sign-out then replace the root themselves (`enterDriverApp`,
/// `driverRootAfterSignOut`).
class DriverSessionGate extends StatefulWidget {
  const DriverSessionGate({
    super.key,
    required this.auth,
    required this.homeBuilder,
    required this.signInBuilder,
  });

  final AuthController auth;
  final Widget Function() homeBuilder;
  final Widget Function() signInBuilder;

  @override
  State<DriverSessionGate> createState() => _DriverSessionGateState();
}

class _DriverSessionGateState extends State<DriverSessionGate> {
  late final Future<bool> _hasSession = widget.auth.hasSession().catchError(
    (Object _) => false,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // The store answers within a frame or two; the sign-in ground
          // meanwhile, so nothing flashes.
          return const ColoredBox(color: AuthColors.ground);
        }
        return snapshot.data == true
            ? widget.homeBuilder()
            : widget.signInBuilder();
      },
    );
  }
}
