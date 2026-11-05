part of 'accept_ride.dart';

// Base job B8 (2026-11-04): moved word for word out of accept_ride_trip.dart
// (no behaviour change).
extension _AcceptRideTripNext on _AcceptRideState {
  /// The secured next trip, as completion, a driver cancel and the
  /// journal's `next` snapshot all start it: destination mode included.
  AcceptRide _nextRideFor(_NextTripRadarOffer offer) => AcceptRide(
    tripId: offer.id,
    riderName: offer.riderName,
    riderRating: offer.rating,
    fare: offer.terms.fare,
    driverBonus: offer.terms.driverBonus,
    category: offer.category,
    matchedVia: WaybillRecord.exclusiveOfferSource,
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
    dispatchRepository: widget.dispatchRepository,
    destinationModeActive: _destinationActive,
    destinationAddress: _destinationAddress,
    destinationPosition: _destinationPosition,
  );

  PersistedActiveRide _snapshotForOffer(_NextTripRadarOffer offer) =>
      PersistedActiveRide(
        tripId: offer.id,
        stage: ActiveRideStage.headingToPickup,
        pickupKm: offer.pickupKm,
        destinationModeActive: _destinationActive,
        destinationAddress: _destinationAddress,
        destinationPoint: _destinationPosition == null
            ? null
            : GeoPointMaps.fromLatLng(_destinationPosition!),
        riderName: offer.riderName,
        riderRating: offer.rating,
        fare: offer.terms.fare,
        driverBonus: offer.terms.driverBonus,
        category: offer.category,
        matchedVia: WaybillRecord.exclusiveOfferSource,
        pickupAddress: offer.pickup,
        dropoffAddress: offer.dropoff,
        pickupLat: offer.pickupPosition.latitude,
        pickupLng: offer.pickupPosition.longitude,
        dropoffLat: offer.dropoffPosition.latitude,
        dropoffLng: offer.dropoffPosition.longitude,
      );

  void _unlockStageAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stageTransitioning = false;
      // driver-42: a route change (the pickup route cleared on arrival)
      // notified while the stage was changing; apply it now.
      if (mounted) {
        _onNavigationChanged();
      }
    });
  }

  Future<void> _focusWaitingPickup() async {
    await _followVehicle();
  }

  void _startOnTripRadar() {
    if (_onTripRadarState == _OnTripRadarState.stopped) {
      return;
    }
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();

    if (!mounted || _stage != ActiveRideStage.onTrip) {
      return;
    }

    _rebuild(() {
      _onTripRadarState = _OnTripRadarState.scanning;
      _nextTripRadarOffer = null;
    });

    _maybeScheduleOnTripRadarDemoOffer();
  }

  /// R13-18: the same on-the-way filter as Home (R13-9); the next trip
  /// starts at this trip's drop-off.
  bool _dropoffFollowsDestination(LatLng dropoff) {
    if (!_destinationActive) {
      return true;
    }
    final destination = _destinationPosition;
    if (destination == null) {
      return true;
    }
    return OnTripDestination.follows(
      from: GeoPointMaps.fromLatLng(_dropoffPosition),
      destination: GeoPointMaps.fromLatLng(destination),
      dropoff: GeoPointMaps.fromLatLng(dropoff),
    );
  }

  _NextTripRadarOffer _onTripRadarOfferForDestination() {
    if (!_destinationActive) {
      return _uniqueDemoNext;
    }
    final destination = _destinationPosition;
    if (destination == null) {
      return _uniqueDemoNext;
    }
    final address = _destinationAddress?.trim();
    return _NextTripRadarOffer(
      id: tripOccurrenceId('${widget.tripId}-next-destination'),
      category: _AcceptRideState._demoNextTripOffer.category,
      fare: _AcceptRideState._demoNextTripOffer.fare,
      rating: _AcceptRideState._demoNextTripOffer.rating,
      pickupMinutes: _AcceptRideState._demoNextTripOffer.pickupMinutes,
      pickupKm: _AcceptRideState._demoNextTripOffer.pickupKm,
      tripMinutes: _AcceptRideState._demoNextTripOffer.tripMinutes,
      riderName: _AcceptRideState._demoNextTripOffer.riderName,
      pickup: _AcceptRideState._demoNextTripOffer.pickup,
      dropoff: address == null || address.isEmpty
          ? tr.alongYourDestination
          : address,
      pickupPosition: _AcceptRideState._demoNextTripOffer.pickupPosition,
      dropoffPosition: destination,
    );
  }

  void _stopOnTripRadar() {
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
    if (!mounted || _stage != ActiveRideStage.onTrip) {
      return;
    }
    if (_onTripRadarState == _OnTripRadarState.secured) {
      return;
    }
    _rebuild(() {
      _onTripRadarState = _OnTripRadarState.stopped;
      _nextTripRadarOffer = null;
    });
    unawaited(_rideLifecycle.persistNow()); // kept for a restore (u68)
  }

  void _maybeScheduleOnTripRadarDemoOffer() {
    // A live build: no demo next trip; the server sends real ones.
    if (LiveDriverServices.active) {
      return;
    }
    // Q18: while driving a rider only Exclusive offers come, when admin
    // allows them; never Radar trips.
    if (!DriverOfferRules.current.exclusiveWhileDriving ||
        DriverOfferRules.current.exclusiveWhileDrivingCount < 1) {
      return;
    }
    if (!mounted ||
        _offersHeld ||
        _stage != ActiveRideStage.onTrip ||
        // u76: the trip has ended (its outcome sheet may still be up).
        _rideLifecycle.terminal ||
        _onTripRadarState != _OnTripRadarState.scanning ||
        _onTripRadarDeclined ||
        (_nextTripRadarDemoTimer?.isActive ?? false)) {
      return;
    }

    // Offers are explicitly simulated. A future live adapter must pass the freshness gate.
    double? metersToDropoff;
    if (_hasLiveLocation) {
      metersToDropoff = GeoPointMaps.fromLatLng(
        _driverPosition,
      ).distanceMetersTo(GeoPointMaps.fromLatLng(_dropoffPosition));
      if (metersToDropoff > _AcceptRideState._nextTripRadarRadiusMeters) {
        return;
      }
    }
    // R13-18: only on the way to the final drop-off, within admin's km
    // and/or minutes of it. The demo keeps next trips as they were.
    final toFinal = _stopCursor >= _stopAddresses.length;
    if (!NextTripGate.allows(
      demo: driverDemoFeatures,
      onTrip: _stage == ActiveRideStage.onTrip,
      toFinalDropoff: toFinal,
      metersToDropoff: metersToDropoff,
      secondsToDropoff: toFinal ? _routeDurationSeconds : null,
    )) {
      return;
    }

    _nextTripRadarDemoTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted ||
          _offersHeld ||
          _stage != ActiveRideStage.onTrip ||
          _onTripRadarState != _OnTripRadarState.scanning) {
        return;
      }

      // R10-2: a Ride check is open; the offer waits for the answer.
      if (RideCheckGate.open) {
        // Not yet seen: it gets its whole time after the answer.
        if (_nextTripOfferHeldAt == null) {
          _nextTripOfferDeadline = null;
        }
        _nextTripOfferHeldAt ??= DateTime.now();
        return;
      }
      _presentOnTripOffer();
    });
  }

  void _presentOnTripOffer({Duration? left}) {
    // D-05: never while the trip is hidden; the resume looks again.
    // Never after the trip ended either (u76).
    if (_offersHeld || _rideLifecycle.terminal) {
      return;
    }
    _rebuild(() {
      final offer = _onTripRadarOfferForDestination();
      if (!_dropoffFollowsDestination(offer.dropoffPosition)) {
        return;
      }
      _nextTripRadarOffer = offer;
      _onTripRadarState = _OnTripRadarState.offerAvailable;
    });
    _armOnTripOfferExpiry(left: left);
    _hideRideSheetForOffer();
  }

  void _armOnTripOfferExpiry({Duration? left}) {
    _nextTripOfferExpiry?.cancel();
    if (_onTripRadarState != _OnTripRadarState.offerAvailable) {
      return;
    }
    final time = left ?? _AcceptRideState._onTripOfferLifetime;
    if (left == null) {
      _nextTripOfferDeadline = _offerNow().add(time);
    }
    _nextTripOfferExpiry = Timer(time, () {
      if (!mounted || _onTripRadarState != _OnTripRadarState.offerAvailable) {
        return;
      }
      _denyNextTripRadar();
    });
  }

  void _hideRideSheetForOffer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ridePanelController.isAttached) {
        return;
      }
      if (_onTripRadarState == _OnTripRadarState.offerAvailable) {
        _ridePanelController.close();
      }
    });
  }

  void _restoreRideSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ridePanelController.isAttached) {
        return;
      }
      // The trip sheet always rests down; the driver lifts it.
      unawaited(_ridePanelController.close());
    });
  }

  void _secureNextTrip(_NextTripRadarOffer offer) {
    // Accepted: its pickup pay is kept as it was shown (driver-12).
    final secured = offer.secured();
    _rebuild(() {
      _onTripRadarState = _OnTripRadarState.secured;
      _nextTripRadarOffer = secured;
    });
    _waybills.secureNext(_buildNextWaybill(secured));
    _rideLifecycle.persistNow();
  }

  /// driver-r4-29: a next trip accepted but still "Matching" is secured
  /// now, before the current trip ends, so no exit drops it.
  void _flushNextTripMatch() {
    final offer = _nextTripRadarOffer;
    if (_nextTripRadarMatchTimer?.isActive != true || offer == null) {
      return;
    }
    _nextTripRadarMatchTimer!.cancel();
    if (mounted && _onTripRadarState == _OnTripRadarState.matching) {
      _secureNextTrip(offer);
    }
  }

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _syncWaitClock();
    _waitAnchorAt = widget.waitNow?.call() ?? DateTime.now();
    _waitAnchorSeconds = _waitSeconds;
    if (_liveUpdatesPaused) {
      return;
    }
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_countingWait) {
        return;
      }
      _rebuild(_syncWaitClock);
    });
  }

  void _syncWaitClock() {
    final anchor = _waitAnchorAt;
    if (!_countingWait || anchor == null) {
      return;
    }
    final now = widget.waitNow?.call() ?? DateTime.now();
    final elapsed = math.max(0, now.difference(anchor).inSeconds);
    _waitSeconds = math.max(_waitSeconds, _waitAnchorSeconds + elapsed);
  }

  /// Q6 (contract v0.18.7 `feeAmountsShown`): the driver's part of the
  /// no-show fee as the server set it at arrive (`waiting.noShowDriverShare`);
  /// the trip's terms before a server sends it.
  Money? get _noShowDriverShare =>
      _live?.waiting?.noShowDriverShare ??
      (_waitTerms.pricesKnown ? _waitTerms.driverNoShowFee : null);

  /// "Mark as no-show? You get 52 kr" / "… No fee"; no amount the phone
  /// does not know (no server terms).
  String get _noShowConfirmTitle {
    final share = _noShowDriverShare;
    if (share == null) return tr.cancelThisTripQuestion;
    return share.isZero
        ? tr.noShowConfirmNoFee
        : tr.noShowConfirmYouGet(share.formattedShort);
  }

  /// A no-show's earnings for the driver: their share of the no-show fee
  /// plus their share of the paid wait (the waiting sheet's words).
  String? get _noShowEarned {
    final fee = _noShowDriverShare;
    final wait = _waitTerms.driverWaitingFee(_paidWaitTotal);
    if (fee == null) return wait.minorUnits <= 0 ? null : wait.formatted;
    final total = wait.currency == fee.currency ? fee + wait : fee;
    return total.minorUnits <= 0 ? null : total.formatted;
  }

  Future<void> _submitTripCancellation(_TripCancellationReason reason) async {
    if (_cancellationInFlight ||
        _completionInFlight ||
        _handlingRiderCancellation) {
      return;
    }
    _cancellationInFlight = true;
    // Contract v0.3: a no-show is its own command and status; a driver
    // cancel before the rider is on board sends the trip back to dispatch
    // (`searching`), after that it is `cancelled_by_driver`.
    final noShow = reason.code == CancelReasons.current.noShow.code;
    final outcome = _rideLifecycle.driverTarget(
      noShow ? TripCommand.noShow : TripCommand.cancel,
    );
    if (outcome == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.thisTripCannotBeCancelledRight)),
        );
      }
      _cancellationInFlight = false;
      return;
    }
    if (LiveDriverServices.active &&
        (!await _AcceptRideLive(this)._serverStep(
              (trips) => noShow
                  ? trips.noShow(widget.tripId, reasonCode: reason.code)
                  : trips.cancel(widget.tripId, reasonCode: reason.code),
            ) ||
            !mounted ||
            _rideLifecycle.terminal)) {
      _cancellationInFlight = false;
      return;
    }
    try {
      _flushNextTripMatch();
      final secured = _onTripRadarState == _OnTripRadarState.secured
          ? _nextTripRadarOffer
          : null;
      await CompletionJournal(
        active: widget.activeRideRepository ?? MemoryActiveRideRepository(),
      ).finish(
        _ownWaybill(),
        pickupPoint: GeoPointMaps.fromLatLng(_pickupPosition),
        dropoffPoint: GeoPointMaps.fromLatLng(_dropoffPosition),
        status: outcome,
        cancellationReasonCode: reason.code,
        cancellationActor: 'driver',
        // driver-r5-13: the no-show fee share and paid wait the waiting
        // sheet told the driver they get.
        feeEarned: noShow ? _noShowEarned : null,
        next: secured == null ? null : _snapshotForOffer(secured),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.couldNotSaveCancellationRetry)),
        );
      }
      _cancellationInFlight = false;
      return;
    }
    if (await _yieldToAuthoritativeTerminal()) return;
    // The journal has already applied terminal cleanup and queued handoff.
    if (!await (noShow
        ? _rideLifecycle.noShow(clearSnapshot: false)
        : _rideLifecycle.cancel(clearSnapshot: false))) {
      _cancellationInFlight = false;
      return;
    }
    if (!mounted) {
      return;
    }
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _waybills.discardCurrent();

    final offer = _nextTripRadarOffer;
    final queuedNext =
        _onTripRadarState == _OnTripRadarState.secured && offer != null;
    final nextRide = queuedNext ? _nextRideFor(offer) : null;
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
              ? tr.firstTripEndedStartingNextOne
              : _stage == ActiveRideStage.onTrip
              ? tr.tripEndedEarlyTitle(reason.title)
              : tr.tripCancelledTitle(reason.title),
        ),
        backgroundColor: _AcceptRideState._ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    // Like every other trip exit: the session is free again, so Home takes
    // offers and the queued trip can begin.
    widget.sessionController?.stayOnlineAfterTrip();
    final navigator = _navigatorAtTripRoute();
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

  bool get _rideCheckWatching =>
      mounted &&
      _stage == ActiveRideStage.onTrip &&
      !_rideCheck.active &&
      !_rideLifecycle.terminal &&
      !_completionInFlight &&
      !_cancellationInFlight;

  /// Waiting at a stop or close to the next point is not a long stop.
  bool get _rideCheckAtPlannedStop {
    if (_paidStopWait) {
      return true;
    }
    final target = _routeTarget;
    return target != null &&
        GeoPointMaps.fromLatLng(
              _driverPosition,
            ).distanceMetersTo(GeoPointMaps.fromLatLng(target)) <=
            RideCheckRules.plannedStopRadiusMeters;
  }

  String? get _rideCheckPlace {
    final road = _navigation.snapshot.banner?.roadName?.trim();
    return road == null || road.isEmpty ? null : road;
  }

  /// driver-u86: GPS that went quiet (a tunnel, a garage) is lost, not a
  /// car standing still: the native stream sends a fix every second even
  /// when parked. On web the stream filters by distance, so quiet there
  /// means still and the last fix is current.
  bool get _rideCheckGpsFresh =>
      _hasLiveLocation &&
      (kIsWeb || _lastLocation?.isUsableAt(_rideCheckNow) == true);

  void _openRideCheck(RideCheckEvent? event) {
    if (event == null || !mounted) {
      return;
    }
    _rideCheckDetector.unwatched(); // the card stops the watch
    // The trigger is used for this trip: saved for a restore (u44).
    if (!event.demo) {
      unawaited(_rideLifecycle.persistNow());
    }
    unawaited(
      _rideCheck.open(event, instant: MediaQuery.disableAnimationsOf(context)),
    );
  }

  void _rideCheckPlan(RoadRoute route) {
    if (_stage != ActiveRideStage.onTrip || _paidStopWait) {
      return;
    }
    _demoDrive?.followRoad(route.points);
    _rideCheckDetector.planLeg(
      '$_stopCursor',
      route.points,
      route.durationSeconds,
      wholeTrip: _stopAddresses.isEmpty,
    );
  }

  void _rideCheckObserve() {
    if (!_rideCheckWatching || !_hasLiveLocation) {
      return;
    }
    _openRideCheck(
      _rideCheckDetector.observe(
        GeoPointMaps.fromLatLng(_driverPosition),
        _rideCheckNow,
        atPlannedStop: _rideCheckAtPlannedStop,
        place: _rideCheckPlace,
        destination: _onwardAddress,
      ),
    );
  }

  /// Finished far from drop-off: Finish tapped more than admin's km from
  /// the drop-off. Demo arrival is simulated, so its position says nothing about the drop-off,
  /// except on a RideCheck demo trip, whose scripted GPS is the trip's own.
  RideCheckEvent? _rideCheckFarDrop() {
    if (_rideCheckFinishDemo) {
      _rideCheckFinishDemo = false;
      return _rideCheck.active
          ? null
          : _rideCheckDetector.demo(
              RideCheckTrigger.droppedFar,
              _rideCheckNow,
              destination: _dropoffAddress,
            );
    }
    if ((_arrivalDemo && _demoDrive == null) ||
        _rideCheck.active ||
        !_hasLiveLocation ||
        _lastLocation?.isUsableAt(DateTime.now()) != true) {
      return null;
    }
    return _rideCheckDetector.finish(
      driver: GeoPointMaps.fromLatLng(_driverPosition),
      dropoff: GeoPointMaps.fromLatLng(_dropoffPosition),
      dropoffAddress: _dropoffAddress,
      at: _rideCheckNow,
    );
  }
}
