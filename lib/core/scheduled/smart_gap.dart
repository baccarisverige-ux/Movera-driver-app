import 'dart:math' as math;

import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

/// The smart gap (notes Q9/Q10): a scheduled ride must still fit after
/// what the driver does before it. The time needed is the drive to its
/// pickup plus the spare minutes admin sets for its kind of ride.
///
/// The demo has no road routing here, so a drive is estimated from the
/// straight distance (see [driveMinutes]). A backend gives real times.
class SmartGap {
  const SmartGap._();

  /// Roads are this much longer than the straight line, in the city.
  static const double roadFactor = 1.35;

  /// Average city speed for the estimate.
  static const double cityKmh = 32;

  /// Estimated minutes to drive from [from] to [to]; at least 1.
  static int driveMinutes(GeoPoint from, GeoPoint to) {
    final km = from.distanceMetersTo(to) / 1000 * roadFactor;
    return math.max(1, (km / cityKmh * 60).ceil());
  }

  /// Airport if either end is an airport; then events (set by admin), long
  /// trips, Comfort/Premium and the rest.
  static ScheduledRideKind kindOf(
    ReservationRequestPreview ride,
    ScheduledRideRules rules,
  ) {
    final set = ride.kind;
    if (set != null) {
      return set;
    }
    final airport = RegExp(r'airport|arlanda|terminal', caseSensitive: false);
    if (airport.hasMatch(ride.pickupAddress) ||
        airport.hasMatch(ride.dropoffAddress)) {
      return ScheduledRideKind.airport;
    }
    if (ride.tripKm > rules.longTripKm) {
      return ScheduledRideKind.longTrip;
    }
    final category = ride.category.trim().toLowerCase();
    if (category == 'comfort' || category == 'premium') {
      return ScheduledRideKind.comfortPremium;
    }
    return ScheduledRideKind.normal;
  }

  static ScheduledRideKindRule ruleOf(
    ReservationRequestPreview ride,
    ScheduledRideRules rules,
  ) => rules.ruleFor(kindOf(ride, rules));

  /// [first] and then [second] work out: the first ride, the drive from
  /// its drop-off to the second pickup and the second ride's spare minutes
  /// all fit before the second pickup. False when a time is unknown.
  static bool fitsBefore(
    ReservationRequestPreview first,
    ReservationRequestPreview second, {
    required DateTime now,
    required ScheduledRideRules rules,
  }) {
    final firstAt = first.pickupAt(now);
    final secondAt = second.pickupAt(now);
    if (firstAt == null || secondAt == null || !secondAt.isAfter(firstAt)) {
      return false;
    }
    final needed =
        first.tripMinutes +
        driveMinutes(first.dropoff, second.pickup) +
        ruleOf(second, rules).spareMinutes;
    return !firstAt.add(Duration(minutes: needed)).isAfter(secondAt);
  }

  /// Two scheduled rides one driver cannot both do: neither order leaves
  /// the gap. Rides whose time is unknown never clash.
  static bool clash(
    ReservationRequestPreview a,
    ReservationRequestPreview b, {
    required DateTime now,
    required ScheduledRideRules rules,
  }) {
    if (a.pickupAt(now) == null || b.pickupAt(now) == null) {
      return false;
    }
    return !fitsBefore(a, b, now: now, rules: rules) &&
        !fitsBefore(b, a, now: now, rules: rules);
  }

  /// "Leave now": the latest moment to set off from [driver] for [ride],
  /// the drive plus the spare minutes before its pickup.
  static DateTime? leaveAt(
    ReservationRequestPreview ride, {
    required GeoPoint driver,
    required DateTime now,
    required ScheduledRideRules rules,
  }) {
    final at = ride.pickupAt(now);
    if (at == null) {
      return null;
    }
    final minutes =
        driveMinutes(driver, ride.pickup) + ruleOf(ride, rules).spareMinutes;
    return at.subtract(Duration(minutes: minutes));
  }

  /// `reservations.lateEta`: an online driver on the way with [eta] left
  /// to the pickup would arrive too late, after [pickupAt] plus the
  /// admin's tolerance. Arriving exactly at the tolerance is on time.
  /// Always false while the rule is off.
  static bool wouldBeLate({
    required DateTime now,
    required DateTime pickupAt,
    required Duration eta,
    required ScheduledRideRules rules,
  }) {
    final rule = rules.lateEta;
    if (!rule.on) {
      return false;
    }
    return now.add(eta).isAfter(pickupAt.add(rule.tolerance));
  }

  /// A trip offered now still leaves time for [ride]: getting to the
  /// trip's pickup, the trip, the drive on to [ride]'s pickup and the spare
  /// minutes all fit before it.
  static bool offerFits({
    required int offerPickupMinutes,
    required int offerTripMinutes,
    required GeoPoint offerDropoff,
    required ReservationRequestPreview ride,
    required DateTime now,
    required ScheduledRideRules rules,
  }) {
    final at = ride.pickupAt(now);
    if (at == null) {
      return true;
    }
    final needed =
        offerPickupMinutes +
        offerTripMinutes +
        driveMinutes(offerDropoff, ride.pickup) +
        ruleOf(ride, rules).spareMinutes;
    return !now.add(Duration(minutes: needed)).isAfter(at);
  }

  /// The trip ends in the direction of [target], seen from [from], like
  /// destination mode does with the driver's destination.
  static bool headsToward({
    required GeoPoint from,
    required GeoPoint dropoff,
    required GeoPoint target,
  }) {
    final scale = math.cos(from.latitude * math.pi / 180);
    final tx = (target.longitude - from.longitude) * scale;
    final ty = target.latitude - from.latitude;
    final ox = (dropoff.longitude - from.longitude) * scale;
    final oy = dropoff.latitude - from.latitude;
    final tl = math.sqrt(tx * tx + ty * ty);
    final ol = math.sqrt(ox * ox + oy * oy);
    if (tl == 0 || ol == 0) {
      return true;
    }
    return (tx * ox + ty * oy) / (tl * ol) >= 0.45;
  }
}
