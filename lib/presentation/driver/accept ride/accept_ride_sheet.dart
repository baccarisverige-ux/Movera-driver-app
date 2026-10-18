part of 'accept_ride.dart';

// R13 trip sheet: the current and next trip cards with their ••• menus,
// cancelling the next trip, the next-trip radar dock, and a full sheet
// that fits its content.

extension _AcceptRideSheet on _AcceptRideState {
    /// The full sheet's height: its content, never taller than [expanded]
    /// and never lower than just above the middle sheet.
    double _fitRideExpanded(double expanded) {
      final measured = _fullMeasured;
      if (measured == null) { return expanded; }
      final floor = math.min(
        expanded,
        _AcceptRidePanel(this)._rideMiddleTotal(context) + 40,
      );
      return measured.clamp(floor, expanded);
    }
    /// The full sheet's details, laid out but not shown, under the middle
    /// sheet's header: measured ahead, the full sheet's height is right
    /// from the first pull and never jumps when the sheet gets there.
    Widget _buildFullAhead() {
      return Offstage(
        child: TickerMode(
          enabled: false,
          child: ExcludeSemantics(
            child: Column(
              key: _tripMotion.aheadKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _AcceptRidePanel(this)._fullDetails(),
            ),
          ),
        ),
      );
    }
    void _measureRideFull({bool ahead = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        final scroll = (ahead ? _tripMotion.aheadKey : _fullScrollKey)
            .currentContext?.findRenderObject();
        final content = (ahead ? _tripMotion.aheadKey : _fullContentKey)
            .currentContext?.findRenderObject();
        final panel = _ridePanelKey.currentContext?.findRenderObject();
        if (scroll is! RenderBox || content is! RenderBox || panel is! RenderBox ||
            !scroll.attached || !content.attached || !panel.attached) {
          return;
        }
        final top = scroll.localToGlobal(Offset.zero).dy -
            panel.localToGlobal(Offset.zero).dy;
        // Content, the scroll's bottom padding and the safe area.
        final measured = top + _tripMotion.gripMissing() +
            content.size.height + 16 +
            MediaQuery.paddingOf(context).bottom;
        final old = _fullMeasured;
        // Fine: a change keeps the sheet's height and glides (see keep).
        if (old != null && (old - measured).abs() < 0.5) { return; }
        _rebuild(() => _fullMeasured = measured);
      });
    }
    String? get _etaLabel => _routeDurationSeconds == null ? null : _routeEtaText;
    String _withEta(String label, String? eta) =>
        eta == null ? label : '$label · $eta';

    /// The trip being driven, in the same card as a secured next trip.
    Widget _buildCurrentTripCard() {
      final onTrip = _stage == ActiveRideStage.onTrip;
      final eta = _etaLabel;
      final stops = widget.stopAddresses;
      final toDropoff = onTrip && !_paidStopWait && _stopCursor >= stops.length;
      final points = <TripCardPoint>[
        TripCardPoint(
          label: switch (_stage) {
            ActiveRideStage.headingToPickup => _withEta('Pickup', eta),
            ActiveRideStage.waitingForRider => 'Pickup · arrived',
            ActiveRideStage.onTrip => 'Pickup · picked up',
          },
          address: widget.pickupAddress,
          color: TripCard.pickupGreen,
        ),
        for (var i = 0; i < stops.length; i++)
          TripCardPoint(
            label: onTrip && i < _stopCursor
                ? 'Stop ${i + 1} · done'
                : onTrip && i == _stopCursor && !_paidStopWait
                ? _withEta('Stop ${i + 1}', eta)
                : 'Stop ${i + 1}',
            address: stops[i],
            color: TripCard.stopGrey,
          ),
        TripCardPoint(
          label: toDropoff ? _withEta('Drop-off', eta) : 'Drop-off',
          address: widget.dropoffAddress,
          color: TripCard.ink,
          square: true,
        ),
      ];
      return ValueListenableBuilder<WaybillRecord?>(
        valueListenable: _waybills.currentListenable,
        builder: (context, record, _) => TripCard(
          key: const ValueKey<String>('active-ride-current-trip-card'),
          title: onTrip ? 'Current trip' : 'Your trip',
          fare: widget.fare,
          points: points,
          footer: '${widget.category} · ${widget.riderName.split(' ').first}',
          moreKey: const ValueKey<String>('current-trip-more'),
          onMore: _AcceptRidePanel(this)._showTripOptions,
          waybillKey: const ValueKey<String>('current-waybill-shortcut'),
          onWaybill: record == null
              ? null
              : () => showMoveraWaybillSheet(
                    context,
                    record,
                    title: 'Current trip waybill',
                  ),
        ),
      );
    }

    /// The secured next trip, under the current one.
    Widget _buildNextTripCard() {
      final offer = _nextTripRadarOffer;
      if (_stage != ActiveRideStage.onTrip ||
          _onTripRadarState != _OnTripRadarState.secured ||
          offer == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TripCard(
          key: const ValueKey<String>('secured-next-trip-details'),
          title: 'Next trip secured',
          fare: offer.shownFare,
          points: [
            TripCardPoint(
              label: 'Pickup · ${offer.pickupMinutes} min',
              address: offer.pickup,
              color: TripCard.pickupGreen,
            ),
            TripCardPoint(
              label: 'Drop-off · ${offer.tripMinutes} min trip',
              address: offer.dropoff,
              color: TripCard.ink,
              square: true,
            ),
          ],
          footer: '${offer.category} · ${offer.riderName}',
          moreKey: const ValueKey<String>('next-trip-more'),
          moreTooltip: 'Next trip options',
          onMore: _showNextTripOptions,
          waybillKey: const ValueKey<String>('next-trip-waybill'),
          onWaybill: _openNextWaybill,
        ),
      );
    }
    void _openNextWaybill() {
      final record = _waybills.next;
      if (record == null) { return; }
      showMoveraWaybillSheet(context, record, title: 'Next trip waybill');
    }

    /// Next trips are possible now: on the trip, allowed by admin, and
    /// none secured or on screen yet.
    bool get _nextTripOffersPossible =>
        _stage == ActiveRideStage.onTrip &&
        DriverOfferRules.current.exclusiveWhileDriving &&
        DriverOfferRules.current.exclusiveWhileDrivingCount >= 1 &&
        (_onTripRadarState == _OnTripRadarState.scanning ||
            _onTripRadarState == _OnTripRadarState.off ||
            _onTripRadarState == _OnTripRadarState.stopped);

    /// The next-trip radar at the bottom middle; hold it to stop or start
    /// next-trip offers (the island's long-press menu does the same).
    Widget _buildRadarDock() {
      if (!_nextTripOffersPossible) { return const SizedBox.shrink(); }
      return Padding(
        key: const ValueKey<String>('trip-radar-dock'),
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: SizedBox(
          width: double.infinity,
          child: TripRadarDock(
            on: _onTripRadarOn,
            onToggle: _AcceptRideTrip(this)._toggleOnTripRadar,
          ),
        ),
      );
    }

    /// ••• on the next trip card.
    Future<void> _showNextTripOptions() async {
      final offer = _nextTripRadarOffer;
      if (offer == null) { return; }
      await showMoveraModalSheet<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        heightFactor: 0.78,
        fitContent: true,
        builder: (sheetContext) {
          return _CleanSheet(
            key: const ValueKey<String>('next-trip-options-sheet'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_waybills.next != null)
                  _CleanRow(
                    key: const ValueKey<String>('next-trip-open-waybill'),
                    title: 'Open waybill',
                    subtitle: '${offer.pickup} → ${offer.dropoff}',
                    onTap: () {
                      if (popOwned(sheetContext)) { _openNextWaybill(); }
                    },
                  ),
                _CleanRow(
                  key: const ValueKey<String>('next-trip-contact-rider'),
                  title: 'Contact rider',
                  subtitle: offer.riderName,
                  onTap: () {
                    if (!popOwned(sheetContext)) { return; }
                    pushSingle(
                      context,
                      BottomToTopTransition(
                        Chat(riderDisplayName: offer.riderName),
                      ),
                    );
                  },
                ),
                _CleanRow(
                  title: 'Safety toolkit',
                  subtitle: 'Share trip, record audio, get help',
                  onTap: () {
                    if (popOwned(sheetContext)) { showSafetyToolKitSheet(context); }
                  },
                ),
                _CleanRow(
                  key: const ValueKey<String>('next-trip-cancel-option'),
                  title: 'Cancel next trip',
                  subtitle: 'Your current trip continues · reason required',
                  danger: true,
                  last: true,
                  onTap: () {
                    if (!popOwned(sheetContext)) { return; }
                    _AcceptRidePanel(this)._showCancellationReasons(nextTrip: true);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    /// Drops the secured next trip; the current trip goes on. The next trip
    /// goes back to dispatch (demo: it is dropped). It is kept in history as
    /// cancelled by the driver with its reason, so it counts like any other
    /// driver cancel unless the reason doesn't count.
    void _cancelNextTrip(_TripCancellationReason reason) {
      final offer = _nextTripRadarOffer;
      if (!mounted ||
          offer == null ||
          _onTripRadarState != _OnTripRadarState.secured) {
        return;
      }
      final record = _waybills.next;
      _rebuild(() {
        _nextTripRadarOffer = null;
        _onTripRadarState = _OnTripRadarState.scanning;
      });
      _waybills.clearNext();
      unawaited(_rideLifecycle.persistNow());
      if (record != null) {
        unawaited(
          PrefsTripHistoryRepository()
              .archive(
                record,
                status: TripStatus.cancelledByDriver,
                cancellationActor: 'driver',
                cancellationReasonCode: reason.code,
              )
              .catchError((Object error, StackTrace stack) {
                DriverLog.error('Next trip cancel was not archived', error, stack);
              }),
        );
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const ValueKey<String>('next-trip-cancelled-notice'),
          content: Text('Next trip cancelled · ${reason.title}'),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
}
