import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/geo/geo_point.dart';

import 'driver_map_web_bridge_stub.dart'
    if (dart.library.js_interop) 'driver_map_web_bridge.dart'
    as web;

/// Continuous damped follow. One in-flight animation is retargeted as GPS
/// arrives, so the map does not brake to a stop between fixes.
///
/// The logical pose (vehicle at the camera target) is never replaced by the
/// web anchor shift. That shift is applied inside the same Maps update.
class GoogleDriverCameraPort
    implements
        DriverCameraPort,
        DriverCameraFraming,
        DriverCameraTilting,
        DriverCameraTiltBinding {
  GoogleDriverCameraPort(
    this.controller, {
    this.reducedMotion = false,
    this.onFrame,
    this.onStatus,
    CameraPosition? initialPosition,
  }) : _logical = initialPosition;
  final GoogleMapController controller;
  final bool reducedMotion;
  final void Function(CameraPosition)? onFrame;
  final void Function(String?)? onStatus;
  CameraPosition? _logical;
  DriverCameraPose? _goal;
  DateTime _goalAt = DateTime.now();
  Completer<void>? _active;
  int _generation = 0;
  bool _disposed = false;
  bool _looping = false;
  bool _producingFrames = false;
  bool _followOwned = false;
  bool _flightPending = false;

  void onMove(CameraPosition position) {
    // SDK echoes include the web anchor pan. While we own follow, the logical
    // vehicle pose is the only legal interpolation origin.
    if (_producingFrames || _followOwned) {
      return;
    }
    // A flat (raster) map always reports north-up. Keep the camera's own
    // heading: it still decides on which side the road ahead is shown.
    _logical = _threeD
        ? position
        : CameraPosition(
            target: position.target,
            zoom: position.zoom,
            bearing: _logical?.bearing ?? 0,
            tilt: _logical?.tilt ?? 0,
          );
  }

  void onIdle() {} // Idle is not evidence of a user gesture.

  /// Tilt and rotation exist only on a vector map (a Map ID on web).
  bool get _threeD => web.supports3D(controller.mapId);

  /// The camera's own pose: heading and tilt even when the map is flat.
  CameraPosition _at(DriverCameraPose pose, GeoPoint target) => CameraPosition(
    target: LatLng(target.latitude, target.longitude),
    zoom: pose.zoom,
    bearing: pose.bearing,
    tilt: pose.tilt,
  );

  /// Closest zoom on a flat (raster) map: past it Google upscales the tiles
  /// into giant blurry street names. The web bridge caps pinch zoom there too.
  static const double rasterMaxZoom = 18;

  /// What the map is asked for: a flat map never gets heading or tilt, nor a
  /// zoom closer than [rasterMaxZoom].
  CameraPosition _sdk(CameraPosition logical) => _threeD
      ? logical
      : CameraPosition(
          target: logical.target,
          zoom: math.min(logical.zoom, rasterMaxZoom),
        );

  /// Screen pixels the camera would slide across: beyond about three
  /// screens a glide only smears the city, so the camera cuts instead.
  static bool _far(CameraPosition a, CameraPosition b) {
    final meters = GeoPoint(a.target.latitude, a.target.longitude)
        .distanceMetersTo(GeoPoint(b.target.latitude, b.target.longitude));
    final zoom = math.min(a.zoom, b.zoom);
    final metersPerPixel = 156543.03392 *
        math.cos(b.target.latitude * math.pi / 180).abs() /
        math.pow(2, zoom);
    return metersPerPixel > 0 && meters / metersPerPixel > 2400;
  }

  /// A recenter / locate flight takes this long, start to rest. It runs on
  /// the clock, eased in and out, and lands with no speed left (no snap).
  /// The damped approach used for it before crept on for 4-5 s (up to the
  /// frame cap) before it counted as settled.
  static const Duration flightDuration = Duration(milliseconds: 1000);

  /// Ease-in-out (smoothstep) of a flight at progress [t] (0..1): zero
  /// speed at both ends, a peak of 1.5x the mean speed (no zoom leap).
  static double flightEase(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// Offer and route previews fly in this long (eased in and out).
  static const Duration previewFlight = Duration(milliseconds: 650);

  GeoPoint _coasted(DriverCameraPose goal) {
    if (!goal.coast || goal.speedMetersPerSecond < 1) {
      return goal.target;
    }
    final seconds = DateTime.now().difference(_goalAt).inMicroseconds / 1e6;
    final meters = math.min(
      goal.speedMetersPerSecond * math.min(seconds, 1.1),
      22,
    );
    if (meters < 0.5) {
      return goal.target;
    }
    final rad = goal.bearing * math.pi / 180;
    final lat = goal.target.latitude + (meters * math.cos(rad)) / 111320.0;
    final lngScale = math.max(
      0.2,
      math.cos(goal.target.latitude * math.pi / 180),
    );
    final lng =
        goal.target.longitude +
        (meters * math.sin(rad)) / (111320.0 * lngScale);
    return GeoPoint(lat, lng);
  }

  CameraPosition _approach(
    CameraPosition from,
    CameraPosition to,
    int dtMicros,
    Duration duration,
  ) {
    final span = math.max(200000, duration.inMicroseconds);
    double step(num tau) => 1 - math.exp(-dtMicros / tau);
    final pos = step(span * 0.70);
    final bearing = step(span * 1.60);
    final zoom = step(span * 1.10);
    return CameraPosition(
      target: LatLng(
        from.target.latitude +
            (to.target.latitude - from.target.latitude) * pos,
        from.target.longitude +
            (to.target.longitude - from.target.longitude) * pos,
      ),
      zoom: from.zoom + (to.zoom - from.zoom) * zoom,
      bearing: GeoPoint.shortestAngleLerp(from.bearing, to.bearing, bearing),
      tilt: from.tilt + (to.tilt - from.tilt) * zoom,
    );
  }

  bool _settled(CameraPosition a, CameraPosition b) {
    if ((a.target.latitude - b.target.latitude).abs() > 0.00002) {
      return false;
    }
    if ((a.target.longitude - b.target.longitude).abs() > 0.00002) {
      return false;
    }
    if (DriverCameraPolicy.angleDelta(a.bearing, b.bearing).abs() > 0.4) {
      return false;
    }
    if ((a.zoom - b.zoom).abs() > 0.02 || (a.tilt - b.tilt).abs() > 0.4) {
      return false;
    }
    return true;
  }

  bool _trackCar(CameraPosition next, DriverCameraPose goal) {
    // Recenter/entry flights must not drag the car across the browsed map.
    if (goal.duration.inMilliseconds > 600) {
      return false;
    }
    final meters = GeoPoint(
      next.target.latitude,
      next.target.longitude,
    ).distanceMetersTo(goal.target);
    return meters < 25;
  }

  /// [coastLat]/[coastLng]: how far the frame's chase point coasted ahead
  /// of the car (degrees). The car marker gets the frame without it, so it
  /// never slides along the camera bearing past the last fix (driver-u176).
  Future<void> _move(
    CameraPosition logical, {
    required bool trackVehicle,
    required int generation,
    bool anchored = true,
    double coastLat = 0,
    double coastLng = 0,
  }) async {
    if (_disposed || generation != _generation) return;
    _logical = logical;
    // Follow frames sit on the driving anchor, with the road ahead on the
    // side the car drives to; preview frames are placed exactly.
    web.claim(
      controller.mapId,
      anchored: anchored,
      lead: anchored ? logical.bearing : null,
    );
    await controller.moveCamera(
      CameraUpdate.newCameraPosition(_sdk(logical)),
    );
    // A physical pan, app suspension, replaced map, or disposal can interrupt
    // this command while the Maps SDK still awaits acknowledgement. Never
    // publish an old camera frame or clear a newer error after that point.
    if (_disposed || generation != _generation) return;
    onStatus?.call(null);
    if (trackVehicle) {
      onFrame?.call(coastLat == 0 && coastLng == 0
          ? logical
          : CameraPosition(
              target: LatLng(
                logical.target.latitude - coastLat,
                logical.target.longitude - coastLng,
              ),
              zoom: logical.zoom,
              bearing: logical.bearing,
              tilt: logical.tilt,
            ));
    }
  }

  @override
  void retarget(DriverCameraPose pose) {
    if (_disposed || !_looping) {
      return;
    }
    _goal = pose;
    _goalAt = DateTime.now();
  }

  @override
  Future<void> animate(DriverCameraPose pose) {
    if (_disposed) {
      return Future<void>.value();
    }
    _goal = pose;
    _goalAt = DateTime.now();
    _followOwned = true;
    _producingFrames = true;
    // A recenter / locate: a flight, also when the follow loop is running.
    if (pose.duration.inMilliseconds > 600) _flightPending = true;
    if (_looping) {
      return _active?.future ?? Future<void>.value();
    }
    final session = Completer<void>();
    _active = session;
    _looping = true;
    final generation = ++_generation;
    unawaited(_run(session, generation));
    return session.future;
  }

  Future<void> _run(Completer<void> session, int generation) async {
    try {
      final initial = _goal;
      if (initial == null) {
        return;
      }
      if (reducedMotion || _logical == null) {
        await _move(_at(initial, initial.target),
          trackVehicle: true, generation: generation);
        return;
      }
      var dt = 16000;
      // A recenter / locate flight (long duration) runs on the clock
      // ([flightDuration]): each frame closes the share of the remaining
      // gap that the eased curve covers in it, so a still goal follows the
      // curve exactly and a moving one (GPS fixes, coasting) is turned to
      // smoothly. Then the damped follow takes over.
      var flying = false;
      var flown = 0;
      // The first frame is always sent, even when the map already shows
      // this pose: it puts the car on the anchor above the sheet (a map
      // opens with the car in the middle of the whole view).
      var first = true;
      while (!_disposed && generation == _generation) {
        final goal = _goal;
        if (goal == null || generation != _generation) {
          break;
        }
        final coasted = _coasted(goal);
        final coastLat = coasted.latitude - goal.target.latitude;
        final coastLng = coasted.longitude - goal.target.longitude;
        final destination = _at(goal, coasted);
        final from = _logical ?? destination;
        if (_far(from, destination)) {
          _flightPending = false;
          await _move(destination, trackVehicle: true, generation: generation,
            coastLat: coastLat, coastLng: coastLng);
          break;
        }
        if (_flightPending) {
          _flightPending = false;
          flying = true;
          flown = 0;
        }
        if (flying) {
          first = false;
          final span = flightDuration.inMicroseconds;
          final before = flightEase(flown / span);
          flown += dt;
          final after = flightEase(flown / span);
          if (after >= 1) flying = false;
          final next = after >= 1
              ? destination
              : _blend(from, destination, (after - before) / (1 - before));
          await _move(next,
            trackVehicle: _trackCar(next, goal), generation: generation,
            coastLat: coastLat, coastLng: coastLng);
          if (_disposed || generation != _generation) {
            break;
          }
          final stamp = DateTime.now();
          await _sleep(const Duration(milliseconds: 16));
          if (_disposed || generation != _generation) {
            break;
          }
          dt = math.max(16000, DateTime.now().difference(stamp).inMicroseconds);
          continue;
        }
        final settled = _settled(from, destination);
        if (!settled || first) {
          first = false;
          final next = settled
              ? destination
              : _approach(from, destination, dt, goal.duration);
          await _move(next,
            trackVehicle: _trackCar(next, goal), generation: generation,
            coastLat: coastLat, coastLng: coastLng);
        }
        if (_disposed || generation != _generation || settled) {
          break;
        }
        final stamp = DateTime.now();
        await _sleep(Duration(milliseconds: settled ? 50 : 16));
        if (_disposed || generation != _generation) {
          break;
        }
        final real = DateTime.now().difference(stamp).inMicroseconds;
        dt = math.max(settled ? 50000 : 16000, real);
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        onStatus?.call(tr.mapCameraUnavailable);
      }
    } finally {
      if (generation == _generation) {
        _producingFrames = false;
        // Retain logical follow ownership while idle: delayed SDK anchor echoes
        // must not become the interpolation origin for the next GPS fix.
        _looping = false;
      }
      if (!session.isCompleted) {
        session.complete();
      }
    }
  }

  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {
    if (_disposed || points.isEmpty) {
      return;
    }
    interrupt();
    final generation = _generation;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points.skip(1)) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    if ((north - south).abs() < .00001) {
      south -= .0002;
      north += .0002;
    }
    if ((east - west).abs() < .00001) {
      west -= .0002;
      east += .0002;
    }
    final position = _logical;
    if (position != null) {
      await _move(
        CameraPosition(
          target: position.target,
          zoom: position.zoom,
          bearing: position.bearing,
          tilt: position.tilt,
        ),
        trackVehicle: false,
        generation: generation,
        anchored: false,
      );
    }
    if (_disposed || generation != _generation) {
      return;
    }
    try {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          padding,
        ),
      );
      // The driver may have panned, dismissed Preview or left the route while
      // Google Maps was acknowledging the bounds fit. Such a stale response
      // cannot clear a newer camera error or assume ownership again.
      if (_disposed || generation != _generation) return;
      onStatus?.call(null);
    } catch (_) {
      if (_disposed || generation != _generation) {
        return;
      }
      onStatus?.call(tr.mapCameraUnavailable);
      // The owner must know that fitting the route failed. Otherwise it
      // remains in Overview forever and suppresses subsequent GPS following.
      rethrow;
    }
  }

  /// The whole offer route: to its fitted target and zoom, flat, in one
  /// eased flight (zoom and position together, no zoom pop then slide).
  /// Map padding is not needed: the fit already left the sheet free.
  @override
  Future<void> frame(GeoPoint target, double zoom) async {
    if (_disposed) return;
    interrupt();
    final generation = _generation;
    final position = CameraPosition(
      target: LatLng(target.latitude, target.longitude),
      zoom: zoom,
    );
    final from = _logical;
    try {
      if (reducedMotion || from == null || _far(from, position)) {
        await _move(position,
            trackVehicle: false, generation: generation, anchored: false);
      } else {
        _producingFrames = true;
        final started = DateTime.now();
        while (true) {
          final t = (DateTime.now().difference(started).inMicroseconds /
                  previewFlight.inMicroseconds)
              .clamp(0.0, 1.0);
          final e = t < .5 ? 4 * t * t * t : 1 - math.pow(2 - 2 * t, 3) / 2;
          await _move(_blend(from, position, e),
              trackVehicle: false, generation: generation, anchored: false);
          if (_disposed || generation != _generation || t >= 1) break;
          await _sleep(const Duration(milliseconds: 16));
        }
        if (generation == _generation) _producingFrames = false;
      }
      if (_disposed || generation != _generation) return;
      _logical = position;
      onStatus?.call(null);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _producingFrames = false;
      onStatus?.call(tr.mapCameraUnavailable);
      rethrow;
    }
  }

  @override
  void bindTiltToZoom(bool enabled) =>
      web.tiltFollowsZoom(controller.mapId, enabled);

  @override
  double? get currentZoom => _logical?.zoom;

  @override
  double? get currentTilt => _logical?.tilt;

  /// Tilts the map where the driver left it (same target, zoom and
  /// heading) in one short eased move. A flat map only keeps the tilt as
  /// the camera's own, for the next follow frame.
  ///
  /// Maps reports idle between the ease's own frames, so the same request
  /// arrives again while it runs: that one keeps the ease going instead of
  /// restarting it (a restart re-accelerates from rest each time, which
  /// stutters). A new tilt retargets it from where the tilt is now. Every
  /// frame keeps the camera's latest target, zoom and heading: only the
  /// tilt moves, so the ease can never pull zoom or position back.
  @override
  Future<void> tiltTo(double tilt) async {
    final from = _logical;
    if (_disposed || from == null) return;
    final easing = _tiltEase;
    if (easing != null && (easing.target - tilt).abs() < .5 &&
        easing.generation == _generation) {
      return easing.done.future;
    }
    interrupt();
    final generation = _generation;
    CameraPosition at(CameraPosition base, double t) => CameraPosition(
      target: base.target,
      zoom: base.zoom,
      bearing: base.bearing,
      tilt: t,
    );
    if (!_threeD || reducedMotion) {
      if (_threeD) {
        await _move(at(from, tilt),
            trackVehicle: false, generation: generation, anchored: false);
      }
      if (!_disposed && generation == _generation) _logical = at(from, tilt);
      return;
    }
    final ease = _tiltEase = (target: tilt, generation: generation,
        done: Completer<void>());
    _producingFrames = true;
    try {
      final started = DateTime.now();
      final fromTilt = from.tilt;
      var frames = 0;
      while (true) {
        // Real time, but never slower than one 16 ms step per frame, so the
        // ease ends even where the clock barely moves (tests, fast frames).
        final micros = math.max(
            DateTime.now().difference(started).inMicroseconds,
            frames * 16000);
        final t = (micros / tiltFlight.inMicroseconds).clamp(0.0, 1.0);
        frames++;
        final e = t * t * (3 - 2 * t);
        final base = _logical ?? from;
        await _move(at(base, fromTilt + (tilt - fromTilt) * e),
            trackVehicle: false, generation: generation, anchored: false);
        if (_disposed || generation != _generation || t >= 1) break;
        await _sleep(const Duration(milliseconds: 16));
      }
    } finally {
      if (generation == _generation) _producingFrames = false;
      if (identical(_tiltEase, ease)) _tiltEase = null;
      ease.done.complete();
    }
  }

  ({double target, int generation, Completer<void> done})? _tiltEase;

  /// The tilt following a driver's own zoom eases in this long.
  static const Duration tiltFlight = Duration(milliseconds: 350);

  static CameraPosition _blend(CameraPosition a, CameraPosition b, double t) =>
      CameraPosition(
        target: LatLng(
          a.target.latitude + (b.target.latitude - a.target.latitude) * t,
          a.target.longitude + (b.target.longitude - a.target.longitude) * t,
        ),
        zoom: a.zoom + (b.zoom - a.zoom) * t,
        bearing: GeoPoint.shortestAngleLerp(a.bearing, b.bearing, t),
        tilt: a.tilt + (b.tilt - a.tilt) * t,
      );

  Timer? _sleepTimer;
  Completer<void>? _sleeping;

  /// A frame pause that an interrupt (gesture, new preview, disposal)
  /// ends at once, so no camera timer outlives the camera's owner.
  Future<void> _sleep(Duration duration) {
    final done = Completer<void>();
    _sleeping = done;
    _sleepTimer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  void interrupt() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    final sleeping = _sleeping;
    _sleeping = null;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
    _generation++;
    _producingFrames = false;
    _followOwned = false;
    _looping = false;
    _goal = null;
    _flightPending = false;
  }

  @override
  void dispose() {
    _disposed = true;
    interrupt();
  }
}
