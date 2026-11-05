import 'package:movera/core/content/driver_app_texts.dart';
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

/// The card's words in the driver's language (sv / fr / en). Kept here and
/// not in `lib/l10n/app_*.arb`: those files are over the rule-25 size limit
/// until their split job runs; move these keys there with that split.
abstract final class NextBookedRideTexts {
  /// "Next: booked ride at 14:05".
  static String title(String time) => switch (DriverAppTexts.language) {
    'sv' => 'Nästa: bokad resa kl. $time',
    'fr' => 'Suivante : course réservée à $time',
    _ => 'Next: booked ride at $time',
  };

  /// "After this trip, drive to the pickup".
  static String get hint => switch (DriverAppTexts.language) {
    'sv' => 'Efter den här resan, kör till upphämtningen',
    'fr' => 'Après cette course, allez à la prise en charge',
    _ => 'After this trip, drive to the pickup',
  };
}
