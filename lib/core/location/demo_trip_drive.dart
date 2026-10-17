import 'dart:async';
import 'dart:math' as math;

import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// What a scripted demo drive does once the rider is in the car.
enum DemoDriveScript {
  /// Drives toward the drop-off and stops for good more than admin's
  /// "finished far from drop-off" km before it.
  farDropoff,

  /// Drives part of the way, stands still for more than admin's
  /// "unexpected long stop" minutes, then drives on to the drop-off.
  longStop,
}

/// The car's GPS on a RideCheck demo trip: fresh, accurate fixes along the
/// trip, one per [tick]. The trip screen treats them as real GPS, so the
/// real RideCheck checks decide when the card opens; nothing here opens it.
///
/// Until [startTrip] the car waits at the pickup. The path is a straight
/// line pickup → drop-off until [followRoad] gives the planned road.
class DemoTripDrive implements DriverLocationRepository {
  DemoTripDrive({
    required this.script,
    required this.pickup,
    required this.dropoff,
    this.tick = const Duration(seconds: 1),
    RideCheckAdminConfig? config,
  }) : config = config ?? RideCheckAdminConfig.current;

  /// Demo dispatch ids of the two RideCheck demo trips.
  static const String farDropoffOfferId = 'ridecheck-demo-far-dropoff';
  static const String longStopOfferId = 'ridecheck-demo-long-stop';

  /// The scripted drive for trip [tripId] (a dispatch id, or one made by
  /// `tripOccurrenceId`), or null for any other trip.
  static DemoTripDrive? forTrip(
    String tripId, {
    required GeoPoint pickup,
    required GeoPoint dropoff,
  }) {
    bool matches(String id) => tripId == id || tripId.startsWith('$id-');
    final script = matches(farDropoffOfferId)
        ? DemoDriveScript.farDropoff
        : matches(longStopOfferId)
        ? DemoDriveScript.longStop
        : null;
    return script == null
        ? null
        : DemoTripDrive(script: script, pickup: pickup, dropoff: dropoff);
  }

  final DemoDriveScript script;
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final Duration tick;
  final RideCheckAdminConfig config;

  /// Ticks of driving to the far stop, or to and from the long stop.
  static const int driveTicks = 40;

  /// Where the long stop is, as a share of the path.
  static const double longStopAt = 0.4;

  /// The far stop is this much past admin's distance from the drop-off.
  static const double farMarginMeters = 1500;

  List<GeoPoint> _path = const <GeoPoint>[];
  bool _road = false;
  int? _ticks;
  Timer? _timer;
  GeoPoint? _last;
  late final StreamController<DriverLocation> _fixes =
      StreamController<DriverLocation>.broadcast(
        onListen: _resume,
        onCancel: _pause,
      );

  /// The rider is in the car: the script starts.
  void startTrip() {
    _ticks ??= 0;
  }

  bool get started => _ticks != null;

  /// The planned road of the trip; the drive follows it from now on. Only
  /// the first road counts, like the trip's own plan.
  void followRoad(List<GeoPoint> road) {
    if (_road || road.length < 2) return;
    _road = true;
    _path = List<GeoPoint>.unmodifiable(road);
  }

  /// Ticks the car stands still at the long stop: just over admin's
  /// minutes.
  int get stopTicks =>
      config.longStopMinutes * 60 * 1000 ~/ tick.inMilliseconds +
      30 * 1000 ~/ tick.inMilliseconds;

  /// Where the car is after [ticks] ticks of the trip.
  GeoPoint positionAt(int ticks) {
    switch (script) {
      case DemoDriveScript.farDropoff:
        final end = _farStopShare();
        return _along(end * math.min(1, ticks / driveTicks));
      case DemoDriveScript.longStop:
        if (ticks <= driveTicks) {
          return _along(longStopAt * ticks / driveTicks);
        }
        final after = ticks - driveTicks - stopTicks;
        if (after <= 0) return _along(longStopAt);
        return _along(
          longStopAt +
              (1 - longStopAt) * math.min(1, after / driveTicks),
        );
    }
  }

  /// The car right now.
  GeoPoint get position {
    final ticks = _ticks;
    return ticks == null ? pickup : positionAt(ticks);
  }

  List<GeoPoint> get _points =>
      _path.length >= 2 ? _path : <GeoPoint>[pickup, dropoff];

  /// The last share of the path still more than admin's km plus a margin
  /// from the drop-off, in a straight line (what Finish measures).
  double _farStopShare() {
    final limit = config.finishFarFromDropoffMeters + farMarginMeters;
    const steps = 200;
    for (var i = steps; i >= 0; i--) {
      final share = i / steps;
      if (_along(share).distanceMetersTo(dropoff) >= limit) return share;
    }
    return 0;
  }

  GeoPoint _along(double share) {
    final points = _points;
    final legs = <double>[
      for (var i = 1; i < points.length; i++)
        points[i - 1].distanceMetersTo(points[i]),
    ];
    final total = legs.fold<double>(0, (sum, leg) => sum + leg);
    if (total <= 0) return points.first;
    var left = total * share.clamp(0.0, 1.0);
    for (var i = 0; i < legs.length; i++) {
      if (left <= legs[i] || i == legs.length - 1) {
        final t = legs[i] == 0 ? 0.0 : (left / legs[i]).clamp(0.0, 1.0);
        final a = points[i], b = points[i + 1];
        return GeoPoint(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      left -= legs[i];
    }
    return points.last;
  }

  DriverLocation _fix() {
    final point = position;
    final last = _last;
    _last = point;
    final moved = last == null ? 0.0 : last.distanceMetersTo(point);
    return DriverLocation(
      point: point,
      headingDegrees: last == null || moved < 1 ? 0 : _bearing(last, point),
      speedMetersPerSecond: moved * 1000 / tick.inMilliseconds,
      measuredAt: DateTime.now(),
      accuracyMeters: 5,
    );
  }

  static double _bearing(GeoPoint from, GeoPoint to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) {
      final ticks = _ticks;
      if (ticks != null) _ticks = ticks + 1;
      if (!_fixes.isClosed) _fixes.add(_fix());
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix();

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _fixes.stream;
}
