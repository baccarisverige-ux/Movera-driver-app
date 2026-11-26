import 'dart:math' as math;

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_repository.dart';

/// v0.18.169 (contract.json#offerRouteLine, owner 2026-11-26 "Route in
/// driver !!"): the Google route an offer carries (`Offer.routePolyline`,
/// the trip's stored quote route). The offer parser keeps it here, cut into
/// one leg per stop, and [RoadRouteService] answers those legs from it, so
/// the Home offer preview draws the road with no route request (owner:
/// about 2 Google calls per trip). Nothing kept = the old route request.
abstract final class OfferRoutes {
  /// The most trips kept (a few offers at a time).
  static const int limit = 16;

  static final Map<String, RoadRoute> _legs = <String, RoadRoute>{};

  /// Keeps [encoded] as the road of the trip [waypoints] (pickup, every
  /// stop, drop-off), lasting [tripSeconds]. An empty or broken line, or
  /// one that does not start and end near the trip's ends, is not kept.
  static void remember(
    List<GeoPoint> waypoints,
    String? encoded, {
    int tripSeconds = 0,
  }) {
    if (waypoints.length < 2 || encoded == null || encoded.isEmpty) return;
    final points = decodeGooglePolyline(encoded);
    if (points == null || points.length < 2) return;
    if (_meters(points.first, waypoints.first) > 500 ||
        _meters(points.last, waypoints.last) > 500) {
      return;
    }
    final total = _length(points);
    // Cut the line at the point nearest each stop, in order.
    var from = 0;
    for (var leg = 1; leg < waypoints.length; leg++) {
      var to = points.length - 1;
      if (leg < waypoints.length - 1) {
        final stop = waypoints[leg];
        var best = from;
        for (var i = from; i < points.length; i++) {
          if (_meters(points[i], stop) < _meters(points[best], stop)) best = i;
        }
        to = best;
      }
      final inner = points.sublist(from, to + 1);
      final piece = <GeoPoint>[
        if (inner.first != waypoints[leg - 1]) waypoints[leg - 1],
        ...inner,
        if (inner.last != waypoints[leg]) waypoints[leg],
      ];
      final meters = _length(piece);
      _legs.remove(_key(waypoints[leg - 1], waypoints[leg]));
      _legs[_key(waypoints[leg - 1], waypoints[leg])] = RoadRoute(
        points: List<GeoPoint>.unmodifiable(piece),
        distanceMeters: meters,
        durationSeconds: total <= 0 ? 0 : tripSeconds * meters / total,
      );
      from = to;
    }
    while (_legs.length > limit * 4) {
      _legs.remove(_legs.keys.first);
    }
  }

  /// The kept road from [origin] to [destination], or null.
  static RoadRoute? leg(GeoPoint origin, GeoPoint destination) =>
      _legs[_key(origin, destination)];

  /// Tests and sign-out.
  static void clear() => _legs.clear();

  static String _key(GeoPoint a, GeoPoint b) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}>'
      '${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';

  static double _length(List<GeoPoint> points) {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += _meters(points[i - 1], points[i]);
    }
    return sum;
  }

  static double _meters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }
}

/// Decodes a Google encoded polyline (precision 5), or null when malformed.
List<GeoPoint>? decodeGooglePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  int? next() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= encoded.length) return null;
      final b = encoded.codeUnitAt(index++) - 63;
      if (b < 0 || b > 63) return null;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) break;
      if (shift > 30) return null;
    }
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    final dLat = next();
    final dLng = next();
    if (dLat == null || dLng == null) return null;
    lat += dLat;
    lng += dLng;
    final la = lat / 1e5;
    final ln = lng / 1e5;
    if (la.abs() > 90 || ln.abs() > 180) return null;
    points.add(GeoPoint(la, ln));
  }
  return points;
}
