part of 'accept_ride.dart';

/// Read-only getters of the trip screen state (moved from accept_ride.dart, no change).
extension _AcceptRideStateGetters on _AcceptRideState {
  LatLng? get _routeTarget {
    if (_stage == ActiveRideStage.onTrip &&
        _stopCursor < _stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    if (_stage == ActiveRideStage.onTrip) {
      return _dropoffPosition;
    }
    return _pickupPosition;
  }

  bool get _arrivalDemo => DriverRuntimeConfig.current.simulatedArrival;

  /// A RideCheck demo trip: its scripted GPS is the trip's own position.
  DemoTripDrive? get _demoDrive {
    final location = _locationService;
    return location is DemoTripDrive ? location : null;
  }

  LatLng? get _arrivalTarget {
    if (_stage == ActiveRideStage.headingToPickup) {
      return _pickupPosition;
    }
    if (_stage == ActiveRideStage.onTrip &&
        !_paidStopWait &&
        _stopCursor < _stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    return null;
  }

  bool get _nearArrivalTarget {
    final target = _arrivalTarget;
    if (target == null) {
      return false;
    }
    if (_arrivalDemo) {
      return true;
    }
    if (!_hasLiveLocation ||
        _lastLocation?.isUsableAt(DateTime.now()) != true) {
      return false;
    }
    return GeoPointMaps.fromLatLng(
          _driverPosition,
        ).distanceMetersTo(GeoPointMaps.fromLatLng(target)) <=
        100;
  }

  bool get _countingWait =>
      _stage == ActiveRideStage.waitingForRider || _paidStopWait;

  LatLng? get _approachTarget {
    if (_stage == ActiveRideStage.headingToPickup ||
        _stage == ActiveRideStage.waitingForRider) {
      return _pickupPosition;
    }
    if (_stage == ActiveRideStage.onTrip &&
        _stopCursor < _stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    if (_stage == ActiveRideStage.onTrip) {
      return _dropoffPosition;
    }
    return null;
  }

  ArrivalPointKind get _approachKind {
    if (_stage == ActiveRideStage.headingToPickup ||
        _stage == ActiveRideStage.waitingForRider) {
      return ArrivalPointKind.pickup;
    }
    if (_stopCursor < _stopAddresses.length) {
      return ArrivalPointKind.stop;
    }
    return ArrivalPointKind.destination;
  }

  String get _approachLabel {
    return switch (_approachKind) {
      ArrivalPointKind.pickup => tr.pickup,
      ArrivalPointKind.stop => tr.stopNumber(_stopCursor + 1),
      ArrivalPointKind.destination => tr.destination,
    };
  }

  String get _approachAddress {
    return switch (_approachKind) {
      ArrivalPointKind.pickup => _pickupAddress,
      ArrivalPointKind.stop => _stopAddresses[_stopCursor],
      ArrivalPointKind.destination => _dropoffAddress,
    };
  }

  double? get _approachDistanceMeters {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return 0;
    }
    final target = _approachTarget;
    if (target == null ||
        !_hasLiveLocation ||
        _lastLocation?.isUsableAt(DateTime.now()) != true) {
      return null;
    }
    return GeoPointMaps.fromLatLng(
      _driverPosition,
    ).distanceMetersTo(GeoPointMaps.fromLatLng(target));
  }

  bool get _showArrivalApproach {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return true;
    }
    final distance = _approachDistanceMeters;
    return distance != null &&
        distance <= _AcceptRideState._arrivalApproachThresholdMeters;
  }

  bool get _arrivalApproachArrived {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return true;
    }
    final distance = _approachDistanceMeters;
    return distance != null && distance <= 25;
  }

  bool get _allowExternalRouting => DriverRuntimeConfig.current.externalRouting;

  /// One line under the time and distance in the collapsed trip bar.
  String get _tripBarStatus {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return tr.pickingUpRiderName(_riderName);
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? tr.riderNameIsOnWay(_riderName)
            : tr.waitingForRiderName(_riderName);
      case ActiveRideStage.onTrip:
        if (_paidStopWait) {
          return tr.waitingAtStopNumber(_stopCursor + 1);
        }
        if (_stopCursor < _stopAddresses.length) {
          return tr.headingToStopNumber(_stopCursor + 1);
        }
        return tr.droppingOffRiderName(_riderName);
    }
  }

  /// First line of the trip sheet: the next thing to do.
  String get _tripBarInstruction {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return tr.pickUpRiderName(_riderName);
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? tr.riderNameIsOnWay(_riderName)
            : tr.waitingForRiderName(_riderName);
      case ActiveRideStage.onTrip:
        if (_paidStopWait) {
          return tr.waitingAtStopNumber(_stopCursor + 1);
        }
        if (_stopCursor < _stopAddresses.length) {
          return tr.driveToStopNumber(_stopCursor + 1);
        }
        return tr.dropOffRiderName(_riderName);
    }
  }

  /// Second line: where. Location problems show on the island.
  String get _tripBarAddress => _nextStopAddress;

  /// Share of the way to the next point already driven; null while
  /// waiting or before a road route exists.
  double? get _legFraction {
    if (_countingWait || _routeDurationSeconds == null) {
      return null;
    }
    final remaining = _remainingMeters;
    if (remaining == null) {
      return null;
    }
    // Measured against the longest distance seen on this step, so a
    // reroute from the driver's new position does not reset the line.
    final key = '${_stage.name}-$_stopCursor';
    if (_legKey != key || remaining > _legTotalMeters) {
      _legKey = key;
      _legTotalMeters = remaining;
    }
    if (_legTotalMeters <= 0) {
      return null;
    }
    return (1 - remaining / _legTotalMeters).clamp(0.0, 1.0);
  }

  /// Road distance still to drive to the next point.
  double? get _remainingMeters {
    final total = _navigation.route?.distanceMeters;
    if (total == null || total <= 0) {
      return null;
    }
    return total * (1 - (_navigation.routeFraction ?? 0));
  }

  bool get _tripEndedTooQuickly {
    final started = _onTripStartedAt;
    if (started == null) {
      return false;
    }
    return DateTime.now().difference(started) < const Duration(seconds: 90);
  }

  bool get _pendingTerminal =>
      _pendingProjection?.kind == DriverRealtimeKind.riderCancelled ||
      _pendingProjection?.status?.isTerminal == true;

  bool get _onTripRadarOn =>
      _onTripRadarState == _OnTripRadarState.scanning ||
      _onTripRadarState == _OnTripRadarState.offerAvailable ||
      _onTripRadarState == _OnTripRadarState.matching ||
      _onTripRadarState == _OnTripRadarState.secured;

  /// driver-u60: one trip id per offer, so a cancelled next trip and a
  /// later one never share a history row or terminal marker.
  _NextTripRadarOffer get _uniqueDemoNext => _NextTripRadarOffer(
    id: tripOccurrenceId('${widget.tripId}-next'),
    category: _AcceptRideState._demoNextTripOffer.category,
    fare: _AcceptRideState._demoNextTripOffer.fare,
    rating: _AcceptRideState._demoNextTripOffer.rating,
    pickupMinutes: _AcceptRideState._demoNextTripOffer.pickupMinutes,
    pickupKm: _AcceptRideState._demoNextTripOffer.pickupKm,
    tripMinutes: _AcceptRideState._demoNextTripOffer.tripMinutes,
    riderName: _AcceptRideState._demoNextTripOffer.riderName,
    pickup: _AcceptRideState._demoNextTripOffer.pickup,
    dropoff: _AcceptRideState._demoNextTripOffer.dropoff,
    pickupPosition: _AcceptRideState._demoNextTripOffer.pickupPosition,
    dropoffPosition: _AcceptRideState._demoNextTripOffer.dropoffPosition,
  );

  bool get _incomingOfferOpen =>
      _stage == ActiveRideStage.onTrip &&
      _onTripRadarState == _OnTripRadarState.offerAvailable &&
      _nextTripRadarOffer != null;

  /// Q24: the last leg of a cash trip, cash not collected yet: the main
  /// button is "Collect cash" instead of the slide.
  bool get _collectsCashNow =>
      widget.paidByCash &&
      _stage == ActiveRideStage.onTrip &&
      !_paidStopWait &&
      _stopCursor >= _stopAddresses.length;

  /// R8-4: the cash taken from the rider; the fare unless a promotion
  /// changed it.
  String get _cashToCollect => WaitingTerms.addFee(
    widget.cashToCollect ?? _AcceptRideTrip(this)._riderFare,
    _waitTerms.waitingFee(_AcceptRideTrip(this)._paidWaitTotal),
  );
  int get _includedWaitSeconds => _waitTerms.freeSeconds;
  // G6 `terms.stopFreeWaitMin` in seconds.
  int get _stopFreeSeconds => (_live?.terms?.stopFreeWaitMinutes ?? 0) * 60;
  int get _noShowWaitSeconds => _waitTerms.noShowSeconds;

  bool get _inIncludedWait =>
      !_paidStopWait && _waitSeconds < _includedWaitSeconds;

  String get _waitBarStatus {
    if (_paidStopWait) return _AcceptRideRouteChange(this)._stopWaitStatus();
    if (_inIncludedWait) {
      return tr.includedWaitThenPaid;
    }
    if (_waitSeconds < _noShowWaitSeconds) {
      return tr.paidWaitRunning;
    }
    return tr.paidWaitNoShowAvailable;
  }

  /// Share of the pickup wait window used (free minutes, then paid up to
  /// the no-show point); null at a stop, where waiting is paid throughout.
  Color get _waitBarColor {
    if (_inIncludedWait) {
      return _AcceptRideState._ink;
    }
    if (!_paidStopWait && _waitSeconds >= _noShowWaitSeconds) {
      return const Color(0xFF9E2B33);
    }
    return const Color(0xFF146B45);
  }

  String get _slideLabel {
    // Q30: the main trip buttons read admin's Driver app texts.
    if (_paidStopWait) {
      final next = _stopCursor + 2;
      if (next <= _stopAddresses.length) {
        return driverText(DriverTexts.tripGoToStop, {
          'stop': _AcceptRideTrip(this)._stopWord(next),
        });
      }
      return driverText(DriverTexts.tripGoToDropoff);
    }
    return driverText(switch (_stage) {
      ActiveRideStage.headingToPickup => DriverTexts.tripArrived,
      ActiveRideStage.waitingForRider =>
        _stopAddresses.isEmpty
            ? DriverTexts.tripStart
            : DriverTexts.tripStartFirstStop,
      ActiveRideStage.onTrip =>
        _stopCursor < _stopAddresses.length
            ? DriverTexts.tripArriveAtStop
            : DriverTexts.tripComplete,
    });
  }

  String get _slideConfirmedLabel {
    if (_paidStopWait) {
      return _stopCursor + 1 < _stopAddresses.length
          ? tr.nextStop
          : tr.toDropOff;
    }
    return switch (_stage) {
      ActiveRideStage.headingToPickup => tr.waiting,
      ActiveRideStage.waitingForRider => tr.tripStarted,
      ActiveRideStage.onTrip => tr.tripCompleted,
    };
  }

  String get _onwardAddress {
    if (_stopCursor < _stopAddresses.length &&
        (_stage == ActiveRideStage.onTrip ||
            _stage == ActiveRideStage.waitingForRider)) {
      return _stopAddresses[_stopCursor];
    }
    return _dropoffAddress;
  }

  String get _nextStopAddress {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return _pickupAddress;
      case ActiveRideStage.waitingForRider:
      case ActiveRideStage.onTrip:
        return _onwardAddress;
    }
  }
}
