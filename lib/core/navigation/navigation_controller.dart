import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

enum RouteLoadState { idle, loading, ready, failed }

/// Why the route on screen is missing or changing. The words come from
/// [text], in the driver's language; the logic only compares the value.
enum NavigationRouteStatus {
  updating,
  recalculating,
  unavailableRetry,
  unavailableCheckLocation;

  String get text => switch (this) {
    updating => tr.navRouteUpdating,
    recalculating => tr.navRouteRecalculating,
    unavailableRetry => tr.navRouteUnavailableRetry,
    unavailableCheckLocation => tr.navRouteUnavailableLocation,
  };
}

class NavigationSnapshot {
  const NavigationSnapshot({
    required this.vehicle,
    required this.headingDegrees,
    required this.followCamera,
    required this.waitingAtPickup,
    this.route,
    this.banner,
    this.status,
    this.offRoute = false,
  });

  final GeoPoint vehicle;
  final double headingDegrees;
  final bool followCamera;
  final bool waitingAtPickup;
  final RoadRoute? route;
  final NavigationBanner? banner;
  final String? status;
  final bool offRoute;

  static const stockholm = GeoPoint(59.3262, 18.0595);
}

/// Owns live route progress, next-maneuver banner and displayed vehicle pose.
///
/// High-frequency GPS must not rebuild the whole trip screen. The ride
/// lifecycle stays in [ActiveRideController]; this controller never pops
/// navigation or completes a trip.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.routeRepository,
    this.offRouteThresholdMeters = 50,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _progress = RouteProgressCalculator(
         offRouteThresholdMeters: offRouteThresholdMeters,
       );

  final RouteRepository routeRepository;
  final double offRouteThresholdMeters;
  final RouteProgressCalculator _progress;

  /// Clock for when routes are asked for.
  final DateTime Function() _now;

  NavigationSnapshot _snapshot = const NavigationSnapshot(
    vehicle: NavigationSnapshot.stockholm,
    headingDegrees: 0,
    followCamera: true,
    waitingAtPickup: false,
  );
  RoadRoute? _route;
  GeoPoint? _destination;
  ActiveRideStage _stage = ActiveRideStage.headingToPickup;
  int _routeRequestToken = 0;
  DateTime? _lastRouteAt;
  int _instructionHint = 0;
  double? _progressAlong;
  // driver-u26/u28: the last on-route progress. Off route the projection
  // starts again from scratch (_progressAlong is null), but the share
  // already driven, and with it the ETA and leg progress, stays known.
  double? _drivenAlong;
  DateTime? _lastMeasuredAt;
  double? _routeLength;
  bool _userPausedFollow = false;
  NavigationRouteStatus? _status;
  String? _locationWarning;
  String? get _displayStatus => _locationWarning ?? _status?.text;
  Timer? _rerouteDebounce;
  bool _disposed = false;
  bool _routeInFlight = false;
  String? _targetLabel;
  ActiveRideStage? _lastRouteStage;
  RouteLoadState _routeState = RouteLoadState.idle;
  RouteLoadState get routeState => _routeState;
  int _reroutes = 0;

  /// Accepted GPS fixes that moved the car. A route asked for at this count
  /// already answered for where the car is now.
  int _fixSeq = 0;
  int _routeFixSeq = -1;

  /// Where the last reroute was asked from, and how many reroutes in a row
  /// started within [_stuckMeters] of it (parked off the road).
  GeoPoint? _rerouteOrigin;
  int _stuckReroutes = 0;
  static const double _stuckMeters = 20;
  static const Duration _rerouteDelay = Duration(seconds: 2);
  static const Duration _maxRerouteDelay = Duration(seconds: 60);

  /// Last accepted measured fix, and a far one held back until a second fix
  /// agrees with it.
  DriverLocation? _lastMeasured;
  DriverLocation? _heldJump;

  /// Faster than this between two fixes is a GPS jump, not driving.
  static const double maxPlausibleSpeedMetersPerSecond = 70;

  /// Routes replaced because the driver left the route. The island says
  /// "Route updated" only when this grows, never after a silent refresh.
  int get reroutes => _reroutes;

  /// Driving along the route never asks for a new one; only this slow,
  /// silent refresh keeps the time to arrival fresh. The route and its
  /// instructions stay on screen while it loads.
  static const silentRefreshInterval = Duration(seconds: 90);

  Future<void> retryRoute() async {
    final destination = _destination;
    if (destination == null || _disposed || _routeInFlight) return;
    await ensureRoute(
      origin: _snapshot.vehicle,
      destination: destination,
      force: true,
      targetLabel: _targetLabel,
    );
  }

  NavigationSnapshot get snapshot => _snapshot;
  RoadRoute? get route => _route;

  /// Share of the current route already driven, 0..1; null without one.
  double? get routeFraction {
    final route = _route;
    final length = _routeLength;
    if (route == null || length == null || length <= 0) {
      return null;
    }
    return ((_progressAlong ?? _drivenAlong ?? 0) / length).clamp(0.0, 1.0);
  }

  bool get followCamera => !_userPausedFollow;
  String? get status => _displayStatus;

  void setStage(ActiveRideStage stage) {
    if (_stage != stage) {
      _routeRequestToken++;
      _routeInFlight = false;
      _rerouteDebounce?.cancel();
      _rerouteDebounce = null;
      _route = null;
      _routeLength = null;
      _destination = null;
      _targetLabel = null;
      _lastRouteAt = null;
      _lastRouteStage = null;
      _status = null;
      _routeState = RouteLoadState.idle;
      _instructionHint = 0;
      _progressAlong = null;
      _drivenAlong = null;
      _rerouteOrigin = null;
      _stuckReroutes = 0;
    }
    _stage = stage;
    if (stage == ActiveRideStage.waitingForRider) {
      _status = null;
      _rebuildBanner();
      return;
    }
    _rebuildBanner();
  }

  void pauseFollow() {
    if (_userPausedFollow) {
      return;
    }
    _userPausedFollow = true;
    _rebuildBanner();
  }

  void resumeFollow() {
    _userPausedFollow = false;
    _rebuildBanner();
  }

  /// Returns false only for a fix held back as a GPS jump: the caller
  /// should not draw it either. Every other fix returns true.
  bool setVehicle(DriverLocation location) {
    if (_disposed) return true;
    final point = location.point;
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return true;
    }
    // Real GPS measurements carry freshness/accuracy evidence. Reject
    // unusable ones before altering the route, progress or recovery banner.
    // Keep metadata-free demo/test positions working as before.
    if ((location.measuredAt != null || location.accuracyMeters != null) &&
        !location.isUsableAt(DateTime.now())) {
      return true;
    }
    final at = location.measuredAt;
    if (at != null &&
        _lastMeasuredAt != null &&
        at.isBefore(_lastMeasuredAt!)) {
      return true;
    }
    // One far outlier must not move progress or start a reroute.
    if (_isGpsJump(location)) return false;
    if (at != null) {
      _lastMeasuredAt = at;
      _lastMeasured = location;
    }
    // A valid fix may arrive at exactly the same coordinates as the last
    // point, especially after a brief stream interruption. Clear only the
    // transient GPS warning; a failed road route still needs explicit retry.
    final restoredGps =
        _locationWarning != null && location.isUsableAt(DateTime.now());
    if (restoredGps) {
      _locationWarning = null;
    }
    final moved = _snapshot.vehicle.distanceMetersTo(location.point);
    if (!restoredGps &&
        moved < 0.4 &&
        (location.headingDegrees - _snapshot.headingDegrees).abs() < 1) {
      return true;
    }

    final heading = location.courseOr(_snapshot.headingDegrees);
    _fixSeq++;

    _snapshot = NavigationSnapshot(
      vehicle: location.point,
      headingDegrees: heading,
      followCamera: !_userPausedFollow,
      waitingAtPickup: _stage == ActiveRideStage.waitingForRider,
      route: _route,
      banner: _snapshot.banner,
      status: _displayStatus,
      offRoute: _snapshot.offRoute,
    );
    _rebuildBanner();
    return true;
  }

  /// True for a fix that implies more than [maxPlausibleSpeedMetersPerSecond]
  /// from the last accepted one. A second fix that agrees with it is let
  /// through: the car really is there (a long tunnel, a bad first fix).
  bool _isGpsJump(DriverLocation location) {
    final last = _lastMeasured;
    if (last == null || location.measuredAt == null) return false;
    if (_impliedSpeed(last, location) <= maxPlausibleSpeedMetersPerSecond) {
      _heldJump = null;
      return false;
    }
    final held = _heldJump;
    if (held != null &&
        _impliedSpeed(held, location) <= maxPlausibleSpeedMetersPerSecond) {
      _heldJump = null;
      return false;
    }
    _heldJump = location;
    return true;
  }

  /// Metres per second between two fixes, after both accuracies. Fixes less
  /// than a second apart count as a second apart.
  static double _impliedSpeed(DriverLocation from, DriverLocation to) {
    final seconds = math.max(
      1.0,
      to.measuredAt!.difference(from.measuredAt!).inMilliseconds.abs() / 1000,
    );
    final slack = (from.accuracyMeters ?? 0) + (to.accuracyMeters ?? 0);
    final meters = from.point.distanceMetersTo(to.point) - slack;
    return math.max(0.0, meters) / seconds;
  }

  void keepLastKnown({String? status}) {
    _locationWarning = status ?? tr.locationUpdatingEllipsis;
    _rebuildBanner();
  }

  Future<void> ensureRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    bool force = false,
    String? targetLabel,
  }) async {
    if (_disposed) {
      return;
    }
    _targetLabel = targetLabel;
    if (_stage == ActiveRideStage.waitingForRider) {
      return;
    }

    if (!origin.isValid || !destination.isValid) {
      _routeRequestToken++;
      _routeInFlight = false;
      _rerouteDebounce?.cancel();
      _rerouteDebounce = null;
      _destination = null;
      _route = null;
      _routeLength = null;
      _progressAlong = null;
      _drivenAlong = null;
      _routeState = RouteLoadState.failed;
      _status = NavigationRouteStatus.unavailableCheckLocation;
      _rebuildBanner();
      return;
    }

    final previousDestination = _destination;
    final sameDestination =
        previousDestination != null &&
        previousDestination.latitude == destination.latitude &&
        previousDestination.longitude == destination.longitude &&
        _lastRouteStage == _stage;
    _destination = destination;
    final now = _now();
    final lastAt = _lastRouteAt;
    // The route being followed to this same point. It stays on screen,
    // instructions included, while a new one loads.
    final kept = sameDestination ? _route : null;
    if (!force && sameDestination) {
      if (kept != null) {
        // On the route: keep it. Leaving it is the reroute's job.
        if (_routeInFlight ||
            _snapshot.offRoute ||
            lastAt == null ||
            now.difference(lastAt) < silentRefreshInterval) {
          return;
        }
      } else if (lastAt != null &&
          now.difference(lastAt) < const Duration(seconds: 8)) {
        // No route yet: the request on its way (or one that just failed)
        // gets a few seconds before another one replaces it.
        return;
      }
    }
    final silent = kept != null && !force;
    final rerouting = kept != null && _snapshot.offRoute;

    _rerouteDebounce?.cancel();
    _rerouteDebounce = null;
    _lastRouteStage = _stage;
    _lastRouteAt = now;
    final token = ++_routeRequestToken;
    _routeInFlight = true;
    _routeFixSeq = _fixSeq;
    if (kept == null) {
      // Nothing to follow yet: only then does the island say so.
      _routeState = RouteLoadState.loading;
      _route = null;
      _instructionHint = 0;
      _progressAlong = null;
      _drivenAlong = null;
      _status = NavigationRouteStatus.updating;
      _rebuildBanner();
    }

    try {
      final route = await routeRepository.drivingRoute(
        origin: origin,
        destination: destination,
      );
      if (_disposed || token != _routeRequestToken) {
        return;
      }
      if (route.points.length < 2 ||
          route.points.any((point) => !point.isValid) ||
          route.instructions.any(
            (instruction) =>
                !instruction.maneuverLocation.isValid ||
                !instruction.distanceMeters.isFinite ||
                instruction.distanceMeters < 0,
          ) ||
          !route.distanceMeters.isFinite ||
          !route.durationSeconds.isFinite ||
          route.distanceMeters < 0 ||
          route.durationSeconds < 0) {
        throw const FormatException('Invalid route');
      }
      _routeState = RouteLoadState.ready;
      // The provider may reuse its lists. Own a snapshot so projection's
      // cached geometry and the displayed polyline cannot diverge later.
      _route = RoadRoute(
        points: List<GeoPoint>.unmodifiable(route.points),
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
        instructions: List<RouteInstruction>.unmodifiable(route.instructions),
      );
      _routeLength = 0;
      for (var i = 1; i < route.points.length; i++) {
        _routeLength =
            _routeLength! +
            route.points[i - 1].distanceMetersTo(route.points[i]);
      }
      _instructionHint = 0;
      _progressAlong = null;
      _drivenAlong = null;
      // The same road back is not "Route updated".
      if (rerouting && !_samePoints(kept.points, route.points)) _reroutes++;
      _status = null;
      _rebuildBanner();
    } catch (_) {
      if (_disposed || token != _routeRequestToken) {
        return;
      }
      if (kept != null && (silent || !_snapshot.offRoute)) {
        // The route on screen still leads there: keep following it.
        return;
      }
      _routeState = RouteLoadState.failed;
      _route = null;
      _status = NavigationRouteStatus.unavailableRetry;
      _rebuildBanner();
    } finally {
      if (token == _routeRequestToken) {
        _routeInFlight = false;
        // A fix may have moved off the returned route during the fetch.
        // Banner rebuild could not queue a reroute while the lane was busy.
        if (!_disposed &&
            _routeState == RouteLoadState.ready &&
            _snapshot.offRoute) {
          _scheduleReroute();
        }
      }
    }
  }

  void _rebuildBanner() {
    if (_disposed) {
      return;
    }
    final waiting = _stage == ActiveRideStage.waitingForRider;
    if (waiting) {
      _snapshot = NavigationSnapshot(
        vehicle: _snapshot.vehicle,
        headingDegrees: _snapshot.headingDegrees,
        followCamera: false,
        waitingAtPickup: true,
        route: _route,
        banner: NavigationBanner(
          primary: tr.pickup,
          distanceLabel: tr.navWaitingForRider,
          symbol: NavigationBannerSymbol.arrive,
        ),
        status: _displayStatus,
      );
      notifyListeners();
      return;
    }

    final route = _route;
    RouteProgress? progress;
    if (route != null && route.geoPoints.length >= 2) {
      progress = _progress.measure(
        route: route,
        position: _snapshot.vehicle,
        instructionHint: _instructionHint,
        previousAlongMeters: _progressAlong,
      );
      _instructionHint = progress.instructionIndex;
      _progressAlong = progress.offRoute ? null : progress.alongMeters;
      if (!progress.offRoute) _drivenAlong = progress.alongMeters;
    }

    if (progress != null &&
        progress.offRoute &&
        _destination != null &&
        _stage != ActiveRideStage.waitingForRider) {
      _status = NavigationRouteStatus.recalculating;
      _scheduleReroute();
    } else if (progress != null && !progress.offRoute) {
      _rerouteDebounce?.cancel();
      _rerouteDebounce = null;
      _rerouteOrigin = null;
      _stuckReroutes = 0;
      if (_status == NavigationRouteStatus.recalculating) _status = null;
    }

    _snapshot = NavigationSnapshot(
      vehicle: _snapshot.vehicle,
      headingDegrees: _snapshot.headingDegrees,
      followCamera: !_userPausedFollow,
      waitingAtPickup: false,
      route: route,
      banner: _bannerFor(progress),
      status: _displayStatus,
      offRoute: progress?.offRoute ?? false,
    );
    notifyListeners();
  }

  NavigationBanner _bannerFor(RouteProgress? progress) {
    final arrivingToPickup = _stage == ActiveRideStage.headingToPickup;
    final instruction = progress?.nextInstruction;
    if (instruction == null) {
      return NavigationBanner(
        primary: arrivingToPickup
            ? tr.navToPickup
            : tr.navToPoint(_targetLabel ?? tr.navDropOffLower),
        // A route without turns: the distance left to the point.
        distanceLabel:
            _displayStatus ??
            (progress == null
                ? NavigationRouteStatus.updating.text
                : RouteInstructionCopy.toPoint(progress.remainingMeters)),
        distanceMeters: _displayStatus == null ? progress?.remainingMeters : null,
        symbol: arrivingToPickup
            ? NavigationBannerSymbol.straight
            : NavigationBannerSymbol.arrive,
        status: _displayStatus,
      );
    }

    final meters =
        progress?.distanceToManeuverMeters ?? instruction.distanceMeters;
    if (instruction.isArrival) {
      // The side of the street comes with the arrival step, when known.
      final side = instruction.type == RouteManeuverType.arrive
          ? instruction.symbol
          : NavigationBannerSymbol.arrive;
      if (arrivingToPickup) {
        return NavigationBanner(
          primary: meters < RouteInstructionCopy.nowMeters
              ? tr.navPickupAhead
              : tr.pickup,
          distanceLabel: RouteInstructionCopy.toPoint(meters),
          distanceMeters: meters,
          roadName: instruction.roadName,
          symbol: side,
          status: _displayStatus,
        );
      }
      return NavigationBanner(
        primary: _targetLabel != null
            ? (meters < RouteInstructionCopy.nowMeters
                  ? tr.navPointAhead(_targetLabel!)
                  : _targetLabel!)
            : (meters < RouteInstructionCopy.nowMeters
                  ? tr.navDropOffAhead
                  : tr.dropOff),
        distanceLabel: RouteInstructionCopy.toPoint(meters),
        distanceMeters: meters,
        roadName: instruction.roadName,
        symbol: side,
        status: _displayStatus,
      );
    }

    final towards = instruction.towards;
    final shields = instruction.shields;
    final exitRef = instruction.exitRef;
    // "Exit 165 · Liljeholmen" names the first place; the rest go under it.
    final named = exitRef != null &&
        (instruction.type == RouteManeuverType.offRamp ||
            instruction.type == RouteManeuverType.ramp);
    final cue = RouteInstructionCopy.cue(
      type: instruction.type,
      modifier: instruction.modifier,
      exitNumber: instruction.exitNumber,
      exitRef: exitRef,
      towards: towards.isEmpty ? null : towards.first,
      highway: instruction.highway,
      hasRoad: shields.isNotEmpty || (instruction.roadName ?? '').isNotEmpty,
      toll: instruction.toll,
      tunnel: instruction.tunnel,
    );
    final rest = named ? towards.skip(1) : towards;
    return NavigationBanner(
      primary: RouteInstructionCopy.livePrimary(cue: cue, meters: meters),
      instruction: RouteInstructionCopy.liveInstruction(
        cue: cue,
        meters: meters,
      ),
      distanceLabel: RouteInstructionCopy.formatDistance(meters),
      distanceMeters: meters,
      exitRef: named ? exitRef : null,
      roadName: instruction.roadName,
      exitNumber: instruction.exitNumber,
      exitAngleDegrees: instruction.exitAngleDegrees,
      symbol: instruction.symbol,
      status: _displayStatus,
      shields: shields,
      towards: rest.isEmpty ? null : rest.join(', '),
      lanes: RouteLane.matter(instruction.lanes)
          ? instruction.lanes
          : const <RouteLane>[],
      laneModifier: instruction.modifier,
      toll: instruction.toll,
    );
  }

  static bool _samePoints(List<GeoPoint> a, List<GeoPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  void _scheduleReroute() {
    final destination = _destination;
    if (_disposed ||
        destination == null ||
        _rerouteDebounce != null ||
        _routeInFlight) {
      return;
    }
    // No fix since this route was asked for: asking again from the same
    // place would bring the same road back.
    if (_route != null && _fixSeq == _routeFixSeq) return;
    // Still near where the last reroute started (parked off the road):
    // wait twice as long each time, up to a minute.
    final last = _rerouteOrigin;
    final stuck =
        last != null && _snapshot.vehicle.distanceMetersTo(last) < _stuckMeters;
    final delay = stuck
        ? _rerouteDelay * math.pow(2, math.min(_stuckReroutes + 1, 5))
        : _rerouteDelay;
    _rerouteDebounce = Timer(
        delay > _maxRerouteDelay ? _maxRerouteDelay : delay, () {
      _rerouteDebounce = null;
      if (_disposed) {
        return;
      }
      _stuckReroutes = stuck ? _stuckReroutes + 1 : 0;
      _rerouteOrigin = _snapshot.vehicle;
      unawaited(
        ensureRoute(
          origin: _snapshot.vehicle,
          destination: destination,
          force: true,
          targetLabel: _targetLabel,
        ),
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _routeRequestToken++;
    _rerouteDebounce?.cancel();
    super.dispose();
  }
}
