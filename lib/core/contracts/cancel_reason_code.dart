/// Cancel reason codes, `contracts/contract.json#cancelReasons` (v0.3.0).
///
/// Mirrors the contract; `test/contract/cancel_reason_code_test.dart`
/// checks every group and code. Titles stay in [CancelReasons] (admin-edited
/// copy); the codes are the wire values.
library;

/// The contract's reason groups. [wireName] is the `cancelReasons` key.
enum CancelReasonGroupId {
  rider('rider'),
  driverBeforeTrip('driverBeforeTrip'),
  driverDuringTrip('driverDuringTrip'),
  driverNextTrip('driverNextTrip'),
  scheduled('scheduled'),
  noShow('noShow'),
  admin('admin'),
  system('system');

  const CancelReasonGroupId(this.wireName);
  final String wireName;
}

enum CancelReasonCode {
  // rider
  pickupIncorrect('pickup_incorrect', CancelReasonGroupId.rider),
  wrongRideOption('wrong_ride_option', CancelReasonGroupId.rider),
  requestedByMistake('requested_by_mistake', CancelReasonGroupId.rider),
  waitTooLong('wait_too_long', CancelReasonGroupId.rider),
  destinationChange('destination_change', CancelReasonGroupId.rider),
  driverNotSuitable('driver_not_suitable', CancelReasonGroupId.rider),
  plansChanged('plans_changed', CancelReasonGroupId.rider),
  somethingElse('something_else', CancelReasonGroupId.rider),
  // driverBeforeTrip
  riderRequestedCancel('rider_requested_cancel', CancelReasonGroupId.driverBeforeTrip),
  riderNotAtPickup('rider_not_at_pickup', CancelReasonGroupId.driverBeforeTrip),
  unsafePickup('unsafe_pickup', CancelReasonGroupId.driverBeforeTrip),
  vehicleIssueBeforeStart('vehicle_issue_before_start', CancelReasonGroupId.driverBeforeTrip),
  driverEmergencyBeforeStart('driver_emergency_before_start', CancelReasonGroupId.driverBeforeTrip),
  otherBeforeStart('other_before_start', CancelReasonGroupId.driverBeforeTrip),
  // driverDuringTrip
  riderRequestedEarlyEnd('rider_requested_early_end', CancelReasonGroupId.driverDuringTrip),
  safetyConcernOnTrip('safety_concern_on_trip', CancelReasonGroupId.driverDuringTrip),
  vehicleIssueOnTrip('vehicle_issue_on_trip', CancelReasonGroupId.driverDuringTrip),
  accidentOrRoadEmergency('accident_or_road_emergency', CancelReasonGroupId.driverDuringTrip),
  riderBehavior('rider_behavior', CancelReasonGroupId.driverDuringTrip),
  tripOrDestinationIssue('trip_or_destination_issue', CancelReasonGroupId.driverDuringTrip),
  otherOnTrip('other_on_trip', CancelReasonGroupId.driverDuringTrip),
  // driverNextTrip
  nextTripCurrentRunningLate('next_trip_current_running_late', CancelReasonGroupId.driverNextTrip),
  nextTripPickupTooFar('next_trip_pickup_too_far', CancelReasonGroupId.driverNextTrip),
  nextTripRiderRequested('next_trip_rider_requested', CancelReasonGroupId.driverNextTrip),
  nextTripVehicleIssue('next_trip_vehicle_issue', CancelReasonGroupId.driverNextTrip),
  nextTripDriverEmergency('next_trip_driver_emergency', CancelReasonGroupId.driverNextTrip),
  nextTripOther('next_trip_other', CancelReasonGroupId.driverNextTrip),
  // scheduled
  scheduledCannotMakeTime('scheduled_cannot_make_time', CancelReasonGroupId.scheduled),
  scheduledVehicleIssue('scheduled_vehicle_issue', CancelReasonGroupId.scheduled),
  scheduledPersonalEmergency('scheduled_personal_emergency', CancelReasonGroupId.scheduled),
  scheduledPickupTooFar('scheduled_pickup_too_far', CancelReasonGroupId.scheduled),
  scheduledTripDetails('scheduled_trip_details', CancelReasonGroupId.scheduled),
  scheduledOther('scheduled_other', CancelReasonGroupId.scheduled),
  // noShow
  riderNoShow('rider_no_show', CancelReasonGroupId.noShow),
  // admin
  adminSafety('admin_safety', CancelReasonGroupId.admin),
  adminFraud('admin_fraud', CancelReasonGroupId.admin),
  adminRiderRequest('admin_rider_request', CancelReasonGroupId.admin),
  adminDriverRequest('admin_driver_request', CancelReasonGroupId.admin),
  adminOperational('admin_operational', CancelReasonGroupId.admin),
  adminOther('admin_other', CancelReasonGroupId.admin),
  // system
  systemNoDriver('system_no_driver', CancelReasonGroupId.system),
  systemPaymentFailed('system_payment_failed', CancelReasonGroupId.system),
  systemZoneClosed('system_zone_closed', CancelReasonGroupId.system),
  systemError('system_error', CancelReasonGroupId.system);

  const CancelReasonCode(this.wireName, this.group);

  /// Snake_case code sent as `reasonCode`.
  final String wireName;
  final CancelReasonGroupId group;

  static CancelReasonCode? tryParse(String? value) {
    for (final code in CancelReasonCode.values) {
      if (code.wireName == value) return code;
    }
    return null;
  }

  static Iterable<CancelReasonCode> inGroup(CancelReasonGroupId group) =>
      CancelReasonCode.values.where((code) => code.group == group);
}
