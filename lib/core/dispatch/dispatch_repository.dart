import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';

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
    this.riderName = '',
    this.riderTrips = 0,
    this.stops = const <ReservationStop>[],
    this.fareBoost,
    this.cashToCollect,
  });

  /// A reservation as a Radar trip. The driver's distance to the pickup is
  /// not known here, so the demo uses a fixed one.
  factory RideOffer.reservation(ReservationRequestPreview reservation) =>
      RideOffer(
        id: reservation.id,
        category: reservation.category,
        fare: Money.parseSekLabel(reservation.fare)?.formatted ??
            reservation.fare,
        rating: reservation.rating,
        pickupMinutes: 16,
        pickupKm: 2.1,
        tripMinutes: reservation.tripMinutes,
        tripKm: reservation.tripKm,
        pickup: reservation.pickupAddress,
        dropoff: reservation.dropoffAddress,
        pickupPosition: reservation.pickup,
        dropoffPosition: reservation.dropoff,
        isNearby: true,
        followsDestination: false,
        payment: reservation.paidByCash ? 'Cash' : 'Card',
        reservationTime: reservation.pickupTime,
        riderName: reservation.riderName,
        riderTrips: reservation.riderTrips,
        stops: reservation.stops,
        fareBoost: reservation.fareBoost,
        cashToCollect: reservation.paidByCash ? reservation.cashToCollect : null,
      );

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

  /// The rider's first name and trips, for the trip screen; empty / 0
  /// when not known.
  final String riderName;
  final int riderTrips;

  /// Stops between pickup and drop-off, in driving order.
  final List<ReservationStop> stops;

  /// Admin raised the fare, e.g. "+40 kr"; [fare] already includes it.
  final String? fareBoost;

  /// R8-4: on a cash trip, the cash to take from the rider when it is not
  /// the fare (rider promotions), e.g. "250 kr". Null: the fare.
  final String? cashToCollect;

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
  /// back out to drivers, to the step the admin rule "After a driver
  /// cancels" says (Radar trips too when it is close to pickup).
  void releaseReservation(String reservationId);

  /// Scheduled rides Movera assigns to this driver (Q29). Each needs the
  /// driver's Accept, claimed through [claimOffer], in time.
  Stream<ReservationRequestPreview> watchAssignments();
}
