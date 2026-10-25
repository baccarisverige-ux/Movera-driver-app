import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';

/// A fleet's car as My fleet and Vehicles show it: make, model, plate,
/// its review status, who drives it, and "Choose this car" for an
/// approved car that is free (or picked by an offline driver).
class FleetCarCard extends StatelessWidget {
  const FleetCarCard({
    super.key,
    required this.vehicle,
    required this.myDriverId,
    this.pickedByName,
    this.onPick,
    this.busy = false,
  });

  final FleetVehicle vehicle;
  final String myDriverId;

  /// The owner's view knows the drivers' names.
  final String? pickedByName;

  /// Null hides the pick button (a car that is not approved).
  final VoidCallback? onPick;
  final bool busy;

  static (String, Color) statusOf(String status) => switch (status) {
    'approved' => (tr.vehStatusApproved, AccountStyle.green),
    'rejected' => (tr.vehStatusRejected, AccountStyle.error),
    'blocked' => (tr.vehStatusBlocked, AccountStyle.error),
    _ => (tr.vehStatusPending, AccountStyle.amber),
  };

  @override
  Widget build(BuildContext context) {
    final mine = vehicle.driverId == myDriverId;
    final takenByOther = vehicle.driverId != null && !mine;
    final (statusLabel, statusColor) = statusOf(vehicle.status);
    final types = [
      for (final id in vehicle.categoryIds)
        CategoryCatalog.driverLabels[id] ?? id,
    ].join(' · ');
    return Container(
      key: ValueKey('car-${vehicle.vehicleId}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? AccountStyle.ink : AccountStyle.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicle.title,
                  style: AuthText.urbanist(size: 17, weight: FontWeight.w800),
                ),
              ),
              StatusChip(statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              vehicle.plate,
              vehicle.color,
              tr.fleetCarSeatsCount(vehicle.seats),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: AccountStyle.hint(),
          ),
          if (types.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(types, style: AccountStyle.hint()),
            ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AccountStyle.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr.fleetYourCar,
                    style: AuthText.urbanist(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AccountStyle.green,
                    ),
                  ),
                ],
              ),
            )
          else if (takenByOther && vehicle.inUse)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                tr.fleetInUse,
                key: ValueKey('car-in-use-${vehicle.vehicleId}'),
                style: AuthText.urbanist(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: AccountStyle.muted,
                ),
              ),
            )
          else if (takenByOther && pickedByName != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                tr.fleetPickedBy(pickedByName!),
                style: AccountStyle.hint(),
              ),
            ),
          if (!mine && onPick != null && vehicle.isApproved)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: AccountButton(
                  key: ValueKey('car-pick-${vehicle.vehicleId}'),
                  label: tr.fleetChooseCar,
                  outlined: true,
                  busy: busy,
                  // In use by another driver: shown, not tappable.
                  onPressed: takenByOther && vehicle.inUse ? null : onPick,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
