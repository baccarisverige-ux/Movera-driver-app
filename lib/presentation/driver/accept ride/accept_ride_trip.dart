part of 'accept_ride.dart';

// Trip, realtime, and navigation orchestration for AcceptRide.
// The state object still owns timers, subscriptions, and the stage.
// This extension is the only place that advances that lifecycle.

extension _AcceptRideTrip on _AcceptRideState {
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

  /// The current trip's waybill with the waiting fee in its fare.
  WaybillRecord _paidWaybill() {
    final fee = _waitTerms.driverWaitingFee(_paidWaitTotal);
    return (_waybills.current ?? _buildCurrentWaybill()).copyWith(
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

  void _pauseLiveUpdates() {
    _camera.suspend();
    if (_liveUpdatesPaused) {
      return;
    }
    _syncWaitClock();
    _waitTimer?.cancel();
    _liveUpdatesPaused = true;
    _rideCheckDetector.unwatched(); // driver-u45
    // D-05: no next-trip offer comes or runs out while the driver cannot
    // see the trip; the offer up keeps its deadline for the resume.
    _nextTripRadarDemoTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
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
    if (!_liveUpdatesPaused) {
      return;
    }
    _liveUpdatesPaused = false;
    if (_countingWait) {
      _syncWaitClock();
      _startWaitTimer();
      _rebuild(() {});
    }
    if (!_tripHidden) {
      _camera.resume();
    }
    if (!MediaQuery.disableAnimationsOf(context) &&
        !_radarPulseController.isAnimating) {
      _radarPulseController.repeat(reverse: true);
    }
    if (!MediaQuery.disableAnimationsOf(context) &&
        !_radarSweepController.isAnimating) {
      _radarSweepController.repeat();
    }
    unawaited(_startLiveLocation());
    _resumeOnTripOffer();
  }

  /// D-05 / driver-u80: a route (History, Chat, Support, a sheet) covers
  /// the trip: no offer comes, the one up keeps its deadline.
  void _coverTrip() {
    _tripCovered = true;
    _nextTripRadarDemoTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
  }

  void _uncoverTrip() {
    if (!_tripCovered) {
      return;
    }
    _tripCovered = false;
    if (!_liveUpdatesPaused) {
      _resumeOnTripOffer();
    }
  }

  /// driver-r5-33: the side menu covers the trip like a route (as
  /// driver-u115 on Home): no offer comes and the one up keeps its
  /// deadline; when the menu closes it gets the time left, or leaves
  /// unseen (not a miss). Its own flag: a menu page pushed as the
  /// drawer closes keeps the trip covered through _tripCovered.
  void _menuChanged(bool open) {
    if (_menuOpen == open) {
      return;
    }
    _menuOpen = open;
    if (open) {
      _nextTripRadarDemoTimer?.cancel();
      _nextTripOfferExpiry?.cancel();
    } else if (!_liveUpdatesPaused) {
      _resumeOnTripOffer();
    }
  }

  /// driver-u59: no camera moves on the hidden map. Only a full screen
  /// hides it; under a sheet or a dialog the camera keeps following the
  /// car (driver-r5-31).
  void _hideTrip() {
    _tripHidden = true;
    _camera.suspend();
  }

  void _showTrip() {
    if (!_tripHidden) {
      return;
    }
    _tripHidden = false;
    if (!_liveUpdatesPaused) {
      _camera.resume();
    }
  }

  /// Next-trip offers wait: the app is hidden or a route covers the trip.
  bool get _offersHeld => _liveUpdatesPaused || _tripCovered || _menuOpen;

  /// D-05: back on screen. An offer whose time ran out while hidden
  /// leaves without counting as a miss (as on Home); one with time left
  /// counts down the rest. Radar then looks for the next one.
  void _resumeOnTripOffer() {
    if (!mounted ||
        _tripCovered ||
        _menuOpen ||
        _stage != ActiveRideStage.onTrip ||
        _rideLifecycle.terminal) {
      return;
    }
    if (_onTripRadarState == _OnTripRadarState.offerAvailable) {
      final deadline = _nextTripOfferDeadline;
      final left = deadline?.difference(_offerNow());
      if (left != null && left > Duration.zero) {
        _armOnTripOfferExpiry(left: left);
        return;
      }
      _nextTripOfferDeadline = null;
      _rebuild(() {
        _nextTripRadarOffer = null;
        _onTripRadarState = _OnTripRadarState.scanning;
      });
      _restoreRideSheet();
    }
    _maybeScheduleOnTripRadarDemoOffer();
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

  /// Waybills show the driver and the car as the server knows them
  /// (owner N11, live test 2026-10-26): the signed-in driver's name and
  /// the car on the profile (`vehicleId`, else the first car), never
  /// the demo's "Movera Driver" / "MVR 418". The demo keeps the local
  /// vehicle store, the same vehicle as Profile and Vehicles.
  Future<void> _loadVehicleIdentity() async {
    final live = DriverRuntimeScope.maybeOf(context)?.account;
    if (live != null) {
      await _loadLiveIdentity(live);
    } else {
      final identity = await LocalVehicleStore().primaryIdentity();
      if (!mounted || identity == null) {
        return;
      }
      _vehicleLabel = identity.vehicle;
      _vehiclePlate = identity.plate;
    }
    if (!mounted) {
      return;
    }
    for (final (record, apply) in [
      (_waybills.current, _waybills.beginCurrent),
      (_waybills.next, _waybills.secureNext),
    ]) {
      if (record != null &&
          (record.vehicle != _vehicleLabel ||
              record.licensePlate != _vehiclePlate ||
              record.driverName != _driverName) &&
          (record.tripId == widget.tripId ||
              record.tripId == _nextTripRadarOffer?.id)) {
        apply(
          record.copyWith(
            vehicle: _vehicleLabel,
            licensePlate: _vehiclePlate,
            driverName: _driverName,
          ),
        );
      }
    }
  }

  Future<void> _loadLiveIdentity(DriverAccountSession live) async {
    var account = live.account;
    if (account == null) {
      try {
        account = await live.refresh();
      } catch (_) {
        /* offline: the name stays */
      }
    }
    if (!mounted) {
      return;
    }
    final name = account?.fullName ?? '';
    if (name.isNotEmpty) {
      _driverName = name;
    }
    try {
      final cars = await live.repository.vehicles();
      if (!mounted || cars.isEmpty) {
        return;
      }
      final car = cars.firstWhere(
        (c) => c.vehicleId == account?.vehicleId,
        orElse: () => cars.first,
      );
      _vehicleLabel = car.title;
      _vehiclePlate = car.plate;
    } catch (error) {
      DriverLog.warn('waybill car not read: $error', name: 'live');
    }
  }

  /// The completed trip's waybill and, for cash, what was collected:
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
      paid = paid.copyWith(
        fare: money.driverPay.formatted,
        riderFare: money.riderFare.formatted,
        waitingFee: money.waitingFee?.formatted,
        clearWaitingFee: money.waitingFee == null,
      );
      if (widget.paidByCash) {
        cash = money.cash.formatted;
      }
    }
    return (paid: paid, cash: cash);
  }

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
        return;
    }
  }

  Future<void> _resyncTrip() async {
    try {
      await _realtime.reconnectAndResync(widget.tripId);
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

  /// Contract v0.18.8 `waiting.alerts` (owner G6 decision 6): the first
  /// time a kind appears on this trip the island says it once, with no
  /// sound; the newest new kind wins. Alerts already there when the screen
  /// opens ([initial]) are marked as said, never replayed.
  String? _newWaitingAlert(TripWaitingNow? waiting, {required bool initial}) {
    if (waiting == null) return null;
    String? line;
    for (final kind in const [
      TripWaitingNow.paidWaitingStarted,
      TripWaitingNow.noShowPossible,
    ]) {
      if (!waiting.alerts.contains(kind) || !_waitingAlertsShown.add(kind)) {
        continue;
      }
      if (initial) continue;
      line = kind == TripWaitingNow.noShowPossible
          ? tr.g6AlertNoShow
          : tr.g6AlertPaid;
    }
    return _stage == ActiveRideStage.waitingForRider ? line : null;
  }

  /// Status item 4 (contract v0.18.7 `pickupMove`): the rider moved the
  /// pickup (at most `terms.maxPickupMoveMeters`): the route, the pin, the
  /// waybill and the saved trip follow it.
  void _afterPickupMoved() {
    if (!mounted) return;
    final current = _waybills.current;
    if (current != null && current.tripId == widget.tripId) {
      _waybills.beginCurrent(current.copyWith(pickup: _pickupAddress));
    }
    _rideLifecycle.persistNow();
    if (_stage == ActiveRideStage.headingToPickup) {
      unawaited(_refreshRoadRoute(force: true));
      unawaited(_fitRoute());
    }
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

  Future<void> _drainProjection() async {
    if (!mounted || _drainingProjection || _pendingProjection == null) {
      return;
    }
    // Given to another driver here (late ETA): the trip is over for this
    // phone while it leaves; a later event must not journal it.
    if (_releasedForLateEta) {
      _pendingProjection = null;
      return;
    }
    if (_rideLifecycle.saving ||
        _completionInFlight ||
        _cancellationInFlight ||
        _stageTransitioning) {
      _projectionRetry ??= Timer(const Duration(milliseconds: 100), () {
        _projectionRetry = null;
        unawaited(_drainProjection());
      });
      return;
    }
    _drainingProjection = true;
    final event = _pendingProjection!;
    final status = event.kind == DriverRealtimeKind.riderCancelled
        ? TripStatus.cancelledByRider
        : event.status!;
    try {
      if (status == TripStatus.cancelledByRider) {
        // Q6 (contract v0.18.7): what the driver gets is
        // `cancellation.driverShare`. `cancelFee` is the RIDER's fee: it is
        // never shown as the driver's money (checker round 1); only "no
        // fee" (zero) is safe to say from it.
        final cancellation = event.live?.cancellation;
        final riderFeeZero = event.cancelFee?.isZero == true
            ? event.cancelFee
            : null;
        await _handleRiderCancelled(
          fee: cancellation == null ? riderFeeZero : cancellation.driverEarns,
          feeKind: cancellation?.feeKind,
          riderFee: cancellation?.fee,
        );
      } else if (status.isTerminal) {
        _flushNextTripMatch();
        final secured = _onTripRadarState == _OnTripRadarState.secured
            ? _nextTripRadarOffer
            : null;
        final next = secured == null ? null : _snapshotForOffer(secured);
        // A completed trip keeps what the driver's own finish records: the
        // waiting fee and, for cash, what was collected.
        final completed = status == TripStatus.completed;
        final cash = completed && widget.paidByCash;
        final settled = completed ? _settledPaid() : null;
        await CompletionJournal(
          active: widget.activeRideRepository ?? MemoryActiveRideRepository(),
        ).finish(
          settled?.paid ?? _waybills.current ?? _buildCurrentWaybill(),
          pickupPoint: GeoPointMaps.fromLatLng(_pickupPosition),
          dropoffPoint: GeoPointMaps.fromLatLng(_dropoffPosition),
          status: status,
          authoritative: true,
          next: next,
          paymentMethod: completed ? (cash ? 'Cash' : 'Card') : null,
          cashCollected: cash ? settled?.cash : null,
        );
        if (!mounted) {
          return;
        }
        if (!await _rideLifecycle.applyProjection(status)) {
          // driver-r3-12: a background save (GPS snapshot, lock screen)
          // that started during the journal holds the lifecycle; retry
          // unless this outcome is already applied.
          if (_rideLifecycle.terminalStatus != status) {
            _scheduleProjectionRetry();
          }
          return;
        }
        if (identical(event, _pendingProjection)) {
          _pendingProjection = null;
        }
        _projectionRetryDelay = _AcceptRideState._projectionRetryBase;
        await _leaveAfterAuthoritativeOutcome(status, next, settled?.paid);
        return;
      } else if (status.isReleasedToDispatch) {
        // X5: admin reassign or a released reservation. Already over here
        // (the echo of this driver's own cancel): nothing more to do.
        if (!_rideLifecycle.terminal) {
          if (!await _rideLifecycle.applyProjection(status)) {
            _scheduleProjectionRetry();
            return;
          }
        }
        if (identical(event, _pendingProjection)) {
          _pendingProjection = null;
        }
        _projectionRetryDelay = _AcceptRideState._projectionRetryBase;
        if (_rideLifecycle.terminalStatus == status && !_cancellationInFlight) {
          await _leaveAfterRelease(status);
        }
        return;
      } else {
        final before = _stage;
        if (!await _rideLifecycle.applyProjection(status)) {
          return;
        }
        // A same-stage projection (in_trip, approaching_dropoff) changes
        // nothing here: the next-trip radar, route and camera stay.
        if (mounted) {
          _rebuild(() {});
          if (_stage != before) {
            _resumeStageSideEffects();
          }
        }
      }
      if (status == TripStatus.cancelledByRider && !_rideLifecycle.terminal) {
        _scheduleProjectionRetry();
        return;
      }
      if (identical(event, _pendingProjection)) {
        _pendingProjection = null;
      }
      _projectionRetryDelay = _AcceptRideState._projectionRetryBase;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.tripUpdateCouldNotBeSaved),
            action: SnackBarAction(
              label: tr.retryNow,
              onPressed: () => unawaited(_drainProjection()),
            ),
          ),
        );
      }
      _scheduleProjectionRetry();
    } finally {
      _drainingProjection = false;
      // driver-u70: a newer event that came in while this one drained was
      // turned away by the guard above; drain it now.
      if (mounted &&
          _projectionRetry == null &&
          _pendingProjection != null &&
          !identical(event, _pendingProjection)) {
        unawaited(_drainProjection());
      }
    }
  }

  /// An authoritative terminal outcome must not depend on the driver seeing
  /// a SnackBar. Retry with bounded backoff until it is applied.
  void _scheduleProjectionRetry() {
    if (!mounted || _pendingProjection == null || _projectionRetry != null) {
      return;
    }
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
  /// [paid] is the completed trip's waybill, null for any other outcome.
  Future<void> _leaveAfterAuthoritativeOutcome(
    TripStatus status,
    PersistedActiveRide? next,
    WaybillRecord? paid,
  ) async {
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _pauseLiveUpdates();
    if (paid != null) {
      // Home's last trip is this one, as after the driver's own finish.
      _waybills.beginCurrent(paid);
      _waybills.completeCurrent();
    } else {
      _waybills.discardCurrent();
    }
    await showTripOutcomeSheet(context, status: status, hasNext: next != null);
    if (!mounted) {
      return;
    }
    widget.sessionController?.stayOnlineAfterTrip();
    final navigator = _navigatorAtTripRoute();
    if (next != null) {
      _waybills.promoteNextToCurrent();
      navigator.pushReplacement(
        BottomToTopTransition(
          AcceptRide.fromPersisted(
            next,
            waybillRepository: _waybills,
            sessionController: widget.sessionController,
            locationRepository: widget.locationRepository,
            routeRepository: widget.routeRepository,
            activeRideRepository: widget.activeRideRepository,
            dispatchRepository: widget.dispatchRepository,
          ),
        ),
      );
      return;
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
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

  /// [fee]: the driver's part of the cancel fee from the backend (R15-7,
  /// v0.18.7 `cancellation.driverShare`), if decided. [feeKind] (Q2):
  /// `cancel` or `no_show`, the rule that set the rider's [riderFee].
  Future<void> _handleRiderCancelled({
    Money? fee,
    String? feeKind,
    Money? riderFee,
  }) async {
    if (!mounted || _handlingRiderCancellation || _releasedForLateEta) {
      return;
    }

    _handlingRiderCancellation = true;
    final wasOnTrip = _stage == ActiveRideStage.onTrip;

    if (_completionInFlight || _cancellationInFlight) {
      _handlingRiderCancellation = false;
      return;
    }
    _flushNextTripMatch();
    final secured = _onTripRadarState == _OnTripRadarState.secured
        ? _nextTripRadarOffer
        : null;
    final next = secured == null ? null : _snapshotForOffer(secured);
    try {
      await CompletionJournal(
        active: widget.activeRideRepository ?? MemoryActiveRideRepository(),
      ).finish(
        _waybills.current ?? _buildCurrentWaybill(),
        pickupPoint: GeoPointMaps.fromLatLng(_pickupPosition),
        dropoffPoint: GeoPointMaps.fromLatLng(_dropoffPosition),
        status: TripStatus.cancelledByRider,
        authoritative: true,
        // The rider's own reason code is not sent to the driver yet.
        cancellationActor: 'rider',
        // The fee the island tells the driver they earn (driver-r5-13).
        feeEarned: fee == null || fee.minorUnits <= 0 ? null : fee.formatted,
        next: next,
      );
      if (!mounted) {
        return;
      }
      if (!await _rideLifecycle.applyProjection(TripStatus.cancelledByRider)) {
        _handlingRiderCancellation = false;
        return;
      }
    } catch (_) {
      _handlingRiderCancellation = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.couldNotSaveRiderCancellationRetry),
            action: SnackBarAction(
              label: tr.retry,
              onPressed: () {
                _handleRiderCancelled(
                  fee: fee,
                  feeKind: feeKind,
                  riderFee: riderFee,
                );
              },
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _pauseLiveUpdates();

    _waybills.discardCurrent();

    // Back to Home when it is underneath: its island tells the driver.
    final home = _navigatorAtTripRoute();
    if (next == null && home.canPop()) {
      IslandMessages.show(
        HomeIslandNotices.riderCancelledWithFee(
          fee,
          onTrip: wasOnTrip,
          feeKind: riderFee != null && !riderFee.isZero ? feeKind : null,
        ),
      );
      widget.sessionController?.stayOnlineAfterTrip();
      home.pop();
      return;
    }

    await showRiderCancelledSheet(
      context,
      riderName: _riderName,
      wasOnTrip: wasOnTrip,
      fee: fee,
      feeKind: feeKind,
      riderFee: riderFee,
    );
    if (!mounted) {
      return;
    }

    widget.sessionController?.stayOnlineAfterTrip();
    final navigator = _navigatorAtTripRoute();
    if (next != null) {
      _waybills.promoteNextToCurrent();
      navigator.pushReplacement(
        BottomToTopTransition(
          AcceptRide.fromPersisted(
            next,
            waybillRepository: _waybills,
            sessionController: widget.sessionController,
            locationRepository: widget.locationRepository,
            routeRepository: widget.routeRepository,
            activeRideRepository: widget.activeRideRepository,
            dispatchRepository: widget.dispatchRepository,
          ),
        ),
      );
      return;
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
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

  void _blockedArrival() {
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

  /// A last fix exists but is too old to judge the distance; the arrival
  /// tap asks for a fresh one (G7 live fix). No fix at all is not aged.
  bool get _arrivalFixAged =>
      _arrivalTarget != null &&
      _lastLocation != null &&
      _lastLocation?.isUsableAt(DateTime.now()) != true;

  Future<void> _onArrivedTap() async {
    if (!_nearArrivalTarget && _arrivalFixAged) {
      // G7 live fix: a parked phone (a browser above all) may send no new
      // fix while it stands still, so the last one ages past its 30 s and
      // the tap was refused although the car is at the stop. Ask for one
      // fresh fix before saying no (only for an aged fix: no fix at all
      // says "location unavailable" at once). A missing road route never blocks.
      await _freshFixForArrival();
      if (!mounted) return;
    }
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
        _stopCursor < _stopAddresses.length) {
      // Contract v0.7.1 §3.8: the server charges the stop wait from this
      // tap, so a live build tells it first.
      final stop = _stopCursor;
      if (LiveDriverServices.active &&
          (!await _AcceptRideLive(this)._serverStep(
                (trips) => trips.arriveAtStop(widget.tripId, stop),
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

  Future<void> _confirmPickupArrival() async {
    if (_stageTransitioning ||
        !mounted ||
        _rideLifecycle.terminal ||
        _stage != ActiveRideStage.headingToPickup) {
      return;
    }

    _stageTransitioning = true;
    if (LiveDriverServices.active &&
        (!await _AcceptRideLive(
              this,
            )._serverStep((trips) => trips.arrive(widget.tripId)) ||
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

  /// The map's route lines for the route, the car's progress and zoom.
  void _syncRouteLines() => _routeLines.sync(
    _roadGeoPoints,
    _camera.alongMetersOn(_roadGeoPoints),
    _routeZoomStep,
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
        preview = await trips.previewComplete(widget.tripId);
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
      fare: preview?.driverEarnings?.formatted ?? _fareWithWaiting,
      cash: preview?.cashDue.formatted ?? _cashToCollect,
      riderName: _riderName,
      category: widget.category,
      recalculated: preview?.earlyEnd ?? false,
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
    _completionInFlight = false;
    _cancellationInFlight = false;
    _stageTransitioning = false;
    await _drainProjection();
    return true;
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
        (!await _AcceptRideLive(this)._serverStep(
              (trips) => trips.complete(
                widget.tripId,
                preview: trips.previewOf(widget.tripId),
                cash: widget.paidByCash,
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
      _waybills.beginCurrent(paid);
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
        return;
      }
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
    final nextRide = queuedNext ? _nextRideFor(offer) : null;
    Navigator.of(context).pushReplacement(
      BottomToTopTransition(
        DriverRideCompleted(
          waybillRepository: _waybills,
          sessionController: widget.sessionController,
          activeRideRepository: widget.activeRideRepository,
          nextRide: nextRide,
          paidByCash: widget.paidByCash,
        ),
      ),
    );
  }

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

  Future<void> _refreshOnTripRoute({bool fitCamera = false}) async {
    await _refreshRoadRoute(force: true);
    if (!mounted || _stage != ActiveRideStage.onTrip) {
      return;
    }
    if (fitCamera) {
      await _fitRoute();
    }
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
      demo: !driverProductionRequested,
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
        _waybills.current ?? _buildCurrentWaybill(),
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
