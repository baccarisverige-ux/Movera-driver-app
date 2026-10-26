import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/destination_filter.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/geo/geo_point.dart';

/// When a next-trip offer may come while the driver drives a rider
/// (R13-18). Only Exclusive offers and Exclusive reservations, never Radar
/// trips; only on the way to the FINAL drop-off (not before pickup, not on
/// the way to a stop); and only within admin's km and/or minutes of the
/// drop-off, whichever comes first (both off: the whole last leg).
///
/// The demo keeps next trips as they were, with no limits (owner).
class NextTripGate {
  const NextTripGate._();

  static bool allows({
    required bool demo,
    required bool onTrip,
    required bool toFinalDropoff,
    double? metersToDropoff,
    double? secondsToDropoff,
    NextTripRules? rules,
  }) {
    if (!onTrip) {
      return false;
    }
    if (demo) {
      return true;
    }
    if (!toFinalDropoff) {
      return false;
    }
    final r = rules ?? NextTripRules.current;
    if (r.offerTypes.isEmpty) {
      return false;
    }
    if (r.wholeLastLeg) {
      return true;
    }
    final byKm =
        r.withinKmOfDropoffOn &&
        metersToDropoff != null &&
        metersToDropoff <= r.withinKmOfDropoff * 1000;
    final byTime =
        r.withinMinutesOfDropoffOn &&
        secondsToDropoff != null &&
        secondsToDropoff <= r.withinMinutesOfDropoff * 60;
    return byKm || byTime;
  }
}

/// Destination mode on the trip screen (R13-18): next-trip offers follow
/// the same on-the-way filter as Home. The next trip starts at the current
/// drop-off, so that is where "closer" is measured from.
class OnTripDestination {
  const OnTripDestination._();

  static bool follows({
    required GeoPoint from,
    required GeoPoint destination,
    required GeoPoint dropoff,
  }) {
    final session = DestinationModeSession.instance;
    // The admin time limit ended it: no filter any more.
    if (session.expired()) {
      return true;
    }
    return DestinationFilter.follows(
      driver: from,
      destination: destination,
      dropoff: dropoff,
      route: session.routeTo(destination),
    );
  }

  /// Short text when a destination cannot be set now, else null.
  static String? refusalText() {
    final refusal = DestinationModeSession.instance.refusal();
    if (refusal == null) {
      return null;
    }
    return driverText(
      refusal == DestinationRefusal.off
          ? DriverTexts.islandDestinationOff
          : DriverTexts.islandDestinationsUsed,
    );
  }

  /// A destination was set on the trip: it counts for today, and Home
  /// takes it over when the trip ends (driver-u65).
  static void started({String? address, GeoPoint? position}) =>
      DestinationModeSession.instance.started(
        address: address,
        position: position,
      );
}
