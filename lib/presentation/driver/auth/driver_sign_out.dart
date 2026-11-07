import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

/// Signs the driver out (Profile › Log out and the paused-account sheet):
/// the runtime's logout, or the local clean-up in the demo, then the first
/// screen after sign-out. Returns false when it could not clear.
///
/// v0.18.49 §71 (owner Q8, S8 R4): the server refuses while the driver has
/// a current trip: he stays signed in, reads « Terminez d’abord la
/// course. » and goes back to Home, which opens that trip (the server's
/// `activeTripId`).
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
  } on SignOutOnTrip {
    if (context.mounted) showSignOutOnTrip(context);
    return true;
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

/// The refused sign-out (a current trip): the words, then Home on top, which
/// restores the server's active trip when it is not on screen yet.
void showSignOutOnTrip(BuildContext context) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(tr.fleetOnTrip)));
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}
