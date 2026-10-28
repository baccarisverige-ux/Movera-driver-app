/// A zone of `GET /driver/zones` (contract v0.11.0 §20): an OPEN zone with
/// its outline and its names in the app languages.
class DriverZone {
  const DriverZone({
    required this.id,
    required this.polygon,
    this.names = const {},
    this.country,
    this.currency,
    this.timeZone,
    this.kind = 'operating',
  });

  final String id;
  final Map<String, String> names;
  final String? country;
  final String? currency;
  final String? timeZone;

  /// `operating` (a city zone) or `airport`.
  final String kind;

  /// `[lat, lng]` points in order, not closed.
  final List<List<double>> polygon;

  bool get isAirport => kind == 'airport';

  /// The name in [language], else English, else any, else the id.
  String nameIn(String language) =>
      names[language] ??
      names['en'] ??
      (names.isEmpty ? id : names.values.first);

  ({double south, double west, double north, double east}) get bounds {
    var south = polygon.first[0], north = south;
    var west = polygon.first[1], east = west;
    for (final p in polygon) {
      if (p[0] < south) south = p[0];
      if (p[0] > north) north = p[0];
      if (p[1] < west) west = p[1];
      if (p[1] > east) east = p[1];
    }
    return (south: south, west: west, north: north, east: east);
  }

  double get area {
    final b = bounds;
    return (b.north - b.south) * (b.east - b.west);
  }

  /// True when the outline holds [lat], [lng] (a point on the edge is in).
  bool contains(double lat, double lng) {
    final b = bounds;
    if (lat < b.south || lat > b.north || lng < b.west || lng > b.east) {
      return false;
    }
    return polygonHolds(polygon, lat, lng);
  }

  /// A zone of the answer, or null when [raw] is not one.
  static DriverZone? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['zoneId'];
    if (id is! String || id.isEmpty) return null;
    final rawPolygon = raw['polygon'];
    if (rawPolygon is! List) return null;
    final points = <List<double>>[];
    for (final point in rawPolygon) {
      if (point is! List || point.length < 2) return null;
      final lat = point[0];
      final lng = point[1];
      if (lat is! num || lng is! num) return null;
      points.add([lat.toDouble(), lng.toDouble()]);
    }
    if (points.length < 3) return null;
    final names = <String, String>{};
    final rawNames = raw['names'];
    if (rawNames is Map) {
      rawNames.forEach((key, value) {
        if (key is String && value is String && value.trim().isNotEmpty) {
          names[key] = value.trim();
        }
      });
    }
    String? text(String key) => raw[key] is String ? raw[key] as String : null;
    return DriverZone(
      id: id,
      polygon: points,
      names: names,
      country: text('country'),
      currency: text('currency'),
      timeZone: text('timeZone'),
      kind: text('kind') ?? 'operating',
    );
  }

  Map<String, Object?> toJson() => {
    'zoneId': id,
    'names': names,
    if (country != null) 'country': country,
    if (currency != null) 'currency': currency,
    if (timeZone != null) 'timeZone': timeZone,
    'kind': kind,
    'polygon': polygon,
  };
}

/// Point in polygon with a point on an edge inside. [outline] is
/// `[lat, lng]` points, not closed.
bool polygonHolds(List<List<double>> outline, double lat, double lng) {
  const eps = 1e-12;
  var inside = false;
  for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
    final ay = outline[i][0], ax = outline[i][1];
    final by = outline[j][0], bx = outline[j][1];
    final cross = (bx - ax) * (lat - ay) - (by - ay) * (lng - ax);
    if (cross.abs() < eps &&
        lng >= (ax < bx ? ax : bx) - eps &&
        lng <= (ax < bx ? bx : ax) + eps &&
        lat >= (ay < by ? ay : by) - eps &&
        lat <= (ay < by ? by : ay) + eps) {
      return true;
    }
    if ((ay > lat) != (by > lat) &&
        lng < (bx - ax) * (lat - ay) / (by - ay) + ax) {
      inside = !inside;
    }
  }
  return inside;
}
