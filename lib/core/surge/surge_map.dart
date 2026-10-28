import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Contract v0.7.2 §17 (`contract.json#driverSurgeMap`, owner 2026-10-28):
/// the driver sees a surge only as a coloured zone on the Home map. The
/// server sends a level and a rectangle, never the multiplier; the app
/// shows no text, number or money for it.
enum SurgeLevel {
  low,
  medium,
  high;

  /// The wire value (`low | medium | high`), or null for anything else.
  static SurgeLevel? fromWire(Object? value) => switch (value) {
    'low' => SurgeLevel.low,
    'medium' => SurgeLevel.medium,
    'high' => SurgeLevel.high,
    _ => null,
  };

  /// `contract.json#driverSurgeMap.levels`, the server's own rule
  /// (`fixtures/surge_levels.json`): null = not listed, no colour. The app
  /// never receives a multiplier; this exists so the demo's zones and the
  /// contract replay use the same rule as the server.
  static SurgeLevel? forMultiplier(double multiplier) {
    if (multiplier <= 1) return null;
    if (multiplier < 1.5) return SurgeLevel.low;
    if (multiplier <= 2.5) return SurgeLevel.medium;
    return SurgeLevel.high;
  }
}

/// A zone's rectangle (`bounds { south, west, north, east }`).
@immutable
class SurgeBounds {
  const SurgeBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  static SurgeBounds? fromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['south'], w = json['west'];
    final n = json['north'], e = json['east'];
    if (s is! num || w is! num || n is! num || e is! num) return null;
    if (s > n || w > e) return null;
    return SurgeBounds(
      south: s.toDouble(),
      west: w.toDouble(),
      north: n.toDouble(),
      east: e.toDouble(),
    );
  }

  /// The four corners, clockwise from south-west.
  List<GeoPoint> get corners => [
    GeoPoint(south, west),
    GeoPoint(north, west),
    GeoPoint(north, east),
    GeoPoint(south, east),
  ];

  bool contains(GeoPoint point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  /// Metres from [point] to the nearest edge; 0 inside.
  double distanceMetersTo(GeoPoint point) {
    if (contains(point)) return 0;
    final nearest = GeoPoint(
      point.latitude.clamp(south, north).toDouble(),
      point.longitude.clamp(west, east).toDouble(),
    );
    return point.distanceMetersTo(nearest);
  }

  @override
  bool operator ==(Object other) =>
      other is SurgeBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// `DriverSurgeZone { zoneId, level, bounds }`.
@immutable
class DriverSurgeZone {
  const DriverSurgeZone({
    required this.zoneId,
    required this.level,
    required this.bounds,
  });

  final String zoneId;
  final SurgeLevel level;
  final SurgeBounds bounds;

  /// Null when the item is not a usable zone (unknown level, bad bounds).
  static DriverSurgeZone? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['zoneId'];
    final level = SurgeLevel.fromWire(json['level']);
    final bounds = SurgeBounds.fromJson(json['bounds']);
    if (id is! String || id.isEmpty || level == null || bounds == null) {
      return null;
    }
    return DriverSurgeZone(zoneId: id, level: level, bounds: bounds);
  }

  @override
  bool operator ==(Object other) =>
      other is DriverSurgeZone &&
      other.zoneId == zoneId &&
      other.level == level &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(zoneId, level, bounds);
}

/// The answer of `GET /driver/surge-map`: `{ at, zones }`. Items the app
/// cannot read are left out.
List<DriverSurgeZone> surgeZonesFromJson(Map<String, dynamic> json) {
  final zones = json['zones'];
  if (zones is! List) {
    throw const FormatException('surge-map answer without zones');
  }
  return List<DriverSurgeZone>.unmodifiable([
    for (final item in zones) ?DriverSurgeZone.fromJson(item),
  ]);
}

/// `contract.json#driverSurgeMap.tipDistanceKm`.
const double surgeTipDistanceKm = 3;

/// True while [position] is inside a listed zone or less than
/// [surgeTipDistanceKm] from its rectangle, any level: the waiting tip
/// "Hög bonus i närheten" shows then.
bool nearSurgeZone(GeoPoint? position, Iterable<DriverSurgeZone> zones) {
  if (position == null) return false;
  for (final zone in zones) {
    if (zone.bounds.distanceMetersTo(position) < surgeTipDistanceKm * 1000) {
      return true;
    }
  }
  return false;
}

/// Where the surge zones come from: the server in a live build, the demo's
/// own set otherwise.
abstract class SurgeMapSource {
  Future<List<DriverSurgeZone>> fetch();
}

/// The demo build (no server): three zones around the driver, one of each
/// level, so the owner's demo shows the design. Their levels come from
/// demo multipliers through the server's rule ([SurgeLevel.forMultiplier]).
class DemoSurgeMapSource implements SurgeMapSource {
  DemoSurgeMapSource({required this.center});

  /// The driver's position now.
  final GeoPoint Function() center;

  /// (north offset km, east offset km, half height km, half width km,
  /// multiplier). The nearest one starts just under 1 km away, so the
  /// "High boost nearby" rule holds in the demo too.
  static const List<(double, double, double, double, double)> _layout = [
    (1.6, -1.4, 0.7, 0.9, 1.3),
    (-1.5, 1.8, 0.8, 1.0, 2.0),
    (2.2, 2.4, 0.6, 0.8, 3.0),
  ];

  static const List<String> _ids = ['DEMO-LOW', 'DEMO-MEDIUM', 'DEMO-HIGH'];

  @override
  Future<List<DriverSurgeZone>> fetch() async => zonesAround(center());

  static List<DriverSurgeZone> zonesAround(GeoPoint at) {
    const kmPerDegLat = 110.574;
    final kmPerDegLng =
        111.320 * math.cos(at.latitude * math.pi / 180).abs().clamp(0.01, 1);
    return [
      for (var i = 0; i < _layout.length; i++)
        if (SurgeLevel.forMultiplier(_layout[i].$5) case final level?)
          DriverSurgeZone(
            zoneId: _ids[i],
            level: level,
            bounds: SurgeBounds(
              south:
                  at.latitude + (_layout[i].$1 - _layout[i].$3) / kmPerDegLat,
              north:
                  at.latitude + (_layout[i].$1 + _layout[i].$3) / kmPerDegLat,
              west:
                  at.longitude + (_layout[i].$2 - _layout[i].$4) / kmPerDegLng,
              east:
                  at.longitude + (_layout[i].$2 + _layout[i].$4) / kmPerDegLng,
            ),
          ),
    ];
  }
}

/// Home's surge zones (contract `driverSurgeMap.refresh`): asked on going
/// online, then every [every] while online on Home, and when the app comes
/// back to the front. A failed call keeps the last answer; offline there
/// are no zones.
class SurgeMapController extends ChangeNotifier {
  SurgeMapController({
    required SurgeMapSource source,
    this.every = const Duration(seconds: 60),
  }) : _source = source;

  final SurgeMapSource _source;
  final Duration every;

  List<DriverSurgeZone> _zones = const [];
  bool _online = false;
  bool _onHome = true;
  bool _disposed = false;
  Timer? _timer;
  int _epoch = 0;

  /// The zones to colour; empty while offline.
  List<DriverSurgeZone> get zones => _zones;

  bool get online => _online;

  /// Follows Home: [online] is the driver's availability, [onHome] is
  /// Home on screen with the app in front. Going online asks at once.
  void sync({required bool online, bool onHome = true}) {
    if (_disposed) return;
    final wasOnline = _online;
    final wasOnHome = _onHome;
    _online = online;
    _onHome = onHome;
    if (!online) {
      _timer?.cancel();
      _timer = null;
      _epoch++;
      if (_zones.isNotEmpty) {
        _zones = const [];
        notifyListeners();
      }
      return;
    }
    if (!onHome) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (!wasOnline || !wasOnHome || _timer == null) {
      unawaited(refresh());
      _restartTimer();
    }
  }

  /// The app is in front again: ask now (while online).
  void resumed() {
    if (_disposed || !_online) return;
    _onHome = true;
    unawaited(refresh());
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) {
      if (_online && _onHome) unawaited(refresh());
    });
  }

  /// One read; a failure keeps the last zones.
  Future<void> refresh() async {
    if (_disposed || !_online) return;
    final epoch = _epoch;
    try {
      final next = await _source.fetch();
      if (_disposed || !_online || epoch != _epoch) return;
      if (!listEquals(next, _zones)) {
        _zones = List<DriverSurgeZone>.unmodifiable(next);
        notifyListeners();
      }
    } catch (error) {
      DriverLog.warn('surge map not read: $error', name: 'live');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
