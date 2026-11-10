part of 'accept_ride.dart';

// Base job B8 (2026-11-04): moved word for word out of accept_ride_trip.dart
// (no behaviour change).
extension _AcceptRideTripDrive on _AcceptRideState {
  void _blockedArrival() {
    // G7 live fix 3: an earlier message with an action stays until closed
    // (Flutter's SnackBar.persist) and queued this one out of sight.
    ScaffoldMessenger.of(context).clearSnackBars();
    if (_arrivalTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.thisStopNeedsVerifiedMapLocation)),
      );
      return;
    }
    if (!_arrivalDemo && !_hasLiveLocation) {
      // driver-u24: location is on but only approximate; say so.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _preciseLocationOff
                ? tr.preciseLocationOff
                : tr.locationUnavailableEnableLocationToConfirm,
          ),
          action: _preciseLocationOff
              ? SnackBarAction(
                  label: tr.settings,
                  onPressed: () =>
                      unawaited(DriverLocationService.openSettings()),
                )
              : null,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _stage == ActiveRideStage.onTrip
              ? tr.moveWithin100MOfStop
              : tr.moveWithin100MOfPickup,
        ),
        backgroundColor: _AcceptRideState._ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _confirmPickupArrival() async {
    if (_stageTransitioning ||
        !mounted ||
        _rideLifecycle.terminal ||
        _stage != ActiveRideStage.headingToPickup) {
      return;
    }

    _stageTransitioning = true;
    if (LiveDriverServices.active &&
        (!await _whileStepBusy(
              () => _AcceptRideLive(
                this,
              )._serverStep((trips) => trips.arrive(widget.tripId)),
            ) ||
            !mounted ||
            _rideLifecycle.terminal ||
            _stage != ActiveRideStage.headingToPickup)) {
      _stageTransitioning = false;
      return;
    }
    if (!await _rideLifecycle.transitionTo(ActiveRideStage.waitingForRider)) {
      _stageTransitioning = false;
      return;
    }

    _waitSeconds = 0;
    _waitAnchorAt = null;
    _startWaitTimer();
    await _rideLifecycle.persistNow();
    unawaited(
      _realtime.sendSignal(
        tripId: widget.tripId,
        kind: DriverRealtimeKind.driverArrived,
        message: tr.yourDriverHasArrivedAtPickup,
      ),
    );
    if (mounted) {
      _rebuild(() {});
    }
    _unlockStageAfterFrame();
  }

  Future<void> _freshFixForArrival() async {
    if (_liveUpdatesPaused) return;
    final epoch = _locationEpoch;
    try {
      final position = await _locationService.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) return;
      // The fix is taken at once; the road route it asks for may be slow or
      // unavailable and never holds the arrival back.
      unawaited(_applyDriverPosition(position));
    } catch (_) {
      // The usual "location unavailable" answer follows.
    }
  }

  /// driver-u23: approximate-only location never gives a usable fix, so
  /// the trip says "Precise location off" instead of "Location
  /// updating…", which would never end.
  void _locationFailed(Object error) {
    final precise = error is PreciseLocationRequiredException;
    _navigation.keepLastKnown(preciseLocationOff: precise);
    _rebuild(() {
      _preciseLocationOff = precise;
      _hasLiveLocation = false;
      _locationStatus = _navigation.status;
    });
  }

  /// D-07: what the screen shows from a fix outside the map and the
  /// island (both follow on their own). A fix that changes none of it
  /// does not rebuild the trip screen.
  Object get _fixView => (
    _nearArrivalTarget,
    _hasLiveLocation,
    _locationStatus,
    _etaLabel,
    _freshRadarLocation,
    _camera.mode,
    _camera.isGuidance,
  );

  Future<void> _applyDriverPosition(
    DriverLocation location, {
    bool forceRoute = false,
  }) async {
    if (!mounted) {
      return;
    }
    final shown = _fixView;
    if (!location.isDisplayableAt(DateTime.now())) {
      // Keep the previous car position and route; do not draw a stale fix.
      _navigation.keepLastKnown();
      _rebuild(() {
        _hasLiveLocation = false;
        _locationStatus = _navigation.status;
      });
      return;
    }
    // A far GPS outlier: keep the car, camera and route where they are.
    if (!_navigation.setVehicle(location)) {
      _confirmHeldJumpLater(location);
      return;
    }
    final next = location.point.toLatLng();

    _lastGpsAppliedAt = DateTime.now();
    _lastLocation = location;
    _driverPosition = next;
    _hasLiveLocation = location.isUsableAt(DateTime.now());
    _locationStatus = _navigation.status;

    // Camera GPS updates are independent of slow route/network requests.
    _camera.update(
      location: location,
      route: _navigation.route,
      navigating: _stage != ActiveRideStage.waitingForRider && !_paidStopWait,
      waiting: _stage == ActiveRideStage.waitingForRider || _paidStopWait,
    );
    _vehicle.moveTo(
      (_camera.vehiclePoint ?? location.point).toLatLng(),
      _camera.vehicleCourse,
    );
    _syncRouteLines();

    final lastSnap = _lastSnapshotAt;
    if (lastSnap == null ||
        DateTime.now().difference(lastSnap) > const Duration(minutes: 2)) {
      _lastSnapshotAt = DateTime.now();
      _rideLifecycle.persistNow();
    }

    if (_stage != ActiveRideStage.waitingForRider && !_paidStopWait) {
      await _refreshRoadRoute(force: forceRoute);
      await _followVehicle();
    }

    if (_stage == ActiveRideStage.onTrip) {
      _maybeScheduleOnTripRadarDemoOffer();
      _rideCheckObserve();
    }
    _AcceptRideLateEta(this)._checkLateEtaOnFirstFix();
    if (mounted && _fixView != shown) {
      _rebuild(() {});
    }
  }

  /// BrowserStack Tunis 2026-11-10: a far fix that no later fix
  /// contradicts is applied again after a short wait (the controller then
  /// takes it), instead of freezing the car until the screen reopens.
  void _confirmHeldJumpLater(DriverLocation location) {
    _heldJumpConfirm?.cancel();
    final epoch = _locationEpoch;
    _heldJumpConfirm = Timer(NavigationController.heldJumpConfirmAfter, () {
      if (!mounted ||
          _liveUpdatesPaused ||
          epoch != _locationEpoch ||
          !identical(_navigation.heldJump, location)) {
        return;
      }
      unawaited(_applyDriverPosition(location));
    });
  }

  Future<void> _refreshRoadRoute({bool force = false}) async {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return;
    }
    if (!_allowExternalRouting) {
      return;
    }
    // driver-u75: no real fix yet: _driverPosition is the placeholder, so
    // no road route from it; the first accepted fix asks for the route.
    if (_lastLocation == null) {
      return;
    }
    final target = _routeTarget;
    if (target == null) {
      _rebuild(() {
        _roadGeoPoints = [];

        _routeDurationSeconds = null;
        _locationStatus = tr.stopLocationUnavailable;
      });
      return;
    }
    final fromLiveFix = _hasLiveLocation;
    await _navigation.ensureRoute(
      origin: GeoPointMaps.fromLatLng(_driverPosition),
      destination: GeoPointMaps.fromLatLng(target),
      targetLabel:
          _stage == ActiveRideStage.onTrip &&
              _stopCursor < _stopAddresses.length
          ? tr.stopNumber(_stopCursor + 1)
          : null,
      force: force,
    );
    if (!mounted) {
      return;
    }
    _routeFromLiveFix = fromLiveFix;

    final route = _navigation.route;
    final drawn = route != null && route.points.length >= 2;
    if (drawn) {
      _rideCheckPlan(route);
    }
    // D-07: the same route and status as drawn: nothing to rebuild.
    if (_locationStatus == _navigation.status &&
        (!drawn ||
            (identical(_roadGeoPoints, route.points) &&
                _routeDurationSeconds == route.durationSeconds))) {
      return;
    }
    _rebuild(() {
      if (drawn) {
        _roadGeoPoints = route.points;

        _routeDurationSeconds = route.durationSeconds;
      }
      _locationStatus = _navigation.status;
    });
  }

  Future<void> _followVehicle({bool force = false}) async {
    final location = _lastLocation;
    if (location == null || _liveUpdatesPaused) {
      return;
    }
    _camera.update(
      location: location,
      route: _navigation.route,
      navigating: _stage != ActiveRideStage.waitingForRider && !_paidStopWait,
      waiting: _stage == ActiveRideStage.waitingForRider || _paidStopWait,
    );
    if (force) {
      _camera.recenter();
    }
  }

  /// Manual zoom collapses expanded details, retaining the rider dock.
  void _enterBrowse() {
    if (_browsing || _incomingOfferOpen) {
      return;
    }
    _rebuild(() => _browsing = true);
    _browseReturnPos = _ridePanelController.isAttached
        ? _ridePanelController.panelPosition
        : 0;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _browsePulse.repeat();
    }
    // Do not move the rider sheet while two fingers are pinching the map:
    // changing the overlay mid-gesture can interrupt/shift the zoom.
    if (_mapZoomSettle.requestCollapse()) {
      _finishBrowseSheetCollapse();
    }
  }

  Future<void> _askBeforeShortFinish() async {
    final started = _onTripStartedAt;
    final seconds = started == null
        ? 0
        : DateTime.now().difference(started).inSeconds;
    final finish = await showFinishSoonSheet(
      context,
      minutesSincePickup: (seconds / 60).ceil(),
    );
    if (finish != true || !mounted || _stage != ActiveRideStage.onTrip) {
      return;
    }
    await _completeCurrentTrip();
  }

  Future<bool> _yieldToAuthoritativeTerminal() async {
    if (!_pendingTerminal) return false;
    // Live G8 3a: the server's `completed` echo of this driver's own
    // finish (it arrives while the finish is saved) is not someone else's
    // outcome: the driver's finish goes on to the finished screen ("Din
    // andel", "Avslutad tidigt", the rating), never the generic
    // "Trip completed / OK" sheet and Home.
    final pending = _pendingProjection;
    if (_completionInFlight &&
        pending?.kind != DriverRealtimeKind.riderCancelled &&
        pending?.status == TripStatus.completed) {
      // Live G8 fix 1: kept until the local finish is saved; if that save
      // fails the server's outcome is shown instead (never stuck on the trip).
      _ownCompletionEcho = pending;
      _pendingProjection = null;
      return false;
    }
    _completionInFlight = false;
    _cancellationInFlight = false;
    _stageTransitioning = false;
    await _drainProjection();
    return true;
  }

  void _restoreOwnCompletionEcho() {
    final echo = _ownCompletionEcho;
    _ownCompletionEcho = null;
    if (echo == null || !mounted) return;
    _pendingProjection ??= echo;
    unawaited(_drainProjection());
  }
}
