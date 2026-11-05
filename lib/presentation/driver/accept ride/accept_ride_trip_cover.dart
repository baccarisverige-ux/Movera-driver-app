part of 'accept_ride.dart';

// Rule 25 split (owner 2026-11-05 "Split first", fix job 5): moved word for
// word out of accept_ride_trip.dart (no behaviour change): pausing and
// resuming live updates while the trip is covered or hidden, and the
// waybill's driver and car identity.

extension _AcceptRideTripCover on _AcceptRideState {
  void _pauseLiveUpdatesMoved() {
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

  void _resumeLiveUpdatesMoved() {
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
  void _coverTripMoved() {
    _tripCovered = true;
    _nextTripRadarDemoTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
  }

  void _uncoverTripMoved() {
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
  void _menuChangedMoved(bool open) {
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
  void _hideTripMoved() {
    _tripHidden = true;
    _camera.suspend();
  }

  void _showTripMoved() {
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

  /// Waybills show the driver and the car as the server knows them
  /// (owner N11, live test 2026-10-26): the signed-in driver's name and
  /// the car on the profile (`vehicleId`, else the first car), never
  /// the demo's "Movera Driver" / "MVR 418". The demo keeps the local
  /// vehicle store, the same vehicle as Profile and Vehicles.
  Future<void> _loadVehicleIdentityMoved() async {
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
}
