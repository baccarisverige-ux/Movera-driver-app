import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

enum RouteLoadState { idle, loading, ready, failed }

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
  DateTime? _lastMeasuredAt;
  double? _routeLength;
  bool _userPausedFollow = false;
  String? _status;
  String? _locationWarning;
  String? get _displayStatus => _locationWarning ?? _status;
  Timer? _rerouteDebounce;
  bool _disposed = false;
  bool _routeInFlight = false;
  String? _targetLabel;
  ActiveRideStage? _lastRouteStage;
  RouteLoadState _routeState = RouteLoadState.idle;
  RouteLoadState get routeState => _routeState;
  int _reroutes = 0;

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
    return ((_progressAlong ?? 0) / length).clamp(0.0, 1.0);
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

  void setVehicle(DriverLocation location) {
    if (_disposed) return;
    final point = location.point;
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return;
    }
    // Real GPS measurements carry freshness/accuracy evidence. Reject
    // unusable ones before altering the route, progress or recovery banner.
    // Keep metadata-free demo/test positions working as before.
    if ((location.measuredAt != null || location.accuracyMeters != null) &&
        !location.isUsableAt(DateTime.now())) {
      return;
    }
    final at = location.measuredAt;
    if (at != null &&
        _lastMeasuredAt != null &&
        at.isBefore(_lastMeasuredAt!)) {
      return;
    }
    if (at != null) _lastMeasuredAt = at;
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
      return;
    }

    final heading = location.courseOr(_snapshot.headingDegrees);

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
  }

  void keepLastKnown({String? status}) {
    _locationWarning = status ?? 'Location updating…';
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
      _routeState = RouteLoadState.failed;
      _status = 'Route unavailable — check location';
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
    if (kept == null) {
      // Nothing to follow yet: only then does the island say so.
      _routeState = RouteLoadState.loading;
      _route = null;
      _instructionHint = 0;
      _progressAlong = null;
      _status = 'Route updating…';
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
      if (rerouting) _reroutes++;
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
      _status = 'Route unavailable — retry';
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
        banner: const NavigationBanner(
          primary: 'Pickup',
          distanceLabel: 'Waiting for rider',
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
    }

    if (progress != null &&
        progress.offRoute &&
        _destination != null &&
        _stage != ActiveRideStage.waitingForRider) {
      _status = 'Recalculating route…';
      _scheduleReroute();
    } else if (progress != null && !progress.offRoute) {
      _rerouteDebounce?.cancel();
      _rerouteDebounce = null;
      if (_status == 'Recalculating route…') _status = null;
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
            ? 'Navigate to pickup'
            : 'Navigate to ${_targetLabel ?? 'drop-off'}',
        // A route without turns: the distance left to the point.
        distanceLabel:
            _displayStatus ??
            (progress == null
                ? 'Route updating…'
                : _toPoint(progress.remainingMeters)),
        symbol: arrivingToPickup
            ? NavigationBannerSymbol.straight
            : NavigationBannerSymbol.arrive,
        status: _displayStatus,
      );
    }

    final meters =
        progress?.distanceToManeuverMeters ?? instruction.distanceMeters;
    if (instruction.isArrival) {
      if (arrivingToPickup) {
        return NavigationBanner(
          primary: meters < 25 ? 'Pickup ahead' : 'Pickup',
          distanceLabel: _toPoint(meters),
          roadName: instruction.roadName,
          symbol: NavigationBannerSymbol.arrive,
          status: _displayStatus,
        );
      }
      return NavigationBanner(
        primary: _targetLabel != null
            ? '${_targetLabel!}${meters < 25 ? ' ahead' : ''}'
            : (meters < 25 ? 'Drop-off ahead' : 'Drop-off'),
        distanceLabel: _toPoint(meters),
        roadName: instruction.roadName,
        symbol: NavigationBannerSymbol.arrive,
        status: _displayStatus,
      );
    }

    final action = RouteInstructionCopy.shortAction(
      type: instruction.type,
      modifier: instruction.modifier,
      exitNumber: instruction.exitNumber,
    );
    return NavigationBanner(
      primary: RouteInstructionCopy.livePrimary(action: action, meters: meters),
      distanceLabel: RouteInstructionCopy.formatDistance(meters),
      roadName: instruction.roadName,
      exitNumber: instruction.exitNumber,
      exitAngleDegrees: instruction.exitAngleDegrees,
      symbol: RouteInstructionCopy.symbolFor(
        type: instruction.type,
        modifier: instruction.modifier,
      ),
      status: _displayStatus,
    );
  }

  /// "in 150 m", or "now" at the point.
  static String _toPoint(double meters) {
    final distance = RouteInstructionCopy.formatDistance(meters);
    return distance == 'now' ? distance : 'in $distance';
  }

  void _scheduleReroute() {
    final destination = _destination;
    if (_disposed ||
        destination == null ||
        _rerouteDebounce != null ||
        _routeInFlight) {
      return;
    }
    _rerouteDebounce = Timer(const Duration(seconds: 2), () {
      _rerouteDebounce = null;
      if (_disposed) {
        return;
      }
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
