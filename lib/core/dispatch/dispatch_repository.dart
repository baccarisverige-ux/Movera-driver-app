import 'package:movera/core/geo/geo_point.dart';

enum ClaimOutcome {
  success,
  alreadyClaimed,
  expired,
  unavailable,
  networkError,
}

class RideOffer {
  const RideOffer({
    required this.id,
    required this.category,
    required this.fare,
    required this.rating,
    required this.pickupMinutes,
    required this.pickupKm,
    required this.tripMinutes,
    required this.tripKm,
    required this.pickup,
    required this.dropoff,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.isNearby,
    required this.followsDestination,
    this.bags = 0,
    this.payment = 'Card',
    this.reservationTime,
  });

  final String id;
  final String category;
  final String fare;
  final String rating;
  final int pickupMinutes;
  final double pickupKm;
  final int tripMinutes;
  final double tripKm;
  final String pickup;
  final String dropoff;
  final GeoPoint pickupPosition;
  final GeoPoint dropoffPosition;
  final bool isNearby;
  final bool followsDestination;

  /// Bags the rider said they bring; 0 when none.
  final int bags;

  /// How the rider pays, e.g. "Card", "Apple Pay", "Swish".
  final String payment;

  /// Set when the trip is a reservation close to pickup that still needs
  /// a driver: its pickup time, e.g. "07:40". Radar shows it as a
  /// "Reservation" trip, never as Exclusive.
  final String? reservationTime;

  bool get isReservation => reservationTime != null;
}

class ClaimResult {
  const ClaimResult._(this.outcome, {this.offer});

  const ClaimResult.success(RideOffer offer)
      : this._(ClaimOutcome.success, offer: offer);

  const ClaimResult.alreadyClaimed() : this._(ClaimOutcome.alreadyClaimed);
  const ClaimResult.expired() : this._(ClaimOutcome.expired);
  const ClaimResult.unavailable() : this._(ClaimOutcome.unavailable);
  const ClaimResult.networkError() : this._(ClaimOutcome.networkError);

  final ClaimOutcome outcome;
  final RideOffer? offer;

  bool get isSuccess => outcome == ClaimOutcome.success;
}

/// Dispatch/Radar boundary. UI must not decide an atomic winner.
abstract interface class DispatchRepository {
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  });

  Stream<List<RideOffer>> watchNextTripOffers();

  /// Radar trips and open reservations alike: the server gives each one
  /// to the first driver who claims it.
  Future<ClaimResult> claimOffer(String offerId);

  void refreshOffers();

  /// The driver who took reservation [reservationId] cancelled it: it goes
  /// back out to drivers (which step it returns to is admin job L3).
  void releaseReservation(String reservationId);
}
