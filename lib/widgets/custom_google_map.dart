import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:math' as math;

import '../styles/reference_map_style.dart';
import '../core/navigation/map_double_tap_policy.dart';
import 'driver_map_web_bridge_stub.dart'
    if (dart.library.js_interop) 'driver_map_web_bridge.dart'
    as web;

class CustomGoogleMap extends StatefulWidget {
  final CameraPosition? initialPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Set<Circle>? circles;
  final Set<Polygon>? polygons;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final bool compassEnabled;
  final bool trafficEnabled;
  final bool buildingsEnabled;
  final bool indoorViewEnabled;
  final bool scrollGesturesEnabled;
  final bool zoomGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final MapType mapType;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(LatLng)? onTap;
  final void Function(LatLng)? onLongPress;
  final void Function(CameraPosition)? onCameraMove;
  final void Function()? onCameraIdle;

  /// Fired only for physical drag/pinch/rotate/tilt/wheel input, never SDK moves.
  final VoidCallback? onUserGesture;
  final EdgeInsets padding;

  /// Vertical screen anchor; .72 drives, clamped above sheet overlays.
  final double cameraAnchor;
  final String? customMapStyle;

  /// Web only: Google's camera (zoom / pan) control in the corner.
  final bool webCameraControlEnabled;

  /// The "2D map · 3D unavailable" note when 3D cannot be shown.
  final bool show3DNotice;

  const CustomGoogleMap({
    super.key,
    this.initialPosition,
    this.markers,
    this.polylines,
    this.circles,
    this.polygons,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.mapToolbarEnabled = false,
    this.compassEnabled = false,
    this.trafficEnabled = false,
    this.buildingsEnabled = true,
    this.indoorViewEnabled = false,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.mapType = MapType.normal,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onCameraMove,
    this.onCameraIdle,
    this.onUserGesture,
    this.padding = EdgeInsets.zero,
    this.cameraAnchor = .5,
    this.customMapStyle,
    this.webCameraControlEnabled = false,
    this.show3DNotice = true,
  });

  @override
  State<CustomGoogleMap> createState() => _CustomGoogleMapState();
}

class _CustomGoogleMapState extends State<CustomGoogleMap> {
  final Map<int, Offset> _pointerOrigins = {};
  bool _gestureReported = false;
  Duration? _lastTapAt;
  Offset? _lastTapPosition;
  bool _doubleTapCandidate = false;

  void _forgetTap() {
    _lastTapAt = null;
    _lastTapPosition = null;
    _doubleTapCandidate = false;
  }

  bool get _cameraGesturesEnabled =>
      widget.scrollGesturesEnabled ||
      widget.zoomGesturesEnabled ||
      widget.rotateGesturesEnabled ||
      widget.tiltGesturesEnabled;

  void _reportGesture() {
    if (!_cameraGesturesEnabled || _gestureReported) {
      return;
    }
    _gestureReported = true;
    widget.onUserGesture?.call();
  }

  GoogleMapController? _mapController;
  void Function()? _removeWebGesture;
  void Function()? _removeWebRenderer;
  bool _supports3D = true;

  @override
  void didUpdateWidget(CustomGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollGesturesEnabled != widget.scrollGesturesEnabled ||
        oldWidget.zoomGesturesEnabled != widget.zoomGesturesEnabled ||
        oldWidget.rotateGesturesEnabled != widget.rotateGesturesEnabled ||
        oldWidget.tiltGesturesEnabled != widget.tiltGesturesEnabled) {
      // The ride sheet can lock/unlock map gestures while a finger remains
      // down. Flutter may not send its original pointer-up through the newly
      // blocked platform view. Do not let that stale finger become a phantom
      // second pointer, or an earlier tap become a new double-tap zoom.
      _pointerOrigins.clear();
      _gestureReported = false;
      _forgetTap();
    }
    final controller = _mapController;
    if (controller != null) {
      web.configure(
        controller.mapId,
        widget.padding.top,
        widget.padding.bottom,
        widget.cameraAnchor,
      );
      _updateWebVehicle(controller.mapId);
      web.gestures(controller.mapId, _cameraGesturesEnabled);
    }
  }

  void _updateWebVehicle(int mapId) {
    for (final marker in widget.markers ?? <Marker>{}) {
      if (marker.markerId.value == 'driver' ||
          marker.markerId.value == 'driver_location') {
        web.vehicle(mapId, marker.rotation);
      }
    }
  }

  // Default location - central Stockholm, the app's operating city.
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(59.3293, 18.0686),
    zoom: 13.0,
  );

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Platform map views may expose no Flutter hit-test child (notably
      // headless tests and some web platform-view frames). Still observe
      // genuine input over the full map surface without blocking the map.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_pointerOrigins.isEmpty) {
          _gestureReported = false;
          final at = _lastTapAt;
          final point = _lastTapPosition;
          _doubleTapCandidate = widget.zoomGesturesEnabled &&
              MapDoubleTapPolicy.isSecondTap(
                previousAt: at,
                previousPosition: point,
                currentAt: event.timeStamp,
                currentPosition: event.position,
              );
        }
        _pointerOrigins[event.pointer] = event.position;
        // A marker tap stays in Follow. A second simultaneous pointer
        // signals pinch/rotate, even if neither finger has moved yet.
        if (_pointerOrigins.length > 1) {
          _forgetTap();
          _reportGesture();
        }
      },
      onPointerMove: (event) {
        final origin = _pointerOrigins[event.pointer];
        if (origin != null && (event.position - origin).distance >= 6) {
          _forgetTap();
          _reportGesture();
        }
      },
      onPointerUp: (event) {
        final origin = _pointerOrigins.remove(event.pointer);
        if (origin == null || _pointerOrigins.isNotEmpty) return;
        if (_gestureReported || (event.position - origin).distance >= 6) {
          _forgetTap();
          return;
        }
        if (_doubleTapCandidate) {
          // Native Maps can zoom on two stationary taps. Unlike a pan or
          // pinch, this has no pointer-move signal; yield Follow ownership
          // before its zoom animation is undone by the next GPS frame.
          _forgetTap();
          _reportGesture();
        } else {
          _lastTapAt = event.timeStamp;
          _lastTapPosition = event.position;
          _doubleTapCandidate = false;
        }
      },
      onPointerCancel: (event) {
        _pointerOrigins.remove(event.pointer);
        _forgetTap();
      },
      onPointerSignal: (_) {
        _gestureReported = false;
        _reportGesture();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: widget.initialPosition ?? _defaultPosition,
            markers: widget.markers ?? {},
            polylines: widget.polylines ?? {},
            circles: widget.circles ?? {},
            polygons: widget.polygons ?? {},
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: widget.myLocationButtonEnabled,
            zoomControlsEnabled: widget.zoomControlsEnabled,
            mapToolbarEnabled: widget.mapToolbarEnabled,
            compassEnabled: widget.compassEnabled,
            trafficEnabled: widget.trafficEnabled,
            buildingsEnabled: widget.buildingsEnabled,
            indoorViewEnabled: widget.indoorViewEnabled,
            scrollGesturesEnabled: widget.scrollGesturesEnabled,
            zoomGesturesEnabled: widget.zoomGesturesEnabled,
            rotateGesturesEnabled: widget.rotateGesturesEnabled,
            tiltGesturesEnabled: widget.tiltGesturesEnabled,
            mapType: widget.mapType,
            padding: widget.padding,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            webGestureHandling: WebGestureHandling.greedy,
            webCameraControlEnabled: widget.webCameraControlEnabled,
            style: widget.customMapStyle ?? moveraReferenceMapStyle,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _supports3D = web.supports3D(controller.mapId);
              _removeWebRenderer = web.listenRenderer(controller.mapId, () {
                if (mounted) {
                  setState(
                    () => _supports3D = web.supports3D(controller.mapId),
                  );
                }
              });
              if (mounted) {
                setState(() {});
              }
              web.configure(
                controller.mapId,
                widget.padding.top,
                widget.padding.bottom,
                widget.cameraAnchor,
              );
              _removeWebGesture = web.listen(controller.mapId, () {
                if (mounted) {
                  widget.onUserGesture?.call();
                }
              });
              _updateWebVehicle(controller.mapId);
              web.gestures(controller.mapId, _cameraGesturesEnabled);
              // Call the provided onMapCreated callback
              if (widget.onMapCreated != null) {
                widget.onMapCreated!(controller);
              }
            },
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onCameraMove: widget.onCameraMove,
            onCameraIdle: widget.onCameraIdle,
          ),
          if (!_supports3D && widget.show3DNotice)
            Positioned(
              left: 12,
              bottom: widget.padding.bottom + 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      '2D map · 3D unavailable',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Getter to access the map controller from outside
  GoogleMapController? get mapController => _mapController;

  @override
  void dispose() {
    _removeWebGesture?.call();
    _removeWebRenderer?.call();
    // GoogleMap owns its platform controller. Avoid a second web disposal.
    _mapController = null;
    super.dispose();
  }
}

// Helper class for creating common map elements
class MapHelper {
  // Create a custom marker
  static Future<Marker> createCustomMarker({
    required String markerId,
    required LatLng position,
    String? infoWindow,
    BitmapDescriptor? icon,
    VoidCallback? onTap,
  }) async {
    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      infoWindow: InfoWindow(title: infoWindow),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      onTap: onTap,
    );
  }

  // Create a polyline (route)
  static Polyline createRoute({
    required String polylineId,
    required List<LatLng> points,
    Color color = Colors.blue,
    double width = 5.0,
  }) {
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: color,
      width: width.toInt(),
    );
  }

  // Create a circle
  static Circle createCircle({
    required String circleId,
    required LatLng center,
    required double radius,
    Color fillColor = Colors.blue,
    Color strokeColor = Colors.blue,
    double strokeWidth = 2.0,
  }) {
    return Circle(
      circleId: CircleId(circleId),
      center: center,
      radius: radius,
      fillColor: fillColor.withValues(alpha: 0.3),
      strokeColor: strokeColor,
      strokeWidth: strokeWidth.toInt(),
    );
  }

  // Calculate bounds for multiple points
  static LatLngBounds boundsFromLatLngList(List<LatLng> list) {
    double minLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLat = list.first.latitude;
    double maxLng = list.first.longitude;

    for (LatLng point in list) {
      minLat = math.min(minLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLat = math.max(maxLat, point.latitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

// Import this for math operations
