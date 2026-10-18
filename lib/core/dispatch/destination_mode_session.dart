import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/geo/geo_point.dart';

/// The driver's destination today (R13-9): when it was set, how many were
/// set today, and the latest road route to it, shared by Home and the trip
/// screen. Admin limits come from [DestinationModeRules.current].
class DestinationModeSession {
  DestinationModeSession({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static DestinationModeSession instance = DestinationModeSession();

  final DateTime Function() _now;
  final List<DateTime> _started = <DateTime>[];
  DateTime? _activeSince;
  bool _timedOut = false;
  GeoPoint? _routeTo;
  List<GeoPoint> _route = const <GeoPoint>[];

  DateTime get now => _now();

  /// Destinations set on [now]'s day.
  int usedToday([DateTime? at]) {
    final day = at ?? _now();
    return _started
        .where((t) => t.year == day.year && t.month == day.month && t.day == day.day)
        .length;
  }

  /// Why a new destination cannot be set now, or null when it can.
  DestinationRefusal? refusal({DestinationModeRules? rules}) {
    final r = rules ?? DestinationModeRules.current;
    if (!r.enabled) { return DestinationRefusal.off; }
    if (r.dailyLimitOn && usedToday() >= r.destinationsPerDay) {
      return DestinationRefusal.usedToday;
    }
    return null;
  }

  /// A destination was set: it counts for today and its time starts.
  void started() {
    final at = _now();
    _activeSince = at;
    _timedOut = false;
    _started.add(at);
    _route = const <GeoPoint>[];
    _routeTo = null;
  }

  void ended() {
    _activeSince = null;
    _route = const <GeoPoint>[];
    _routeTo = null;
  }

  /// Time left before the admin time limit ends it; null without a limit
  /// or a destination.
  Duration? timeLeft({DestinationModeRules? rules}) {
    final since = _activeSince;
    final limit = (rules ?? DestinationModeRules.current).timeLimit;
    if (since == null || limit == null) { return null; }
    final left = since.add(limit).difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The admin time limit has run out (or ended the destination).
  bool expired({DestinationModeRules? rules}) =>
      _timedOut || timeLeft(rules: rules) == Duration.zero;

  /// The time limit ended the destination.
  void timedOut() {
    ended();
    _timedOut = true;
  }

  /// The road route Home drew to [destination].
  void keepRoute(GeoPoint destination, List<GeoPoint> points) {
    _routeTo = destination;
    _route = List<GeoPoint>.unmodifiable(points);
  }

  /// The road route to [destination], or empty when there is none.
  List<GeoPoint> routeTo(GeoPoint destination) =>
      _routeTo != null && _routeTo!.distanceMetersTo(destination) < 50
          ? _route
          : const <GeoPoint>[];
}

enum DestinationRefusal {
  /// Destination mode is off in this zone.
  off,

  /// Today's destinations are used up.
  usedToday,
}
