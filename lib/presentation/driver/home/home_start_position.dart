part of 'home.dart';

// Where Home's map opens. Owner REMINDERS 144/145: the map is built at
// once (never a hidden wait longer than the intro) at the position known
// now (this run, saved last position, platform last fix), else the zone
// centre without a car, and moves when a position arrives.

extension _HomeStartPosition on _DriverHomeState {
  void _restoreStartPosition() {
    final cached = DriverStartPosition.cached;
    if (cached != null) {
      _useStartPosition(cached);
      return;
    }
    unawaited(
      DriverStartPosition.load().then((point) {
        if (point == null || !mounted || _startPositionKnown) {
          return;
        }
        _rebuild(() => _useStartPosition(point));
        // The map is already up at the zone centre: glide to the position
        // unless live GPS placed it first.
        if (!_didCenterOnLiveLocation) {
          _cameraLocation ??= _startTarget(point);
          unawaited(_HomeMapSheet(this)._animateToDriverLocation());
        }
      }),
    );
  }

  /// A camera target for a start position (saved, or a rough first fix):
  /// stamped now so the camera, which follows accurate fixes only, moves.
  DriverLocation _startTarget(GeoPoint point) => DriverLocation(
    point: point,
    measuredAt: DateTime.now(),
    accuracyMeters: 0,
  );

  void _useStartPosition(GeoPoint point) {
    _driverPosition = point.toLatLng();
    _startPositionKnown = true;
    _markers = _driverMarkers();
  }

  Set<Marker> _driverMarkers() => {
    Marker(
      markerId: const MarkerId('driver_location'),
      position: _driverPosition,
      infoWindow: InfoWindow(title: MoveraVehicleMarker.ownTitle),
      icon: _driverVehicleIcon,
      // Compass heading; CustomGoogleMap draws the position arrow for the
      // camera (flat or tilted) with its halo.
      flat: false,
      anchor: MoveraVehicleMarker.anchor,
      rotation: _driverHeading,
      zIndexInt: 12,
    ),
  };
}
