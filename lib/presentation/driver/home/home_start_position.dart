part of 'home.dart';

// Where Home's map opens. The map and car wait for the driver's real
// position (saved last position, platform last fix, or first GPS fix)
// instead of opening on the city fallback and jumping.

/// Longest wait for a first position before the map opens anyway.
const Duration _startWaitLimit = Duration(seconds: 8);

extension _HomeStartPosition on _DriverHomeState {
  /// The map is built once the start position is known, or GPS failed
  /// (then it opens without a car).
  bool get _mapReady => _startPositionKnown || _startLocationFailed;

  void _restoreStartPosition() {
    final cached = DriverStartPosition.cached;
    if (cached != null) {
      _useStartPosition(cached);
      return;
    }
    // GPS that never answers (no permission answer, no provider) must not
    // keep the map hidden for good: open it without a car.
    _startWait = Timer(_startWaitLimit, () {
      if (mounted && !_mapReady) {
        _rebuild(() => _startLocationFailed = true);
      }
    });
    unawaited(
      DriverStartPosition.load().then((point) {
        if (point == null || !mounted || _startPositionKnown) {
          return;
        }
        _rebuild(() => _useStartPosition(point));
      }),
    );
  }

  void _useStartPosition(GeoPoint point) {
    _driverPosition = point.toLatLng();
    _startPositionKnown = true;
    _markers = _driverMarkers();
  }

  Set<Marker> _driverMarkers() => {
    Marker(
      markerId: const MarkerId('driver_location'),
      position: _driverPosition,
      infoWindow: InfoWindow(title: tr.mapYourCar),
      icon: _driverVehicleIcon,
      // Upright arrow; CustomGoogleMap turns it to the screen.
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
              color: Color(0xFF6B747C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
