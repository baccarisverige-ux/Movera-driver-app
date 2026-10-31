import 'dart:math' as math;

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

/// D-3 (audit Phase 5): the server's own trip for this driver.
///
/// A driver who signs in on a new browser (or after clearing site data)
/// has no saved trip on the device, but the server may still hold one
/// (`Driver.activeTripId` on `GET /driver/profile`). Home asks here when
/// the device has nothing, so the trip opens instead of "searching".
class LiveActiveTrip {
  LiveActiveTrip({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const profilePath = '/api/v1/driver/profile';
  static const tripsPath = '/api/v1/trips';

  /// The trip the server holds for this driver, as a restorable snapshot;
  /// null when there is none, it is not a stage the trip screen runs, or
  /// the server could not be asked (the app then stays as before).
  Future<({PersistedActiveRide ride, Map<String, dynamic> projection})?>
  fetch() async {
    try {
      final profile = await _api.get(profilePath);
      final id = profile['activeTripId'];
      if (id is! String || id.trim().isEmpty) return null;
      final trip = await _api.get('$tripsPath/${Uri.encodeComponent(id)}');
      final ride = snapshotOf(trip);
      return ride == null ? null : (ride: ride, projection: trip);
    } catch (error) {
      DriverLog.warn('active trip not read: $error', name: 'live');
      return null;
    }
  }

  /// The trip screen's stage for a server `TripStatus`; null when the
  /// screen has no such stage (searching, over…).
  static ActiveRideStage? stageOf(Object? status) => switch (status) {
    'accepted' || 'driver_to_pickup' => ActiveRideStage.headingToPickup,
    'arrived' => ActiveRideStage.waitingForRider,
    'rider_onboard' ||
    'in_trip' ||
    'approaching_dropoff' => ActiveRideStage.onTrip,
    _ => null,
  };

  /// A `TripProjection` as the snapshot the trip screen restores from.
  /// Null when a stage or a coordinate is missing.
  static PersistedActiveRide? snapshotOf(Map<String, dynamic> trip) {
    final id = trip['tripId'];
    final stage = stageOf(trip['status']);
    if (id is! String || id.isEmpty || stage == null) return null;
    final pickup = _place(trip['pickup']);
    final dropoff = _place(trip['dropoff']);
    if (pickup == null || dropoff == null) return null;
    final stops = [
      if (trip['stops'] is List)
        for (final stop in trip['stops'] as List) ?_place(stop),
    ];
    final earnings = _money(trip['driverEarnings']);
    final pickupPay = _money(trip['pickupPay']);
    final riderFare = _money(trip['fare']);
    final bonus = _money(trip['driverBonus']);
    // "You get": earnings + pickup pay + bonus (fare − commission).
    Money? pay = earnings;
    for (final extra in [pickupPay, bonus]) {
      if (pay != null && extra != null && extra.currency == pay.currency) {
        pay = pay + extra;
      }
    }
    final cash = trip['paymentMethod'] == 'cash';
    final category = trip['categoryId'];
    // Contract v0.18.7 (Q1): the rider's first name and rating as the
    // server sends them to the driver; "Rider" when it has no name.
    final rider = trip['rider'];
    final riderName = rider is Map ? rider['firstName'] : null;
    final riderRating = rider is Map ? rider['rating'] : null;
    final accepted = trip['acceptedAt'];
    // Contract `Waiting.arrivedAt`: the wait at the pickup counts from it.
    final waiting = trip['waiting'];
    final arrived = waiting is Map ? waiting['arrivedAt'] : null;
    final arrivedAt = arrived is String
        ? DateTime.tryParse(arrived)?.toLocal()
        : null;
    return PersistedActiveRide(
      tripId: id,
      stage: stage,
      acceptedAt: accepted is String
          ? DateTime.tryParse(accepted)?.toLocal()
          : null,
      arrivedAt: arrivedAt,
      // The trip screen's waiting clock restores from these seconds.
      waitSeconds: stage == ActiveRideStage.waitingForRider && arrivedAt != null
          ? math.max(0, DateTime.now().difference(arrivedAt).inSeconds)
          : null,
      riderName: riderName is String && riderName.trim().isNotEmpty
          ? riderName.trim()
          : null,
      riderRating:
          riderRating is num &&
              riderRating.isFinite &&
              riderRating >= 0 &&
              riderRating <= 5
          ? riderRating.toDouble()
          : null,
      fare: pay?.formatted,
      paidByCash: cash,
      cashToCollect: cash ? riderFare?.formatted : null,
      riderFare: riderFare?.formatted,
      driverBonus: bonus,
      category: category is String ? CategoryCatalog.labelOf(category) : null,
      pickupAddress: pickup.address,
      dropoffAddress: dropoff.address,
      stopAddresses: [for (final stop in stops) stop.address ?? ''],
      stopPoints: [for (final stop in stops) stop.point],
      pickupLat: pickup.point.latitude,
      pickupLng: pickup.point.longitude,
      dropoffLat: dropoff.point.latitude,
      dropoffLng: dropoff.point.longitude,
    );
  }

  static ({GeoPoint point, String? address})? _place(Object? value) {
    if (value is! Map) return null;
    final lat = value['lat'];
    final lng = value['lng'];
    if (!validCoordinate(lat, latitude: true) ||
        !validCoordinate(lng, latitude: false)) {
      return null;
    }
    final address = value['address'];
    return (
      point: GeoPoint((lat as num).toDouble(), (lng as num).toDouble()),
      address: address is String && address.trim().isNotEmpty
          ? address.trim()
          : null,
    );
  }

  static Money? _money(Object? value) {
    if (value is! Map) return null;
    try {
      return Money.fromJson(Map<String, dynamic>.from(value));
    } on FormatException {
      return null;
    }
  }
}
