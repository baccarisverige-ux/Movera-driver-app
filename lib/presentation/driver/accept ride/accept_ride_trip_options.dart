part of 'accept_ride.dart';

// Rule 25 split (owner 2026-11-07, "split first"): moved word for word out of
// accept_ride_panel.dart (no behaviour change). Rider profile, trip options
// and the cancel-reason sheets.
extension _AcceptRideTripOptions on _AcceptRideState {
  Future<void> _showRiderProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // L-a Q1: the rider's initials, no stock photo.
                  InitialsAvatar(
                    key: const ValueKey('rider-sheet-initials'),
                    name: _riderName,
                    radius: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _riderName,
                    style: const TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    // G4 decision 3: the rider's real rating only, and only
                    // while the zone shows it; else just the rides.
                    // Finder A2: the rides only when the server sent a
                    // count (0 = none sent), never a made-up one.
                    switch ((_riderRating, widget.riderTrips > 0)) {
                      (final rating?, true)
                          when DriverOfferRules.current.card.riderRating =>
                        tr.ratingAndRides(
                          rating.toStringAsFixed(1),
                          widget.riderTrips,
                        ),
                      (final rating?, false)
                          when DriverOfferRules.current.card.riderRating =>
                        '${rating.toStringAsFixed(1)} ★',
                      (_, true) => tr.riderRidesOnly(widget.riderTrips),
                      _ => '',
                    },
                    style: const TextStyle(
                      color: _AcceptRideState._muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _AcceptRideState._line),
                    ),
                    child: Text(
                      tr.riderDetailsFromBookingWillAppear,
                      style: TextStyle(
                        color: _AcceptRideState._muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTripOptions() async {
    final onTrip = _stage == ActiveRideStage.onTrip;
    final showNext =
        _onTripRadarState == _OnTripRadarState.secured &&
        _waybills.next != null;
    await showMoveraModalSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      heightFactor: 0.78,
      fitContent: true,
      builder: (sheetContext) {
        return _CleanSheet(
          // Scrolls on short screens and large text, so "End trip early"
          // stays reachable.
          child: Flexible(
            child: SingleChildScrollView(
              key: const ValueKey<String>('trip-options-scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_navigation.routeState == RouteLoadState.failed)
                    _CleanRow(
                      key: const ValueKey<String>('retry-route-option'),
                      title: tr.retryRoute,
                      subtitle: tr.routeUnavailableYourTripRemainsActive,
                      onTap: () {
                        if (popOwned(sheetContext)) {
                          unawaited(_navigation.retryRoute());
                        }
                      },
                    ),
                  _CleanRow(
                    key: const ValueKey<String>('current-trip-waybill-option'),
                    title: tr.currentWaybill,
                    subtitle: '$_pickupAddress → $_dropoffAddress',
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      final record = _waybills.current;
                      if (record != null) {
                        showMoveraWaybillSheet(
                          context,
                          record,
                          title: tr.currentTripWaybill,
                        );
                      }
                    },
                  ),
                  if (showNext)
                    _CleanRow(
                      key: const ValueKey<String>('next-trip-waybill-option'),
                      title: tr.nextTripWaybill,
                      subtitle: _waybills.next!.dropoff,
                      onTap: () {
                        if (!popOwned(sheetContext)) return;
                        showMoveraWaybillSheet(
                          context,
                          _waybills.next!,
                          title: tr.nextTripWaybill,
                        );
                      },
                    ),
                  if (onTrip)
                    _CleanRow(
                      key: const ValueKey<String>('trip-destination-option'),
                      title: tr.destination,
                      subtitle: _destinationActive
                          ? (_destinationAddress ?? tr.onYourWay)
                          : tr.nextTripsOnYourWay,
                      onTap: () {
                        if (popOwned(sheetContext)) {
                          _openDestinationPicker();
                        }
                      },
                    ),
                  _CleanRow(
                    title: tr.safetyToolkit,
                    subtitle: SafetyAudioOption.toolkitSubtitle,
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      showSafetyToolKitSheet(context, duringTrip: true);
                    },
                  ),
                  _CleanRow(
                    key: const ValueKey<String>('active-ride-cancel-option'),
                    title: onTrip ? tr.endTripEarly : tr.cancelTrip,
                    subtitle: onTrip ? tr.stopSafelyFirstReasonRequired : null,
                    danger: true,
                    last: true,
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      _showCancellationReasons();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The trip's cancel reasons; with [nextTrip], the same sheet cancels
  /// the secured next trip and the current one goes on.
  Future<void> _showCancellationReasons({bool nextTrip = false}) async {
    final isOnTrip = !nextTrip && _stage == ActiveRideStage.onTrip;
    final reasons = nextTrip
        ? _AcceptRideState._nextTripCancellationReasons
        : isOnTrip
        ? _AcceptRideState._onTripCancellationReasons
        : _stage == ActiveRideStage.waitingForRider &&
              !_paidStopWait &&
              _waitSeconds >= _noShowWaitSeconds
        ? <_TripCancellationReason>[
            _AcceptRideState._noShowReason,
            ..._AcceptRideState._preTripCancellationReasons,
          ]
        // G5 re-check 2026-10-30 ("wrong cancel reason before arrival"):
        // "Rider not at pickup" only once the driver is at the pickup.
        : _stage == ActiveRideStage.headingToPickup
        ? [
            for (final reason in _AcceptRideState._preTripCancellationReasons)
              if (reason.code != 'rider_not_at_pickup') reason,
          ]
        : _AcceptRideState._preTripCancellationReasons;

    final reason = await showMoveraModalSheet<_TripCancellationReason>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      heightFactor: 0.86,
      fitContent: true,
      builder: (sheetContext) {
        return _CleanSheet(
          key: ValueKey<String>(
            nextTrip
                ? 'next-trip-cancellation-reasons-sheet'
                : 'trip-cancellation-reasons-sheet',
          ),
          child: Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                Text(
                  nextTrip
                      ? tr.whyAreYouCancellingNextTripQuestion
                      : isOnTrip
                      ? tr.whyAreYouEndingTripQuestion
                      : tr.whyAreYouCancellingQuestion,
                  style: _CleanSheet.title,
                ),
                const SizedBox(height: 4),
                Text(
                  nextTrip
                      ? tr.yourCurrentTripContinues
                      : isOnTrip
                      ? tr.stopInSafePlaceFirst
                      : tr.pickReasonThatFitsBest,
                  style: _CleanSheet.note,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < reasons.length; i++)
                  _CleanRow(
                    key: ValueKey<String>(
                      'trip-cancel-reason-${reasons[i].code}',
                    ),
                    title: reasons[i].title,
                    subtitle: reasons[i].detail,
                    last: i == reasons.length - 1,
                    onTap: () => popOwned(sheetContext, reasons[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || reason == null) {
      return;
    }
    await _AcceptRideTrip(
      this,
    )._confirmCancellationReason(reason, nextTrip: nextTrip);
  }
}
