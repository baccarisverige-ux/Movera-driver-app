import 'package:flutter/foundation.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/next_booked_ride.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// Fix job 5 (contract v0.18.33, owner 2026-11-05 "Add on sheet when on trip
/// after accept second trip or if its time to drive to reservation!
/// Notification popup after finish current trip"): the trip a driver on a
/// trip does next — a live trip he accepted as an Exclusive (queued behind
/// this one) or a booked ride whose time to drive is near.
class NextTrip {
  const NextTrip({
    required this.tripId,
    required this.riderName,
    required this.pickupAddress,
    this.pickupAt,
    this.booked = false,
  });

  final String tripId;
  final String riderName;
  final String pickupAddress;

  /// A booked ride's pickup time; null for a queued live trip.
  final DateTime? pickupAt;
  final bool booked;

  /// The queued live trip of a `TripProjection` (driver view).
  static NextTrip? fromQueued(Map<String, dynamic>? projection) {
    final id = projection?['tripId'];
    if (projection == null || id is! String) return null;
    final rider = projection['rider'];
    final pickup = projection['pickup'];
    return NextTrip(
      tripId: id,
      riderName: rider is Map && rider['firstName'] is String
          ? rider['firstName'] as String
          : '',
      pickupAddress: pickup is Map && pickup['address'] is String
          ? pickup['address'] as String
          : '',
    );
  }

  static NextTrip fromBooked(ServerReservation ride) => NextTrip(
    tripId: ride.tripId,
    riderName: '',
    pickupAddress: ride.pickupAddress,
    pickupAt: ride.scheduledAt,
    booked: true,
  );
}

/// A booked ride's time to drive is near: its leave time (from the server's
/// road-route ETA) within 30 min, or, before the server knows it, a pickup
/// within 60 min.
bool bookedDriveNear(ServerReservation ride, DateTime now) {
  final leave = ride.leaveAt;
  if (leave != null) {
    return !leave.isAfter(now.add(const Duration(minutes: 30)));
  }
  return !ride.scheduledAt.isAfter(now.add(const Duration(minutes: 60)));
}

/// The next trip after [currentTripId]: a queued live trip first, else the
/// soonest held booked ride whose time to drive is near.
NextTrip? nextTripAfter(
  String currentTripId, {
  Map<String, dynamic>? queued,
  List<ServerReservation> accepted = const [],
  required DateTime now,
}) {
  final live = NextTrip.fromQueued(queued);
  if (live != null) return live;
  final booked = nextBookedRide(accepted, now, currentTripId: currentTripId);
  if (booked != null && bookedDriveNear(booked, now)) {
    return NextTrip.fromBooked(booked);
  }
  return null;
}

/// The popup the next trip's screen shows once, after the current trip ends
/// (owner: information only, one OK button).
final ValueNotifier<NextTrip?> nextTripNotice = ValueNotifier<NextTrip?>(null);

/// Right after Complete (live build): the next trip opened on the server and
/// read back as the driver's current trip, or null. A queued live trip
/// already became current on the server; a near booked ride is started
/// (`POST /driver/reservations/{id}/start`).
Future<({NextTrip next, PersistedActiveRide ride})?> openNextTripAfter(
  String currentTripId, {
  DateTime Function() now = DateTime.now,
}) async {
  final live = LiveDriverServices.instance;
  if (live == null) return null;
  try {
    final queued = live.trips.queuedAfter(currentTripId);
    var accepted = const <ServerReservation>[];
    if (queued == null) accepted = (await live.reservations.load()).accepted;
    final next = nextTripAfter(
      currentTripId,
      queued: queued,
      accepted: accepted,
      now: now(),
    );
    if (next == null) return null;
    if (next.booked && await live.reservations.start(next.tripId) != null) {
      return null;
    }
    final found = await live.activeTrip.fetch();
    if (found == null || found.ride.tripId != next.tripId) return null;
    live.trips.observe(found.projection);
    return (next: next, ride: found.ride.stamped());
  } catch (_) {
    return null;
  }
}
