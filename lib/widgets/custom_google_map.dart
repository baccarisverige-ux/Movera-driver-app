import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show CircleUpdates, GoogleMapsFlutterPlatform, MarkerUpdates;

import '../core/l10n/driver_l10n.dart';
import '../core/navigation/map_camera_report.dart';
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
    // Owner N6 (live test 2026-10-26): the web plugin reports zoom 0 and
    // a (0, 0) centre when Maps has none to give; that is no camera frame
    // (see MapCameraReport), and the follow, the route line width and the
    // zoom detector must not take it for one.
    if (!MapCameraReport.isFrame(position)) return;
    final band = _styleBand.at(position.zoom);
    if (band != _styleBand && mounted) setState(() => _styleBand = band);
    _followCamera(position);
    widget.onCameraMove?.call(position);
  }

  /// The camera the own position arrow and its halo were last drawn for
  /// (phones; web draws its own in web/driver_map_camera.js).
  late double _vehicleBearing = widget.initialPosition?.bearing ?? 0;
  late double _vehicleTilt = widget.initialPosition?.tilt ?? 0;
  late double _vehicleZoom =
      widget.initialPosition?.zoom ?? _defaultPosition.zoom;

  static bool _isOwnVehicle(Marker marker) =>
      marker.markerId.value == 'driver' ||
      marker.markerId.value == 'driver_location';

  Marker? get _ownVehicle {
    for (final marker in _allMarkers) {
      if (_isOwnVehicle(marker)) return marker;
    }
    return null;
  }

  /// The own position arrow keeps pointing along its heading as the camera
  /// turns and lies in perspective as it tilts; its halo keeps its clamped
  /// size as the camera zooms. Only a new arrow picture (a 2° / 3° bucket)
  /// or a halo change over 2 % redraws, so a following camera does not
  /// churn the markers.
  void _followCamera(CameraPosition camera) {
    if (kIsWeb || !mounted) return;
    final own = _ownVehicle;
    if (own == null) return;
    final shown = _arrowView(own, _vehicleBearing, _vehicleTilt);
    final wanted = _arrowView(own, camera.bearing, camera.tilt);
    final halo = _haloRadius(own, _vehicleZoom);
    final nextHalo = _haloRadius(own, camera.zoom);
    if (shown != wanted || (nextHalo - halo).abs() > halo * .02) {
      setState(() {
        _vehicleBearing = camera.bearing;
        _vehicleTilt = camera.tilt;
        _vehicleZoom = camera.zoom;
      });
    }
  }

  static PositionArrowView _arrowView(
    Marker own,
    double bearing,
    double tilt,
  ) => MoveraVehicleMarker.view(
    heading: own.rotation,
    bearing: bearing,
    tilt: tilt,
  );

  static double _haloRadius(Marker own, double zoom) =>
      MoveraVehicleMarker.haloRadiusMeters(
        latitude: own.position.latitude,
        zoom: zoom,
      );

  /// The arrow picture last shown (while a new one is being drawn).
  PositionArrowView? _arrowShown;
  BitmapDescriptor? _arrowIconShown;

  /// The own vehicle as the map gets it: the arrow picture for the camera,
  /// centred on the position; flat (turned by the heading) on a map seen
  /// from above, else a screen-facing picture drawn in perspective.
  Marker _ownArrow(Marker marker) {
    var view = _arrowView(marker, _vehicleBearing, _vehicleTilt);
    var icon = MoveraVehicleMarker.iconFor(view);
    if (icon == null) {
      unawaited(
        MoveraVehicleMarker.makeIcon(view).then((made) {
          if (made == null || !mounted) return;
          setState(() {});
        }),
      );
      final shown = _arrowShown;
      if (shown != null && _arrowIconShown != null) {
        view = shown;
        icon = _arrowIconShown;
      } else {
        // Nothing drawn yet: the screen's own (flat) picture.
        view = MoveraVehicleMarker.view(
          heading: marker.rotation,
          bearing: 0,
          tilt: 0,
        );
        icon = marker.icon;
      }
    } else {
      _arrowShown = view;
      _arrowIconShown = icon;
    }
    return marker.copyWith(
      iconParam: icon,
      flatParam: view.flat,
      rotationParam: view.markerRotation,
      anchorParam: MoveraVehicleMarker.anchor,
    );
  }

  /// Phones: the halo under the own position (web draws it in
  /// web/driver_map_camera.js, in step with every zoom frame).
  Set<Circle> get _haloCircles {
    if (kIsWeb) return const <Circle>{};
    final own = _ownVehicle;
    if (own == null || !own.visible) return const <Circle>{};
    return {
      Circle(
        circleId: const CircleId(ownHaloId),
        center: own.position,
        radius: _haloRadius(own, _vehicleZoom),
        fillColor: MoveraVehicleMarker.halo.withValues(
          alpha: MoveraVehicleMarker.haloOpacity,
        ),
        strokeWidth: 0,
        strokeColor: const Color(0x00000000),
        zIndex: 0,
      ),
    };
  }

  /// The own position's halo's circle id.
  static const String ownHaloId = 'own-position-halo';

  Set<Circle> get _mapCircles => {...?widget.circles, ..._haloCircles};

  /// What [GoogleMap] gets as circles, the halo included.
  Set<Circle> get _mapCirclesSent {
    _haloShown = _haloCircles;
    return _mapCircles;
  }

  /// The halo as last given to the map.
  Set<Circle> _haloShown = const <Circle>{};

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

  /// Phones: the halo follows the live car between rebuilds.
  void _pushHalo(int mapId) {
    if (kIsWeb) return;
    final next = _haloCircles;
    final updates = CircleUpdates.from(_haloShown, next);
    _haloShown = next;
    if (updates.circlesToAdd.isEmpty &&
        updates.circlesToChange.isEmpty &&
        updates.circleIdsToRemove.isEmpty) {
      return;
    }
    unawaited(
      GoogleMapsFlutterPlatform.instance.updateCircles(updates, mapId: mapId),
    );
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
    _pushHalo(controller.mapId);
    if (updates.markersToAdd.isEmpty &&
        updates.markersToChange.isEmpty &&
        updates.markerIdsToRemove.isEmpty) {
      return;
    }
    unawaited(
      GoogleMapsFlutterPlatform.instance.updateMarkers(
        updates,
        mapId: controller.mapId,
      ),
    );
    _updateWebVehicle(controller.mapId);
  }

  /// The markers as the map gets them: the own vehicle (its rotation a
  /// compass heading) as the position arrow for the camera ([_ownArrow]).
  /// Web: as given; web/driver_map_camera.js draws the arrow.
  Set<Marker> _shown(Iterable<Marker> markers) {
    if (kIsWeb) return markers.toSet();
    return {
      for (final marker in markers)
        if (_isOwnVehicle(marker)) _ownArrow(marker) else marker,
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
          _doubleTapCandidate =
              widget.zoomGesturesEnabled &&
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
              circles: _mapCirclesSent,
              polygons: widget.polygons ?? {},
              myLocationEnabled: widget.myLocationEnabled,
              myLocationButtonEnabled: widget.myLocationButtonEnabled,
              zoomControlsEnabled: widget.zoomControlsEnabled,
              mapToolbarEnabled: widget.mapToolbarEnabled,
              compassEnabled: widget.compassEnabled,
              // Owner (live test 2026-10-26, N5): no Google traffic layer
              // on any driver map; only the Movera map style draws the roads.
              trafficEnabled: false,
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
