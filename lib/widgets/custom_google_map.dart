import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:math' as math;

import '../core/navigation/map_double_tap_policy.dart';
import '../styles/movera_map_palette.dart';
import '../styles/movera_map_style.dart';
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

  /// True while at least one finger (or button) is down on the map, false
  /// once the last one lifts. The camera must not move under a finger:
  /// Maps reports camera idle also while a pinch is held still.
  final ValueChanged<bool>? onTouching;
  final EdgeInsets padding;

  /// Vertical screen anchor; .75 drives, clamped above sheet overlays.
  final double cameraAnchor;

  /// Web only: Google's camera (zoom / pan) control in the corner.
  final bool webCameraControlEnabled;

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
    this.onTouching,
    this.padding = EdgeInsets.zero,
    this.cameraAnchor = .5,
    this.webCameraControlEnabled = false,
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

  /// Far / near map style band (parks change green at zoom 12.5). Changes
  /// only when the camera crosses the band, so the map rebuilds rarely.
  /// With a web Map ID the cloud style wins and this style is not applied.
  late MoveraMapStyleBand _styleBand = MoveraMapStyleBand.of(
    widget.initialPosition?.zoom ?? _defaultPosition.zoom,
  );

  void _onCameraMove(CameraPosition position) {
    final band = _styleBand.at(position.zoom);
    if (band != _styleBand && mounted) setState(() => _styleBand = band);
    widget.onCameraMove?.call(position);
  }

  /// Web: Maps JavaScript (and its camera adapter) can arrive after the
  /// first frame, e.g. with async loading or a slow network. Building
  /// [GoogleMap] before then throws on every rebuild; the framework swaps
  /// the rebuilding Home subtree (popup, offer cards) for an [ErrorWidget]
  /// while the map platform view stays on screen. Wait for it instead.
  bool _mapsReady = web.ready;
  Timer? _mapsReadyPoll;

  @override
  void initState() {
    super.initState();
    if (_mapsReady) return;
    _mapsReadyPoll = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!web.ready) return;
      timer.cancel();
      if (mounted) setState(() => _mapsReady = true);
    });
  }

  void Function()? _removeWebGesture;

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
      if (_pointerOrigins.isNotEmpty) widget.onTouching?.call(false);
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
        if (_pointerOrigins.length == 1) widget.onTouching?.call(true);
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
        widget.onTouching?.call(false);
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
        if (_pointerOrigins.remove(event.pointer) != null &&
            _pointerOrigins.isEmpty) {
          widget.onTouching?.call(false);
        }
        _forgetTap();
      },
      onPointerSignal: (_) {
        _gestureReported = false;
        _reportGesture();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_mapsReady)
            const ColoredBox(color: MoveraMapPalette.land)
          else
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
              style: _styleBand.style,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
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
              onCameraMove: _onCameraMove,
              onCameraIdle: widget.onCameraIdle,
            ),
        ],
      ),
    );
  }

  // Getter to access the map controller from outside
  GoogleMapController? get mapController => _mapController;

  @override
  void dispose() {
    _mapsReadyPoll?.cancel();
    _removeWebGesture?.call();
    // A map replaced under a finger must not leave the camera held.
    if (_pointerOrigins.isNotEmpty) widget.onTouching?.call(false);
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
