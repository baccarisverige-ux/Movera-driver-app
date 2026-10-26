import 'package:movera/core/ride/active_ride_repository.dart';

/// Canonical trip lifecycle, `contracts/contract.json#tripStatus` (v0.3.0).
/// Payment and rating are separate machines, never trip statuses.
///
/// The order matches the contract's `values` list; a contract test checks it.
enum TripStatus {
  draft,
  quoted,
  requested,
  searching,
  offered,
  accepted,
  driverToPickup,
  arrived,
  riderOnboard,
  inTrip,
  approachingDropoff,
  completed,
  cancelledByRider,
  cancelledByDriver,
  cancelledByAdmin,
  cancelledBySystem,
  noShow,
  expired,
  failed,
}

extension TripStatusWire on TripStatus {
  /// The one terminal set (`contract.json#tripStatus.terminal`).
  static const Set<TripStatus> terminal = {
    TripStatus.completed,
    TripStatus.cancelledByRider,
    TripStatus.cancelledByDriver,
    TripStatus.cancelledByAdmin,
    TripStatus.cancelledBySystem,
    TripStatus.noShow,
    TripStatus.expired,
    TripStatus.failed,
  };

  /// `contract.json#tripStatus.driverAssigned`.
  static const Set<TripStatus> driverAssigned = {
    TripStatus.accepted,
    TripStatus.driverToPickup,
    TripStatus.arrived,
    TripStatus.riderOnboard,
    TripStatus.inTrip,
    TripStatus.approachingDropoff,
  };

  /// `contract.json#tripStatus.riderOnboard`.
  static const Set<TripStatus> riderOnboardSet = {
    TripStatus.riderOnboard,
    TripStatus.inTrip,
    TripStatus.approachingDropoff,
  };

  bool get isTerminal => terminal.contains(this);
  bool get isDriverAssigned => driverAssigned.contains(this);
  bool get isRiderOnboard => riderOnboardSet.contains(this);

  /// Snake_case value used on the wire, in logs and in local storage.
  String get wireName => switch (this) {
    TripStatus.draft => 'draft',
    TripStatus.quoted => 'quoted',
    TripStatus.requested => 'requested',
    TripStatus.searching => 'searching',
    TripStatus.offered => 'offered',
    TripStatus.accepted => 'accepted',
    TripStatus.driverToPickup => 'driver_to_pickup',
    TripStatus.arrived => 'arrived',
    TripStatus.riderOnboard => 'rider_onboard',
    TripStatus.inTrip => 'in_trip',
    TripStatus.approachingDropoff => 'approaching_dropoff',
    TripStatus.completed => 'completed',
    TripStatus.cancelledByRider => 'cancelled_by_rider',
    TripStatus.cancelledByDriver => 'cancelled_by_driver',
    TripStatus.cancelledByAdmin => 'cancelled_by_admin',
    TripStatus.cancelledBySystem => 'cancelled_by_system',
    TripStatus.noShow => 'no_show',
    TripStatus.expired => 'expired',
    TripStatus.failed => 'failed',
  };

  /// Reads a wire value (`driver_to_pickup`) or a legacy camelCase save
  /// (`driverToPickup`, written by builds before contract v0.3). Returns null
  /// for anything else.
  static TripStatus? tryParse(String? value) {
    if (value == null) return null;
    for (final status in TripStatus.values) {
      if (status.wireName == value || status.name == value) return status;
    }
    return null;
  }

  /// Like [tryParse], but throws [FormatException] for an unknown value.
  static TripStatus parse(String value) =>
      tryParse(value) ?? (throw FormatException('Unknown trip status', value));
}

extension ActiveRideStageAsTripStatus on ActiveRideStage {
  TripStatus get tripStatus => switch (this) {
    ActiveRideStage.headingToPickup => TripStatus.driverToPickup,
    ActiveRideStage.waitingForRider => TripStatus.arrived,
    ActiveRideStage.onTrip => TripStatus.inTrip,
  };
}
