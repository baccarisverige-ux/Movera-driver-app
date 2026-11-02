part of 'accept_ride.dart';

/// Contract v0.18.9 (driver group 7, `contract.json#onTrip`): what the trip
/// screen does with the projection's `rideCheck` and `routeChange`.
///
/// - Decision 1: the server's "Is everything OK?" (`srv_…`) opens the same
///   Ride check card as the app's own checks; the answer goes to
///   `POST /driver/trips/{id}/ride-check` with the server's checkId.
/// - Decision 3: a pending route change shows [RouteChangeSheet]; an
///   accepted one moves the drop-off and stops (navigation follows); a
///   refused, expired or withdrawn one says so once on the island.
typedef _ChangedRoute = ({
  String dropoffAddress,
  LatLng dropoff,
  List<String> stops,
  List<LatLng> stopPoints,
  String? fare,
  String? riderFare,
});

extension _AcceptRideRouteChange on _AcceptRideState {
  // An accepted change replaces the drop-off and the stops; until then the
  // trip runs on what it was opened with.
  LatLng get _dropoffPosition =>
      _changedRoute?.dropoff ?? widget.dropoffPosition;
  String get _dropoffAddress =>
      _changedRoute?.dropoffAddress ?? widget.dropoffAddress;
  List<String> get _stopAddresses =>
      _changedRoute?.stops ?? widget.stopAddresses;
  List<LatLng> get _stopPositions =>
      _changedRoute?.stopPoints ?? widget.stopPositions;

  /// The driver's earnings: the accepted change's new earnings, else the
  /// trip's own.
  String get _fare => _changedRoute?.fare ?? widget.fare;

  /// G7 decision 4 (`terms.stopWaitPerMin`): the stop's price per minute
  /// from the first minute (or after its free ones).
  String _stopWaitStatus() {
    final free = _live?.terms?.stopFreeWaitMinutes ?? 0;
    final perMin = _live?.terms?.stopWaitPerMin?.formatted;
    if (free > 0 && _waitSeconds < _stopFreeSeconds) {
      return perMin == null
          ? tr.g6StopFreeWait(free)
          : tr.g7StopFree(free, perMin);
    }
    final paid = tr.paidWaitAtStopNumber(_stopCursor + 1);
    return perMin == null ? paid : '$paid · ${tr.g7StopPrice(perMin)}';
  }

  /// [initial]: the trip as the server had it when the screen opened (a
  /// restart): an accepted change is applied again without an island line.
  void _onTripExtras(TripLiveDetails next, {bool initial = false}) {
    final check = next.rideCheck;
    if (check != null &&
        !_rideLifecycle.terminal &&
        check.openForDriver(DateTime.now().toUtc()) &&
        _serverChecksOpened.add(check.checkId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openServerRideCheck(check),
      );
    }
    _adoptServerStopArrival(next);
    final change = next.routeChange;
    if (change == null || change.pending) return;
    if (!_routeChangesSeen.add('${change.changeId}:${change.status}')) return;
    if (change.accepted) _applyChangedRoute(change);
    final line = routeChangeIslandLine(change);
    if (line == null || initial) return;
    if (!mounted) return;
    _rebuild(() {
      _islandNotice = line;
      _islandNoticeKey++;
    });
  }

  /// G7 live fix 2: the server's read at restore was applied before the
  /// saved stop / wait replaced it; the server's stop visits win, and a
  /// device-copy restore reads the trip once.
  void _restoreServerStops() {
    if (_live case final live?) _adoptServerStops(live);
    unawaited(_readServerStopsAtRestore());
  }

  /// G7 live fix 2 (restore): the server's stop visits. Stops it says
  /// were left are behind the driver; the stop it says the driver is at
  /// starts the stop wait (`stops[i].arrivedAt`).
  void _adoptServerStops(TripLiveDetails live) {
    final visits = live.stopVisits ?? const <TripStopVisit>[];
    var left = 0;
    while (left < visits.length &&
        left < _stopAddresses.length &&
        visits[left].leftAt != null) {
      left++;
    }
    if (left > _stopCursor) {
      _stopCursor = left;
      _paidStopWait = false;
    }
    _adoptServerStopArrival(live);
  }

  /// G7 live fix 2: a reopened app that restored the trip from the device
  /// copy has no server read yet (the event stream does not replay the
  /// stop visits): read the trip once so the server's stop arrival wins.
  Future<void> _readServerStopsAtRestore() async {
    if (widget.restoredSnapshot == null || _stopAddresses.isEmpty) return;
    final trips = LiveDriverServices.instance?.trips;
    if (trips == null) return;
    final projection = await trips.refresh(widget.tripId);
    if (!mounted || projection == null || _rideLifecycle.terminal) return;
    final live = TripLiveDetails.fromProjection(projection);
    _AcceptRideTrip(this)._applyLive(live);
    _adoptServerStops(live);
  }

  /// G7 live fix: a stop arrival the server recorded (this phone's tap on
  /// another try, another device, the API) starts the stop wait here too,
  /// counted from the server's `arrivedAt`, so the stop-wait line shows
  /// from minute 1.
  void _adoptServerStopArrival(TripLiveDetails next) {
    if (_rideLifecycle.terminal ||
        _stage != ActiveRideStage.onTrip ||
        _paidStopWait ||
        _stopCursor >= _stopAddresses.length) {
      return;
    }
    final arrivedAt = next.openStopArrival(_stopCursor);
    if (arrivedAt == null) return;
    final now = (widget.waitNow?.call() ?? DateTime.now()).toUtc();
    _rebuild(() {
      _paidStopWait = true;
      _waitSeconds = math.max(0, now.difference(arrivedAt).inSeconds);
      _waitAnchorAt = null;
      _startWaitTimer();
    });
    unawaited(_rideLifecycle.persistNow());
  }

  void _openServerRideCheck(TripRideCheck check) {
    if (!mounted || _rideLifecycle.terminal || _rideCheck.active) return;
    final (trigger, reason) = serverRideCheckReason(
      check,
      RideCheckAdminConfig.current,
      _dropoffAddress,
    );
    _rideCheckDetector.unwatched();
    unawaited(
      _rideCheck.open(
        RideCheckEvent(
          trigger: trigger,
          reason: reason,
          at: check.askedAt ?? DateTime.now().toUtc(),
        ),
        instant: MediaQuery.disableAnimationsOf(context),
        serverCheckId: check.checkId,
      ),
    );
  }

  /// The pending change this phone has not answered yet, while time is left.
  TripRouteChange? get _pendingRouteChange {
    final change = _live?.routeChange;
    if (change == null || !change.pending || _rideLifecycle.terminal) {
      return null;
    }
    if (_routeChangesSeen.contains('${change.changeId}:answered')) return null;
    if (change.answerBy != null &&
        change.secondsLeft(DateTime.now().toUtc()) <= 0) {
      return null;
    }
    return change;
  }

  Future<void> _answerRouteChange(TripRouteChange change, bool accept) async {
    final trips = _liveTrips;
    if (trips == null) {
      // The demo: answered here, as the server would.
      _routeChangesSeen.add('${change.changeId}:answered');
      _onTripExtras(
        TripLiveDetails(
          routeChange: TripRouteChange(
            changeId: change.changeId,
            status: accept ? 'accepted' : 'refused',
            dropoff: change.dropoff,
            stops: change.stops,
            answeredBy: 'driver',
          ),
        ),
      );
      return;
    }
    final outcome = await trips.answerRouteChange(
      widget.tripId,
      changeId: change.changeId,
      accept: accept,
    );
    if (!mounted) return;
    if (!outcome.ok) {
      _showServerRefusal(outcome.message!);
      // The newest state (expired, withdrawn) comes with the refusal.
      if (trips.projectionOf(widget.tripId) case final known?) {
        _AcceptRideTrip(this)._applyLive(TripLiveDetails.fromProjection(known));
      }
      return;
    }
    _routeChangesSeen.add('${change.changeId}:answered');
    if (trips.projectionOf(widget.tripId) case final known?) {
      _AcceptRideTrip(this)._applyLive(TripLiveDetails.fromProjection(known));
    } else {
      _rebuild(() {});
    }
  }

  void _applyChangedRoute(TripRouteChange change) {
    final drop = change.dropoff;
    _changedRoute = (
      dropoffAddress: drop?.address ?? _dropoffAddress,
      dropoff: drop?.point.toLatLng() ?? _dropoffPosition,
      stops: [
        for (final stop in change.stops)
          stop.address ??
              '${stop.point.latitude.toStringAsFixed(5)}, '
                  '${stop.point.longitude.toStringAsFixed(5)}',
      ],
      stopPoints: [for (final stop in change.stops) stop.point.toLatLng()],
      fare: change.driverEarnings?.formatted ?? _changedRoute?.fare,
      riderFare: change.total?.formatted ?? _changedRoute?.riderFare,
    );
    // The waybill follows: new "To" (stops, drop-off) and the new money.
    final current = _waybills.current;
    if (current != null && current.tripId == widget.tripId) {
      _waybills.beginCurrent(
        current.copyWith(
          dropoff: waybillRouteLabel(_dropoffAddress, _stopAddresses),
          fare: _changedRoute?.fare,
          riderFare: _changedRoute?.riderFare,
        ),
      );
    }
    unawaited(_rideLifecycle.persistNow());
    if (_stage == ActiveRideStage.onTrip) {
      unawaited(_AcceptRideTrip(this)._refreshOnTripRoute(fitCamera: true));
    }
  }

  /// The sheet over the trip screen while a change waits for the driver.
  Widget _buildRouteChangeLayer(BuildContext context) {
    final change = _pendingRouteChange;
    if (change == null) return const SizedBox.shrink();
    return Positioned(
      key: const ValueKey<String>('route-change-layer'),
      left: 12,
      right: 12,
      bottom: MediaQuery.paddingOf(context).bottom + 12,
      child: _AcceptRidePanel(this)._mapOverlay(
        child: RouteChangeSheet(
          key: ValueKey<String>('route-change-${change.changeId}'),
          change: change,
          maxStops: OnTripConfig.current.maxStops,
          canRefuse: OnTripConfig.current.driverCanRefuse,
          onAnswer: (accept) => _answerRouteChange(change, accept),
        ),
      ),
    );
  }
}
