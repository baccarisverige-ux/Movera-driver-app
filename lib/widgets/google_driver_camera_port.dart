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
class GoogleDriverCameraPort implements DriverCameraPort, DriverCameraFraming {
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

  void onMove(CameraPosition position) {
    // SDK echoes include the web anchor pan. While we own follow, the logical
    // vehicle pose is the only legal interpolation origin.
    if (_producingFrames || _followOwned) {
      return;
    }
    _logical = position;
  }

  void onIdle() {} // Idle is not evidence of a user gesture.

  CameraPosition _at(DriverCameraPose pose, GeoPoint target) => CameraPosition(
    target: LatLng(target.latitude, target.longitude),
    zoom: pose.zoom,
    bearing: web.supports3D(controller.mapId) ? pose.bearing : 0,
    tilt: web.supports3D(controller.mapId) ? pose.tilt : 0,
  );

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

  Future<void> _move(
    CameraPosition logical, {
    required bool trackVehicle,
    required int generation,
  }) async {
    if (_disposed || generation != _generation) return;
    _logical = logical;
    web.claim(controller.mapId);
    await controller.moveCamera(CameraUpdate.newCameraPosition(logical));
    // A physical pan, app suspension, replaced map, or disposal can interrupt
    // this command while the Maps SDK still awaits acknowledgement. Never
    // publish an old camera frame or clear a newer error after that point.
    if (_disposed || generation != _generation) return;
    onStatus?.call(null);
    if (trackVehicle) {
      onFrame?.call(logical);
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
      while (!_disposed && generation == _generation) {
        final goal = _goal;
        if (goal == null || generation != _generation) {
          break;
        }
        final destination = _at(goal, _coasted(goal));
        final from = _logical ?? destination;
        final settled = _settled(from, destination);
        if (!settled) {
          final next = _approach(from, destination, dt, goal.duration);
          await _move(next,
            trackVehicle: _trackCar(next, goal), generation: generation);
        }
        if (_disposed || generation != _generation || settled) {
          break;
        }
        final stamp = DateTime.now();
        await Future<void>.delayed(Duration(milliseconds: settled ? 50 : 16));
        if (_disposed || generation != _generation) {
          break;
        }
        final real = DateTime.now().difference(stamp).inMicroseconds;
        dt = math.max(settled ? 50000 : 16000, real);
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        onStatus?.call('Map camera unavailable — tap recenter to retry');
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
      onStatus?.call('Map camera unavailable — tap recenter to retry');
      // The owner must know that fitting the route failed. Otherwise it
      // remains in Overview forever and suppresses subsequent GPS following.
      rethrow;
    }
  }

  /// The whole offer route: straight to its fitted target and zoom, flat.
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
    _logical = position;
    try {
      await controller.moveCamera(CameraUpdate.newCameraPosition(position));
      if (_disposed || generation != _generation) return;
      onStatus?.call(null);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      onStatus?.call('Map camera unavailable — tap recenter to retry');
      rethrow;
    }
  }

  @override
  void interrupt() {
    _generation++;
    _producingFrames = false;
    _followOwned = false;
    _looping = false;
    _goal = null;
  }

  @override
  void dispose() {
    _disposed = true;
    interrupt();
  }
}
