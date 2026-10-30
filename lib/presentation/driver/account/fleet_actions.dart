import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// `PATCH /driver/profile { vehicleId }`: the driver picks [vehicle]. A car
/// another driver is out with is refused (`vehicle_in_use`); a stale
/// profile version is read again and the pick retried once. Says what
/// went wrong in a snackbar; true when the car is now the driver's.
Future<bool> pickFleetCar(
  BuildContext context,
  DriverAccountSession session,
  FleetVehicle vehicle,
) async {
  final repository = session.repository;
  var version = session.account?.version ?? 1;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      session.replace(await repository.pickVehicle(vehicle.vehicleId, version));
      return true;
    } catch (error) {
      final message = accountErrorMessage(
        error,
        fallback: tr.fleetCouldNotPick,
      );
      if (message == tr.acctChangedReload && attempt == 0) {
        try {
          version = (await session.refresh()).version;
          continue;
        } catch (_) {
          // The message below says to refresh.
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }
  return false;
}

/// A yes/no dialog in the account screens' plain style.
Future<bool> confirmAccountAction(
  BuildContext context, {
  required String question,
  required String yes,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialog) => MoveraDialogTheme(
      child: AlertDialog(
        backgroundColor: Colors.white,
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(tr.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-yes'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111214),
            ),
            child: Text(yes),
          ),
        ],
      ),
    ),
  );
  return answer == true;
}
