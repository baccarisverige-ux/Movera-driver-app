part of 'accept_ride.dart';

// Base job B8 (2026-11-04): moved word for word out of accept_ride_trip.dart
// (no behaviour change).
extension _AcceptRideTripOutcome on _AcceptRideState {
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
        // v0.18.10 (owner G8 Q1): the rider ended the trip on board: the
        // driver gets the finish (cash sheet with the amount, then the
        // rating), never straight Home.
        final projection = event.projection;
        final money = projection == null
            ? null
            : LiveTripMoney.tryParse(projection);
        if (money?.finish?.riderEndedEarly == true &&
            _stage == ActiveRideStage.onTrip) {
          await _finishAfterRiderEnded(money!);
        } else {
          await _handleRiderCancelled(
            fee: cancellation == null
                ? riderFeeZero
                // Item 12: the server decides a rider's fee in the cancel
                // itself (movera-server riderCancel); `fee: null` on a
                // rider cancel is "no fee", never "not decided yet".
                : cancellation.actor == 'rider' && cancellation.fee == null
                ? Money.zone(0)
                : cancellation.driverEarns,
            feeKind: cancellation?.feeKind,
            riderFee: cancellation?.fee,
          );
        }
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
          settled?.paid ?? _ownWaybill(),
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
      _setOwnWaybill(paid);
      _waybills.completeCurrent();
    } else {
      _waybills.discardCurrent();
    }
    // G9 live 2026-11-02: a trip restored on opening the app that the
    // server already finished before this open (no open status seen here)
    // goes Home quietly: no old "Trip completed" sheet from an earlier trip.
    final endedBeforeOpen =
        status == TripStatus.completed &&
        next == null &&
        widget.restoredSnapshot != null &&
        !_sawOpenTrip;
    if (!endedBeforeOpen) {
      await showTripOutcomeSheet(
        context,
        status: status,
        hasNext: next != null,
      );
    }
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

  /// Owner G8 Q1 (contract v0.18.10 `finish.earlyEnd.rider`): the rider
  /// ended the trip on board. A cash trip shows the cash sheet with
  /// `finish.cashToCollect` ("The rider ended the trip. Collect …"), then
  /// the finished screen with "Din andel" and the rating, then Home.
  Future<void> _finishAfterRiderEnded(LiveTripMoney money) async {
    if (!mounted || _handlingRiderCancellation || _releasedForLateEta) {
      return;
    }
    if (_completionInFlight || _cancellationInFlight) {
      return;
    }
    _handlingRiderCancellation = true;
    final finish = money.finish!;
    final cash = widget.paidByCash ? money.cash : null;
    _flushNextTripMatch();
    final offer = _onTripRadarState == _OnTripRadarState.secured
        ? _nextTripRadarOffer
        : null;
    final next = offer == null ? null : _snapshotForOffer(offer);
    if (cash != null && cash.minorUnits > 0) {
      await showCashCollectSheet(
        context,
        fare: money.driverPay?.formatted ?? '—',
        cash: cash.formatted,
        owedToMovera: money.owedToMovera,
        riderName: _riderName,
        category: widget.category,
        breakdown: money.earningsBreakdown,
        riderEnded: true,
      );
      if (!mounted) {
        _handlingRiderCancellation = false;
        return;
      }
    }
    final paid = _withMoney(
      _paidWaybill(),
      money,
    ).copyWith(endedEarlyBy: 'rider');
    try {
      await CompletionJournal(
        active: widget.activeRideRepository ?? MemoryActiveRideRepository(),
      ).finish(
        paid,
        pickupPoint: GeoPointMaps.fromLatLng(_pickupPosition),
        dropoffPoint: GeoPointMaps.fromLatLng(_dropoffPosition),
        status: TripStatus.cancelledByRider,
        authoritative: true,
        cancellationActor: 'rider',
        next: next,
        paymentMethod: widget.paidByCash ? 'Cash' : 'Card',
        cashCollected: cash?.formatted,
      );
      if (!mounted) {
        return;
      }
      if (!await _rideLifecycle.applyProjection(TripStatus.cancelledByRider)) {
        _handlingRiderCancellation = false;
        _scheduleProjectionRetry();
        return;
      }
    } catch (error, stack) {
      DriverLog.error('Rider early end journal failed', error, stack);
      _handlingRiderCancellation = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.couldNotSaveRiderCancellationRetry)),
        );
      }
      _scheduleProjectionRetry();
      return;
    }
    _waitTimer?.cancel();
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _pauseLiveUpdates();
    _setOwnWaybill(paid);
    _waybills.completeCurrent();
    if (!mounted) {
      return;
    }
    final nextRide = offer == null ? null : _nextRideFor(offer);
    _navigatorAtTripRoute().pushReplacement(
      BottomToTopTransition(
        DriverRideCompleted(
          waybillRepository: _waybills,
          sessionController: widget.sessionController,
          activeRideRepository: widget.activeRideRepository,
          nextRide: nextRide,
          paidByCash: widget.paidByCash,
          ratingAllowed: finish.ratingAllowed,
        ),
      ),
    );
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
        _ownWaybill(),
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
}
