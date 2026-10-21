import 'dart:async';
import 'dart:math' as math;

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/navigation/route_camera_geometry.dart';
import 'package:movera/core/navigation/route_camera_fit.dart';

enum DriverCameraMode { following, browsing, overview }

enum DriverCameraState { explore, preview, following, free }

/// SDK-neutral output: no widgets, trip lifecycle or Google Maps dependency.
class DriverCameraPose {
  const DriverCameraPose(
    this.target,
    this.zoom,
    this.bearing,
    this.tilt, {
    this.duration = const Duration(milliseconds: 450),
    this.speedMetersPerSecond = 0,
    this.coast = false,
  });
  final GeoPoint target;
  final double zoom;
  final double bearing;
  final double tilt;
  final Duration duration;

  /// Used only to coast the chase point between GPS fixes. Never the car marker.
  final double speedMetersPerSecond;

  /// On-route driving only. Explore, waiting and off-route stays stay put.
  final bool coast;
}

abstract interface class DriverCameraPort {
  Future<void> animate(DriverCameraPose pose);

  /// Latest GPS while a follow animation is already running. Must not start
  /// a second command; the in-flight animation steers toward this pose.
  void retarget(DriverCameraPose pose);
  Future<void> overview(List<GeoPoint> points, double padding);
  void interrupt();
  void dispose();
}

/// A port that can put the camera exactly on a target and zoom (a whole
/// route fitted into the free part of the map, see [RouteCameraFit]).
abstract interface class DriverCameraFraming {
  Future<void> frame(GeoPoint target, double zoom);
}

/// A port that can tilt the camera where it is, without moving or zooming it
/// (the driver's own pinch zoom during guidance, see
/// [DriverCameraController.browseSettled]).
abstract interface class DriverCameraTilting {
  /// The map's zoom and tilt now, or null before it reports a camera.
  double? get currentZoom;
  double? get currentTilt;
  Future<void> tiltTo(double tilt);
}

/// A port whose map tilts with the zoom while the driver zooms it by hand
/// (the web gesture layer). Off while waiting: that map stays flat.
abstract interface class DriverCameraTiltBinding {
  void bindTiltToZoom(bool enabled);
}

/// Geometry and maneuver-aware framing. Each route replacement resets progress.
/// Preview an upcoming turn, close in at the maneuver, then recover to cruise.
/// Guidance tilt follows zoom ([tiltForZoom]): flat over the city, tilted
/// toward the horizon close in, like the owner's reference navigation app.
class DriverCameraPolicy {
  final RouteProgressCalculator _progress = const RouteProgressCalculator();
  RoadRoute? _route;
  double? _along;
  int _instructionHint = 0;
  DriverCameraPose? _previous;
  RouteCameraGeometry? _geometry;
  double _course = 0;
  GeoPoint? vehiclePoint;
  double get vehicleCourse => _course;
  double get alongMeters => _along ?? 0;

  /// Home's free-map zoom: the area around the driver, about 10 km across
  /// a phone. Also the zoom Home's map opens at, so the first GPS frame
  /// does not zoom.
  static const double exploreZoom = 11.7;

  /// The locate (recenter) button's view, on Home and on a trip: streets
  /// readable and tilted toward the horizon by the tilt curve (about 58°),
  /// one to two kilometres ahead on screen, like the reference app's
  /// locate view; never closer, so the map does not turn into a few fat
  /// roads. Home then keeps this zoom while it follows the car (it still
  /// opens at [exploreZoom]); a trip eases back to its speed zoom from here.
  static const double locateZoom = 15;

  /// Parked at the pickup or a paid stop.
  static const double waitingZoom = 17.2;

  /// Guidance zoom at a standstill: the zoom the trip map opens at. One
  /// level wider than street zoom: under a strong tilt the near roads of
  /// zoom 16 drew fat across the bottom of the screen (owner, iPhone), so
  /// guidance stays at 15 and below, like the reference navigation app.
  static const double guidanceStartZoom = 15;

  /// Home's follow zoom: [exploreZoom] until the driver taps locate, then
  /// [locateZoom].
  double _exploreZoom = exploreZoom;

  /// The next pose is the locate button's ([locate]).
  bool _locating = false;

  /// The driver tapped locate: the next pose flies to [locateZoom] (its
  /// tilt from [tiltForZoom]); waiting at a stop keeps its own view.
  void locate() => _locating = true;

  /// Smoothed GPS speed: one noisy reading must not zoom the map.
  double? _speed;

  /// Cruise zoom (speed only, before turn and arrival framing).
  double? _cruise;

  /// Speed zoom changes smaller than this are ignored (no breathing);
  /// larger ones move at most this far per GPS fix.
  static const double zoomDeadBand = 0.1;
  static const double maxZoomOutPerFix = 0.25;
  static const double maxZoomInPerFix = 0.4;

  double _smoothedSpeed(double raw, bool reset) {
    final previous = _speed;
    // About three fixes to follow a real change of speed.
    return _speed = reset || previous == null
        ? raw
        : previous + (raw - previous) * 0.3;
  }

  double _cruiseZoom(double speed, bool reset) {
    var zoom = zoomForSpeed(speed);
    final previous = _cruise;
    if (!reset && previous != null) {
      final change = zoom - previous;
      zoom = change.abs() < zoomDeadBand
          ? previous
          : previous + change.clamp(-maxZoomOutPerFix, maxZoomInPerFix);
    }
    return _cruise = zoom;
  }

  /// Zoom at or below which every driver map is flat (region overview).
  static const double flatZoom = 12;

  /// Zoom at or above which the map reaches [maxTilt]: the closest zoom
  /// at which the SDKs allow it ([sdkMaxTilt]), so guidance one level
  /// wider still looks far toward the horizon.
  static const double fullTiltZoom = 15.5;

  /// Strongest tilt the Google Maps SDKs accept (Android, iOS, JS vector).
  static const double maxTilt = 67.5;

  /// Most tilt Google Maps allows at [zoom] (Android/iOS `CameraPosition`):
  /// 30° up to zoom 10, 45° at 14, [maxTilt] from 15.5, linear between.
  /// A bigger value is clamped by the SDK, which would make the map jump.
  static double sdkMaxTilt(double zoom) {
    if (zoom <= 10) return 30;
    if (zoom <= 14) return 30 + (zoom - 10) / 4 * 15;
    if (zoom < 15.5) return 45 + (zoom - 14) / 1.5 * (maxTilt - 45);
    return maxTilt;
  }

  /// Tilt at [zoom] on every driver map: 0° at zoom <= [flatZoom], then
  /// proportional to zoom (linear, about 19° per zoom level) up to [maxTilt]
  /// at [fullTiltZoom], so every small pinch step changes the tilt. The line
  /// stays under [sdkMaxTilt] everywhere (no clamp, no plateau); the min is
  /// a guard. web/driver_map_camera.js applies the same curve live while
  /// the driver pinches; keep both in step.
  static double tiltForZoom(double zoom) {
    if (!zoom.isFinite) return 0;
    final t = ((zoom - flatZoom) / (fullTiltZoom - flatZoom)).clamp(0.0, 1.0);
    return math.min(maxTilt * t, sdkMaxTilt(zoom));
  }

  /// Turn preview: the closest zoom it aims for, and the most it may add to
  /// the cruise zoom, so a junction never races the map to its closest zoom.
  static const double turnZoom = 15.4;
  static const double maxTurnZoomIn = 0.4;

  /// Last [arrivalMeters] before a stop: the zoom eases in gently toward
  /// [arrivalZoom] (never out) and the tilt eases to [arrivalTilt].
  static const double arrivalMeters = 140;
  static const double arrivalZoom = 15.5;
  static const double arrivalTilt = 60;

  static double zoomForSpeed(double speed) {
    // Step thresholds made the map zoom a whole level when GPS speed
    // fluctuated near 20/50/80 km/h. Interpolate between slow, urban,
    // fast-urban and highway framing levels instead. Speeds are metres per
    // second. The tilted map shows far ahead, so guidance stays wide:
    // 15 at a standstill, 14.5 urban, 14 fast urban, 13.625 highway.
    if (!speed.isFinite || speed <= 3) return guidanceStartZoom;
    if (speed >= 30) return guidanceStartZoom - 1.375;
    if (speed <= 10) return guidanceStartZoom - (speed - 3) / 14;
    if (speed <= 20) return guidanceStartZoom - .5 - (speed - 10) / 20;
    return guidanceStartZoom - 1 - (speed - 20) * .0375;
  }

  static double angleDelta(double from, double to) =>
      (to - from + 540) % 360 - 180;

  DriverCameraPose resolve({
    required DriverLocation location,
    RoadRoute? route,
    bool navigating = false,
    bool waiting = false,
    bool immediate = false,
  }) {
    if (!_samePolyline(route, _route)) {
      _along = null;
      _instructionHint = 0;
      _geometry = route == null || route.points.isEmpty
          ? null
          : RouteCameraGeometry(route.points);
    } else if (!_sameManeuvers(route, _route)) {
      // A replacement can keep the road shape but correct turn locations.
      // Keep along-route progress, but locate the next instruction again.
      _instructionHint = 0;
    }
    _route = route;
    _course = location.courseOr(_course);
    vehiclePoint = location.point;
    final rawSpeed = location.speedMetersPerSecond;
    final rawUsable = rawSpeed != null && rawSpeed.isFinite && rawSpeed >= 0
        ? rawSpeed
        : 0.0;
    final guiding = navigating && !waiting;
    // Zoom and look-ahead use the smoothed speed; coasting the real one.
    final speed = _smoothedSpeed(rawUsable, immediate || !guiding);
    if (!guiding) _cruise = null;
    var bearing = guiding ? _course : 0.0;
    final locating = _locating && !waiting;
    _locating = false;
    if (locating && !navigating) _exploreZoom = locateZoom;
    var zoom = waiting
        ? waitingZoom
        : navigating
        ? _cruiseZoom(speed, immediate)
        : _exploreZoom;
    // Locate on a trip: the locate view now; the speed zoom then takes over
    // again at its own pace (at most [maxZoomOutPerFix] a fix).
    if (locating && navigating) zoom = _cruise = locateZoom;
    // Arrival blend toward [arrivalTilt]; 0 = tilt follows zoom.
    var arrival = 0.0;
    var onRoute = false;
    if (navigating && !waiting && route != null && route.points.length > 1) {
      final progress = _progress.measure(
        route: route,
        position: location.point,
        instructionHint: _instructionHint,
        previousAlongMeters: _along,
      );
      _along = progress.alongMeters;
      _instructionHint = progress.instructionIndex;
      if (!progress.offRoute) {
        onRoute = true;
        final car = _geometry!.at(progress.alongMeters);
        vehiclePoint = car;
        final ahead = _geometry!.at(
          progress.alongMeters + (speed * 3).clamp(40.0, 250.0),
        );
        if (car.distanceMetersTo(ahead) > 1) {
          final roadBearing = car.bearingTo(ahead);
          // On guidance entry aim down the road even if GPS is stationary.
          // While moving, anticipate curves without leading course >30°.
          bearing = immediate
              ? roadBearing
              : speed < 1
              ? (_previous?.bearing ?? roadBearing)
              : (_course +
                        angleDelta(_course, roadBearing).clamp(-30.0, 30.0) *
                            .7 +
                        360) %
                    360;
        }
        final maneuver = progress.nextInstruction;
        final distance = progress.distanceToManeuverMeters;
        if (maneuver != null &&
            _needsPreview(maneuver.type) &&
            distance < 180) {
          final approach = (1 - distance / 180).clamp(0.0, 1.0);
          // Enter turn preview progressively: previously crossing the 180 m
          // boundary jumped the map to zoom >=17 in a single GPS update.
          // Reach full maneuver framing by the final 90 m. Zoom in only a
          // little (capped), so the tilt, which follows zoom, rises toward
          // the horizon instead of the map racing to its closest zoom.
          final targetZoom = turnZoom - .5 + .5 * approach;
          final t = (approach * 2).clamp(0.0, 1.0);
          final eased = t * t * (3 - 2 * t);
          zoom += math.min(maxTurnZoomIn, math.max(0.0, targetZoom - zoom)) *
              eased;
        }
        // The former 35 m arrival threshold snapped a fast-road camera
        // from highway zoom straight to a close-up view. Start easing well
        // before arrival, finishing near and still tilted (60°) at the
        // actual endpoint, never flat.
        if (progress.remainingMeters < arrivalMeters) {
          final fraction = (1 - progress.remainingMeters / arrivalMeters)
              .clamp(0.0, 1.0);
          arrival = fraction * fraction * (3 - 2 * fraction);
          zoom += math.max(0.0, arrivalZoom - zoom) * arrival;
        }
      }
    }
    // One noisy GPS heading must not spin the map. A sustained turn still
    // catches up; the SDK adapter damps what remains. Entry/recenter is immediate
    // and aims straight down the road.
    if (!immediate && navigating && !waiting && _previous != null) {
      final turn = angleDelta(_previous!.bearing, bearing).clamp(-55.0, 55.0);
      bearing = (_previous!.bearing + turn * 0.65 + 360) % 360;
    }
    // Waiting is flat; guidance and the free map tilt with their zoom.
    var tilt = waiting ? 0.0 : tiltForZoom(zoom);
    tilt += (arrivalTilt - tilt) * arrival;
    tilt = math.min(tilt, sdkMaxTilt(zoom));
    return _previous = DriverCameraPose(
      vehiclePoint!,
      zoom,
      bearing,
      tilt,
      // A locate that waited for a usable fix still flies (the port's
      // one-second flight), not the short follow glide.
      duration: Duration(milliseconds: immediate || locating ? 900 : 450),
      speedMetersPerSecond: rawUsable,
      coast: onRoute && rawUsable >= 1,
    );
  }

  bool _samePolyline(RoadRoute? next, RoadRoute? previous) {
    if (next == null && previous == null) {
      return true;
    }
    if (next == null || previous == null) {
      return false;
    }
    final a = next.points;
    final b = _geometry?.points ?? previous.points;
    if (a.length != b.length) {
      return false;
    }
    if (a.isEmpty) {
      return true;
    }
    bool same(GeoPoint p, GeoPoint q) =>
        p.latitude == q.latitude && p.longitude == q.longitude;
    for (var i = 0; i < a.length; i++) {
      if (!same(a[i], b[i])) return false;
    }
    return true;
  }

  bool _sameManeuvers(RoadRoute? next, RoadRoute? previous) {
    final a = next?.instructions ?? const <RouteInstruction>[];
    final b = previous?.instructions ?? const <RouteInstruction>[];
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].maneuverLocation != b[i].maneuverLocation ||
          a[i].type != b[i].type ||
          a[i].modifier != b[i].modifier) {
        return false;
      }
    }
    return true;
  }

  bool _needsPreview(RouteManeuverType type) => switch (type) {
    RouteManeuverType.turn ||
    RouteManeuverType.endOfRoad ||
    RouteManeuverType.merge ||
    RouteManeuverType.fork ||
    RouteManeuverType.ramp ||
    RouteManeuverType.onRamp ||
    RouteManeuverType.offRamp ||
    RouteManeuverType.roundabout ||
    RouteManeuverType.rotary ||
    RouteManeuverType.roundaboutTurn ||
    RouteManeuverType.exitRoundabout ||
    RouteManeuverType.exitRotary => true,
    _ => false,
  };
}

/// One owner for follow/free mode, lifecycle and serialized camera commands.
/// GPS continues in browse mode but never steals the driver's viewport.
class DriverCameraController {
  DriverCameraController({DriverCameraPolicy? policy, DateTime Function()? now})
    : _policy = policy ?? DriverCameraPolicy(),
      _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final DriverCameraPolicy _policy;
  DriverCameraPort? _port;
  DriverLocation? _location;
  RoadRoute? _route;
  bool _navigating = false;
  bool _waiting = false;
  bool _suspended = false;
  bool _disposed = false;
  bool _busy = false;
  int _epoch = 0;
  DriverCameraPose? _pending;
  Timer? _throttle;
  DriverCameraMode _mode = DriverCameraMode.following;
  DriverCameraMode get mode => _mode;
  DriverCameraState get state => mode == DriverCameraMode.browsing
      ? DriverCameraState.free
      : mode == DriverCameraMode.overview
      ? DriverCameraState.preview
      : isGuidance
      ? DriverCameraState.following
      : DriverCameraState.explore;
  GeoPoint? get vehiclePoint => _policy.vehiclePoint;
  double get vehicleCourse => _policy.vehicleCourse;
  double get alongMeters => _policy.alongMeters;
  bool get isGuidance => _navigating && !_waiting;
  /// Trip guidance: how long the map may stay moved by the driver before
  /// the camera returns to the car. Null keeps the map until Recenter.
  Duration? autoResumeAfter;

  /// The trip's own recenter (restores its sheet too). Returns false when
  /// now is not the moment (an offer is open); the camera asks again later.
  bool Function()? onAutoResume;

  /// The trip camera's idle time before returning to the car.
  static const Duration tripAutoResume = Duration(seconds: 12);

  Timer? _resumeTimer;
  bool _touching = false;

  /// A finger is on the map: the camera never moves under it, and the
  /// return to the car waits until the map is let go.
  set touching(bool value) {
    if (_touching == value) return;
    _touching = value;
    if (value) {
      _resumeTimer?.cancel();
      _resumeTimer = null;
      // A tilt easing after the last pinch stops under the new finger.
      if (mode == DriverCameraMode.browsing) _port?.interrupt();
      // driver-r4-39: following, the frame in flight stops too; the newest
      // pose waits in _pending until the finger lifts.
      if (mode == DriverCameraMode.following && _busy) {
        _epoch++;
        _busy = false;
        _port?.interrupt();
      }
      _throttle?.cancel();
      _throttle = null;
    } else {
      _scheduleResume();
      if (_settleOnRelease) browseSettled();
      if (_canFollow) unawaited(_flush());
    }
  }

  /// The driver is still moving the map (pan, zoom inertia): restart the
  /// wait before the camera returns.
  void mapActivity() {
    if (_resumeTimer != null) _scheduleResume();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    final after = autoResumeAfter;
    if (after == null || _disposed || _touching || !isGuidance ||
        mode != DriverCameraMode.browsing) {
      return;
    }
    _resumeTimer = Timer(after, () {
      _resumeTimer = null;
      if (_disposed || _touching || _suspended || !isGuidance ||
          mode != DriverCameraMode.browsing) {
        return;
      }
      final resume = onAutoResume;
      if (resume == null) {
        recenter();
      } else if (!resume()) {
        _scheduleResume();
      }
    });
  }

  /// The camera stopped while the driver browses: they pinch-zoomed or
  /// panned (on a trip or on Home). Once the map is let go, tilt it to match
  /// their zoom ([DriverCameraPolicy.tiltForZoom]), so a zoom out flattens
  /// it and a zoom in tilts it toward the horizon. Waiting stays flat.
  /// Maps reports idle whenever the camera pauses, also under a finger
  /// that holds a pinch: nothing moves until the map is let go ([touching]),
  /// or the ease would pull the zoom back from under the driver's fingers.
  /// (The web gesture layer already tilts with zoom live during a pinch, so
  /// there this ease usually has nothing left to do.)
  void browseSettled() {
    if (_touching) {
      _settleOnRelease = true;
      return;
    }
    _settleOnRelease = false;
    final port = _port;
    if (_disposed ||
        _suspended ||
        _waiting ||
        mode != DriverCameraMode.browsing ||
        port is! DriverCameraTilting) {
      return;
    }
    final tilting = port as DriverCameraTilting;
    final zoom = tilting.currentZoom;
    if (zoom == null) return;
    final tilt = DriverCameraPolicy.tiltForZoom(zoom);
    if ((tilt - (tilting.currentTilt ?? tilt)).abs() < 1) return;
    unawaited(tilting.tiltTo(tilt).catchError((Object _) {}));
  }

  bool _settleOnRelease = false;

  void _bindTilt() {
    final port = _port;
    if (port is DriverCameraTiltBinding) {
      (port as DriverCameraTiltBinding).bindTiltToZoom(!_waiting);
    }
  }

  void attach(DriverCameraPort port) {
    if (_disposed) {
      port.dispose();
      return;
    }
    if (identical(port, _port)) return;
    _invalidate();
    _port?.dispose();
    _port = port;
    _busy = false;
    _bindTilt();
    _request(immediate: true);
  }

  void update({
    required DriverLocation location,
    RoadRoute? route,
    bool navigating = false,
    bool waiting = false,
  }) {
    if (_disposed || !location.isUsableAt(_now())) {
      return;
    }
    // The trip reports the same fix again once its route refresh is done.
    // Resolving it twice would smooth the turn twice.
    if (identical(location, _location) &&
        identical(route, _route) &&
        navigating == _navigating &&
        waiting == _waiting) {
      return;
    }
    _location = location;
    _route = route;
    final enteringGuidance =
        navigating && !waiting && (!_navigating || _waiting);
    _navigating = navigating;
    _waiting = waiting;
    _bindTilt();
    // Track car/route progress even while the viewport belongs to the driver.
    final pose = _policy.resolve(
      location: location,
      route: route,
      navigating: navigating,
      waiting: waiting,
      immediate: enteringGuidance,
    );
    if (enteringGuidance && mode == DriverCameraMode.overview) {
      _mode = DriverCameraMode.following;
    }
    if (enteringGuidance && mode == DriverCameraMode.browsing) {
      _scheduleResume();
    }
    _request(immediate: enteringGuidance, resolved: pose);
  }

  void userGesture() {
    if (_disposed) {
      return;
    }
    _mode = DriverCameraMode.browsing;
    _invalidate();
    _scheduleResume();
  }

  /// The locate button (Home and trip): follow the car again at the
  /// locate view ([DriverCameraPolicy.locateZoom]), in one smooth flight.
  void locate() {
    if (_disposed) return;
    _policy.locate();
    recenter();
  }

  void recenter() {
    if (_disposed) {
      return;
    }
    _mode = DriverCameraMode.following;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _invalidate();
    _request(immediate: true);
  }

  /// Dismiss an offer/destination preview without taking the map away from
  /// a driver who has manually panned it since the preview began.
  void endPreview() {
    if (_mode == DriverCameraMode.overview) {
      recenter();
    }
  }

  Future<void> preview(List<GeoPoint> points, {double padding = 80}) async {
    if (_disposed ||
        _suspended ||
        mode == DriverCameraMode.browsing ||
        points.isEmpty ||
        _port == null) {
      return;
    }
    _invalidate();
    _mode = DriverCameraMode.overview;
    final port = _port!;
    final epoch = _epoch;
    try {
      await port.overview(points, padding);
    } catch (_) {
      // A failed camera fit must not strand the driver in Preview forever.
      // Respect any later manual pan, map replacement or lifecycle pause.
      if (!_disposed &&
          !_suspended &&
          epoch == _epoch &&
          identical(port, _port) &&
          _mode == DriverCameraMode.overview) {
        _mode = DriverCameraMode.following;
        _request(immediate: true);
      }
    }
  }

  /// Shows an offer's whole route at [fit]. [takeOver]: a new offer
  /// takes the map even from a driver who moved it; later fits of the
  /// same offer leave a moved map alone. A port that cannot frame falls
  /// back to fitting [points] with [padding].
  Future<void> previewFit(
    RouteCameraFit fit, {
    required List<GeoPoint> points,
    double padding = 80,
    bool takeOver = false,
  }) async {
    final port = _port;
    final framing = port is DriverCameraFraming
        ? port as DriverCameraFraming
        : null;
    if (framing == null) {
      if (takeOver && mode == DriverCameraMode.browsing) {
        _mode = DriverCameraMode.overview;
      }
      return preview(points, padding: padding);
    }
    if (_disposed ||
        _suspended ||
        (!takeOver && mode == DriverCameraMode.browsing)) {
      return;
    }
    _invalidate();
    _mode = DriverCameraMode.overview;
    final epoch = _epoch;
    try {
      await framing.frame(fit.target, fit.zoom);
    } catch (_) {
      if (!_disposed &&
          !_suspended &&
          epoch == _epoch &&
          identical(port, _port) &&
          _mode == DriverCameraMode.overview) {
        _mode = DriverCameraMode.following;
        _request(immediate: true);
      }
    }
  }

  void suspend() {
    _suspended = true;
    _invalidate();
  }

  void resume() {
    _suspended = false;
    // driver-20: a return to the car that came due while suspended was
    // dropped by the timer; wait again from now instead of never.
    if (_resumeTimer == null) _scheduleResume();
    _request(immediate: true);
  }

  bool get _canFollow =>
      !_disposed &&
      !_suspended &&
      mode == DriverCameraMode.following &&
      _port != null;

  void _invalidate() {
    _epoch++;
    _pending = null;
    _throttle?.cancel();
    _throttle = null;
    _port?.interrupt();
    _busy = false;
  }

  void _request({bool immediate = false, DriverCameraPose? resolved}) {
    final location = _location;
    if (!_canFollow || location == null || !location.isUsableAt(_now())) {
      return;
    }
    _pending =
        resolved ??
        _policy.resolve(
          location: location,
          route: _route,
          navigating: _navigating,
          waiting: _waiting,
          immediate: immediate,
        );
    if (immediate) {
      _throttle?.cancel();
      _throttle = null;
    }
    final pending = _pending;
    if (_touching) return; // flushed when the finger lifts (driver-r4-39)
    if (_busy && pending != null) {
      // D-14: the running animation now steers to this pose; animating
      // it again once that one ends would send the same move twice.
      _port?.retarget(pending);
      _pending = null;
    }
    if (!_busy && _throttle == null) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    final port = _port;
    final pose = _pending;
    if (!_canFollow || _busy || _touching || port == null || pose == null) {
      return;
    }
    final location = _location;
    if (location == null || !location.isUsableAt(_now())) {
      _pending = null;
      return;
    }
    _pending = null;
    _busy = true;
    final epoch = _epoch;
    try {
      await port.animate(pose);
    } catch (_) {
      // An unavailable/disposed map must not break the trip lifecycle.
    }
    if (_disposed || epoch != _epoch) {
      return;
    }
    _busy = false;
    _throttle = Timer(const Duration(milliseconds: 16), () {
      _throttle = null;
      if (_canFollow) {
        unawaited(_flush());
      }
    });
  }

  void dispose() {
    _disposed = true;
    _resumeTimer?.cancel();
    _invalidate();
    _port?.dispose();
    _port = null;
  }
}
