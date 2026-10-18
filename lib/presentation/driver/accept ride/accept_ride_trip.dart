part of 'accept_ride.dart';

// Trip, realtime, and navigation orchestration for AcceptRide.
// The state object still owns timers, subscriptions, and the stage.
// This extension is the only place that advances that lifecycle.

extension _AcceptRideTrip on _AcceptRideState {
    PersistedActiveRide _buildSnapshot(ActiveRideStage stage) {
      _syncWaitClock();
      final offer = _nextTripRadarOffer;
      final securedOffer =
          _onTripRadarState == _OnTripRadarState.secured ? offer : null;
      return PersistedActiveRide(
        tripId: widget.offerId,
        stage: stage,
        destinationModeActive: _destinationActive,
        destinationAddress: _destinationAddress,
        destinationPoint: _destinationPosition == null ? null : GeoPointMaps.fromLatLng(_destinationPosition!),
        nextTripId: securedOffer?.id,
        riderName: widget.riderName,
        riderRating: widget.riderRating,
        riderTrips: widget.riderTrips,
        fare: widget.fare,
        paidByCash: widget.paidByCash,
        cashToCollect: widget.cashToCollect,
        category: widget.category,
        matchedVia: widget.matchedVia,
        pickupAddress: widget.pickupAddress,
        pickupArea: widget.pickupArea,
        dropoffAddress: widget.dropoffAddress,
        stopAddresses: widget.stopAddresses,
        stopPoints: widget.stopPositions.map(GeoPointMaps.fromLatLng).toList(),
        pickupLat: widget.pickupPosition.latitude,
        pickupLng: widget.pickupPosition.longitude,
        dropoffLat: widget.dropoffPosition.latitude,
        dropoffLng: widget.dropoffPosition.longitude,
        waitSeconds: _waitSeconds,
        stopIndex: _stopCursor,
        paidStopWait: _paidStopWait,
        startedAt: _onTripStartedAt,
        next: securedOffer == null
            ? null
            : PersistedQueuedTrip(
                tripId: securedOffer.id,
                riderName: securedOffer.riderName,
                fare: securedOffer.fare,
                category: securedOffer.category,
                pickup: securedOffer.pickup,
                dropoff: securedOffer.dropoff,
                pickupLat: securedOffer.pickupPosition.latitude,
                pickupLng: securedOffer.pickupPosition.longitude,
                dropoffLat: securedOffer.dropoffPosition.latitude,
                dropoffLng: securedOffer.dropoffPosition.longitude,
                rating: securedOffer.rating,
                pickupMinutes: securedOffer.pickupMinutes,
                tripMinutes: securedOffer.tripMinutes,
              ),
      );
    }
    void _restoreQueuedNextFromSnapshot() {
      final next = widget.restoredSnapshot?.next;
      if (next == null) { return; }
      _onTripRadarState = _OnTripRadarState.secured;
      _nextTripRadarOffer = _NextTripRadarOffer(
        id: next.tripId,
        category: next.category,
        fare: next.fare,
        rating: next.rating,
        pickupMinutes: next.pickupMinutes,
        tripMinutes: next.tripMinutes,
        riderName: next.riderName,
        pickup: next.pickup,
        dropoff: next.dropoff,
        pickupPosition: LatLng(next.pickupLat, next.pickupLng),
        dropoffPosition: LatLng(next.dropoffLat, next.dropoffLng),
      );
    }
    void _resumeStageSideEffects() {
      if (_countingWait) { _startWaitTimer(); }
      switch (_stage) {
        case ActiveRideStage.headingToPickup:
          return;
        case ActiveRideStage.waitingForRider:
          unawaited(_focusWaitingPickup());
        case ActiveRideStage.onTrip:
          _rideCheckDetector.startTrip(_rideCheckNow);
          _demoDrive?.startTrip();
          if (_onTripRadarState != _OnTripRadarState.secured) {
            _startOnTripRadar();
          }
          unawaited(_refreshOnTripRoute(fitCamera: true));
      }
    }
    void _pauseLiveUpdates() {
      _camera.suspend();
      if (_liveUpdatesPaused) { return; }
      _syncWaitClock();
      _waitTimer?.cancel();
      _liveUpdatesPaused = true;
      _locationEpoch++;
      _hasLiveLocation = false;
      _positionSubscription?.cancel();
      _positionSubscription = null;
      if (_radarPulseController.isAnimating) {
        _radarPulseController.stop();
      }
      if (_radarSweepController.isAnimating) {
        _radarSweepController.stop();
      }
    }
    void _resumeLiveUpdates() {
      if (!_liveUpdatesPaused) { return; }
      _liveUpdatesPaused = false;
      if (_countingWait) {
        _syncWaitClock();
        _startWaitTimer();
        _rebuild(() {});
      }
      _camera.resume();
      if (!MediaQuery.disableAnimationsOf(context) && !_radarPulseController.isAnimating) {
        _radarPulseController.repeat(reverse: true);
      }
      if (!MediaQuery.disableAnimationsOf(context) && !_radarSweepController.isAnimating) {
        _radarSweepController.repeat();
      }
      unawaited(_startLiveLocation());
    }
    WaybillRecord _buildCurrentWaybill() {
      return WaybillRecord(
        tripId: widget.offerId,
        statusLabel: 'Current trip',
        issuedAt: DateTime.now(),
        fare: widget.fare,
        service: widget.category,
        riderName: widget.riderName,
        pickup: widget.pickupAddress,
        dropoff: widget.dropoffAddress,
        source: widget.matchedVia,
        driverName: 'Movera Driver',
        vehicle: _vehicleLabel,
        licensePlate: _vehiclePlate,
        passengerCapacity: 4,
      );
    }
    /// Waybills show the same vehicle as Profile and Vehicles.
    Future<void> _loadVehicleIdentity() async {
      final identity = await LocalVehicleStore().primaryIdentity();
      if (!mounted || identity == null) { return; }
      _vehicleLabel = identity.vehicle;
      _vehiclePlate = identity.plate;
      for (final (record, apply) in [
        (_waybills.current, _waybills.beginCurrent),
        (_waybills.next, _waybills.secureNext),
      ]) {
        if (record != null &&
            record.vehicle != _vehicleLabel &&
            (record.tripId == widget.offerId || record.tripId == _nextTripRadarOffer?.id)) {
          apply(record.copyWith(vehicle: _vehicleLabel, licensePlate: _vehiclePlate));
        }
      }
    }
    WaybillRecord _buildNextWaybill(_NextTripRadarOffer offer) {
      return WaybillRecord(
        tripId: offer.id,
        statusLabel: 'Next trip secured',
        issuedAt: DateTime.now(),
        fare: offer.fare,
        service: offer.category,
        riderName: offer.riderName,
        pickup: offer.pickup,
        dropoff: offer.dropoff,
        source: 'Exclusive offer',
        driverName: 'Movera Driver',
        vehicle: _vehicleLabel,
        licensePlate: _vehiclePlate,
        passengerCapacity: 4,
      );
    }
    LatLng? _stopPoint(int index) {
      if (index < 0 || index >= widget.stopPositions.length) { return null; }
      return widget.stopPositions[index];
    }
    void _syncNavigationStage() {
      _navigation.setStage(_rideLifecycle.stage);
      unawaited(_followVehicle());
    }
    void _onRealtimeEvent(DriverRealtimeEvent event) {
      if (!mounted || event.tripId != widget.offerId) { return; }

      final disposition = _realtimeGate.evaluate(event);
      if (disposition == DriverRealtimeDisposition.staleOrDuplicate ||
          disposition == DriverRealtimeDisposition.blockedAfterTerminal) {
        return;
      }

      if (disposition == DriverRealtimeDisposition.acceptedWithGap) {
        unawaited(_resyncTrip());
      }
      if (event.status != null || event.kind == DriverRealtimeKind.riderCancelled) {
        _pendingProjection = event;
        unawaited(_drainProjection());
        return;
      }

      switch (event.kind) {
        case DriverRealtimeKind.riderOnTheWay:
          if (_rideLifecycle.terminal) { return; }
          _rebuild(() => _riderOnTheWay = true);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                event.message?.trim().isNotEmpty == true
                    ? event.message!
                    : '${widget.riderName} is on the way',
              ),
              backgroundColor: _AcceptRideState._ink,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        case DriverRealtimeKind.riderCancelled:
          unawaited(_handleRiderCancelled());
        case DriverRealtimeKind.tripProjection:
        case DriverRealtimeKind.location:
        case DriverRealtimeKind.driverArrived:
          return;
      }
    }
    Future<void> _resyncTrip() async {
      try { await _realtime.reconnectAndResync(widget.offerId); }
      catch (_) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Trip updates could not be refreshed.'),
          action: SnackBarAction(label: 'Retry', onPressed: () => unawaited(_resyncTrip())))); }
      }
    }
    Future<void> _drainProjection() async {
      if (!mounted || _drainingProjection || _pendingProjection == null) { return; }
      if (_rideLifecycle.saving || _completionInFlight || _cancellationInFlight || _stageTransitioning) {
        _projectionRetry ??= Timer(const Duration(milliseconds: 100), () {
          _projectionRetry = null; unawaited(_drainProjection());
        });
        return;
      }
      _drainingProjection = true;
      final event = _pendingProjection!;
      final status = event.kind == DriverRealtimeKind.riderCancelled ? TripStatus.cancelledByRider : event.status!;
      try {
        if (status == TripStatus.cancelledByRider) {
          await _handleRiderCancelled();
        } else if (status.isTerminal) {
          final secured = _onTripRadarState == _OnTripRadarState.secured ? _nextTripRadarOffer : null;
          final next = secured == null ? null : _snapshotForOffer(secured);
          await CompletionJournal(active: widget.activeRideRepository ?? MemoryActiveRideRepository()).finish(
            _waybills.current ?? _buildCurrentWaybill(), status: status, authoritative:true, next:next);
          if (!mounted) { return; }
          if (!await _rideLifecycle.applyProjection(status)) { return; }
          if (identical(event, _pendingProjection)) { _pendingProjection = null; }
          _projectionRetryDelay = _AcceptRideState._projectionRetryBase;
          await _leaveAfterAuthoritativeOutcome(status, next);
          return;
        } else {
          if (!await _rideLifecycle.applyProjection(status)) { return; }
          if (mounted) { _rebuild(() {}); _resumeStageSideEffects(); }
        }
        if (status == TripStatus.cancelledByRider && !_rideLifecycle.terminal) {
          _scheduleProjectionRetry();
          return;
        }
        if (identical(event, _pendingProjection)) { _pendingProjection = null; }
        _projectionRetryDelay = _AcceptRideState._projectionRetryBase;
      } catch (_) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Trip update could not be saved. Retrying automatically.'),
          action: SnackBarAction(label: 'Retry now', onPressed: () => unawaited(_drainProjection())))); }
        _scheduleProjectionRetry();
      } finally { _drainingProjection = false; }
    }
    /// An authoritative terminal outcome must not depend on the driver seeing
    /// a SnackBar. Retry with bounded backoff until it is applied.
    void _scheduleProjectionRetry() {
      if (!mounted || _pendingProjection == null || _projectionRetry != null) { return; }
      final delay = _projectionRetryDelay;
      _projectionRetryDelay = delay * 2 > _AcceptRideState._projectionRetryMax
          ? _AcceptRideState._projectionRetryMax
          : delay * 2;
      _projectionRetry = Timer(delay, () {
        _projectionRetry = null;
        unawaited(_drainProjection());
      });
    }
    /// Shared exit for every authoritative terminal outcome: same timers,
    /// waybill, session and queued-trip handoff as driver completion.
    Future<void> _leaveAfterAuthoritativeOutcome(TripStatus status, PersistedActiveRide? next) async {
      _waitTimer?.cancel();
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      _pauseLiveUpdates();
      _waybills.discardCurrent();
      await showTripOutcomeSheet(context, status: status, hasNext: next != null);
      if (!mounted) { return; }
      widget.sessionController?.stayOnlineAfterTrip();
      if (next != null) {
        _waybills.promoteNextToCurrent();
        Navigator.of(context).pushReplacement(BottomToTopTransition(AcceptRide.fromPersisted(next,
          waybillRepository:_waybills,sessionController:widget.sessionController,
          locationRepository:widget.locationRepository,routeRepository:widget.routeRepository,
          activeRideRepository:widget.activeRideRepository)));
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) { navigator.pop(); }
    }
    Future<void> _handleRiderCancelled() async {
      if (!mounted ||
          _handlingRiderCancellation) {
        return;
      }

      _handlingRiderCancellation = true;
      final wasOnTrip = _stage == ActiveRideStage.onTrip;

      if (_completionInFlight || _cancellationInFlight) { _handlingRiderCancellation=false; return; }
      final secured = _onTripRadarState == _OnTripRadarState.secured ? _nextTripRadarOffer : null;
      final next = secured == null ? null : _snapshotForOffer(secured);
      try {
        await CompletionJournal(active: widget.activeRideRepository ?? MemoryActiveRideRepository()).finish(
          _waybills.current ?? _buildCurrentWaybill(),
          status: TripStatus.cancelledByRider,
          authoritative:true,
          cancellationReasonCode: 'rider_cancelled',
          cancellationActor: 'rider',
          next: next);
        if (!mounted) { return; }
        if (!await _rideLifecycle.applyProjection(TripStatus.cancelledByRider)) {
          _handlingRiderCancellation=false; return;
        }
      } catch (_) {
        _handlingRiderCancellation=false;
        if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not save rider cancellation. Retry.'),
          action: SnackBarAction(label:'Retry',onPressed:(){ _handleRiderCancelled(); }))); }
        return;
      }
      if(!mounted) { return; }
      _waitTimer?.cancel();
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      _pauseLiveUpdates();

      _waybills.discardCurrent();

      // Back to Home when it is underneath: its island tells the driver.
      final home = Navigator.of(context);
      if (next == null && home.canPop()) {
        IslandMessages.show(wasOnTrip
            ? HomeIslandNotices.riderEndedTrip
            : HomeIslandNotices.riderCancelled);
        widget.sessionController?.stayOnlineAfterTrip();
        home.pop();
        return;
      }

      await showRiderCancelledSheet(
        context,
        riderName: widget.riderName,
        wasOnTrip: wasOnTrip,
      );
      if (!mounted) { return; }

      widget.sessionController?.stayOnlineAfterTrip();
      if(next!=null) {
        _waybills.promoteNextToCurrent();
        Navigator.of(context).pushReplacement(BottomToTopTransition(AcceptRide.fromPersisted(next,
          waybillRepository:_waybills,sessionController:widget.sessionController,
          locationRepository:widget.locationRepository,routeRepository:widget.routeRepository,
          activeRideRepository:widget.activeRideRepository)));
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    void _onPersistenceChanged() {
      if (!mounted || _rideLifecycle.persistenceError == null) { return; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Trip progress could not be saved. Keep this screen open and retry.'),
        action: SnackBarAction(label: 'Retry', onPressed: () { _rideLifecycle.persistNow(); }),
      ));
    }
    void _blockedArrival() {
      if (_arrivalTarget == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This stop needs a verified map location before arrival.'),
        ));
        return;
      }
      if (!_arrivalDemo && !_hasLiveLocation) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location unavailable. Enable location to confirm arrival.'),
        ));
        return;
      }
      final where = _stage == ActiveRideStage.onTrip ? 'stop' : 'pickup';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Move within 100 m of the $where to arrive.'),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    Future<void> _onArrivedTap() async {
      if (!_nearArrivalTarget) {
        _blockedArrival();
        return;
      }
      if (_stage == ActiveRideStage.headingToPickup) {
        await _confirmPickupArrival();
        return;
      }
      if (_stage == ActiveRideStage.onTrip &&
          !_paidStopWait &&
          _stopCursor < widget.stopAddresses.length) {
        _paidStopWait = true;
        _waitSeconds = 0;
        _waitAnchorAt = null;
        _startWaitTimer();
        await _rideLifecycle.persistNow();
        if (mounted) { _rebuild(() {}); }
      }
    }
    Future<void> _confirmPickupArrival() async {
      if (_stageTransitioning ||
          !mounted ||
          _rideLifecycle.terminal ||
          _stage != ActiveRideStage.headingToPickup) {
        return;
      }

      _stageTransitioning = true;
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
          tripId: widget.offerId,
          kind: DriverRealtimeKind.driverArrived,
          message: 'Your driver has arrived at the pickup point.',
        ),
      );
      if (mounted) { _rebuild(() {}); }
      _unlockStageAfterFrame();
    }
    void _onNavigationChanged() {
      if (!mounted || _stageTransitioning) { return; }
      final route = _navigation.route;
      final status = _navigation.status;
      final pointsChanged = route != null &&
          route.points.length >= 2 &&
          !identical(_roadGeoPoints, route.points);
      final mappedRoute = route;
      final routeCleared = route == null && _roadGeoPoints.isNotEmpty;
      if (!routeCleared && !pointsChanged && status == _locationStatus) { return; }
      if (pointsChanged && mappedRoute != null) { _rideCheckPlan(mappedRoute); }
      _rebuild(() {
        if (pointsChanged && mappedRoute != null) {
          _roadGeoPoints = mappedRoute.points;

          _routeDurationSeconds = mappedRoute.durationSeconds;
        }
        if (routeCleared) { _roadGeoPoints = []; _routeDurationSeconds = null; }
        _locationStatus = status;
      });
    }
    Future<void> _prepareDriverVehicleMarker() async {
      final icon = await MoveraVehicleMarker.createIcon();
      final pins = {
        for (final kind in RouteMarkKind.values) kind: await RouteMarkPins.pin(kind),
      };
      if (!mounted) { return; }
      _rebuild(() {
        _driverVehicleIcon = icon;
        _pinIcons = pins;
      });
    }
    Future<void> _startLiveLocation() async {
      final epoch = ++_locationEpoch;
      if (_liveUpdatesPaused) { return; }
      try {
        final position = await _locationService.getCurrentPosition();
        if (!mounted) { return; }

        if (_liveUpdatesPaused || epoch != _locationEpoch) { return; }
        // Subscribe before routing: fresh GPS must remain usable even when
        // the first road-route request is slow or never resolves.
        _positionSubscription?.cancel();
        _positionSubscription = _locationService
            .watchPosition(distanceFilterMeters: 0)
            .listen(
          (position) {
            if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) { return; }
            _applyDriverPosition(position);
          },
          onError: (Object error) {
            if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) { return; }
            _navigation.keepLastKnown(status: 'Location updating…');
            _rebuild(() {
              _hasLiveLocation = false;
              _locationStatus = 'Location updating…';
            });
          },
        );
        await _applyDriverPosition(position, forceRoute: true);
      } catch (_) {
        if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) { return; }
        _navigation.keepLastKnown(status: 'Location updating…');
        _rebuild(() {
          _hasLiveLocation = false;
          _locationStatus = 'Location updating…';
        });
        unawaited(_refreshRoadRoute(force: true));
      }
    }
    Future<void> _applyDriverPosition(
      DriverLocation location, {
      bool forceRoute = false,
    }) async {
      if (!mounted) { return; }
      if (!location.isDisplayableAt(DateTime.now())) {
        // Keep the previous car position and route; do not draw a stale fix.
        _navigation.keepLastKnown(status: 'Location updating…');
        _rebuild(() {
          _hasLiveLocation = false;
          _locationStatus = 'Location updating…';
        });
        return;
      }
      final next = location.point.toLatLng();

      _lastGpsAppliedAt = DateTime.now();
      _lastLocation = location;

      _navigation.setVehicle(location);
      _driverPosition = next;
      _hasLiveLocation = location.isUsableAt(DateTime.now());
      _locationStatus = _navigation.status;

      // Camera GPS updates are independent of slow route/network requests.
      _camera.update(location: location, route: _navigation.route,
        navigating: _stage != ActiveRideStage.waitingForRider && !_paidStopWait,
        waiting: _stage == ActiveRideStage.waitingForRider || _paidStopWait);
      _vehicle.moveTo((_camera.vehiclePoint ?? location.point).toLatLng(),
          _camera.vehicleCourse);

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
    }
    Future<void> _refreshRoadRoute({bool force = false}) async {
      if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) { return; }
      if (!_allowExternalRouting) { return; }

      final target = _routeTarget;
      if (target == null) {
        _rebuild(() {
          _roadGeoPoints = [];

          _routeDurationSeconds = null;
          _locationStatus = 'Stop location unavailable';
        });
        return;
      }
      await _navigation.ensureRoute(
        origin: GeoPointMaps.fromLatLng(_driverPosition),
        destination: GeoPointMaps.fromLatLng(target),
        targetLabel: _stage == ActiveRideStage.onTrip && _stopCursor < widget.stopAddresses.length ? 'Stop ${_stopCursor + 1}' : null,
        force: force,
      );
      if (!mounted) { return; }

      final route = _navigation.route;
      if (route != null && route.points.length >= 2) { _rideCheckPlan(route); }
      _rebuild(() {
        if (route != null && route.points.length >= 2) {
          _roadGeoPoints = route.points;

          _routeDurationSeconds = route.durationSeconds;
        }
        _locationStatus = _navigation.status;
      });
    }
    Future<void> _followVehicle({bool force = false}) async {
      final location = _lastLocation;
      if (location == null || _liveUpdatesPaused) { return; }
      _camera.update(location: location, route: _navigation.route,
        navigating: _stage != ActiveRideStage.waitingForRider && !_paidStopWait,
        waiting: _stage == ActiveRideStage.waitingForRider || _paidStopWait);
      if (force) { _camera.recenter(); }
    }
    void _onCameraMove(CameraPosition position) {
      _cameraPort?.onMove(position);
      final step = DriverRouteStyle.stepZoom(position.zoom);
      if (step != _routeZoomStep) { _rebuild(() => _routeZoomStep = step); }
      // A native +/- control zoom has no Flutter pinch/wheel pointer signal.
      // Observe SDK zoom *deltas*, but only after physical input has already
      // transferred the camera to manual Browse. Pan-only moves stay quiet.
      final browsing = _camera.mode == DriverCameraMode.browsing;
      final zoomChanged = _manualZoomDetector.observe(
        position.zoom, browsing: browsing,
      );
      if (!browsing) { return; }
      final zoom = _lastMapZoom;
      if (zoomChanged || _mapPointers >= 2 || (zoom != null &&
          DateTime.now().difference(zoom) < const Duration(milliseconds: 700))) {
        _enterBrowse();
      }
    }
    /// Manual zoom collapses expanded details, retaining the rider dock.
    void _enterBrowse() {
      if (_browsing || _incomingOfferOpen) { return; }
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
    void _exitBrowse() {
      // The recenter tap itself reaches the map, and the camera then flies
      // back: neither is the driver browsing.
      _mapZoomSettle.cancel();
      _lastMapZoom = null;
      _navigation.resumeFollow();
      _camera.recenter();
      unawaited(_followVehicle());
      _browsePulse
        ..stop()
        ..value = 0;
      if (!_browsing) { _rebuild(() {}); return; }
      _rebuild(() => _browsing = false);
      if (_browseReturnPos > 0.001) {
        unawaited(_snapSheet.springTo(_browseReturnPos));
      }
    }
    Future<void> _fitRoute() async {
      // Starting/changing a leg updates route context without stealing a
      // manually browsed viewport. Recenter is the sole manual resume action.
      await _followVehicle();
    }
    /// Q24 / R8-4: shows the cash to collect; "Finish {category}" there
    /// completes it.
    Future<void> _collectCash() async {
      if (!_collectsCashNow || _stageTransitioning || _rideLifecycle.terminal) { return; }
      final complete = await showCashCollectSheet(
        context,
        fare: widget.fare,
        cash: _cashToCollect,
        riderName: widget.riderName,
        category: widget.category,
      );
      if (!complete || !mounted || !_collectsCashNow) { return; }
      await _advanceRide();
    }
    Future<void> _advanceRide() async {
      if (_stageTransitioning || !mounted || _rideLifecycle.terminal) { return; }

      _stageTransitioning = true;

      switch (_stage) {
        case ActiveRideStage.headingToPickup:
          _stageTransitioning = false;
          return;

        case ActiveRideStage.waitingForRider:
          if (!await _rideLifecycle.transitionTo(ActiveRideStage.onTrip)) {
            _stageTransitioning = false;
            return;
          }
          _waitTimer?.cancel();
          _paidStopWait = false;
          _stopCursor = 0;
          _nextTripRadarDemoTimer?.cancel();
          _nextTripRadarMatchTimer?.cancel();
          _onTripStartedAt = DateTime.now();
          _rideCheckDetector.startTrip(_rideCheckNow);
          _demoDrive?.startTrip();
          await _rideLifecycle.persistNow();
          _onTripRadarState = _OnTripRadarState.scanning;
          _nextTripRadarOffer = null;
          if (mounted) { _rebuild(() {}); }
          _maybeScheduleOnTripRadarDemoOffer();
          _unlockStageAfterFrame();
          unawaited(_refreshOnTripRoute());
          return;

        case ActiveRideStage.onTrip:
          if (_paidStopWait) {
            _paidStopWait = false;
            _waitTimer?.cancel();
            _stopCursor += 1;
            await _rideLifecycle.persistNow();
            _stageTransitioning = false;
            if (mounted) { _rebuild(() {}); }
            unawaited(_refreshOnTripRoute());
            return;
          }
          if (_stopCursor < widget.stopAddresses.length) {
            _stageTransitioning = false;
            return;
          }
          final farDrop = _rideCheckFarDrop();
          if (farDrop != null) {
            // Ask first; the trip finishes once the driver has answered.
            _stageTransitioning = false;
            await _rideCheck.open(farDrop, instant: MediaQuery.disableAnimationsOf(context));
            if (!mounted || _stage != ActiveRideStage.onTrip || _rideLifecycle.terminal) { return; }
            _stageTransitioning = true;
          }
          // A far-drop check already asked the driver about the finish.
          if (_tripEndedTooQuickly && farDrop == null) {
            _stageTransitioning = false;
            await _askBeforeShortFinish();
            return;
          }
          await _completeCurrentTrip();
          return;
      }
    }
    Future<void> _askBeforeShortFinish() async {
      final finish = await showMoveraModalSheet<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        heightFactor: 0.5,
        builder: (sheetContext) {
          return MoveraModalSheet(
            key: const ValueKey<String>('short-trip-finish-sheet'),
            heightFactor: 0.5,
            color: Colors.white,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This ride just started',
                    style: TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Expanded(
                    child: Text(
                      'Very little time has passed since pickup. Go back if the rider is still with you, or confirm that the trip is finished.',
                      style: TextStyle(
                        color: _AcceptRideState._muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => popOwned(sheetContext, false),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _AcceptRideState._ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Go back to the ride',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => popOwned(sheetContext, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AcceptRideState._ink,
                        side: const BorderSide(color: Color(0xFFD5DCDF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Confirm finish',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (finish != true || !mounted || _stage != ActiveRideStage.onTrip) { return; }
      await _completeCurrentTrip();
    }
    Future<bool> _yieldToAuthoritativeTerminal() async {
      if(!_pendingTerminal) return false;
      _completionInFlight=false;_cancellationInFlight=false;_stageTransitioning=false;
      await _drainProjection();
      return true;
    }
    Future<void> _completeCurrentTrip() async {
      if (_completionInFlight || _cancellationInFlight || _handlingRiderCancellation || !mounted || _rideLifecycle.terminal) { return; }
      _completionInFlight = true;
      _stageTransitioning = true;
      final offer = _nextTripRadarOffer;
      final queuedNext = _onTripRadarState == _OnTripRadarState.secured && offer != null;
      final next = queuedNext ? _snapshotForOffer(offer) : null;
      try {
        await CompletionJournal(active: widget.activeRideRepository ?? MemoryActiveRideRepository()).finish(
          _waybills.current ?? _buildCurrentWaybill(), next: next,
          paymentMethod: widget.paidByCash ? 'Cash' : null,
          cashCollected: widget.paidByCash ? _cashToCollect : null);
        if (!mounted) { return; }
        if (await _yieldToAuthoritativeTerminal()) return;
        if (!await _rideLifecycle.complete(clearSnapshot: false)) {
          _completionInFlight = false; _stageTransitioning = false; return;
        }
      } catch (error, stack) {
        DriverLog.error('Trip completion journal failed', error, stack);
        _completionInFlight = false; _stageTransitioning = false;
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not finish saving this trip. Retry completion; the receipt will not duplicate.'))); }
        return;
      }
      _waitTimer?.cancel();
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      if(!mounted) { return; }
      _waybills.completeCurrent();
      final nextRide = queuedNext
          ? AcceptRide(
              offerId: offer.id,
              riderName: offer.riderName,
              riderRating: offer.rating,
              fare: offer.fare,
              category: offer.category,
              matchedVia: 'Exclusive offer',
              pickupAddress: offer.pickup,
              pickupArea: offer.pickup.split(',').last.trim(),
              dropoffAddress: offer.dropoff,
              pickupPosition: offer.pickupPosition,
              dropoffPosition: offer.dropoffPosition,
              locationRepository: widget.locationRepository,
              routeRepository: widget.routeRepository,
              waybillRepository: _waybills,
              sessionController: widget.sessionController,
              activeRideRepository: widget.activeRideRepository,
              destinationModeActive: _destinationActive,
              destinationAddress: _destinationAddress,
              destinationPosition: _destinationPosition,
            )
          : null;
      Navigator.of(context).pushReplacement(
        BottomToTopTransition(
          DriverRideCompleted(
            waybillRepository: _waybills,
            sessionController: widget.sessionController,
            activeRideRepository: widget.activeRideRepository,
            nextRide: nextRide,
            paymentMethod: widget.paidByCash ? 'Cash' : 'Card',
          ),
        ),
      );
    }
    PersistedActiveRide _snapshotForOffer(_NextTripRadarOffer offer) => PersistedActiveRide(
      tripId: offer.id, stage: ActiveRideStage.headingToPickup,
        destinationModeActive: _destinationActive,
        destinationAddress: _destinationAddress,
        destinationPoint: _destinationPosition == null ? null : GeoPointMaps.fromLatLng(_destinationPosition!), riderName: offer.riderName,
      riderRating: offer.rating, fare: offer.fare, category: offer.category, matchedVia: 'Exclusive offer',
      pickupAddress: offer.pickup, dropoffAddress: offer.dropoff,
      pickupLat: offer.pickupPosition.latitude, pickupLng: offer.pickupPosition.longitude,
      dropoffLat: offer.dropoffPosition.latitude, dropoffLng: offer.dropoffPosition.longitude);
    void _unlockStageAfterFrame() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stageTransitioning = false;
      });
    }
    Future<void> _refreshOnTripRoute({bool fitCamera = false}) async {
      await _refreshRoadRoute(force: true);
      if (!mounted || _stage != ActiveRideStage.onTrip) { return; }
      if (fitCamera) {
        await _fitRoute();
      }
    }
    Future<void> _focusWaitingPickup() async {
      await _followVehicle();
    }
    void _startOnTripRadar() {
      if (_onTripRadarState == _OnTripRadarState.stopped) { return; }
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();

      if (!mounted || _stage != ActiveRideStage.onTrip) { return; }

      _rebuild(() {
        _onTripRadarState = _OnTripRadarState.scanning;
        _nextTripRadarOffer = null;
      });

      _maybeScheduleOnTripRadarDemoOffer();
    }
    void _toggleOnTripRadar() {
      if (_stage != ActiveRideStage.onTrip) { return; }
      if (_onTripRadarState == _OnTripRadarState.secured) { return; }
      if (_onTripRadarOn) {
        _stopOnTripRadar();
        return;
      }
      _onTripRadarDeclined = false;
      _rebuild(() => _onTripRadarState = _OnTripRadarState.off);
      _startOnTripRadar();
    }
    bool _dropoffFollowsDestination(LatLng dropoff) {
      if (!_destinationActive) { return true; }
      final destination = _destinationPosition;
      if (destination == null) { return true; }

      final latitudeRadians = _driverPosition.latitude * math.pi / 180;
      final longitudeScale = math.cos(latitudeRadians);
      final destinationX =
          (destination.longitude - _driverPosition.longitude) * longitudeScale;
      final destinationY = destination.latitude - _driverPosition.latitude;
      final offerX = (dropoff.longitude - _driverPosition.longitude) * longitudeScale;
      final offerY = dropoff.latitude - _driverPosition.latitude;
      final destinationLength = math.sqrt(
        destinationX * destinationX + destinationY * destinationY,
      );
      final offerLength = math.sqrt(offerX * offerX + offerY * offerY);
      if (destinationLength == 0 || offerLength == 0) { return true; }
      final cosine = (destinationX * offerX + destinationY * offerY) /
          (destinationLength * offerLength);
      return cosine >= 0.45;
    }
    _NextTripRadarOffer _onTripRadarOfferForDestination() {
      if (!_destinationActive) { return _uniqueDemoNext; }
      final destination = _destinationPosition;
      if (destination == null) { return _uniqueDemoNext; }
      final address = _destinationAddress?.trim();
      return _NextTripRadarOffer(
        id: '${widget.offerId}-next-destination',
        category: _AcceptRideState._demoNextTripOffer.category,
        fare: _AcceptRideState._demoNextTripOffer.fare,
        rating: _AcceptRideState._demoNextTripOffer.rating,
        pickupMinutes: _AcceptRideState._demoNextTripOffer.pickupMinutes,
        pickupKm: _AcceptRideState._demoNextTripOffer.pickupKm,
        tripMinutes: _AcceptRideState._demoNextTripOffer.tripMinutes,
        riderName: _AcceptRideState._demoNextTripOffer.riderName,
        pickup: _AcceptRideState._demoNextTripOffer.pickup,
        dropoff: address == null || address.isEmpty
            ? 'Along your destination'
            : address,
        pickupPosition: _AcceptRideState._demoNextTripOffer.pickupPosition,
        dropoffPosition: destination,
      );
    }
    void _stopOnTripRadar() {
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      _nextTripOfferExpiry?.cancel();
      if (!mounted || _stage != ActiveRideStage.onTrip) { return; }
      if (_onTripRadarState == _OnTripRadarState.secured) { return; }
      _rebuild(() {
        _onTripRadarState = _OnTripRadarState.stopped;
        _nextTripRadarOffer = null;
      });
    }
    void _maybeScheduleOnTripRadarDemoOffer() {
      // Q18: while driving a rider only Exclusive offers come, when admin
      // allows them; never Radar trips.
      if (!DriverOfferRules.current.exclusiveWhileDriving ||
          DriverOfferRules.current.exclusiveWhileDrivingCount < 1) {
        return;
      }
      if (!mounted ||
          _stage != ActiveRideStage.onTrip ||
          _onTripRadarState != _OnTripRadarState.scanning ||
          _onTripRadarDeclined ||
          (_nextTripRadarDemoTimer?.isActive ?? false)) {
        return;
      }

      // Offers are explicitly simulated. A future live adapter must pass the freshness gate.
      if (_hasLiveLocation) {
        final metersToDropoff =
            GeoPointMaps.fromLatLng(_driverPosition).distanceMetersTo(
          GeoPointMaps.fromLatLng(widget.dropoffPosition),
        );
        if (metersToDropoff > _AcceptRideState._nextTripRadarRadiusMeters) { return; }
      }

      _nextTripRadarDemoTimer = Timer(
        const Duration(milliseconds: 2200),
        () {
          if (!mounted ||
              _stage != ActiveRideStage.onTrip ||
              _onTripRadarState != _OnTripRadarState.scanning) {
            return;
          }

          // R10-2: a Ride check is open; the offer waits for the answer.
          if (RideCheckGate.open) {
            _nextTripOfferHeldAt ??= DateTime.now();
            return;
          }
          _presentOnTripOffer();
        },
      );
    }
    void _presentOnTripOffer() {
      _rebuild(() {
        final offer = _onTripRadarOfferForDestination();
        if (!_dropoffFollowsDestination(offer.dropoffPosition)) { return; }
        _nextTripRadarOffer = offer;
        _onTripRadarState = _OnTripRadarState.offerAvailable;
      });
      _armOnTripOfferExpiry();
      _hideRideSheetForOffer();
    }
    /// R10-2: no next-trip offer while the Ride check is open. One already
    /// up steps back and waits; after the answer a waiting offer comes back
    /// if its time has not passed, otherwise it drops and Radar goes on.
    void _onRideCheckGate() {
      if (!mounted || _stage != ActiveRideStage.onTrip) {
        _nextTripOfferHeldAt = null;
        return;
      }
      if (RideCheckGate.open) {
        if (_onTripRadarState != _OnTripRadarState.offerAvailable) { return; }
        _nextTripOfferExpiry?.cancel();
        _nextTripOfferHeldAt = DateTime.now();
        _rebuild(() {
          _nextTripRadarOffer = null;
          _onTripRadarState = _OnTripRadarState.scanning;
        });
        _restoreRideSheet();
        return;
      }
      final heldAt = _nextTripOfferHeldAt;
      if (heldAt == null) { return; }
      _nextTripOfferHeldAt = null;
      if (_onTripRadarState != _OnTripRadarState.scanning || _onTripRadarDeclined) { return; }
      if (DateTime.now().difference(heldAt) >= _AcceptRideState._onTripOfferLifetime) {
        _maybeScheduleOnTripRadarDemoOffer();
        return;
      }
      _presentOnTripOffer();
    }
    void _armOnTripOfferExpiry() {
      _nextTripOfferExpiry?.cancel();
      if (_onTripRadarState != _OnTripRadarState.offerAvailable) { return; }
      _nextTripOfferExpiry = Timer(_AcceptRideState._onTripOfferLifetime, () {
        if (!mounted || _onTripRadarState != _OnTripRadarState.offerAvailable) {
          return;
        }
        _denyNextTripRadar();
      });
    }
    void _hideRideSheetForOffer() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ridePanelController.isAttached) { return; }
        if (_onTripRadarState == _OnTripRadarState.offerAvailable) {
          _ridePanelController.close();
        }
      });
    }
    void _restoreRideSheet() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ridePanelController.isAttached) { return; }
        // The trip sheet always rests down; the driver lifts it.
        unawaited(_ridePanelController.close());
      });
    }
    void _acceptNextTripRadar() {
      final offer = _nextTripRadarOffer;
      if (offer == null || _stage != ActiveRideStage.onTrip) { return; }
      if (_onTripRadarState == _OnTripRadarState.secured ||
          _onTripRadarState == _OnTripRadarState.matching) {
        return;
      }
      _rebuild(() => _onTripRadarState = _OnTripRadarState.matching);
      ExclusiveAnswers.instance.accepted();
      _nextTripOfferExpiry?.cancel();
      _restoreRideSheet();
      _nextTripRadarMatchTimer?.cancel();
      _nextTripRadarMatchTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || _stage != ActiveRideStage.onTrip) { return; }
        _rebuild(() => _onTripRadarState = _OnTripRadarState.secured);
        _waybills.secureNext(_buildNextWaybill(offer));
        _rideLifecycle.persistNow();
      });
    }
    void _denyNextTripRadar() {
      if (_stage != ActiveRideStage.onTrip) { return; }
      if (_onTripRadarState == _OnTripRadarState.secured ||
          _onTripRadarState == _OnTripRadarState.matching) {
        return;
      }
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      _nextTripOfferExpiry?.cancel();
      _rebuild(() {
        _onTripRadarDeclined = true;
        _nextTripRadarOffer = null;
        _onTripRadarState = _OnTripRadarState.scanning;
      });
      _restoreRideSheet();
      // Q16: a declined or missed Exclusive offer counts; at the admin's
      // number in a row the driver goes offline after this trip.
      if (ExclusiveAnswers.instance.missed()) {
        widget.sessionController?.setOnline(false);
        IslandMessages.show(HomeIslandNotices.offlineAfterMissed(
          DriverOfferRules.current.autoOfflineAfter,
        ));
      }
    }
    void _startWaitTimer() {
      _waitTimer?.cancel();
      _syncWaitClock();
      _waitAnchorAt = widget.waitNow?.call() ?? DateTime.now();
      _waitAnchorSeconds = _waitSeconds;
      if (_liveUpdatesPaused) { return; }
      _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_countingWait) { return; }
        _rebuild(_syncWaitClock);
      });
    }
    void _syncWaitClock() {
      final anchor = _waitAnchorAt;
      if (!_countingWait || anchor == null) { return; }
      final now = widget.waitNow?.call() ?? DateTime.now();
      final elapsed = math.max(0, now.difference(anchor).inSeconds);
      _waitSeconds = math.max(_waitSeconds, _waitAnchorSeconds + elapsed);
    }
    String _stopWord(int number) {
      return switch (number) {
        1 => 'first',
        2 => 'second',
        3 => 'third',
        4 => 'fourth',
        5 => 'fifth',
        _ => '$number',
      };
    }
    Future<void> _confirmCancellationReason(
      _TripCancellationReason reason,
    ) async {
      final isOnTrip = _stage == ActiveRideStage.onTrip;

      final confirmed = await showMoveraModalSheet<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.34),
        heightFactor: 0.7,
        fitContent: true,
        builder: (sheetContext) {
          return _CleanSheet(
            key: const ValueKey<String>('trip-cancellation-confirmation'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isOnTrip ? 'End this trip early?' : 'Cancel this trip?',
                  style: _CleanSheet.title,
                ),
                const SizedBox(height: 6),
                Text('Reason: ${reason.title}', style: _CleanSheet.note),
                if (isOnTrip) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Only end the trip after you have stopped in a safe place and the rider can exit safely.',
                    style: _CleanSheet.note,
                  ),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey<String>('confirm-trip-cancellation'),
                    onPressed: () => popOwned(sheetContext, true),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFC2453A),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      isOnTrip ? 'End trip early' : 'Cancel trip',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => popOwned(sheetContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111614),
                      side: const BorderSide(color: Color(0xFFDADEDC)),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Keep trip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (confirmed != true || !mounted) { return; }
      _submitTripCancellation(reason);
    }
    Future<void> _submitTripCancellation(_TripCancellationReason reason) async {
      if(_cancellationInFlight || _completionInFlight || _handlingRiderCancellation) { return; }
      _cancellationInFlight=true;
      try {
        final secured = _onTripRadarState == _OnTripRadarState.secured ? _nextTripRadarOffer : null;
        await CompletionJournal(active: widget.activeRideRepository ?? MemoryActiveRideRepository()).finish(
          _waybills.current ?? _buildCurrentWaybill(),
          status: TripStatus.cancelledByDriver,
          cancellationReasonCode: reason.code,
          cancellationActor: 'driver',
          next: secured == null ? null : _snapshotForOffer(secured));
      } catch (_) {
        if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save cancellation. Retry.'))); }
        _cancellationInFlight=false;
        return;
      }
      if(await _yieldToAuthoritativeTerminal()) return;
      // The journal has already applied terminal cleanup and queued handoff.
      if (!await _rideLifecycle.cancel(clearSnapshot: false)) { _cancellationInFlight=false; return; }
      if (!mounted) { return; }
      _waitTimer?.cancel();
      _nextTripRadarDemoTimer?.cancel();
      _nextTripRadarMatchTimer?.cancel();
      _waybills.discardCurrent();

      final offer = _nextTripRadarOffer;
      final queuedNext =
          _onTripRadarState == _OnTripRadarState.secured && offer != null;
      final nextRide = queuedNext
          ? AcceptRide(
              offerId: offer.id,
              riderName: offer.riderName,
              riderRating: offer.rating,
              fare: offer.fare,
              category: offer.category,
              matchedVia: 'Exclusive offer',
              pickupAddress: offer.pickup,
              pickupArea: offer.pickup.split(',').last.trim(),
              dropoffAddress: offer.dropoff,
              pickupPosition: offer.pickupPosition,
              dropoffPosition: offer.dropoffPosition,
              locationRepository: widget.locationRepository,
              routeRepository: widget.routeRepository,
              waybillRepository: _waybills,
              sessionController: widget.sessionController,
              activeRideRepository: widget.activeRideRepository,
            )
          : null;
      if (nextRide != null) {
        _waybills.promoteNextToCurrent();
      } else {
        _waybills.clearNext();
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            queuedNext
                ? 'First trip ended · starting the next one'
                : _stage == ActiveRideStage.onTrip
                    ? 'Trip ended early · ${reason.title}'
                    : 'Trip cancelled · ${reason.title}',
          ),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      final navigator = Navigator.of(context);
      if (nextRide != null) {
        navigator.pushReplacement(BottomToTopTransition(nextRide));
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    // Ride check: the trip screen feeds the detector, and opens the card
    // when a trigger fires. Never during pickup, and never on top of an open card.
    DateTime get _rideCheckNow => _rideCheckServices!.now();
    bool get _rideCheckWatching => mounted && _stage == ActiveRideStage.onTrip &&
        !_rideCheck.active && !_rideLifecycle.terminal &&
        !_completionInFlight && !_cancellationInFlight;
    /// Waiting at a stop or close to the next point is not a long stop.
    bool get _rideCheckAtPlannedStop {
      if (_paidStopWait) { return true; }
      final target = _routeTarget;
      return target != null && GeoPointMaps.fromLatLng(_driverPosition).distanceMetersTo(
        GeoPointMaps.fromLatLng(target)) <= RideCheckRules.plannedStopRadiusMeters;
    }
    String? get _rideCheckPlace {
      final road = _navigation.snapshot.banner?.roadName?.trim();
      return road == null || road.isEmpty ? null : road;
    }
    SafetyAlertTrip _safetyAlertTrip() => SafetyAlertTrip(
      tripId: widget.offerId, riderName: widget.riderName, riderRating: widget.riderRating,
      pickup: widget.pickupAddress, dropoff: widget.dropoffAddress, fare: widget.fare,
      category: widget.category, driverName: 'Movera Driver', vehicle: _vehicleLabel,
      plate: _vehiclePlate,
      position: _hasLiveLocation ? GeoPointMaps.fromLatLng(_driverPosition) : null);
    void _openRideCheck(RideCheckEvent? event) {
      if (event == null || !mounted) { return; }
      unawaited(_rideCheck.open(event, instant: MediaQuery.disableAnimationsOf(context)));
    }
    void _rideCheckPlan(RoadRoute route) {
      if (_stage != ActiveRideStage.onTrip || _paidStopWait) { return; }
      _demoDrive?.followRoad(route.points);
      _rideCheckDetector.planLeg('$_stopCursor', route.points, route.durationSeconds,
        wholeTrip: widget.stopAddresses.isEmpty);
    }
    void _rideCheckObserve() {
      if (!_rideCheckWatching || !_hasLiveLocation) { return; }
      _openRideCheck(_rideCheckDetector.observe(GeoPointMaps.fromLatLng(_driverPosition), _rideCheckNow,
        atPlannedStop: _rideCheckAtPlannedStop, place: _rideCheckPlace, destination: _onwardAddress));
    }
    /// GPS can stay quiet while the car stands still.
    void _rideCheckTick() {
      if (!_rideCheckWatching || _liveUpdatesPaused) { return; }
      _openRideCheck(_rideCheckDetector.tick(_rideCheckNow, gps: _hasLiveLocation,
        atPlannedStop: _rideCheckAtPlannedStop, place: _rideCheckPlace));
    }
    /// Possible-crash hook: a very hard stop from a motion sensor adapter.
    void _rideCheckHardStop(DateTime at) {
      if (!_rideCheckWatching) { return; }
      _openRideCheck(_rideCheckDetector.hardStop(at, place: _rideCheckPlace));
    }
    /// Finished far from drop-off: Finish tapped more than admin's km from
    /// the drop-off. Demo arrival is simulated, so its position says nothing about the drop-off,
    /// except on a RideCheck demo trip, whose scripted GPS is the trip's own.
    RideCheckEvent? _rideCheckFarDrop() {
      if (_rideCheckFinishDemo) {
        _rideCheckFinishDemo = false;
        return _rideCheck.active ? null : _rideCheckDetector.demo(RideCheckTrigger.droppedFar,
          _rideCheckNow, destination: widget.dropoffAddress);
      }
      if ((_arrivalDemo && _demoDrive == null) || _rideCheck.active || !_hasLiveLocation ||
          _lastLocation?.isUsableAt(DateTime.now()) != true) { return null; }
      return _rideCheckDetector.finish(driver: GeoPointMaps.fromLatLng(_driverPosition),
        dropoff: GeoPointMaps.fromLatLng(widget.dropoffPosition),
        dropoffAddress: widget.dropoffAddress, at: _rideCheckNow);
    }
    /// Demo tools on the island: shows the card for [trigger].
    void _openRideCheckDemo(RideCheckTrigger trigger) {
      if (!mounted || _rideCheck.active || _rideLifecycle.terminal) { return; }
      // Finished far from drop-off: plays the real Finish, so the card opens
      // right as the trip ends and the trip completes once answered.
      if (trigger == RideCheckTrigger.droppedFar && _stage == ActiveRideStage.onTrip &&
          !_paidStopWait && !_stageTransitioning && _stopCursor >= widget.stopAddresses.length) {
        _rideCheckFinishDemo = true;
        unawaited(_advanceRide().whenComplete(() => _rideCheckFinishDemo = false));
        return;
      }
      _openRideCheck(_rideCheckDetector.demo(trigger, _rideCheckNow,
        place: _rideCheckPlace, destination: widget.dropoffAddress));
    }
}
