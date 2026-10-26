import 'dart:math' as math;

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/safety/ride_check.dart';

/// Decides when a Ride check opens. Pure logic: the trip screen feeds it
/// GPS fixes, the planned route and the end of the trip.
///
/// Each trigger opens at most once per trip. A possible crash has no sensor
/// source yet: [hardStop] is the hook a motion sensor adapter calls.
class RideCheckDetector {
  RideCheckDetector({this.rules = RideCheckRules.defaults});

  RideCheckRules rules;

  final Set<RideCheckTrigger> _fired = <RideCheckTrigger>{};
  DateTime? _tripStartedAt;
  double? _expectedSeconds;
  String? _legKey;
  List<GeoPoint> _planned = const <GeoPoint>[];
  GeoPoint? _stillAt;
  DateTime? _stillSince;
  bool _unwatched = false;

  /// The trip screen stopped feeding fixes and ticks (app paused, a card
  /// open). The car may drive meanwhile, so the next [observe] or [tick]
  /// starts the stop clock again instead of counting the gap as a stop
  /// (driver-u45).
  void unwatched() => _unwatched = true;

  void _rewatch(DateTime at) {
    if (!_unwatched) return;
    _unwatched = false;
    if (_stillSince != null) _stillSince = at;
  }

  bool fired(RideCheckTrigger trigger) => _fired.contains(trigger);

  /// The triggers that opened on this trip, for the saved trip.
  List<String> get firedNames => [for (final trigger in _fired) trigger.name];

  /// A restored trip: the triggers that already opened before (by name;
  /// unknown names are skipped) stay used (driver-u44).
  void restoreFired(Iterable<String> names) {
    for (final trigger in RideCheckTrigger.values) {
      if (names.contains(trigger.name)) _fired.add(trigger);
    }
  }

  /// The rider is in the car. Restored trips pass their saved start.
  void startTrip(DateTime at) {
    _tripStartedAt ??= at;
  }

  /// The first route of a leg is the plan; later reroutes are not.
  /// [wholeTrip]: this leg ends at the drop-off with no stops before it, so
  /// its time is the trip's expected time.
  void planLeg(
    String key,
    List<GeoPoint> points,
    double durationSeconds, {
    required bool wholeTrip,
  }) {
    if (_legKey == key || points.length < 2) return;
    _legKey = key;
    _planned = List<GeoPoint>.unmodifiable(points);
    if (wholeTrip && _expectedSeconds == null && durationSeconds > 0) {
      _expectedSeconds = durationSeconds;
    }
  }

  /// A fresh GPS fix mid-trip.
  RideCheckEvent? observe(
    GeoPoint point,
    DateTime at, {
    bool atPlannedStop = false,
    String? place,
    String? destination,
  }) {
    _rewatch(at);
    final still = _stillAt;
    if (atPlannedStop ||
        still == null ||
        still.distanceMetersTo(point) > RideCheckRules.stillRadiusMeters) {
      _stillAt = point;
      _stillSince = at;
    }
    if (atPlannedStop) return _longer(at);
    return _longStop(at, place) ??
        _offRoute(point, at, destination) ??
        _longer(at);
  }

  /// No new fix: GPS may stay quiet while the car stands still. Without
  /// [gps] the car may be moving, so only the trip time is checked.
  RideCheckEvent? tick(
    DateTime at, {
    bool gps = true,
    bool atPlannedStop = false,
    String? place,
  }) {
    _rewatch(at);
    if (atPlannedStop) {
      _stillSince = at;
      return _longer(at);
    }
    if (!gps) return _longer(at);
    return _longStop(at, place) ?? _longer(at);
  }

  /// The driver finishes the trip at [driver].
  RideCheckEvent? finish({
    required GeoPoint driver,
    required GeoPoint dropoff,
    required String dropoffAddress,
    required DateTime at,
  }) {
    const trigger = RideCheckTrigger.droppedFar;
    final meters = driver.distanceMetersTo(dropoff);
    if (meters <= rules.farDropMeters) return null;
    return _fire(trigger, at, droppedFarReason(meters, dropoffAddress));
  }

  /// Hook for a motion sensor: a very hard stop or impact.
  RideCheckEvent? hardStop(DateTime at, {String? place}) =>
      _fire(RideCheckTrigger.possibleCrash, at, crashReason(place));

  /// Demo tools: always opens, whatever the rules and earlier checks.
  RideCheckEvent demo(
    RideCheckTrigger trigger,
    DateTime at, {
    String? place,
    required String destination,
  }) => RideCheckEvent(
    trigger: trigger,
    at: at,
    demo: true,
    reason: switch (trigger) {
      RideCheckTrigger.longStop => longStopReason(rules.longStopMinutes, place),
      RideCheckTrigger.droppedFar => droppedFarReason(
        rules.farDropMeters + 1200,
        destination,
      ),
      RideCheckTrigger.offRoute => offRouteReason(
        rules.offRouteKm * 1000 + 400,
        destination,
      ),
      RideCheckTrigger.possibleCrash => crashReason(place),
    },
  );

  RideCheckEvent? _longStop(DateTime at, String? place) {
    final since = _stillSince;
    if (since == null || _tripStartedAt == null) return null;
    final stopped = at.difference(since);
    if (stopped <= Duration(minutes: rules.longStopMinutes)) return null;
    return _fire(
      RideCheckTrigger.longStop,
      at,
      longStopReason(stopped.inMinutes, place),
    );
  }

  RideCheckEvent? _offRoute(GeoPoint point, DateTime at, String? destination) {
    if (_planned.length < 2) return null;
    final meters = distanceToRouteMeters(point, _planned);
    if (meters <= rules.offRouteKm * 1000) return null;
    return _fire(
      RideCheckTrigger.offRoute,
      at,
      offRouteReason(meters, destination),
    );
  }

  RideCheckEvent? _longer(DateTime at) {
    final started = _tripStartedAt;
    final expected = _expectedSeconds;
    if (started == null || expected == null) return null;
    final elapsed = at.difference(started).inSeconds;
    final limit = expected * (1 + rules.longerThanPercent / 100);
    if (elapsed <= limit) return null;
    final percent = ((elapsed / expected - 1) * 100).round();
    return _fire(
      RideCheckTrigger.offRoute,
      at,
      RideCheckReason.longer(percent),
    );
  }

  RideCheckEvent? _fire(
    RideCheckTrigger trigger,
    DateTime at,
    RideCheckReason reason,
  ) {
    if (!rules.enabled(trigger) || !_fired.add(trigger)) return null;
    return RideCheckEvent(trigger: trigger, reason: reason, at: at);
  }

  static RideCheckReason longStopReason(int minutes, String? place) =>
      RideCheckReason.longStop(minutes, place);

  static RideCheckReason droppedFarReason(double meters, String address) =>
      RideCheckReason.droppedFar(meters, address);

  static RideCheckReason offRouteReason(double meters, String? destination) =>
      RideCheckReason.offRoute(meters, destination);

  static RideCheckReason crashReason(String? place) =>
      RideCheckReason.crash(place);

  /// Shortest distance from [point] to the polyline [route], in meters.
  static double distanceToRouteMeters(GeoPoint point, List<GeoPoint> route) {
    if (route.isEmpty) return double.infinity;
    if (route.length == 1) return point.distanceMetersTo(route.first);
    // Local flat projection around the point; fine at city scale.
    const earth = 6371000.0;
    final cosLat = math.cos(point.latitude * math.pi / 180);
    math.Point<double> flat(GeoPoint p) => math.Point(
      (p.longitude - point.longitude) * math.pi / 180 * earth * cosLat,
      (p.latitude - point.latitude) * math.pi / 180 * earth,
    );
    var best = double.infinity;
    var a = flat(route.first);
    for (final next in route.skip(1)) {
      final b = flat(next);
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final length = dx * dx + dy * dy;
      final t = length == 0
          ? 0.0
          : ((-a.x * dx - a.y * dy) / length).clamp(0.0, 1.0);
      final x = a.x + dx * t;
      final y = a.y + dy * t;
      best = math.min(best, math.sqrt(x * x + y * y));
      a = b;
    }
    return best;
  }
}
