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
            ActiveRideStage.headingToPickup => _withEta(tr.pickup, eta),
            ActiveRideStage.waitingForRider => tr.pickupArrived,
            ActiveRideStage.onTrip => tr.pickupPickedUp,
          },
          address: widget.pickupAddress,
          color: TripCard.pickupGreen,
        ),
        for (var i = 0; i < stops.length; i++)
          TripCardPoint(
            label: onTrip && i < _stopCursor
                ? tr.stopNumberDone(i + 1)
                : onTrip && i == _stopCursor && !_paidStopWait
                ? _withEta(tr.stopNumber(i + 1), eta)
                : tr.stopNumber(i + 1),
            address: stops[i],
            color: TripCard.stopGrey,
          ),
        TripCardPoint(
          label: toDropoff ? _withEta(tr.dropOff, eta) : tr.dropOff,
          address: widget.dropoffAddress,
          color: TripCard.ink,
          square: true,
        ),
      ];
      return ValueListenableBuilder<WaybillRecord?>(
        valueListenable: _waybills.currentListenable,
        builder: (context, record, _) => TripCard(
          key: const ValueKey<String>('active-ride-current-trip-card'),
          title: onTrip ? tr.currentTrip : tr.yourTrip,
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
                    title: tr.currentTripWaybill,
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
          title: tr.nextTripSecured,
          fare: offer.shownFare,
          points: [
            TripCardPoint(
              label: tr.pickupPickupMinutesMin(offer.pickupMinutes),
              address: offer.pickup,
              color: TripCard.pickupGreen,
            ),
            TripCardPoint(
              label: tr.dropOffTripMinutesMinTrip(offer.tripMinutes),
              address: offer.dropoff,
              color: TripCard.ink,
              square: true,
            ),
          ],
          footer: '${offer.category} · ${offer.riderName}',
          moreKey: const ValueKey<String>('next-trip-more'),
          moreTooltip: tr.nextTripOptions,
          onMore: _showNextTripOptions,
          waybillKey: const ValueKey<String>('next-trip-waybill'),
          onWaybill: _openNextWaybill,
        ),
      );
    }
    void _openNextWaybill() {
      final record = _waybills.next;
      if (record == null) { return; }
      showMoveraWaybillSheet(context, record, title: tr.nextTripWaybill);
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
                    title: tr.openWaybill,
                    subtitle: '${offer.pickup} → ${offer.dropoff}',
                    onTap: () {
                      if (popOwned(sheetContext)) { _openNextWaybill(); }
                    },
                  ),
                _CleanRow(
                  key: const ValueKey<String>('next-trip-contact-rider'),
                  title: tr.contactRider,
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
                  title: tr.safetyToolkit,
                  subtitle: tr.shareTripRecordAudioGetHelp,
                  onTap: () {
                    if (popOwned(sheetContext)) { showSafetyToolKitSheet(context); }
                  },
                ),
                _CleanRow(
                  key: const ValueKey<String>('next-trip-cancel-option'),
                  title: tr.cancelNextTrip,
                  subtitle: tr.yourCurrentTripContinuesReasonRequired,
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
    /// goes back to dispatch (`searching`; demo: it is dropped). It is kept in
    /// history as a driver cancel with its reason, so it counts like any other
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
                // Contract v0.3: the queued trip goes back to dispatch.
                status: TripTransitions.apply(
                  TripStatus.accepted,
                  TripCommand.cancel,
                  TripActor.driver,
                ),
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
          content: Text(tr.nextTripCancelledTitle(reason.title)),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
}

class _NextTripRadarOffer {
  const _NextTripRadarOffer({
    required this.id,
    required this.category,
    required this.fare,
    required this.rating,
    required this.pickupMinutes,
    required this.tripMinutes,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.pickupPosition,
    required this.dropoffPosition,
    this.pickupKm = 1.6,
    this.securedPickupPay,
  });

  final String id;
  final String category;
  final String fare;
  final double rating;
  final int pickupMinutes;

  /// From the current trip's drop-off to this pickup.
  final double pickupKm;

  /// The pickup pay the driver accepted, kept from the moment the trip
  /// was secured; null while it is only offered.
  final Money? securedPickupPay;

  /// Pickup pay, worked out each time the offer shows; once secured, the
  /// accepted one.
  PickupPayQuote get pickupPay {
    final leg = PickupLeg(km: pickupKm, minutes: pickupMinutes);
    final secured = securedPickupPay;
    return secured == null
        ? PickupPayCalculator.quote(
            category: category,
            kind: PickupPayOfferKind.nextTripWhileDriving,
            leg: leg,
          )
        : PickupPayQuote(
            pay: secured,
            leg: leg,
            display: PickupPayConfig.current.display,
          );
  }

  /// The fare plus the pickup pay: one total.
  String get shownFare => pickupPay.totalOf(fare);

  /// The trip's terms once accepted: the total the card showed, with the
  /// pickup pay as Movera's bonus (driver-12).
  ({String fare, Money? driverBonus, String? cashToCollect}) get terms =>
      pickupPay.termsOf(fare: fare, paidByCash: false);

  /// This offer, secured: its pickup pay no longer changes.
  _NextTripRadarOffer secured() => _NextTripRadarOffer(
    id: id,
    category: category,
    fare: fare,
    rating: rating,
    pickupMinutes: pickupMinutes,
    tripMinutes: tripMinutes,
    riderName: riderName,
    pickup: pickup,
    dropoff: dropoff,
    pickupPosition: pickupPosition,
    dropoffPosition: dropoffPosition,
    pickupKm: pickupKm,
    securedPickupPay: pickupPay.pay,
  );
  final int tripMinutes;
  final String riderName;
  final String pickup;
  final String dropoff;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
}
