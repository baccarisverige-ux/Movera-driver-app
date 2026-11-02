import 'package:flutter/material.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

/// Signs the driver out (Profile › Log out and the paused-account sheet):
/// the runtime's logout, or the local clean-up in the demo, then the first
/// screen after sign-out. Returns false when it could not clear.
Future<bool> signOutDriver(BuildContext context) async {
  final runtime = DriverRuntimeScope.maybeOf(context);
  try {
    if (runtime?.logout != null) {
      await runtime!.logout!();
    } else {
      await clearLocalUserData();
      ScheduledRideStore.reset();
      IslandMessages.clear(); // driver-r5-27
      runtime?.session.reset();
    }
  } catch (_) {
    return false;
  }
  if (!context.mounted) {
    return true;
  }
  // uat-d2: the demo landing screen is gone; a logged-out driver is
  // back on Home (demo mode). Round 4: a build that requires a session
  // lands on Sign in instead (driverRootAfterSignOut).
  final home = driverRootAfterSignOut(runtime);
  if (home == null) {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    return true;
  }
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => home()),
    (route) => false,
  );
  return true;
}
