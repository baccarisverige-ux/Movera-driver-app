import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';

enum ActiveRideStage { headingToPickup, waitingForRider, onTrip }

/// Queued next trip captured with the live ride so a reload can resume both.
class PersistedQueuedTrip {
  const PersistedQueuedTrip({
    required this.tripId,
    required this.riderName,
    required this.fare,
    required this.category,
    required this.pickup,
    required this.dropoff,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.rating = 4.9,
    this.pickupMinutes = 4,
    this.tripMinutes = 16,
    this.pickupPay,
  });

  final String tripId;
  final String riderName;

  /// The driver's pay for the queued trip (owner decision 2026-10-26), as
  /// [PersistedActiveRide.fare]; a restored trip shows it as saved.
  final String fare;
  final String category;
  final String pickup;
  final String dropoff;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double rating;
  final int pickupMinutes;
  final int tripMinutes;

  /// The pickup pay accepted with it, on top of [fare] (driver-12).
  final Money? pickupPay;

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'riderName': riderName,
    'fare': fare,
    'category': category,
    'pickup': pickup,
    'dropoff': dropoff,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'dropoffLat': dropoffLat,
    'dropoffLng': dropoffLng,
    'rating': rating,
    'pickupMinutes': pickupMinutes,
    'tripMinutes': tripMinutes,
    if (pickupPay != null) 'pickupPay': pickupPay!.toJson(),
  };

  static PersistedQueuedTrip? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final tripId = json['tripId'] as String?;
    if (tripId == null || tripId.trim().isEmpty) {
      return null;
    }
    if (!['pickupLat', 'pickupLng', 'dropoffLat', 'dropoffLng'].every(
      (key) => validCoordinate(json[key], latitude: key.endsWith('Lat')),
    )) {
      return null;
    }
    // Preview metadata is optional, but when supplied it must be usable.
    // Bad estimates cannot become negative time/countdown labels.
    final rating = json['rating'];
    if (rating != null &&
        (rating is! num || !rating.isFinite || rating < 0 || rating > 5)) {
      return null;
    }
    for (final key in ['pickupMinutes', 'tripMinutes']) {
      final minutes = json[key];
      if (minutes != null && (minutes is! int || minutes < 0)) {
        return null;
      }
    }
    return PersistedQueuedTrip(
      tripId: tripId,
      riderName: json['riderName'] as String? ?? '',
      fare: json['fare'] as String? ?? '—',
      category: json['category'] as String? ?? 'Movera',
      pickup: json['pickup'] as String? ?? '',
      dropoff: json['dropoff'] as String? ?? '',
      pickupLat: (json['pickupLat'] as num).toDouble(),
      pickupLng: (json['pickupLng'] as num).toDouble(),
      dropoffLat: (json['dropoffLat'] as num).toDouble(),
      dropoffLng: (json['dropoffLng'] as num).toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      pickupMinutes: (json['pickupMinutes'] as num?)?.toInt() ?? 4,
      tripMinutes: (json['tripMinutes'] as num?)?.toInt() ?? 16,
      pickupPay: PersistedActiveRide._money(json['pickupPay']),
    );
  }
}

class PersistedActiveRide {
  const PersistedActiveRide({
    required this.tripId,
    required this.stage,
    this.nextTripId,
    this.arrivedAt,
    this.acceptedAt,
    this.startedAt,
    this.savedAt,
    this.riderName,
    this.riderRating,
    this.riderTrips,
    this.fare,
    this.paidByCash = false,
    this.cashToCollect,
    this.riderFare,
    this.driverBonus,
    this.category,
    this.matchedVia,
    this.pickupAddress,
    this.pickupArea,
    this.dropoffAddress,
    this.stopAddresses = const <String>[],
    this.stopPoints = const <GeoPoint>[],
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.waitSeconds,
    this.paidWaitSeconds = 0,
    this.stopIndex = 0,
    this.paidStopWait = false,
    this.next,
    this.destinationModeActive = false,
    this.destinationAddress,
    this.destinationPoint,
    this.scheduledPickupAt,
    this.scheduledRideId,
    this.pickupKm,
    this.bags = 0,
    this.rideCheckFired = const <String>[],
    this.nextOffersStopped = false,
  });

  final String tripId;
  final ActiveRideStage stage;
  final String? nextTripId;
  final DateTime? arrivedAt;

  /// When the driver accepted (contract `TripProjection.acceptedAt`, owner
  /// Q12): the live free-cancel clock counts from it.
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? savedAt;
  final String? riderName;
  final double? riderRating;
  final int? riderTrips;

  /// The driver's own money for the trip, after Movera's commission, the
  /// pickup pay and bonus in it (owner decision 2026-10-26). Never the
  /// rider's fare.
  final String? fare;

  /// The rider pays cash in the car; otherwise the card is charged.
  final bool paidByCash;

  /// R8-4: the cash to take from the rider, their own fare. Null only on
  /// a trip saved before the fare became the driver's pay.
  final String? cashToCollect;

  /// Owner N11: what the rider pays, for the waybill; null when unknown.
  final String? riderFare;

  /// Movera's bonus already in [fare] (contract `driverBonus`, Q16/Q18).
  final Money? driverBonus;
  final String? category;
  final String? matchedVia;
  final String? pickupAddress;
  final String? pickupArea;
  final String? dropoffAddress;
  final List<String> stopAddresses;
  final List<GeoPoint> stopPoints;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final int? waitSeconds;

  /// Paid waiting seconds of waits already over (pickup, stops): the
  /// waiting fee the trip has earned so far (Q42/Q43).
  final int paidWaitSeconds;
  final int stopIndex;
  final bool paidStopWait;
  final PersistedQueuedTrip? next;
  final bool destinationModeActive;
  final String? destinationAddress;
  final GeoPoint? destinationPoint;

  /// A scheduled ride opened at "Leave now": its pickup time and
  /// reservation id, so a restored trip keeps watching the ETA to it
  /// (`reservations.lateEta`). Null for every other trip.
  final DateTime? scheduledPickupAt;
  final String? scheduledRideId;

  /// driver-u56: how far the pickup was at accept, so a restored trip keeps
  /// the waiting terms it was accepted under (Q20). Null when not known.
  final double? pickupKm;

  /// The bags the rider said they bring.
  final int bags;

  /// Ride check triggers that already opened on this trip
  /// ([RideCheckTrigger] names): each opens once per trip, also after a
  /// restore (driver-u44).
  final List<String> rideCheckFired;

  /// The driver held the trip radar: no next-trip offers on this trip,
  /// also after a restore (driver-u68).
  final bool nextOffersStopped;
  bool get hasVerifiedEndpoints =>
      validCoordinate(pickupLat, latitude: true) &&
      validCoordinate(pickupLng, latitude: false) &&
      validCoordinate(dropoffLat, latitude: true) &&
      validCoordinate(dropoffLng, latitude: false);

  /// How long a saved live trip may sit untouched and still be restored.
  ///
  /// A Stockholm trip can outlive a short window if the driver backgrounds
  /// the PWA. Six hours matches Rider's active-ride snapshot.
  static const freshnessWindow = Duration(hours: 6);

  bool get isFresh => isFreshAt(DateTime.now());

  bool isFreshAt(DateTime now) {
    final at = savedAt;
    if (at == null) {
      return true;
    }
    final age = now.difference(at);
    return age >= const Duration(minutes: -2) && age < freshnessWindow;
  }

  PersistedActiveRide stamped([DateTime? at]) {
    return PersistedActiveRide(
      tripId: tripId,
      stage: stage,
      nextTripId: nextTripId ?? next?.tripId,
      arrivedAt: arrivedAt,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      savedAt: at ?? DateTime.now(),
      riderName: riderName,
      riderRating: riderRating,
      riderTrips: riderTrips,
      fare: fare,
      paidByCash: paidByCash,
      cashToCollect: cashToCollect,
      riderFare: riderFare,
      driverBonus: driverBonus,
      category: category,
      matchedVia: matchedVia,
      pickupAddress: pickupAddress,
      pickupArea: pickupArea,
      dropoffAddress: dropoffAddress,
      stopAddresses: stopAddresses,
      stopPoints: stopPoints,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      waitSeconds: waitSeconds,
      paidWaitSeconds: paidWaitSeconds,
      stopIndex: stopIndex,
      paidStopWait: paidStopWait,
      next: next,
      destinationModeActive: destinationModeActive,
      destinationAddress: destinationAddress,
      destinationPoint: destinationPoint,
      scheduledPickupAt: scheduledPickupAt,
      scheduledRideId: scheduledRideId,
      pickupKm: pickupKm,
      bags: bags,
      rideCheckFired: rideCheckFired,
      nextOffersStopped: nextOffersStopped,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'tripId': tripId,
    'stage': stage.name,
    if (nextTripId != null || next != null)
      'nextTripId': nextTripId ?? next?.tripId,
    // Instants in UTC: a local time has no offset, so in the repeated
    // autumn hour it read back an hour early (driver-u34). Older saves in
    // local time still read as local.
    if (arrivedAt != null) 'arrivedAt': arrivedAt!.toUtc().toIso8601String(),
    if (acceptedAt != null) 'acceptedAt': acceptedAt!.toUtc().toIso8601String(),
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    if (savedAt != null) 'savedAt': savedAt!.toUtc().toIso8601String(),
    if (riderName != null) 'riderName': riderName,
    if (riderRating != null) 'riderRating': riderRating,
    if (riderTrips != null) 'riderTrips': riderTrips,
    if (fare != null) 'fare': fare,
    if (paidByCash) 'paidByCash': true,
    if (cashToCollect != null) 'cashToCollect': cashToCollect,
    if (riderFare != null) 'riderFare': riderFare,
    if (driverBonus != null) 'driverBonus': driverBonus!.toJson(),
    if (category != null) 'category': category,
    if (matchedVia != null) 'matchedVia': matchedVia,
    if (pickupAddress != null) 'pickupAddress': pickupAddress,
    if (pickupArea != null) 'pickupArea': pickupArea,
    if (dropoffAddress != null) 'dropoffAddress': dropoffAddress,
    if (stopAddresses.isNotEmpty) 'stopAddresses': stopAddresses,
    if (stopPoints.isNotEmpty)
      'stopPoints': [
        for (final point in stopPoints)
          {'latitude': point.latitude, 'longitude': point.longitude},
      ],
    if (pickupLat != null) 'pickupLat': pickupLat,
    if (pickupLng != null) 'pickupLng': pickupLng,
    if (dropoffLat != null) 'dropoffLat': dropoffLat,
    if (dropoffLng != null) 'dropoffLng': dropoffLng,
    if (waitSeconds != null) 'waitSeconds': waitSeconds,
    if (paidWaitSeconds > 0) 'paidWaitSeconds': paidWaitSeconds,
    'stopIndex': stopIndex,
    'paidStopWait': paidStopWait,
    if (next != null) 'next': next!.toJson(),
    'destinationModeActive': destinationModeActive,
    if (destinationAddress != null) 'destinationAddress': destinationAddress,
    if (destinationPoint != null)
      'destinationPoint': {
        'latitude': destinationPoint!.latitude,
        'longitude': destinationPoint!.longitude,
      },
    if (scheduledPickupAt != null)
      'scheduledPickupAt': scheduledPickupAt!.toUtc().toIso8601String(),
    if (scheduledRideId != null) 'scheduledRideId': scheduledRideId,
    if (pickupKm != null) 'pickupKm': pickupKm,
    if (bags > 0) 'bags': bags,
    if (rideCheckFired.isNotEmpty) 'rideCheckFired': rideCheckFired,
    if (nextOffersStopped) 'nextOffersStopped': true,
  };

  /// A saved Money, or null when absent or not readable.
  static Money? _money(Object? value) {
    if (value is! Map) return null;
    try {
      return Money.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      return null;
    }
  }

  static PersistedActiveRide? fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] ?? 1;
    if (version != 1 && version != 2) {
      return null;
    }
    final tripId = json['tripId'] as String?;
    if (tripId == null || tripId.trim().isEmpty) {
      return null;
    }
    final stageName = json['stage'] as String?;
    final stage = ActiveRideStage.values.where(
      (value) => value.name == stageName,
    );
    if (stage.isEmpty) {
      return null;
    }
    for (final key in [
      'arrivedAt',
      'acceptedAt',
      'startedAt',
      'savedAt',
      'scheduledPickupAt',
    ]) {
      if (json[key] != null &&
          (json[key] is! String ||
              DateTime.tryParse(json[key] as String) == null)) {
        return null;
      }
    }
    for (final key in ['pickupLat', 'pickupLng', 'dropoffLat', 'dropoffLng']) {
      if (json[key] != null &&
          !validCoordinate(json[key], latitude: key.endsWith('Lat'))) {
        return null;
      }
    }
    // Never silently drop a saved stop label: a partial restoration can
    // misrepresent the rider's requested journey.
    final addresses = json['stopAddresses'];
    if (addresses != null &&
        (addresses is! List || addresses.any((item) => item is! String))) {
      return null;
    }
    // These counters drive waiting and multi-stop UI after app recovery.
    final waitSeconds = json['waitSeconds'];
    if (waitSeconds != null && (waitSeconds is! int || waitSeconds < 0)) {
      return null;
    }
    final paidWait = json['paidWaitSeconds'];
    if (paidWait != null && (paidWait is! int || paidWait < 0)) {
      return null;
    }
    final stopIndex = json['stopIndex'];
    if (stopIndex != null && (stopIndex is! int || stopIndex < 0)) {
      return null;
    }
    final riderRating = json['riderRating'];
    if (riderRating != null &&
        (riderRating is! num ||
            !riderRating.isFinite ||
            riderRating < 0 ||
            riderRating > 5)) {
      return null;
    }
    final stops = json['stopPoints'];
    if (stops != null &&
        (stops is! List ||
            stops.any(
              (point) =>
                  point is! Map ||
                  !validCoordinate(point['latitude'], latitude: true) ||
                  !validCoordinate(point['longitude'], latitude: false),
            ))) {
      return null;
    }
    final destination = json['destinationPoint'];
    if (destination != null &&
        (destination is! Map ||
            !validCoordinate(destination['latitude'], latitude: true) ||
            !validCoordinate(destination['longitude'], latitude: false))) {
      return null;
    }
    final pickupKm = json['pickupKm'];
    final bags = json['bags'];
    final fired = json['rideCheckFired'];
    final nextJson = json['next'];
    final next = nextJson is Map
        ? PersistedQueuedTrip.fromJson(Map<String, dynamic>.from(nextJson))
        : null;
    if (nextJson != null && next == null) {
      return null;
    }
    return PersistedActiveRide(
      tripId: tripId,
      stage: stage.first,
      nextTripId: json['nextTripId'] as String?,
      arrivedAt: DateTime.tryParse(json['arrivedAt'] as String? ?? '')?.toLocal(),
      acceptedAt: DateTime.tryParse(json['acceptedAt'] as String? ?? '')?.toLocal(),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal(),
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '')?.toLocal(),
      riderName: json['riderName'] as String?,
      riderRating: (json['riderRating'] as num?)?.toDouble(),
      riderTrips: (json['riderTrips'] as num?)?.toInt(),
      fare: json['fare'] as String?,
      paidByCash: json['paidByCash'] == true,
      cashToCollect: json['cashToCollect'] is String
          ? json['cashToCollect'] as String
          : null,
      riderFare: json['riderFare'] is String ? json['riderFare'] as String : null,
      driverBonus: _money(json['driverBonus']),
      category: json['category'] as String?,
      matchedVia: json['matchedVia'] as String?,
      pickupAddress: json['pickupAddress'] as String?,
      pickupArea: json['pickupArea'] as String?,
      dropoffAddress: json['dropoffAddress'] as String?,
      stopAddresses:
          (json['stopAddresses'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      stopPoints:
          (json['stopPoints'] as List?)
              ?.whereType<Map>()
              .map(
                (point) => GeoPoint(
                  (point['latitude'] as num).toDouble(),
                  (point['longitude'] as num).toDouble(),
                ),
              )
              .toList(growable: false) ??
          const <GeoPoint>[],
      pickupLat: (json['pickupLat'] as num?)?.toDouble(),
      pickupLng: (json['pickupLng'] as num?)?.toDouble(),
      dropoffLat: (json['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (json['dropoffLng'] as num?)?.toDouble(),
      waitSeconds: (json['waitSeconds'] as num?)?.toInt(),
      paidWaitSeconds: paidWait is int ? paidWait : 0,
      stopIndex: (json['stopIndex'] as num?)?.toInt() ?? 0,
      paidStopWait: json['paidStopWait'] == true,
      next: next,
      destinationModeActive: json['destinationModeActive'] == true,
      destinationAddress: json['destinationAddress'] as String?,
      destinationPoint: destination is Map
          ? GeoPoint(
              (destination['latitude'] as num).toDouble(),
              (destination['longitude'] as num).toDouble(),
            )
          : null,
      scheduledPickupAt:
          DateTime.tryParse(json['scheduledPickupAt'] as String? ?? '')
              ?.toLocal(),
      scheduledRideId: json['scheduledRideId'] is String
          ? json['scheduledRideId'] as String
          : null,
      // Optional preview data: a bad value is dropped, not trusted.
      pickupKm: pickupKm is num && pickupKm.isFinite && pickupKm >= 0
          ? pickupKm.toDouble()
          : null,
      bags: bags is int && bags > 0 ? bags : 0,
      rideCheckFired: fired is List
          ? List<String>.unmodifiable(fired.whereType<String>())
          : const <String>[],
      nextOffersStopped: json['nextOffersStopped'] == true,
    );
  }
}

/// Persistence boundary for active-trip recovery after app restart.
///
/// Memory-only controller state is not durable. This interface exists so
/// recovery can attach without rewriting screens. No backend is implied.
abstract interface class ActiveRideRepository {
  Future<PersistedActiveRide?> read();

  Future<void> save(PersistedActiveRide ride);

  Future<void> clear();
}

class MemoryActiveRideRepository implements ActiveRideRepository {
  PersistedActiveRide? _ride;

  @override
  Future<PersistedActiveRide?> read() async => _ride;

  @override
  Future<void> save(PersistedActiveRide ride) async {
    _ride = ride;
  }

  @override
  Future<void> clear() async {
    _ride = null;
  }
}

/// Terminal markers survive cleanup failure. Active IDs are never reused.
abstract interface class TerminalRideRepository {
  Future<void> markTerminal(
    String tripId,
    TripStatus status, {
    String? reasonCode,
    String? actor,
    DateTime? occurredAt,
    bool authoritative = false,
  });

  Future<void> clearForTrip(String tripId);
}

bool validCoordinate(Object? value, {required bool latitude}) =>
    value is num && value.isFinite && value.abs() <= (latitude ? 90 : 180);

/// A journal may replace only its own trip or replay its already-installed next trip.
abstract interface class RideHandoffRepository {
  Future<void> handoff(String expectedTripId, PersistedActiveRide next);
}

/// Another trip already owns the active snapshot, so this write would replace
/// independently newer work. Callers keep the newer trip and resolve the older
/// one explicitly instead of retrying forever.
class RideOwnershipConflict extends StateError {
  RideOwnershipConflict(super.message);
}

/// Stored active-trip data exists but cannot be decoded by this app version.
///
/// Distinct from a transient storage failure: retrying will never succeed, so
/// the driver must be offered an explicit way to close it.
class ActiveRideUnreadable implements Exception {
  /// Keeps [cause] without the snapshot text it may quote (driver-25).
  ActiveRideUnreadable(Object cause) : cause = DriverLog.scrub(cause);

  final Object cause;

  @override
  String toString() => 'Active ride snapshot is unreadable: $cause';
}

/// driver-u112: the trip storage itself could not be opened (a browser
/// that blocks site storage). Nothing can be saved or read while this
/// lasts, so it says nothing about a saved trip. Still a [StateError]: a
/// plugin hiccup stays retryable.
class ActiveRideStorageUnavailable extends StateError {
  ActiveRideStorageUnavailable(Object cause)
    : super('Trip storage unavailable: ${DriverLog.scrub(cause)}');
}

/// Storage that can move an unreadable active-trip record aside.
abstract interface class UnreadableRideRecovery {
  /// Moves the raw snapshot to a quarantine key and releases ownership.
  Future<void> quarantineUnreadable();
}
