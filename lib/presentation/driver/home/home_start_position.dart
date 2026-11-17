part of 'home.dart';

// Where Home's map opens. Owner REMINDERS 144/145: the map is built at
// once (never a hidden wait longer than the intro) at the position known
// now (this run, saved last position, platform last fix), else the zone
// centre without a car, and moves when a position arrives.

/// First start only: longest wait for a position before the map opens.
const Duration _startWaitLimit = Duration(seconds: 8);

extension _HomeStartPosition on _DriverHomeState {
  /// Later starts: at once. The first start ever: once a position is
  /// known or location failed (refused, off), then at the country centre.
  bool get _mapReady =>
      !_firstStart || _startPositionKnown || _startLocationFailed;

  void _restoreStartPosition() {
    final cached = DriverStartPosition.cached;
    if (cached != null) {
      _useStartPosition(cached);
      return;
    }
    // First start: GPS that never answers (no permission answer, no
    // provider) must not keep the map hidden for good.
    if (_firstStart) {
      _startWait = Timer(_startWaitLimit, () {
        if (mounted && !_mapReady) {
          _rebuild(() => _startLocationFailed = true);
        }
      });
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

  /// Soft neutral surface while the first position is found.
  Widget _locating() => ColoredBox(
    key: ValueKey<String>('home-map-locating'),
    color: Color(0xFFEEF0F2),
    child: Align(
      alignment: Alignment(0, -0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Static on purpose: no endless animation on the map surface.
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x1F2B3036),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF8A939B),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 10),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            tr.findingYourLocation,
            style: TextStyle(
              color: Color(0xFF5F6B72),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
