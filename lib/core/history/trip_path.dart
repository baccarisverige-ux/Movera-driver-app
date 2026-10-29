import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Where a past trip's line comes from (contract v0.17.0 §25, `TripPath.source`).
enum TripPathSource {
  /// Thinned from the trip's own GPS trace.
  driven,

  /// The server's road route (the trace was deleted after 30 days, or none
  /// was sent).
  planned,

  /// No line: only the pickup and drop-off this phone saved (the server
  /// could not be asked).
  pins,
}

/// The route of an ended trip for the past-ride map: the line, the pickup,
/// the stops and the drop-off.
class TripPath {
  const TripPath({
    required this.source,
    required this.points,
    required this.pickup,
    required this.dropoff,
    this.stops = const <GeoPoint>[],
  });

  final TripPathSource source;
  final List<GeoPoint> points;
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final List<GeoPoint> stops;

  /// Every point the map must show: the line and the pins.
  List<GeoPoint> get extent => [pickup, ...stops, ...points, dropoff];

  /// The two pins only, from points this phone saved with the trip.
  factory TripPath.pinsOnly(GeoPoint pickup, GeoPoint dropoff) => TripPath(
    source: TripPathSource.pins,
    points: const <GeoPoint>[],
    pickup: pickup,
    dropoff: dropoff,
  );

  /// A contract `TripPath`; null when it is not one (a bad source, fewer
  /// than two valid points, a missing pickup or drop-off).
  static TripPath? fromJson(Map<String, dynamic> json) {
    final source = switch (json['source']) {
      'driven' => TripPathSource.driven,
      'planned' => TripPathSource.planned,
      _ => null,
    };
    final pickup = _point(json['pickup']);
    final dropoff = _point(json['dropoff']);
    final raw = json['points'];
    if (source == null || pickup == null || dropoff == null || raw is! List) {
      return null;
    }
    final points = <GeoPoint>[];
    for (final item in raw) {
      final p = _point(item);
      if (p == null) return null;
      points.add(p);
    }
    if (points.length < 2) return null;
    final stops = <GeoPoint>[];
    final rawStops = json['stops'];
    if (rawStops is List) {
      for (final item in rawStops) {
        final p = _point(item);
        if (p != null) stops.add(p);
      }
    }
    return TripPath(
      source: source,
      points: List.unmodifiable(points),
      pickup: pickup,
      dropoff: dropoff,
      stops: List.unmodifiable(stops),
    );
  }

  static GeoPoint? _point(Object? value) {
    if (value is! Map) return null;
    final lat = value['lat'];
    final lng = value['lng'];
    if (lat is! num || lng is! num) return null;
    final p = GeoPoint(lat.toDouble(), lng.toDouble());
    return p.isValid ? p : null;
  }
}

/// `GET /trips/{tripId}/path` (contract v0.17.0 §25).
class LiveTripPath {
  LiveTripPath({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static String pathOf(String tripId) =>
      '/api/v1/trips/${Uri.encodeComponent(tripId)}/path';

  /// The trip's route, or null when the server could not say.
  Future<TripPath?> load(String tripId) async {
    try {
      return TripPath.fromJson(await _api.get(pathOf(tripId)));
    } catch (error) {
      DriverLog.warn('trip path not read: $error', name: 'live');
      return null;
    }
  }
}
