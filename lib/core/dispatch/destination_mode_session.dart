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
  ({double meters, double seconds, DateTime at})? _figures;
  String? _address;
  GeoPoint? _position;

  DateTime get now => _now();

  /// When the current destination was set; null without one.
  DateTime? get activeSince => _activeSince;

  /// The current destination, wherever it was set (Home or the trip
  /// screen, driver-u65); null without one.
  String? get activeAddress => _activeSince == null ? null : _address;
  GeoPoint? get activePosition => _activeSince == null ? null : _position;

  /// Destinations set on [now]'s day.
  int usedToday([DateTime? at]) {
    final day = at ?? _now();
    return _started
        .where(
          (t) => t.year == day.year && t.month == day.month && t.day == day.day,
        )
        .length;
  }

  /// Why a new destination cannot be set now, or null when it can.
  DestinationRefusal? refusal({DestinationModeRules? rules}) {
    final r = rules ?? DestinationModeRules.current;
    if (!r.enabled) {
      return DestinationRefusal.off;
    }
    if (r.dailyLimitOn && usedToday() >= r.destinationsPerDay) {
      return DestinationRefusal.usedToday;
    }
    return null;
  }

  /// A destination was set: it counts for today and its time starts.
  void started({String? address, GeoPoint? position}) {
    final at = _now();
    _activeSince = at;
    _address = address;
    _position = position;
    _timedOut = false;
    _started.add(at);
    _route = const <GeoPoint>[];
    _routeTo = null;
    _figures = null;
  }

  /// A trip restored after a restart had a destination the empty session
  /// does not know: it counts for today and its time runs from [since],
  /// the trip's last save (driver-r4-11). Ignored when one is active.
  void restored({
    required DateTime since,
    String? address,
    GeoPoint? position,
  }) {
    if (_activeSince != null) {
      return;
    }
    _activeSince = since;
    _address = address;
    _position = position;
    _timedOut = false;
    _started.add(since);
  }

  void ended() {
    _activeSince = null;
    _address = null;
    _position = null;
    _route = const <GeoPoint>[];
    _routeTo = null;
    _figures = null;
  }

  /// Time left before the admin time limit ends it; null without a limit
  /// or a destination.
  Duration? timeLeft({DestinationModeRules? rules}) {
    final since = _activeSince;
    final limit = (rules ?? DestinationModeRules.current).timeLimit;
    if (since == null || limit == null) {
      return null;
    }
    final left = since.add(limit).difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// driver-u123: when the admin time limit ends the destination; null
  /// without a limit (it then never ends on its own) or a destination.
  DateTime? endsAt({DestinationModeRules? rules}) {
    final left = timeLeft(rules: rules);
    return left == null ? null : _now().add(left);
  }

  /// The admin time limit has run out (or ended the destination).
  bool expired({DestinationModeRules? rules}) =>
      _timedOut || timeLeft(rules: rules) == Duration.zero;

  /// The time limit ended the destination.
  void timedOut() {
    ended();
    _timedOut = true;
  }

  /// The road route Home drew to [destination], with its distance and
  /// time when known.
  void keepRoute(
    GeoPoint destination,
    List<GeoPoint> points, {
    double? meters,
    double? seconds,
  }) {
    _routeTo = destination;
    _route = List<GeoPoint>.unmodifiable(points);
    _figures = meters == null || seconds == null
        ? null
        : (meters: meters, seconds: seconds, at: _now());
  }

  /// How long the last road figures stand in for a failed refresh or a
  /// lost GPS fix (driver-r5-20).
  static const Duration figuresLast = Duration(minutes: 5);

  /// The last road route's (meters, seconds) to [destination] while they
  /// are recent; null without a route or once older than [figuresLast].
  (double, double)? figuresTo(GeoPoint destination) {
    final f = _figures;
    if (f == null || routeTo(destination).isEmpty) {
      return null;
    }
    return _now().difference(f.at) > figuresLast ? null : (f.meters, f.seconds);
  }

  /// A road route to [destination] was drawn since it was set.
  bool hadRouteTo(GeoPoint destination) => routeTo(destination).isNotEmpty;

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
