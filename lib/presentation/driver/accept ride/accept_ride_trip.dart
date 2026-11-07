part of 'accept_ride.dart';

// Trip, realtime, and navigation orchestration for AcceptRide.
// The state object still owns timers, subscriptions, and the stage.
// This extension is the only place that advances that lifecycle.

extension _AcceptRideTrip on _AcceptRideState {
  // Rule 25 split (fix job 5): these live in accept_ride_trip_cover.dart;
  // accept_ride.dart still calls them through this extension.
  void _pauseLiveUpdates() =>
      _AcceptRideTripCover(this)._pauseLiveUpdatesMoved();
  void _resumeLiveUpdates() =>
      _AcceptRideTripCover(this)._resumeLiveUpdatesMoved();
  void _coverTrip() => _AcceptRideTripCover(this)._coverTripMoved();
  void _uncoverTrip() => _AcceptRideTripCover(this)._uncoverTripMoved();
  void _menuChanged(bool open) =>
      _AcceptRideTripCover(this)._menuChangedMoved(open);
  void _hideTrip() => _AcceptRideTripCover(this)._hideTripMoved();
  void _showTrip() => _AcceptRideTripCover(this)._showTripMoved();
  Future<void> _loadVehicleIdentity() =>
      _AcceptRideTripCover(this)._loadVehicleIdentityMoved();

  /// Closes whatever this trip opened on top of it (chat, preferences, a
  /// sheet, the side menu) so a trip exit pops or replaces the trip
  /// screen itself.
  NavigatorState _navigatorAtTripRoute() {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route != null && route.isActive && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    // The open drawer is local history on this route: a pop would only
    // close it and leave the driver on the trip screen.
    while (route != null && route.isCurrent && route.willHandlePopInternally) {
      navigator.pop();
    }
    return navigator;
  }

  PersistedActiveRide _buildSnapshot(ActiveRideStage stage) {
    _syncWaitClock();
    final offer = _nextTripRadarOffer;
    final securedOffer = _onTripRadarState == _OnTripRadarState.secured
        ? offer
        : null;
    // driver-r5-39: the Start-trip save is the trip as it starts, with
    // the pickup's paid wait in: a kill before the next save keeps it.
    final starting =
        stage == ActiveRideStage.onTrip &&
        _stage == ActiveRideStage.waitingForRider;
    return PersistedActiveRide(
      tripId: widget.tripId,
      stage: stage,
      destinationModeActive: _destinationActive,
      destinationAddress: _destinationAddress,
      destinationPoint: _destinationPosition == null
          ? null
          : GeoPointMaps.fromLatLng(_destinationPosition!),
      scheduledPickupAt: widget.scheduledPickupAt,
      scheduledRideId: widget.scheduledRideId,
      bookedTime: widget.bookedTime,
      pickupKm: widget.pickupKm,
      bags: widget.bags,
      rideCheckFired: _rideCheckDetector.firedNames,
      nextOffersStopped: _onTripRadarState == _OnTripRadarState.stopped,
      nextTripId: securedOffer?.id,
      riderName: _riderName,
      riderRating: _riderRating,
      riderTrips: widget.riderTrips,
      fare: _fare,
      paidByCash: widget.paidByCash,
      cashToCollect: widget.cashToCollect,
      riderFare: _changedRoute?.riderFare ?? widget.riderFare,
      driverBonus: widget.driverBonus,
      category: widget.category,
      matchedVia: widget.matchedVia,
      pickupAddress: _pickupAddress,
      pickupArea: widget.pickupArea,
      dropoffAddress: _dropoffAddress,
      stopAddresses: _stopAddresses,
      stopPoints: _stopPositions.map(GeoPointMaps.fromLatLng).toList(),
      pickupLat: _pickupPosition.latitude,
      pickupLng: _pickupPosition.longitude,
      dropoffLat: _dropoffPosition.latitude,
      dropoffLng: _dropoffPosition.longitude,
      waitSeconds: _waitSeconds,
      paidWaitSeconds: _paidWaitSeconds + (starting ? _paidWaitNow : 0),
      acceptedAt: _acceptedAt,
      stopIndex: _stopCursor,
      paidStopWait: _paidStopWait,
      startedAt: _onTripStartedAt,
      next: securedOffer == null
          ? null
          : PersistedQueuedTrip(
              tripId: securedOffer.id,
              riderName: securedOffer.riderName,
              // The driver's pay, as the live ride's fare is.
              fare: securedOffer.driverPay,
              pickupPay: securedOffer.securedPickupPay,
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

  /// Q42: paid seconds of the wait running now. Contract v0.18.8: a stop
  /// wait is paid after the trip's `terms.stopFreeWaitMin` (0 = from its
  /// first second).
  int get _paidWaitNow => !_countingWait
      ? 0
      : _paidStopWait
      ? math.max(0, _waitSeconds - _stopFreeSeconds)
      : math.max(0, _waitSeconds - _includedWaitSeconds);
  int get _paidWaitTotal => _paidWaitSeconds + _paidWaitNow;

  /// Q43: the fare with the driver's waiting fee in it, for the earnings.
  String get _fareWithWaiting =>
      WaitingTerms.addFee(_fare, _waitTerms.driverWaitingFee(_paidWaitTotal));

  /// The cash of a cash trip saved before the trip's fare became the
  /// driver's own pay (owner decision 2026-10-26): the fare without
  /// Movera's bonus, which the rider never pays (driver-u61). Trips
  /// accepted since carry the rider's cash in `cashToCollect`
  /// (`RideOffer.riderCash`).
  String get _riderFare {
    final bonus = widget.driverBonus;
    if (bonus == null || bonus.minorUnits <= 0) {
      return _fare;
    }
    final fare = Money.parseLabel(_fare, currency: bonus.currency);
    if (fare == null || fare.minorUnits < bonus.minorUnits) {
      return _fare;
    }
    return (fare - bonus).formatted;
  }

  /// This trip's waybill: the current one only when it is this trip's.
  /// Live G8 fix 2 (re-check 2026-11-02): an earlier trip's waybill was
  /// still the current one (beginCurrent keeps an active record of another
  /// trip), so this trip's finished screen showed that trip's old fee
  /// ("Tidigare obetald avgift −35,00 kr", commission "+2,78 kr").
  WaybillRecord _ownWaybill() {
    final current = _waybills.current;
    return current != null && current.tripId == widget.tripId
        ? current
        : _buildCurrentWaybill();
  }

  /// Makes [paid] (this trip's, finished on the server) the current
  /// waybill. An earlier trip's record still held as current is dropped
  /// first: beginCurrent kept it, and completeCurrent then made it the
  /// finished screen's record (live G8 fix 2).
  void _setOwnWaybill(WaybillRecord paid) {
    if (_waybills.current?.tripId != paid.tripId) _waybills.discardCurrent();
    _waybills.beginCurrent(paid);
  }

  /// The current trip's waybill with the waiting fee in its fare.
  WaybillRecord _paidWaybill() {
    final fee = _waitTerms.driverWaitingFee(_paidWaitTotal);
    return _ownWaybill().copyWith(
      fare: _fareWithWaiting,
      waitingFee: fee.isZero ? null : fee.formatted,
      paidByCash: widget.paidByCash,
    );
  }

  void _restoreDestinationFromSnapshot() {
    final restored = widget.restoredSnapshot;
    if (restored == null || !restored.destinationModeActive) {
      return;
    }
    DestinationModeSession.instance.restored(
      since: restored.savedAt ?? DateTime.now(),
      address: restored.destinationAddress,
      position: restored.destinationPoint,
    );
  }

  void _restoreQueuedNextFromSnapshot() {
    // driver-u68: offers the driver held off stay off.
    if (widget.restoredSnapshot?.nextOffersStopped == true) {
      _onTripRadarState = _OnTripRadarState.stopped;
    }
    final next = widget.restoredSnapshot?.next;
    if (next == null) {
      return;
    }
    _onTripRadarState = _OnTripRadarState.secured;
    _nextTripRadarOffer = _NextTripRadarOffer(
      id: next.tripId,
      category: next.category,
      // Saved as the driver's pay: not reduced again.
      fare: next.fare,
      driverEarnings: next.fare,
      rating: next.rating,
      pickupMinutes: next.pickupMinutes,
      tripMinutes: next.tripMinutes,
      riderName: next.riderName,
      pickup: next.pickup,
      dropoff: next.dropoff,
      pickupPosition: LatLng(next.pickupLat, next.pickupLng),
      dropoffPosition: LatLng(next.dropoffLat, next.dropoffLng),
      securedPickupPay: next.pickupPay,
    );
  }

  void _resumeStageSideEffects() {
    if (_countingWait) {
      _startWaitTimer();
    }
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return;
      case ActiveRideStage.waitingForRider:
        unawaited(_focusWaitingPickup());
      case ActiveRideStage.onTrip:
        // A restored trip keeps its start (driver-u44).
        _rideCheckDetector.startTrip(_onTripStartedAt ?? _rideCheckNow);
        _demoDrive?.startTrip();
        if (_onTripRadarState != _OnTripRadarState.secured) {
          _startOnTripRadar();
        }
        unawaited(_refreshOnTripRoute(fitCamera: true));
    }
  }

  DateTime _offerNow() => widget.waitNow?.call() ?? DateTime.now();
  WaybillRecord _buildCurrentWaybill() {
    return WaybillRecord(
      tripId: widget.tripId,
      statusLabel: WaybillRecord.currentTrip,
      issuedAt: DateTime.now(),
      fare: _fare,
      driverBonus: WaybillRecord.bonusLabel(widget.driverBonus),
      service: widget.category,
      riderName: _riderName,
      pickup: _pickupAddress,
      dropoff: waybillRouteLabel(_dropoffAddress, _stopAddresses),
      source: widget.matchedVia,
      driverName: _driverName,
      riderFare: widget.riderFare,
      vehicle: _vehicleLabel,
      licensePlate: _vehiclePlate,
      passengerCapacity: 4,
      paidByCash: widget.paidByCash,
    );
  }

  /// the server's final money when the live trip's completed projection
  /// carries it (owner N9: a finish away from the drop-off is priced by
  /// what was driven, never below the minimum, never above the booked
  /// fare, and the driver's earnings follow it), else the booked pay
  /// with the waiting fee.
  ({WaybillRecord paid, String? cash}) _settledPaid() {
    var paid = _paidWaybill();
    var cash = widget.paidByCash ? _cashToCollect : null;
    final money = _AcceptRideLive(this)._settledMoney();
    if (money != null) {
      paid = _withMoney(paid, money);
      if (widget.paidByCash) {
        cash = money.cash.formatted;
      }
    }
    return (paid: paid, cash: cash);
  }

  /// The server's money on the waybill (v0.18.10: one driver number with
  /// its lines, the tip, an old fee, an early end).
  WaybillRecord _withMoney(WaybillRecord paid, LiveTripMoney money) =>
      paid.copyWith(
        fare: money.driverPay.formatted,
        riderFare: money.riderFare.formatted,
        waitingFee: money.waitingFee?.formatted,
        clearWaitingFee: money.waitingFee == null,
        earningsBreakdown: money.earningsBreakdown,
        // The server's money replaces what the waybill held: no tip, old
        // fee or early end the server does not send (live G8 fix 2).
        tip: money.tip,
        clearTip: money.tip == null,
        debtCollected: money.debtCollected,
        clearDebtCollected: money.debtCollected == null,
        endedEarlyBy: money.finish?.endedEarly == true
            ? money.finish?.endedBy ?? 'driver'
            : null,
        clearEndedEarlyBy: money.finish?.endedEarly != true,
      );

  WaybillRecord _buildNextWaybill(_NextTripRadarOffer offer) {
    return WaybillRecord(
      tripId: offer.id,
      statusLabel: WaybillRecord.nextTripSecured,
      issuedAt: DateTime.now(),
      // The total the card showed, pickup pay in it (driver-12).
      fare: offer.terms.fare,
      driverBonus: WaybillRecord.bonusLabel(offer.terms.driverBonus),
      service: offer.category,
      riderName: offer.riderName,
      pickup: offer.pickup,
      dropoff: offer.dropoff,
      source: WaybillRecord.exclusiveOfferSource,
      driverName: _driverName,
      // The rider's fare, unless the save already holds the driver's pay.
      riderFare: offer.driverEarnings == offer.fare ? null : offer.fare,
      vehicle: _vehicleLabel,
      licensePlate: _vehiclePlate,
      passengerCapacity: 4,
    );
  }

  LatLng? _stopPoint(int index) {
    if (index < 0 || index >= _stopPositions.length) {
      return null;
    }
    return _stopPositions[index];
  }

  void _syncNavigationStage() {
    _navigation.setStage(_rideLifecycle.stage);
    unawaited(_followVehicle());
  }

  void _onRealtimeEvent(DriverRealtimeEvent event) {
    if (!mounted || event.tripId != widget.tripId) {
      return;
    }

    final disposition = _realtimeGate.evaluate(event);
    if (disposition == DriverRealtimeDisposition.duplicate ||
        disposition == DriverRealtimeDisposition.invalid ||
        disposition == DriverRealtimeDisposition.blockedAfterTerminal) {
      return;
    }

    if (disposition == DriverRealtimeDisposition.acceptedWithGap) {
      unawaited(_resyncTrip());
    }
    // The server's accept time wins over this phone's (Q12).
    if (event.acceptedAt case final at?) {
      _acceptedAt = at;
    }
    // Contract v0.18.7: the projection's rider, terms, ETA, waiting and
    // pickup; the ETA tick rides on a location event (Q4, every 30 s).
    if (event.live case final live?) {
      _applyLive(live.withEta(event.eta));
    } else if (event.eta case final eta?) {
      _applyLive(TripLiveDetails(eta: eta));
    }
    if (event.status case final status? when !status.isTerminal) {
      _sawOpenTrip = true;
    }
    if (event.status != null ||
        event.kind == DriverRealtimeKind.riderCancelled) {
      _pendingProjection = event;
      unawaited(_drainProjection());
      // driver-r4-1: any kind may carry the projection; the rider's own
      // signal is still shown.
      if (event.kind != DriverRealtimeKind.riderOnTheWay ||
          event.status?.isTerminal != false) {
        return;
      }
    }

    switch (event.kind) {
      case DriverRealtimeKind.riderOnTheWay:
        if (_rideLifecycle.terminal) {
          return;
        }
        _rebuild(() => _riderOnTheWay = true);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              // The rider app sends its own English words ("I'm on the
              // way"); they read in the driver's language.
              event.message?.trim().isNotEmpty == true &&
                      event.message!.trim() != riderOnTheWayMessage
                  ? event.message!
                  : tr.riderNameIsOnWay(_riderName),
            ),
            backgroundColor: _AcceptRideState._ink,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      // A rider cancel always goes through the projection drain above.
      case DriverRealtimeKind.riderCancelled:
      case DriverRealtimeKind.tripProjection:
      case DriverRealtimeKind.pickupMoved:
      case DriverRealtimeKind.location:
      case DriverRealtimeKind.driverArrived:
      // Contract v0.3 kinds the driver screen does not show yet. A driver
      // cancel comes back with its projection, handled above.
      case DriverRealtimeKind.driverCancelled:
      case DriverRealtimeKind.paymentUpdated:
      case DriverRealtimeKind.ratingUpdated:
      case DriverRealtimeKind.message:
      // v0.18.38 §62: in-app calls are handled by LiveTripCalls.
      case DriverRealtimeKind.callRinging:
      case DriverRealtimeKind.callAnswered:
      case DriverRealtimeKind.callSignal:
      case DriverRealtimeKind.callEnded:
      case DriverRealtimeKind.callMissed:
        return;
    }
  }

  Future<void> _resyncTrip({bool reopen = false}) async {
    try {
      await _realtime.reconnectAndResync(widget.tripId, reopen: reopen);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.tripUpdatesCouldNotBeRefreshed),
            action: SnackBarAction(
              label: tr.retry,
              onPressed: () => unawaited(_resyncTrip()),
            ),
          ),
        );
      }
    }
  }

  /// Folds in what a projection (or the ETA tick) says beyond the
  /// status: a moved pickup re-routes the map and the island says so.
  ///
  /// [initial]: what the server already said before the screen was built
  /// (the accept answer, a restore read): taken as the starting point,
  /// nothing is redrawn or re-routed yet.
  void _applyLive(
    TripLiveDetails next, {
    bool rebuild = true,
    bool initial = false,
  }) {
    _live = next.merge(_live);
    // The waiting clocks on this trip follow its terms.
    WaitingTerms.active = _waitTerms;
    final moved = next.pickup;
    final movedTo = moved?.point.toLatLng();
    final pickupChanged =
        movedTo != null &&
        (movedTo.latitude != _pickupPosition.latitude ||
            movedTo.longitude != _pickupPosition.longitude);
    if (pickupChanged) {
      _pickupPosition = movedTo;
      if (moved?.address case final address?) {
        _resolvedPickup = address;
      }
    }
    final alert = _newWaitingAlert(next.waiting, initial: initial);
    // G7 (contract v0.18.9): the server's ride check and route change.
    _AcceptRideRouteChange(this)._onTripExtras(next, initial: initial);
    if (initial) return;
    if (mounted && (rebuild || pickupChanged || alert != null)) {
      _rebuild(() {
        if (pickupChanged) {
          _islandNotice = tr.pickupMovedIsland;
          _islandNoticeKey++;
        }
        if (alert != null) {
          _waitingAlert = alert;
          _waitingAlertKey++;
        }
      });
    }
    if (pickupChanged) _afterPickupMoved();
  }

  /// `pickupWaiting.follow`: while the event stream is down, read the
  /// trip every 10 s so the ETA, the waiting and a moved pickup still
  /// reach the screen; the stream itself replays what it missed.
  Future<void> _followTick() async {
    if (!mounted || _rideLifecycle.terminal || _liveUpdatesPaused) return;
    final realtime = _realtime;
    if (realtime is ApiDriverRealtime && realtime.connected) return;
    final trips = _AcceptRideLive(this)._liveTrips;
    if (trips == null) return;
    final projection = await trips.refresh(widget.tripId);
    if (!mounted || projection == null) return;
    _applyLive(TripLiveDetails.fromProjection(projection));
  }

  /// X5: the trip went back to dispatch without this driver. Navigation
  /// and offers stop, the island says so on Home, and the driver is back
  /// to the availability they had.
  ///
  /// [notice] replaces "Trip removed by Movera" on the island (a late
  /// ETA says why the ride went to another driver).
  Future<void> _leaveAfterRelease(
    TripStatus status, {
    IslandMessage? notice,
  }) async {
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
    _pauseLiveUpdates();
    _waybills.discardCurrent();
    _waybills.clearNext();
    widget.sessionController?.stayOnlineAfterTrip();
    final navigator = _navigatorAtTripRoute();
    if (navigator.canPop()) {
      IslandMessages.show(notice ?? HomeIslandNotices.tripRemoved);
      navigator.pop();
      return;
    }
    if (notice != null) {
      IslandMessages.show(notice);
    }
    await showTripOutcomeSheet(context, status: status, hasNext: false);
  }

  /// driver-u72: once per failed write; Retry repeats the failed slide
  /// (Arrive, Start trip), or the background save.
  void _onPersistenceChanged() {
    final ride = _rideLifecycle;
    if (!mounted ||
        ride.persistenceError == null ||
        ride.failures == _shownSaveFailures) {
      return;
    }
    _shownSaveFailures = ride.failures;
    final failed = ride.failedStage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr.tripProgressCouldNotBeSaved),
        action: SnackBarAction(
          label: tr.retry,
          onPressed: () {
            if (!mounted) {
              return;
            }
            switch (failed) {
              case ActiveRideStage.waitingForRider:
                unawaited(_confirmPickupArrival());
              case ActiveRideStage.onTrip:
                unawaited(_advanceRide());
              default:
                unawaited(ride.persistNow());
            }
          },
        ),
      ),
    );
  }

  /// A last fix exists but is too old to judge the distance; the arrival
  /// tap asks for a fresh one (G7 live fix). No fix at all is not aged.
  bool get _arrivalFixAged =>
      _arrivalTarget != null &&
      _lastLocation != null &&
      _lastLocation?.isUsableAt(DateTime.now()) != true;

  Future<void> _onArrivedTap() async {
    // G7 live fix 3: a held fix at the target counts at once; the tap no
    // longer waits for a one-shot read a still browser never answers.
    final near = _nearArrivalTarget || _AcceptRideLive(this)._nearByHeldFix;
    if (!near && _arrivalFixAged) {
      // G7 live fix: a parked phone (a browser above all) may send no new
      // fix while it stands still, so the last one ages past its 30 s and
      // the tap was refused although the car is at the stop. Ask for one
      // fresh fix before saying no (only for an aged fix: no fix at all
      // says "location unavailable" at once). A missing road route never blocks.
      await _freshFixForArrival();
      if (!mounted) return;
    }
    if (!near && !_nearArrivalTarget) {
      _blockedArrival();
      return;
    }
    if (_stage == ActiveRideStage.headingToPickup) {
      await _confirmPickupArrival();
      return;
    }
    if (_stage == ActiveRideStage.onTrip &&
        !_paidStopWait &&
        _stopCursor < _stopAddresses.length) {
      // Contract v0.7.1 §3.8: the server charges the stop wait from this
      // tap, so a live build tells it first.
      final stop = _stopCursor;
      if (LiveDriverServices.active &&
          (!await _whileStepBusy(
                () => _AcceptRideLive(this)._serverStep(
                  (trips) => trips.arriveAtStop(widget.tripId, stop),
                ),
              ) ||
              !mounted ||
              _stage != ActiveRideStage.onTrip ||
              _paidStopWait)) {
        return;
      }
      _paidStopWait = true;
      _waitSeconds = 0;
      _waitAnchorAt = null;
      _startWaitTimer();
      await _rideLifecycle.persistNow();
      if (mounted) {
        _rebuild(() {});
      }
    }
  }

  void _onNavigationChanged() {
    if (!mounted || _stageTransitioning) {
      return;
    }
    final route = _navigation.route;
    final status = _navigation.status;
    final pointsChanged =
        route != null &&
        route.points.length >= 2 &&
        !identical(_roadGeoPoints, route.points);
    final mappedRoute = route;
    final routeCleared = route == null && _roadGeoPoints.isNotEmpty;
    if (!routeCleared && !pointsChanged && status == _locationStatus) {
      return;
    }
    if (pointsChanged && mappedRoute != null) {
      _rideCheckPlan(mappedRoute);
    }
    _rebuild(() {
      if (pointsChanged && mappedRoute != null) {
        _roadGeoPoints = mappedRoute.points;

        _routeDurationSeconds = mappedRoute.durationSeconds;
      }
      if (routeCleared) {
        _roadGeoPoints = [];
        _routeDurationSeconds = null;
      }
      _locationStatus = status;
    });
  }

  Future<void> _prepareDriverVehicleMarker() async {
    final icon = await MoveraVehicleMarker.createIcon();
    final pins = {
      for (final kind in RouteMarkKind.values)
        kind: await RouteMarkPins.pin(kind),
    };
    if (!mounted) {
      return;
    }
    _rebuild(() {
      _driverVehicleIcon = icon;
      _pinIcons = pins;
    });
  }

  Future<void> _startLiveLocation() async {
    final epoch = ++_locationEpoch;
    if (_liveUpdatesPaused) {
      return;
    }
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }

      if (_liveUpdatesPaused || epoch != _locationEpoch) {
        return;
      }
      _preciseLocationOff = false;
      // Subscribe before routing: fresh GPS must remain usable even when
      // the first road-route request is slow or never resolves.
      _watchLiveLocation(epoch);
      await _applyDriverPosition(position, forceRoute: true);
    } catch (error) {
      if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) {
        return;
      }
      _locationFailed(error);
      // driver-r5-15: a missed first fix (8 s limit, a permission prompt)
      // must not leave the trip without GPS until the next app resume.
      if (_positionSubscription == null) {
        _watchLiveLocation(epoch);
      }
      unawaited(_refreshRoadRoute(force: true));
    }
  }

  void _watchLiveLocation(int epoch) {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService
        .watchPosition(distanceFilterMeters: 0)
        .listen(
          (position) {
            if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) {
              return;
            }
            _applyDriverPosition(position);
          },
          onError: (Object error) {
            if (!mounted || _liveUpdatesPaused || epoch != _locationEpoch) {
              return;
            }
            _locationFailed(error);
          },
        );
  }

  /// The map's route lines for the route, the car's progress and zoom.
  void _syncRouteLines() => _routeLines.sync(
    _roadGeoPoints,
    _camera.alongMetersOn(_roadGeoPoints),
    _routeZoomStep,
  );

  void _onCameraMove(CameraPosition position) {
    _cameraPort?.onMove(position);
    final step = DriverRouteStyle.stepZoom(position.zoom);
    // The zoom step only changes the line widths: the map alone redraws.
    if (step != _routeZoomStep) {
      _routeZoomStep = step;
      _syncRouteLines();
    }
    // A native +/- control zoom has no Flutter pinch/wheel pointer signal.
    // Observe SDK zoom *deltas*, but only after physical input has already
    // transferred the camera to manual Browse. Pan-only moves stay quiet.
    final browsing = _camera.mode == DriverCameraMode.browsing;
    final zoomChanged = _manualZoomDetector.observe(
      position.zoom,
      browsing: browsing,
    );
    if (!browsing) {
      return;
    }
    _camera.mapActivity();
    final zoom = _lastMapZoom;
    if (zoomChanged ||
        _mapPointers >= 2 ||
        (zoom != null &&
            DateTime.now().difference(zoom) <
                const Duration(milliseconds: 700))) {
      _enterBrowse();
    }
  }

  /// [locate]: the driver tapped recenter, so the camera flies to the
  /// locate view; the quiet return after browsing keeps the speed zoom.
  void _exitBrowse({bool locate = false}) {
    // The recenter tap itself reaches the map, and the camera then flies
    // back: neither is the driver browsing.
    _mapZoomSettle.cancel();
    _lastMapZoom = null;
    _navigation.resumeFollow();
    if (locate) {
      _camera.locate();
    } else {
      _camera.recenter();
    }
    unawaited(_followVehicle());
    _browsePulse
      ..stop()
      ..value = 0;
    if (!_browsing) {
      _rebuild(() {});
      return;
    }
    _rebuild(() => _browsing = false);
    if (_browseReturnPos > 0.001) {
      unawaited(_snapSheet.springTo(_browseReturnPos));
    }
  }

  /// The trip camera returns to the car on its own after the driver
  /// leaves the map alone, and keeps the car above the resting sheet.
  void _setUpTripCamera() {
    _camera.onAutoResume = () {
      if (!mounted || _incomingOfferOpen) {
        return false;
      }
      _exitBrowse();
      return true;
    };
    _cameraSheet.addListener(() {
      if (mounted) {
        _rebuild(() {});
      }
    });
  }

  Future<void> _fitRoute() async {
    // Starting/changing a leg updates route context without stealing a
    // manually browsed viewport. Recenter is the sole manual resume action.
    await _followVehicle();
  }

  /// Q24 / R8-4: shows the cash to collect; "Finish {category}" there
  /// completes it.
  Future<void> _collectCash({CompletePreview? changed}) async {
    if (!_collectsCashNow || _stageTransitioning || _rideLifecycle.terminal) {
      return;
    }
    // Owner 2026-10-29 (live bug A, contract v0.18.1 §26): a live trip
    // shows the server's final price, never the booked cash: a finish more
    // than 300 m before the drop-off is priced by what was driven.
    final trips = _AcceptRideLive(this)._liveTrips;
    CompletePreview? preview = changed;
    if (trips != null && preview == null) {
      _stageTransitioning = true;
      try {
        preview = await _whileStepBusy(
          () => trips.previewComplete(widget.tripId),
        );
      } finally {
        _stageTransitioning = false;
      }
      if (!mounted) {
        return;
      }
      // A server before the preview (404): the old finish, so a cash trip
      // is never stuck.
      if (preview == null && !trips.previewUnsupported(widget.tripId)) {
        _AcceptRideLive(this)._showServerRefusal(liveTripErrorMessage(null));
        return;
      }
    }
    final complete = await showCashCollectSheet(
      context,
      // The driver's own money (owner decision 2026-10-26): no fee is
      // taken off it again.
      // v0.18.10 (owner G8 Q3): "Din andel" = driverTotal, the same
      // number as the finished screen.
      fare: preview?.yourShare?.formatted ?? _fareWithWaiting,
      cash: preview?.cashDue.formatted ?? _cashToCollect,
      riderName: _riderName,
      category: widget.category,
      recalculated: preview?.earlyEnd ?? false,
      earlyEndNote: preview == null || !preview.earlyEnd
          ? null
          : switch (preview.repriced) {
              true => tr.g8PricedForDriven,
              false => tr.g8BookedPriceStands,
              null => null,
            },
      breakdown: preview?.earningsBreakdown ?? const [],
    );
    if (!complete || !mounted || !_collectsCashNow) {
      return;
    }
    await _advanceRide();
  }

  Future<void> _advanceRide() async {
    if (_stageTransitioning || !mounted || _rideLifecycle.terminal) {
      return;
    }

    _stageTransitioning = true;

    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        _stageTransitioning = false;
        return;

      case ActiveRideStage.waitingForRider:
        if (LiveDriverServices.active &&
            (!await _AcceptRideLive(this)._startOnServer() ||
                !mounted ||
                _rideLifecycle.terminal ||
                _stage != ActiveRideStage.waitingForRider)) {
          _stageTransitioning = false;
          return;
        }
        _syncWaitClock();
        final paidWait = _paidWaitNow;
        // In the Start-trip save already (driver-r5-39).
        _onTripStartedAt = DateTime.now();
        if (!await _rideLifecycle.transitionTo(ActiveRideStage.onTrip)) {
          _onTripStartedAt = null;
          _stageTransitioning = false;
          return;
        }
        _paidWaitSeconds += paidWait;
        _waitTimer?.cancel();
        _paidStopWait = false;
        _stopCursor = 0;
        _nextTripRadarDemoTimer?.cancel();
        _nextTripRadarMatchTimer?.cancel();
        _rideCheckDetector.startTrip(_rideCheckNow);
        _demoDrive?.startTrip();
        await _rideLifecycle.persistNow();
        _onTripRadarState = _OnTripRadarState.scanning;
        _nextTripRadarOffer = null;
        if (mounted) {
          _rebuild(() {});
        }
        _maybeScheduleOnTripRadarDemoOffer();
        _unlockStageAfterFrame();
        unawaited(_refreshOnTripRoute());
        return;

      case ActiveRideStage.onTrip:
        if (_paidStopWait) {
          // Leaving the stop ends its paid wait on the server (v0.7.1).
          final stop = _stopCursor;
          if (LiveDriverServices.active &&
              (!await _AcceptRideLive(this)._serverStep(
                    (trips) => trips.leaveStop(widget.tripId, stop),
                  ) ||
                  !mounted ||
                  !_paidStopWait)) {
            _stageTransitioning = false;
            return;
          }
          _syncWaitClock();
          _paidWaitSeconds += _paidWaitNow;
          _paidStopWait = false;
          _waitTimer?.cancel();
          _stopCursor += 1;
          await _rideLifecycle.persistNow();
          _stageTransitioning = false;
          if (mounted) {
            _rebuild(() {});
          }
          unawaited(_refreshOnTripRoute());
          return;
        }
        if (_stopCursor < _stopAddresses.length) {
          _stageTransitioning = false;
          return;
        }
        final farDrop = _rideCheckFarDrop();
        if (farDrop != null) {
          // Ask first; the trip finishes once the driver has answered.
          _stageTransitioning = false;
          await _rideCheck.open(
            farDrop,
            instant: MediaQuery.disableAnimationsOf(context),
          );
          if (!mounted ||
              _stage != ActiveRideStage.onTrip ||
              _rideLifecycle.terminal) {
            return;
          }
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

  Future<void> _completeCurrentTrip() async {
    if (_completionInFlight ||
        _cancellationInFlight ||
        _handlingRiderCancellation ||
        !mounted ||
        _rideLifecycle.terminal) {
      return;
    }
    _completionInFlight = true;
    _stageTransitioning = true;
    _flushNextTripMatch();
    final offer = _nextTripRadarOffer;
    final queuedNext =
        _onTripRadarState == _OnTripRadarState.secured && offer != null;
    final next = queuedNext ? _snapshotForOffer(offer) : null;
    if (LiveDriverServices.active &&
        (!await _whileStepBusy(
              () => _AcceptRideLive(this)._serverStep(
                (trips) => trips.complete(
                  widget.tripId,
                  preview: trips.previewOf(widget.tripId),
                  cash: widget.paidByCash,
                ),
              ),
            ) ||
            !mounted ||
            _rideLifecycle.terminal)) {
      _completionInFlight = false;
      _stageTransitioning = false;
      // v0.18.1 §26: 409 price_changed: the sheet again with the new price.
      final changed = _AcceptRideLive(
        this,
      )._liveTrips?.takePriceChanged(widget.tripId);
      if (changed != null && mounted) {
        unawaited(_collectCash(changed: changed));
      }
      return;
    }
    try {
      // Q43: the waiting fee is the driver's, in the trip's earnings;
      // N9: a live trip takes the server's final numbers.
      final (:paid, :cash) = _settledPaid();
      _setOwnWaybill(paid);
      await CompletionJournal(
        active: widget.activeRideRepository ?? MemoryActiveRideRepository(),
      ).finish(
        paid,
        pickupPoint: GeoPointMaps.fromLatLng(_pickupPosition),
        dropoffPoint: GeoPointMaps.fromLatLng(_dropoffPosition),
        next: next,
        paymentMethod: widget.paidByCash ? 'Cash' : 'Card',
        cashCollected: cash,
      );
      if (!mounted) {
        return;
      }
      if (await _yieldToAuthoritativeTerminal()) return;
      if (!await _rideLifecycle.complete(clearSnapshot: false)) {
        _completionInFlight = false;
        _stageTransitioning = false;
        _restoreOwnCompletionEcho();
        return;
      }
      _ownCompletionEcho = null;
    } catch (error, stack) {
      DriverLog.error('Trip completion journal failed', error, stack);
      _completionInFlight = false;
      _stageTransitioning = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.couldNotFinishSavingThisTrip)),
        );
      }
      return;
    }
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    if (!mounted) {
      return;
    }
    _waybills.completeCurrent();
    // Fix job 5 (owner 2026-11-05): the next trip — a live one he accepted
    // during this trip, or a booked ride whose time to drive is near — opens
    // on screen after this one, with an information popup (OK only).
    // Finder A4: the summary shows at once; the server is asked for the
    // next trip behind it, and Done waits only if it has not answered yet.
    final nextRide = queuedNext ? _nextRideFor(offer) : null;
    Future<Widget?>? nextRideLater;
    if (nextRide == null) {
      final screen = widget, waybills = _waybills;
      nextRideLater = openNextTripAfter(screen.tripId).then<Widget?>(
        (opened) => opened == null
            ? null
            : NextTripPopupHost(
                next: opened.next,
                child: AcceptRide.fromPersisted(
                  opened.ride,
                  locationRepository: screen.locationRepository,
                  routeRepository: screen.routeRepository,
                  waybillRepository: waybills,
                  sessionController: screen.sessionController,
                  activeRideRepository: screen.activeRideRepository,
                  dispatchRepository: screen.dispatchRepository,
                ),
              ),
        onError: (Object _) => null,
      );
    }
    Navigator.of(context).pushReplacement(
      BottomToTopTransition(
        DriverRideCompleted(
          waybillRepository: _waybills,
          sessionController: widget.sessionController,
          activeRideRepository: widget.activeRideRepository,
          nextRide: nextRide,
          nextRideLater: nextRideLater,
          paidByCash: widget.paidByCash,
        ),
      ),
    );
  }

  Future<void> _refreshOnTripRoute({bool fitCamera = false}) async {
    await _refreshRoadRoute(force: true);
    if (!mounted || _stage != ActiveRideStage.onTrip) {
      return;
    }
    if (fitCamera) {
      await _fitRoute();
    }
  }

  void _toggleOnTripRadar() {
    if (_stage != ActiveRideStage.onTrip) {
      return;
    }
    if (_onTripRadarState == _OnTripRadarState.secured) {
      return;
    }
    if (_onTripRadarOn) {
      _stopOnTripRadar();
      return;
    }
    _onTripRadarDeclined = false;
    _rebuild(() => _onTripRadarState = _OnTripRadarState.off);
    _startOnTripRadar();
    unawaited(_rideLifecycle.persistNow());
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
      if (_onTripRadarState != _OnTripRadarState.offerAvailable) {
        return;
      }
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
    if (heldAt == null) {
      return;
    }
    _nextTripOfferHeldAt = null;
    if (_onTripRadarState != _OnTripRadarState.scanning ||
        _onTripRadarDeclined) {
      return;
    }
    // driver-45: an offer that was on screen keeps its deadline; only
    // the rest of its time is left.
    final left = _nextTripOfferDeadline?.difference(_offerNow());
    if ((left ??
            _AcceptRideState._onTripOfferLifetime -
                DateTime.now().difference(heldAt)) <=
        Duration.zero) {
      _nextTripOfferDeadline = null;
      _maybeScheduleOnTripRadarDemoOffer();
      return;
    }
    _presentOnTripOffer(left: left);
  }

  void _acceptNextTripRadar() {
    final offer = _nextTripRadarOffer;
    if (offer == null || _stage != ActiveRideStage.onTrip) {
      return;
    }
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
      if (!mounted || _stage != ActiveRideStage.onTrip) {
        return;
      }
      _secureNextTrip(offer);
    });
  }

  void _denyNextTripRadar() {
    if (_stage != ActiveRideStage.onTrip) {
      return;
    }
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
    // Owner 2026-10-27 (contract v0.8.0 §6.7): an Exclusive offer missed or
    // declined while the driver is on a trip never counts toward going
    // offline.
  }

  String _stopWord(int number) {
    return switch (number) {
      1 => tr.stopOrdinal1,
      2 => tr.stopOrdinal2,
      3 => tr.stopOrdinal3,
      4 => tr.stopOrdinal4,
      5 => tr.stopOrdinal5,
      _ => tr.stopOrdinalN(number),
    };
  }

  Future<void> _confirmCancellationReason(
    _TripCancellationReason reason, {
    bool nextTrip = false,
  }) async {
    final isOnTrip = !nextTrip && _stage == ActiveRideStage.onTrip;
    final noShow =
        !nextTrip && reason.code == CancelReasons.current.noShow.code;

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
                nextTrip
                    ? tr.cancelNextTripQuestion
                    : noShow
                    ? _noShowConfirmTitle
                    : isOnTrip
                    ? tr.endThisTripEarlyQuestion
                    : tr.cancelThisTripQuestion,
                style: _CleanSheet.title,
              ),
              const SizedBox(height: 6),
              Text(tr.reasonTitle(reason.title), style: _CleanSheet.note),
              if (nextTrip) ...[
                const SizedBox(height: 6),
                Text(
                  tr.yourCurrentTripContinuesNextTrip,
                  style: _CleanSheet.note,
                ),
              ],
              if (isOnTrip) ...[
                const SizedBox(height: 6),
                Text(tr.onlyEndTripAfterYouHave, style: _CleanSheet.note),
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
                    nextTrip
                        ? tr.cancelNextTrip
                        : isOnTrip
                        ? tr.endTripEarly
                        : tr.cancelTrip,
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
                  child: Text(
                    tr.keepTrip,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }
    if (nextTrip) {
      _AcceptRideSheet(this)._cancelNextTrip(reason);
      return;
    }
    _submitTripCancellation(reason);
  }

  SafetyAlertTrip _safetyAlertTrip() => SafetyAlertTrip(
    tripId: widget.tripId,
    riderName: _riderName,
    riderRating: _riderRating,
    pickup: _pickupAddress,
    dropoff: _dropoffAddress,
    fare: _fare,
    category: widget.category,
    driverName: _driverName,
    vehicle: _vehicleLabel,
    plate: _vehiclePlate,
    position: _rideCheckGpsFresh
        ? GeoPointMaps.fromLatLng(_driverPosition)
        : null,
  );

  /// GPS can stay quiet while the car stands still.
  void _rideCheckTick() {
    if (!_rideCheckWatching || _liveUpdatesPaused) {
      // driver-u45: nobody watched; the stop clock restarts after.
      _rideCheckDetector.unwatched();
      return;
    }
    _openRideCheck(
      _rideCheckDetector.tick(
        _rideCheckNow,
        gps: _rideCheckGpsFresh,
        atPlannedStop: _rideCheckAtPlannedStop,
        place: _rideCheckPlace,
      ),
    );
  }

  /// Possible-crash hook: a very hard stop from a motion sensor adapter.
  void _rideCheckHardStop(DateTime at) {
    if (!_rideCheckWatching) {
      return;
    }
    _openRideCheck(_rideCheckDetector.hardStop(at, place: _rideCheckPlace));
  }

  /// Demo tools on the island: shows the card for [trigger].
  void _openRideCheckDemo(RideCheckTrigger trigger) {
    if (!mounted || _rideCheck.active || _rideLifecycle.terminal) {
      return;
    }
    // Finished far from drop-off: plays the real Finish, so the card opens
    // right as the trip ends and the trip completes once answered.
    if (trigger == RideCheckTrigger.droppedFar &&
        _stage == ActiveRideStage.onTrip &&
        !_paidStopWait &&
        !_stageTransitioning &&
        _stopCursor >= _stopAddresses.length) {
      _rideCheckFinishDemo = true;
      unawaited(
        _advanceRide().whenComplete(() => _rideCheckFinishDemo = false),
      );
      return;
    }
    _openRideCheck(
      _rideCheckDetector.demo(
        trigger,
        _rideCheckNow,
        place: _rideCheckPlace,
        destination: _dropoffAddress,
      ),
    );
  }
}
