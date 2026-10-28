import 'dart:math' as math;

import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';

/// Demo trips for Destination mode (R13-9): with real filtering the fixed
/// demo trips rarely head the driver's way, so the demo adds some along the
/// route to the destination. One ends near the destination (the Exclusive
/// offer), two end on the way 35 % and 60 % along the route inside the
/// corridor, and two fall outside (far off the route, and behind the
/// driver) so the filter can be seen working.
class DemoDestinationTrips {
  const DemoDestinationTrips._();

  static const String idPrefix = 'demo-destination-';
  static const String exclusiveId = '${idPrefix}final';

  static List<RideOffer> along({
    required GeoPoint driver,
    required GeoPoint destination,
    List<GeoPoint> route = const <GeoPoint>[],
    double corridorKm = 5,
    String? destinationLabel,
  }) {
    final path = route.length >= 2 ? route : <GeoPoint>[driver, destination];
    final corridor = corridorKm * 1000;
    final pickup = _offset(driver, _bearing(driver, destination) + 90, 600);
    RideOffer trip(
      String id,
      String rider,
      String dropoff,
      GeoPoint at,
      Money fare, {
      required bool follows,
    }) {
      final km = pickup.distanceMetersTo(at) / 1000 * 1.25;
      return RideOffer(
        id: '$idPrefix$id',
        riderName: rider,
        riderTrips: 40 + rider.length * 9,
        category: 'Comfort',
        fare: fare,
        rating: '4.95',
        pickupMinutes: 3,
        pickupKm: 0.8,
        tripMinutes: math.max(4, (km * 1.4).round()),
        tripKm: double.parse(km.toStringAsFixed(1)),
        pickup: tr.demoPickupNearYou,
        dropoff: dropoff,
        pickupPosition: pickup,
        dropoffPosition: at,
        isNearby: true,
        followsDestination: follows,
      );
    }

    final (nearEnd, endBearing) = _pointAt(path, 0.97);
    final (way1, way1Bearing) = _pointAt(path, 0.35);
    final (way2, way2Bearing) = _pointAt(path, 0.60);
    final (mid, midBearing) = _pointAt(path, 0.50);
    return <RideOffer>[
      trip(
        'final',
        'Sofia',
        tr.demoNearPlace(destinationLabel ?? tr.demoYourDestination),
        _offset(nearEnd, endBearing + 90, math.min(800, corridor * 0.2)),
        Money.ore(24800),
        follows: true,
      ),
      trip(
        'way-1',
        'Adam',
        tr.demoOnYourWayPercent(35),
        _offset(way1, way1Bearing + 90, corridor * 0.4),
        Money.ore(16450),
        follows: true,
      ),
      trip(
        'way-2',
        'Ella',
        tr.demoOnYourWayPercent(60),
        _offset(way2, way2Bearing - 90, corridor * 0.5),
        Money.ore(19830),
        follows: true,
      ),
      trip(
        'off-route',
        'Karl',
        tr.demoAwayFromRoute,
        _offset(mid, midBearing + 90, corridor * 3),
        Money.ore(15200),
        follows: false,
      ),
      trip(
        'behind',
        'Noor',
        tr.demoBehindYou,
        _offset(driver, _bearing(destination, driver), corridor * 1.5),
        Money.ore(12140),
        follows: false,
      ),
    ];
  }

  /// The point [fraction] along [path] by length, and the path's bearing
  /// there.
  static (GeoPoint, double) _pointAt(List<GeoPoint> path, double fraction) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += path[i - 1].distanceMetersTo(path[i]);
    }
    var left = total * fraction;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], b = path[i];
      final step = a.distanceMetersTo(b);
      if (step > 0 && left <= step) {
        final t = left / step;
        return (
          GeoPoint(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
          _bearing(a, b),
        );
      }
      left -= step;
    }
    return (path.last, _bearing(path[path.length - 2], path.last));
  }

  static double _bearing(GeoPoint a, GeoPoint b) =>
      a.distanceMetersTo(b) == 0 ? 0 : a.bearingTo(b);

  /// [point] moved [meters] toward [bearing] degrees (flat, fine for km).
  static GeoPoint _offset(GeoPoint point, double bearing, double meters) {
    final r = bearing * math.pi / 180;
    const perDegree = 111320.0;
    return GeoPoint(
      point.latitude + meters * math.cos(r) / perDegree,
      point.longitude +
          meters *
              math.sin(r) /
              (perDegree * math.cos(point.latitude * math.pi / 180)),
    );
  }
}
