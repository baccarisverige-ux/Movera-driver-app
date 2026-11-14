part of 'accept_ride.dart';

/// On-trip Exclusive offers in a live build (owner-approved fix 2026-11-08).
///
/// The server offers a driver on a trip an Exclusive next trip (a live
/// ride, queued behind this one, or a booked ride, held for later) once the
/// rider is on board and most of the route is done. Those offers come on the
/// driver's one offer feed (the same [LiveDriverServices.dispatch] Home
/// reads, no second connection), which stays open during the trip. Home
/// does not look at it while the trip screen covers it, so the trip screen
/// does: the offer shows on the same next-trip card as the demo, counts
/// down to the server's `expiresAt`, and Accept / No go to the server.
/// After an Accept the trip sheet's Next card reads the accepted trip from
/// the server's answer (`nextAfterTripId`, or the held booked ride).
class _ServerNextOffers {
  _ServerNextOffers(this._s);

  final _AcceptRideState _s;
  final List<StreamSubscription<Object>> _subs = [];
  List<RideOffer> _nearby = const [], _next = const [];

  /// Offers already answered, run out or taken away: never shown again.
  final Set<String> _done = {};

  /// The server offer on screen, or waiting until it may be shown (the
  /// trip is covered, a Ride check is open, the trip has not started).
  RideOffer? _pending;

  /// Told when the driver's Accept went through: the Next card reads the
  /// accepted trip at once.
  final ValueNotifier<int> accepted = ValueNotifier<int>(0);

  DispatchRepository? get _dispatch => LiveDriverServices.instance?.dispatch;

  void start() {
    final dispatch = _dispatch;
    if (dispatch == null || _subs.isNotEmpty) return;
    _subs
      ..add(
        dispatch.watchNearbyOffers().listen((offers) {
          _nearby = offers;
          _changed();
        }),
      )
      ..add(
        dispatch.watchNextTripOffers().listen((offers) {
          _next = offers;
          _changed();
        }),
      )
      ..add(dispatch.watchWithdrawals().listen(_withdrawn));
  }

  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    accepted.dispose();
  }

  DateTime get _now => _AcceptRideTrip(_s)._offerNow();

  bool _open(RideOffer offer) {
    final expires = offer.expiresAt;
    return expires == null || expires.isAfter(_now);
  }

  void _changed() {
    if (!_s.mounted) return;
    if (_pending == null) {
      for (final offer in [..._nearby, ..._next]) {
        if (offer.isExclusive &&
            !_done.contains(offer.id) &&
            offer.tripId != _s.widget.tripId &&
            _open(offer)) {
          _pending = offer;
          break;
        }
      }
    }
    present();
  }

  /// Shows the waiting server offer when the trip screen may show one.
  void present() {
    final offer = _pending;
    final s = _s;
    if (offer == null ||
        !s.mounted ||
        s._stage != ActiveRideStage.onTrip ||
        s._rideLifecycle.terminal ||
        // Already up, being accepted, or next offers turned off.
        (s._onTripRadarState != _OnTripRadarState.scanning &&
            s._onTripRadarState != _OnTripRadarState.off)) {
      return;
    }
    if (!_open(offer)) {
      _forget(offer.id);
      return;
    }
    if (s._offersHeld) return; // the resume looks again (D-05)
    if (RideCheckGate.open) {
      // R10-2: shown after the Ride check's answer, if still open.
      s._nextTripOfferHeldAt ??= DateTime.now();
      return;
    }
    final expires = offer.expiresAt;
    final left = expires == null
        ? _AcceptRideState._onTripOfferLifetime
        : expires.difference(_now);
    s._rebuild(() {
      s._nextTripRadarOffer = _cardOf(offer);
      s._onTripRadarState = _OnTripRadarState.offerAvailable;
    });
    s._nextTripOfferDeadline = _now.add(left);
    s._armOnTripOfferExpiry(left: left);
    s._hideRideSheetForOffer();
  }

  /// v0.18.65 §86 (owner phone test 2026-11-11): the trip radar's stop /
  /// start reaches the server (`POST /driver/next-trips`), so it sends no
  /// on-trip offers while it is off. If the server did not hear it, the
  /// radar goes back and the driver is told.
  Future<void> tellSwitch({required bool on}) async {
    final presence = LiveDriverServices.instance?.presence;
    if (presence == null) return;
    final failed = await presence.setNextTrips(on: on);
    final s = _s;
    if (failed == null || !s.mounted || s._stage != ActiveRideStage.onTrip) {
      return;
    }
    if (on) {
      _AcceptRideTripNext(s)._stopOnTripRadar();
    } else if (s._onTripRadarState == _OnTripRadarState.stopped) {
      s._rebuild(() => s._onTripRadarState = _OnTripRadarState.off);
      _AcceptRideTripNext(s)._startOnTripRadar();
    }
    ScaffoldMessenger.maybeOf(
      s.context,
    )?.showSnackBar(SnackBar(content: Text(failed)));
  }

  /// The server offer on the demo's next-trip card.
  _NextTripRadarOffer _cardOf(RideOffer offer) => _NextTripRadarOffer(
    id: offer.tripId ?? offer.id,
    serverOfferId: offer.id,
    category: offer.category,
    fare: offer.fare.formatted,
    driverEarnings: offer.driverEarnings?.formatted,
    rating: double.tryParse(offer.rating) ?? 0,
    pickupMinutes: offer.pickupMinutes,
    pickupKm: offer.pickupKm,
    tripMinutes: offer.tripMinutes,
    riderName: offer.riderName,
    pickup: offer.pickup,
    dropoff: offer.dropoff,
    pickupPosition: offer.pickupPosition.toLatLng(),
    dropoffPosition: offer.dropoffPosition.toLatLng(),
    // The server's pickup pay, none when it sent none (never local rates).
    serverPickupPay:
        offer.pickupPay ?? Money(minorUnits: 0, currency: offer.fare.currency),
    serverDriverTotal: offer.driverTotal,
    expiresAt: offer.expiresAt,
  );

  /// Accept: `POST /offers/{offerId}/accept`. The answer (the trip, with
  /// `nextAfterTripId` for a queued live ride) is kept by the trip commands.
  Future<void> accept() async {
    final s = _s;
    final offer = _pending;
    final dispatch = _dispatch;
    if (offer == null ||
        dispatch == null ||
        s._onTripRadarState != _OnTripRadarState.offerAvailable) {
      return;
    }
    s._rebuild(() => s._onTripRadarState = _OnTripRadarState.matching);
    ExclusiveAnswers.instance.accepted();
    s._nextTripOfferExpiry?.cancel();
    s._restoreRideSheet();
    ClaimResult result;
    try {
      result = await dispatch.claimOffer(offer.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    if (!s.mounted || s._onTripRadarState != _OnTripRadarState.matching) {
      return;
    }
    if (result.outcome == ClaimOutcome.networkError && _open(offer)) {
      // Nothing was decided: the offer is up again for its time left.
      IslandMessages.show(HomeIslandNotices.noConnection);
      s._rebuild(() => s._onTripRadarState = _OnTripRadarState.scanning);
      present();
      return;
    }
    if (result.outcome == ClaimOutcome.networkError) {
      // IN-DL.9 #524 (a): no answer and the offer's local time is over.
      // Not "gone": keep asking the server (same Idempotency-Key).
      result = await _askUntilKnown(dispatch, offer);
      if (!s.mounted || s._onTripRadarState != _OnTripRadarState.matching) {
        return;
      }
      if (result.outcome == ClaimOutcome.networkError) {
        _unknownAfterChecks();
        return;
      }
    }
    _done.add(offer.id);
    _pending = null;
    s._rebuild(() {
      s._nextTripRadarOffer = null;
      s._onTripRadarState = _OnTripRadarState.scanning;
    });
    if (result.isSuccess) {
      accepted.value++;
      return;
    }
    ScaffoldMessenger.maybeOf(
      s.context,
    )?.showSnackBar(SnackBar(content: Text(tr.offerNoLongerAvailable)));
    _changed();
  }

  /// No: `POST /offers/{offerId}/decline`; the card is already down.
  void declined(String offerId) {
    _forget(offerId);
    final dispatch = _dispatch;
    if (dispatch != null) unawaited(dispatch.declineOffer(offerId));
    _changed();
  }

  /// Its time ran out: taken away; the server lets it go itself.
  void expired() {
    final offer = _pending;
    if (offer != null) _forget(offer.id);
    _takeDown();
    _changed();
  }

  void _withdrawn(OfferWithdrawal gone) {
    _done.add(gone.offerId);
    if (_pending?.id != gone.offerId) return;
    // While Accept is sent its answer decides.
    if (_s._onTripRadarState == _OnTripRadarState.matching) return;
    _pending = null;
    if (_s._nextTripRadarOffer?.serverOfferId == gone.offerId) _takeDown();
    _changed();
  }

  void _forget(String offerId) {
    _done.add(offerId);
    if (_pending?.id == offerId) _pending = null;
  }

  void _takeDown() {
    final s = _s;
    if (!s.mounted || s._onTripRadarState != _OnTripRadarState.offerAvailable) {
      return;
    }
    s._nextTripOfferExpiry?.cancel();
    s._nextTripOfferDeadline = null;
    s._rebuild(() {
      s._nextTripRadarOffer = null;
      s._onTripRadarState = _OnTripRadarState.scanning;
    });
    s._restoreRideSheet();
  }
}
