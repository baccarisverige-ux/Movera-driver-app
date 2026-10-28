part of 'home.dart';

/// What runs only while Home is in view (the camera, the position feed,
/// the offer timers), and the coloured surge zones of the map (contract
/// v0.7.2 §17): the server's in a live build, the demo's own set in the
/// demo, none otherwise.
extension _HomeUpdates on _DriverHomeState {
  void _startSurgeMap() {
    final live = LiveDriverServices.instance;
    final SurgeMapSource? source = live != null
        ? live.surgeMap
        : _ownsDispatch && _dispatch is DemoDispatchRepository
        ? DemoSurgeMapSource(
            center: () =>
                GeoPoint(_driverPosition.latitude, _driverPosition.longitude),
          )
        : null;
    if (source == null) return;
    _surgeMap = SurgeMapController(source: source)
      ..addListener(_onSurgeMapChanged);
    _syncSurgeMap();
  }

  /// Online (free for offers) asks for the zones; offline shows none. The
  /// minute read runs only while Home is on screen with the app in front.
  void _syncSurgeMap() => _surgeMap?.sync(
    online: _driverSession.availableForOffers,
    onHome: _liveVisible,
  );

  void _onSurgeMapChanged() {
    if (!mounted) return;
    _rebuild(
      () => _surgePolygons = surgeZonePolygons(_surgeMap?.zones ?? const []),
    );
  }

  void _pauseHomeUpdates() {
    _syncSurgeMap();
    _camera.suspend();
    _locationEpoch++;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _radarSubscription?.cancel();
    _radarSubscription = null;
    _withdrawalSubscription?.cancel();
    _HomeOfferRadar(this)._cancelAllOfferTimers(preserveClaim: true);
    _offerSimulationTimer?.cancel();
    _directOfferTimer?.cancel();
    _expandedDirectOfferTimer?.cancel();
    _radarOfferTwoTimer?.cancel();
    _radarOfferThreeTimer?.cancel();
    _goOnlinePulseController.stop();
    _radarSweepController.stop();
    _radarMotionController.stop();
    _offerRouteFrame.stopLine();
  }

  void _resumeHomeUpdates() {
    if (!mounted || !_liveVisible) {
      return;
    }
    _camera.resume();
    _syncSurgeMap();
    unawaited(_HomeMapSheet(this)._startDriverLocation());
    _HomeMapSheet(this)._recheckDestinationLimit();
    _HomeOfferRadar(this)._scheduleVisibleOffers();
    _HomeOfferRadar(this)._resumeOfferTimers();
    _HomeOfferRules(this)._releaseHeldOffline();
    _HomeOfferRoute(this)._resumeRouteLine();
    _HomeMapSheet(this)._showNextIslandMessage();
    _HomeRadarMotion(this)._syncRadarAnimation();
    _rebuild(() {});
  }
}
