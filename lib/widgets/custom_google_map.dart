import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show GoogleMapsFlutterPlatform, MarkerUpdates;


import '../core/l10n/driver_l10n.dart';
import '../core/navigation/map_double_tap_policy.dart';
import '../styles/movera_map_palette.dart';
import '../styles/movera_map_style.dart';
import 'movera_vehicle_marker.dart';
import 'driver_map_web_bridge_stub.dart'
    if (dart.library.js_interop) 'driver_map_web_bridge.dart'
    as web;

class CustomGoogleMap extends StatefulWidget {
  /// Web: Maps JavaScript is installed. Tests replace it.
  @visibleForTesting
  static bool Function() mapsReadyProbe = () => web.ready;

  /// driver-99: how long the map waits for Maps JavaScript before it says
  /// the map is unavailable (a blocker, a rejected key, offline). It still
  /// shows the map if the script arrives later.
  static const Duration mapsUnavailableAfter = Duration(seconds: 12);

  final CameraPosition? initialPosition;
  final Set<Marker>? markers;

  /// D-08: one marker that moves often (the own car). Each move goes to the
  /// map as a marker update of its own; the map widget is not rebuilt, so
  /// lines, pins and the rest are not sent again.
  final ValueListenable<Marker?>? liveMarker;
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
    this.liveMarker,
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
    _turnVehicleWith(position);
    widget.onCameraMove?.call(position);
  }

  /// The map bearing the own vehicle's billboard rotation was last worked
  /// out for (native maps; web turns its own native marker). Zoom and tilt
  /// play no part: the marker keeps one size and one picture.
  late double _vehicleBearing = widget.initialPosition?.bearing ?? 0;

  static bool _isOwnVehicle(Marker marker) =>
      marker.markerId.value == 'driver' ||
      marker.markerId.value == 'driver_location';

  /// A billboard turns with the screen: as the camera turns, turn the
  /// arrow back onto its heading. Only a visible change (over 1.5°)
  /// rebuilds the markers, so a following camera does not churn them.
  void _turnVehicleWith(CameraPosition camera) {
    if (kIsWeb || !mounted) return;
    for (final marker in _allMarkers) {
      if (!_isOwnVehicle(marker) || marker.flat) continue;
      final shown =
          MoveraVehicleMarker.screenRotation(marker.rotation, _vehicleBearing);
      final wanted =
          MoveraVehicleMarker.screenRotation(marker.rotation, camera.bearing);
      final change = ((wanted - shown + 540) % 360 - 180).abs();
      if (change > 1.5) setState(() => _vehicleBearing = camera.bearing);
      return;
    }
  }

  /// Every marker, the live one included.
  Iterable<Marker> get _allMarkers {
    final live = widget.liveMarker?.value;
    final markers = widget.markers ?? const <Marker>{};
    return live == null ? markers : [...markers, live];
  }

  Set<Marker> get _mapMarkers => _shown(_allMarkers);

  /// What [GoogleMap] gets: every marker, and the live one as sent now.
  Set<Marker> get _mapMarkersSent {
    _liveShown = _liveNow;
    return _mapMarkers;
  }

  /// The live marker as last given to the map.
  Set<Marker> _liveShown = const <Marker>{};

  Set<Marker> get _liveNow {
    final live = widget.liveMarker?.value;
    return live == null ? const <Marker>{} : _shown([live]);
  }

  bool _livePushQueued = false;

  /// At most one live-marker update a frame, as a rebuild would be.
  void _onLiveMarker() {
    if (!mounted || _livePushQueued) return;
    _livePushQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _livePushQueued = false;
      _pushLiveMarker();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _pushLiveMarker() {
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null || !_mapsReady) {
      setState(() {});
      return;
    }
    final next = _liveNow;
    final updates = MarkerUpdates.from(_liveShown, next);
    _liveShown = next;
    if (updates.markersToAdd.isEmpty &&
        updates.markersToChange.isEmpty &&
        updates.markerIdsToRemove.isEmpty) {
      return;
    }
    unawaited(GoogleMapsFlutterPlatform.instance
        .updateMarkers(updates, mapId: controller.mapId));
    _updateWebVehicle(controller.mapId);
  }

  /// The markers as the map gets them: the own vehicle (a billboard, its
  /// rotation a compass heading) turned to the screen. One marker, one
  /// size: the ring is in its picture.
  Set<Marker> _shown(Iterable<Marker> markers) {
    if (kIsWeb) return markers.toSet();
    return {
      for (final marker in markers)
        if (_isOwnVehicle(marker) && !marker.flat)
          marker.copyWith(
            rotationParam: MoveraVehicleMarker.screenRotation(
                marker.rotation, _vehicleBearing),
          )
        else
          marker,
    };
  }

  /// Web: Maps JavaScript (and its camera adapter) can arrive after the
  /// first frame, e.g. with async loading or a slow network. Building
  /// [GoogleMap] before then throws on every rebuild; the framework swaps
  /// the rebuilding Home subtree (popup, offer cards) for an [ErrorWidget]
  /// while the map platform view stays on screen. Wait for it instead.
  bool _mapsReady = CustomGoogleMap.mapsReadyProbe();
  bool _mapsUnavailable = false;
  Timer? _mapsReadyPoll;

  @override
  void initState() {
    super.initState();
    widget.liveMarker?.addListener(_onLiveMarker);
    if (_mapsReady) return;
    const poll = Duration(milliseconds: 50);
    _mapsReadyPoll = Timer.periodic(poll, (timer) {
      if (!CustomGoogleMap.mapsReadyProbe()) {
        if (!_mapsUnavailable &&
            poll * timer.tick >= CustomGoogleMap.mapsUnavailableAfter &&
            mounted) {
          setState(() => _mapsUnavailable = true);
        }
        return;
      }
      timer.cancel();
      if (mounted) {
        setState(() {
          _mapsReady = true;
          _mapsUnavailable = false;
        });
      }
    });
  }

  void Function()? _removeWebGesture;

  @override
  void didUpdateWidget(CustomGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.liveMarker, widget.liveMarker)) {
      oldWidget.liveMarker?.removeListener(_onLiveMarker);
      widget.liveMarker?.addListener(_onLiveMarker);
    }
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
    for (final marker in _allMarkers) {
      if (_isOwnVehicle(marker)) {
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
            ColoredBox(
              color: MoveraMapPalette.land,
              child: !_mapsUnavailable
                  ? null
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr.mapUnavailable,
                          key: const ValueKey<String>('map-unavailable'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF3F4A52),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            )
          else
            GoogleMap(
              initialCameraPosition: widget.initialPosition ?? _defaultPosition,
              markers: _mapMarkersSent,
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
    widget.liveMarker?.removeListener(_onLiveMarker);
    _mapsReadyPoll?.cancel();
    _removeWebGesture?.call();
    // A map replaced under a finger must not leave the camera held.
    if (_pointerOrigins.isNotEmpty) widget.onTouching?.call(false);
    // GoogleMap owns its platform controller. Avoid a second web disposal.
    _mapController = null;
    super.dispose();
  }
}
