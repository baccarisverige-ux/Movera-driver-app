import 'package:movera/core/scheduled/server_reservations.dart';

/// Fix job 5 (contract v0.18.33, `contract.json#afterTestRules.bookedNext`,
/// owner Q7): a driver on a trip may hold a booked ride as his next one. The
/// trip sheet shows "Next: booked ride at 14:05" for the soonest booked ride
/// he holds (not the trip he is driving), until 30 min after its pickup time.
ServerReservation? nextBookedRide(
  List<ServerReservation> accepted,
  DateTime now, {
  String? currentTripId,
}) {
  ServerReservation? soonest;
  for (final ride in accepted) {
    if (!ride.accepted || ride.tripId == currentTripId) continue;
    if (ride.scheduledAt.isBefore(now.subtract(const Duration(minutes: 30)))) {
      continue;
    }
    if (soonest == null || ride.scheduledAt.isBefore(soonest.scheduledAt)) {
      soonest = ride;
    }
  }
  return soonest;
}
