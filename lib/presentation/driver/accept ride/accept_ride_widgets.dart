part of 'accept_ride.dart';

class _ThrottledVehicleMap extends StatefulWidget {
  const _ThrottledVehicleMap({
    super.key,
    required this.vehicle,
    required this.vehicleIcon,
    required this.stage,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.pickupAddress,
    required this.stopPositions,
    required this.stopCursor,
    required this.pinIcons,
    required this.dropoffAddress,
    required this.routeLines,
    required this.padding,
    required this.cameraAnchor,
    required this.blockGestures,
    required this.initialTarget,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onUserGesture,
  });

  final LiveVehicleAnimator vehicle;
  final BitmapDescriptor vehicleIcon;
  final ActiveRideStage stage;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final String pickupAddress;
  final String dropoffAddress;
  final List<LatLng> stopPositions;
  final int stopCursor;
  final Map<RouteMarkKind, BitmapDescriptor> pinIcons;
  final TripRouteLines routeLines;
  final EdgeInsets padding;
  final double cameraAnchor;
  final bool blockGestures;
  final LatLng initialTarget;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;
  final VoidCallback onUserGesture;

  @override
  State<_ThrottledVehicleMap> createState() => _ThrottledVehicleMapState();
}

class _ThrottledVehicleMapState extends State<_ThrottledVehicleMap> {
  Timer? _ticker;
  late LiveVehiclePose _pose;

  /// D-08: the moving car goes to the map on its own; the map widget (and
  /// with it every line and pin) is not rebuilt for it.
  late final ValueNotifier<Marker?> _car;

  @override
  void initState() {
    super.initState();
    _pose = widget.vehicle.current;
    _car = ValueNotifier<Marker?>(_carMarker);
    if (!DriverRuntimeConfig.current.liveMapTicker) {
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      // driver-u59: a route covering the trip turns tickers off here.
      if (!mounted || !TickerMode.valuesOf(context).enabled) {
        return;
      }
      final next = widget.vehicle.current;
      if (next.position.latitude == _pose.position.latitude &&
          next.position.longitude == _pose.position.longitude &&
          next.headingDegrees == _pose.headingDegrees) {
        return;
      }
      _pose = next;
      _car.value = _carMarker;
    });
  }

  @override
  void didUpdateWidget(covariant _ThrottledVehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.vehicle, widget.vehicle)) {
      _pose = widget.vehicle.current;
    }
    if (!identical(oldWidget.vehicle, widget.vehicle) ||
        oldWidget.vehicleIcon != widget.vehicleIcon) {
      _car.value = _carMarker;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _car.dispose();
    super.dispose();
  }

  Marker get _carMarker => Marker(
    markerId: const MarkerId('driver'),
    position: _pose.position,
    // Compass heading; CustomGoogleMap draws the position arrow for the
    // camera (flat or tilted) with its halo.
    rotation: _pose.headingDegrees,
    flat: false,
    anchor: MoveraVehicleMarker.anchor,
    zIndexInt: 12,
    icon: widget.vehicleIcon,
    // No default map bubble on the car.
    consumeTapEvents: true,
    infoWindow: InfoWindow(title: MoveraVehicleMarker.ownTitle),
  );

  /// The pins; they change only with the trip's step.
  Set<Marker> get _pins {
    final markers = <Marker>{};
    Marker pin(String id, LatLng at, RouteMarkKind kind) => Marker(
      markerId: MarkerId(id),
      position: at,
      icon: widget.pinIcons[kind] ?? BitmapDescriptor.defaultMarker,
      anchor: RouteMarkPins.pinAnchor,
      zIndexInt: 8,
      consumeTapEvents: true,
    );

    // Pins in the colour of what they mark: green pickup, orange stops,
    // black drop-off.
    if (widget.stage != ActiveRideStage.onTrip) {
      markers.add(pin('pickup', widget.pickupPosition, RouteMarkKind.pickup));
    } else {
      for (var i = widget.stopCursor; i < widget.stopPositions.length; i++) {
        markers.add(
          pin('stop-$i', widget.stopPositions[i], RouteMarkKind.stop),
        );
      }
      markers.add(
        pin('dropoff', widget.dropoffPosition, RouteMarkKind.dropoff),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<Polyline>>(
      valueListenable: widget.routeLines,
      builder: (context, lines, _) => RepaintBoundary(
        child: CustomGoogleMap(
          key: const ValueKey<String>('active-ride-map'),
          initialPosition: CameraPosition(
            target: widget.initialTarget,
            zoom: DriverCameraPolicy.guidanceStartZoom,
            // Opens already tilted: no tilt-up flight when the trip starts.
            tilt: DriverCameraPolicy.tiltForZoom(
              DriverCameraPolicy.guidanceStartZoom,
            ),
          ),
          markers: _pins,
          liveMarker: _car,
          polylines: lines,
          cameraAnchor: widget.cameraAnchor,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          webCameraControlEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          buildingsEnabled: true,
          indoorViewEnabled: false,
          scrollGesturesEnabled: !widget.blockGestures,
          zoomGesturesEnabled: !widget.blockGestures,
          rotateGesturesEnabled: !widget.blockGestures,
          tiltGesturesEnabled: !widget.blockGestures,
          mapType: MapType.normal,
          padding: widget.padding,
          onCameraMove: widget.onCameraMove,
          onCameraIdle: widget.onCameraIdle,
          onUserGesture: widget.onUserGesture,
          onMapCreated: widget.onMapCreated,
        ),
      ),
    );
  }
}

class _SlideRideAction extends StatefulWidget {
  const _SlideRideAction({
    super.key,
    required this.semanticsKey,
    required this.label,
    required this.confirmedLabel,
    required this.accent,
    required this.onConfirmed,
  });

  final Key semanticsKey;
  final String label;
  final String confirmedLabel;

  /// Colour of the track once the action is confirmed.
  final Color accent;
  final Future<void> Function() onConfirmed;

  @override
  State<_SlideRideAction> createState() => _SlideRideActionState();
}

class _SlideRideActionState extends State<_SlideRideAction> {
  static const double _height = 58;
  static const double _thumb = 58;
  static const double _trigger = 0.78;

  double _fraction = 0;
  bool _dragging = false;
  bool _confirmed = false;
  bool _confirming = false;

  @override
  void didUpdateWidget(covariant _SlideRideAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label == widget.label && oldWidget.accent == widget.accent) {
      return;
    }
    _fraction = 0;
    _dragging = true;
    _confirmed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _confirmed || _fraction != 0) {
        return;
      }
      setState(() => _dragging = false);
    });
  }

  void _update(double delta, double maxTravel) {
    if (_confirmed || _confirming || maxTravel <= 0) {
      return;
    }
    final next = (_fraction + (delta / maxTravel)).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _fraction = next >= _trigger ? 1 : next;
    });
  }

  void _cancelDrag() {
    if (_confirming || !mounted) {
      return;
    }
    setState(() {
      _dragging = false;
      _fraction = 0;
      _confirmed = false;
    });
  }

  Future<void> _finish() async {
    if (_confirming) {
      return;
    }
    if (_fraction < _trigger) {
      _cancelDrag();
      return;
    }
    setState(() {
      _confirmed = true;
      _confirming = true;
      _dragging = false;
      _fraction = 1;
    });
    HapticFeedback.mediumImpact();
    try {
      await widget.onConfirmed();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.actionCouldNotBeCompletedPlease)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirmed = false;
          _confirming = false;
          _fraction = 0;
          _dragging = false;
        });
      }
    }
  }

  Future<void> _accessibleConfirm() async {
    if (_confirming) {
      return;
    }
    final confirmed = await showMoveraConfirm(
      context,
      title: widget.label.replaceFirst('Slide to ', ''),
      body: tr.confirmThisTripActionQuestion,
      cancel: tr.cancel,
      confirm: tr.confirm,
    );
    if (!mounted || confirmed != true || _confirming) {
      return;
    }
    _fraction = 1;
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: widget.semanticsKey,
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTravel = math.max(0.0, constraints.maxWidth - _thumb);

          return Semantics(
            button: true,
            enabled: !_confirming,
            excludeSemantics: true, // u63: read once
            label: _confirmed
                ? widget.confirmedLabel
                : widget.label.replaceFirst('Slide to ', ''),
            onTap: _confirming ? null : _accessibleConfirm,
            child: FocusableActionDetector(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _accessibleConfirm();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics:
                    true, // u64: a11y uses the tap above, which asks
                onHorizontalDragUpdate: (details) =>
                    _update(details.delta.dx, maxTravel),
                onHorizontalDragEnd: (_) => _finish(),
                onHorizontalDragCancel: _cancelDrag,
                // Light track with a black square thumb carrying an arrow.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _confirmed ? widget.accent : const Color(0xFFEEEFF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: _dragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              width: _thumb + maxTravel * _fraction,
                              color: const Color(
                                0xFF111614,
                              ).withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _thumb + 8,
                        right: 12,
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: Text(
                            _confirmed ? widget.confirmedLabel : widget.label,
                            key: ValueKey<String>(
                              _confirmed ? widget.confirmedLabel : widget.label,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _confirmed
                                  ? Colors.white
                                  : const Color(0xFF111614),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: maxTravel * _fraction,
                        top: 0,
                        child: Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111614),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _confirmed
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
