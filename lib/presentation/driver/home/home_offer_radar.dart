part of 'home.dart';

// Offer and Trip Radar orchestration for DriverHome.
// Timers and fields stay on the state. This extension is the only
// place that schedules or presents those demo offers.

enum _HomeRadarMatchState { available, resolving, claimedElsewhere }

/// Why a Radar offer is leaving the list.
enum _RadarOfferGone {
  /// This driver tapped Match and another driver won.
  lostOwnMatch,

  /// Expired, cancelled by the rider or gone from Radar for another reason.
  unavailable,

  /// Dispatch withdrew it: another driver (of its radar group) took it.
  takenElsewhere,
}

class _HomeDirectOffer {
  final String id;

  /// X9: the trip behind this offer, when dispatch sent it (never [id]).
  final String? tripId;
  final String category;

  /// Why it is Exclusive, shown on its card (see [ExclusiveReasons]).
  final String reason;
  final String fare;
  final String rating;
  final int pickupMinutes;
  final double pickupKm;
  final int tripMinutes;
  final double tripKm;
  final String pickup;
  final String dropoff;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final bool reservation;
  final bool cash;

  /// R8-4: cash to take from the rider when not the fare; see [RideOffer].
  final String? cashToCollect;
  final int bags;
  final String payment;

  /// A reservation's pickup time, e.g. "07:40".
  final String? pickupTime;
  final bool driverSigned = false;

  /// The rider, for the trip screen.
  final String riderName;
  final int riderTrips;

  /// Stops between pickup and drop-off, passed into the trip.
  final List<ReservationStop> stops;

  /// Admin raised the fare, e.g. "+40 kr" (Q13).
  final String? fareBoost;

  /// A scheduled ride Movera assigned to this driver (Q29): Accept keeps
  /// it for later instead of opening a trip.
  final bool assigned;

  /// How long its Exclusive card stays; null for the usual offer time.
  final Duration? lifetime;

  /// Q18: admin's priority or Movera-paid bonus ([fare] includes it): the
  /// red "Priority" badge.
  final bool priority;

  /// Movera-paid extra already in [fare] (Q16): the trip's earnings say
  /// "incl. +X Movera bonus".
  final Money? driverBonus;

  /// The admin's radar group (contract `Offer.groupId`); null otherwise.
  final String? groupId;

  /// An admin direct assign (contract §3.1): "Assigned by Movera".
  bool get adminAssigned => reason == ExclusiveReasons.assigned && !assigned;

  /// Dispatch's own Exclusive offer for this driver (an admin direct
  /// assign, or `kind: exclusive` / `assigned`): Accept is its claim.
  final bool dispatchExclusive;

  /// The server's driver net and pickup pay (driver-r5-1); null for demo
  /// offers.
  final String? driverEarnings;
  final Money? serverPickupPay;

  /// Accept is dispatch's claim (§3, §3.1).
  bool get claimedViaDispatch => adminAssigned || dispatchExclusive;

  /// Accept and No go through dispatch's accept/decline (§3.1).
  bool get viaDispatchAnswer => claimedViaDispatch || groupId != null;

  const _HomeDirectOffer({
    required this.id,
    this.tripId,
    required this.category,
    this.reason = '',
    required this.fare,
    required this.rating,
    required this.pickupMinutes,
    required this.pickupKm,
    required this.tripMinutes,
    required this.tripKm,
    required this.pickup,
    required this.dropoff,
    required this.pickupPosition,
    required this.dropoffPosition,
    this.reservation = false,
    this.cash = false,
    this.cashToCollect,
    this.bags = 0,
    this.payment = 'Card',
    this.pickupTime,
    this.riderName = '',
    this.riderTrips = 0,
    this.stops = const <ReservationStop>[],
    this.fareBoost,
    this.assigned = false,
    this.lifetime,
    this.priority = false,
    this.driverBonus,
    this.groupId,
    this.dispatchExclusive = false,
    this.driverEarnings,
    this.serverPickupPay,
  });

  /// A dispatch offer on Home. A reservation keeps its pickup time for
  /// its "Reservation" badge.
  factory _HomeDirectOffer.fromRide(
    RideOffer offer, {
    String reason = '',
    bool assigned = false,
    Duration? lifetime,
    bool dispatchExclusive = false,
  }) => _HomeDirectOffer(
    id: offer.id,
    tripId: offer.tripId,
    category: offer.category,
    reason: reason,
    fare: offer.fareLabel,
    rating: offer.rating,
    pickupMinutes: offer.pickupMinutes,
    pickupKm: offer.pickupKm,
    tripMinutes: offer.tripMinutes,
    tripKm: offer.tripKm,
    pickup: offer.pickup,
    dropoff: offer.dropoff,
    pickupPosition: offer.pickupPosition.toLatLng(),
    dropoffPosition: offer.dropoffPosition.toLatLng(),
    bags: offer.bags,
    payment: offer.payment,
    cash: RadarOfferView.isCash(offer.payment),
    cashToCollect: offer.cashToCollectLabel,
    reservation: offer.isReservation,
    pickupTime: offer.reservationTime,
    riderName: offer.riderName,
    riderTrips: offer.riderTrips,
    stops: offer.stops,
    fareBoost: offer.fareBoostLabel,
    assigned: assigned,
    lifetime: lifetime,
    priority: offer.isPriority,
    driverBonus: offer.driverBonus,
    groupId: offer.groupId,
    dispatchExclusive: dispatchExclusive,
    driverEarnings: offer.driverEarnings?.formatted,
    serverPickupPay: offer.pickupPay,
  );
}

extension _HomeOfferRadar on _DriverHomeState {
    void _maybeShowSoonReservation() {
      if (!_soonReservationReady || !mounted || !_isOnline || RideCheckGate.open) { return; }
      final offer = _HomeScheduled(this)._soonReservationOffer();
      // Close to pickup means minutes before its pickup time, not the
      // drive to it.
      if (offer == null ||
          offer.driverSigned ||
          !_HomeScheduled(this)._exclusiveStepReached(offer.id)) {
        return;
      }
      // Taken already (here or elsewhere): it is gone everywhere (R23).
      if (!ScheduledRideStore.isOpen(offer.id)) { return; }
      if (!_directOfferFollowsDestination(offer)) { return; }

      // Close to pickup it is an Exclusive offer, no longer the popup.
      _HomeReservation(this)._reservationBecomesExclusive(offer.id);
      _showOutsideRadarOffer(offer);
      if (_outsideRadarOffer?.id == offer.id) {
        _soonReservationReady = false;
      } else if (!_isDirectOfferRoutePreview) {
        // Held back: the map follows the car until it comes.
        _camera.endPreview();
      }
    }
    bool _directOfferFollowsDestination(_HomeDirectOffer offer) =>
        _followsDestination(offer.dropoffPosition);
    /// R13-9: a drop-off near the road route to the destination (admin
    /// corridor) that brings the driver closer, by admin's focus.
    bool _followsDestination(LatLng dropoff) {
      if (!_destinationModeActive) { return true; }
      final destination = _destinationPosition;
      if (destination == null) { return true; }
      return DestinationFilter.follows(
        driver: GeoPointMaps.fromLatLng(_driverPosition),
        destination: GeoPointMaps.fromLatLng(destination),
        dropoff: GeoPointMaps.fromLatLng(dropoff),
        route: _cameraRoute?.points ?? const <GeoPoint>[],
      );
    }
    void _clearDirectOfferRoute() {
      if (!mounted) { return; }
      _offerRouteFrame.stopLine();
      _HomeExclusive(this)._sinkExclusiveIfGone();
      _rebuild(() {
        _mapPreviews.cancel();
        _camera.endPreview();
        _isDirectOfferRoutePreview = false;
        _directOfferRouteMarkers = {};
        _directOfferRoutePolylines = {};
      });
    }
    Future<void> _showOutsideRadarOffer(
      _HomeDirectOffer offer, {
      int held = 0,
    }) async {
      // The reservation up on the dock holds the offer back, but not longer
      // than it would have lasted on screen: then it has expired.
      const wait = Duration(seconds: 2);
      final lifetime = offer.lifetime ?? _DriverHomeState._outsideOfferLifetime;
      if (wait * held > lifetime) { return; }
      // So does an open Ride check (R10-2) until the driver answers, and
      // the side menu, which would cover it (driver-u115).
      if (mounted && (RideCheckGate.open || _HomeReservation(this)._reservationUp ||
          (_scaffoldKey.currentState?.isDrawerOpen ?? false))) {
        _directOfferTimer?.cancel();
        _directOfferTimer = Timer(
          wait,
          () => _showOutsideRadarOffer(offer, held: held + 1),
        );
        return;
      }
      if (!mounted ||
          !_isOnline ||
          showRideRequests ||
          // One Exclusive offer at a time: a waiting one never replaces it,
          // and the one up is not shown again (that would restart its
          // countdown, driver-72).
          _outsideRadarOffer != null ||
          // Its card is sliding down: it is leaving.
          _exclusive.leaving ||
          _radarHomeOffers.isNotEmpty ||
          // Radar trips waiting off screen hold an Exclusive offer back,
          // but not a reservation close to pickup: it needs a driver soon.
          (!offer.reservation &&
              (_pendingRadarHomeOffers.isNotEmpty || _hasRideOffers)) ||
          !_directOfferFollowsDestination(offer) ||
          !_HomeScheduled(this)._fitsSchedule(offer) ||
          !_HomeOfferRules(this)._offerAllowed(offer) ||
          (offer.reservation &&
              (offer.driverSigned ||
                  !_HomeScheduled(this)._exclusiveStepReached(offer.id))) ||
          _mainPanelPosition > 0.04 ||
          isPanelOpen) {
        return;
      }

      _outsideOfferTimeoutTimer?.cancel();
      _rebuild(() {
        _outsideRadarOffer = offer;
      });
      if (offer.claimedViaDispatch) { _adminAssignsShown.add(offer.id); }
      // The sheet rises over the dock; its orb's ring starts full. The
      // route comes onto the map once the sheet has settled.
      _HomeExclusive(this)._raiseExclusive(offer, lifetime);
      // The island says it too while the card arrives.
      IslandMessages.show(offer.assigned
          ? HomeIslandNotices.assignedRide
          : offer.reservation
          ? HomeIslandNotices.exclusiveReservation
          : HomeIslandNotices.exclusiveRide);
      // And it is in Notifications (Q31, N1).
      final feed = DriverNotificationFeed.instance;
      feed.add(
        DriverNotices.exclusiveOffer(at: feed.now, seconds: lifetime.inSeconds),
        popup: false,
      );

      _outsideOfferTimeoutTimer = Timer(
        lifetime,
        () {
          if (!mounted || _outsideRadarOffer?.id != offer.id) { return; }
          // Ran out without Accept: it counts as missed (Q16).
          _dismissOutsideRadarOffer(missed: true);
        },
      );
    }
    /// The Exclusive offer leaves. [missed]: it ran out or the driver
    /// tapped ×; a row of those takes the driver offline (Q16). Its card
    /// slides back into the sheet first; the offer clears once it is down.
    void _dismissOutsideRadarOffer({bool missed = false}) {
      _outsideOfferTimeoutTimer?.cancel();
      _outsideOfferTimeoutTimer = null;
      if (!mounted) { return; }

      final gone = _outsideRadarOffer;
      if (gone != null) {
        if (_exclusive.leaving) { return; }
        _rebuild(() => _exclusive.leaving = true);
        _HomeExclusive(this)._sinkExclusive(then: () {
          if (mounted && _outsideRadarOffer?.id == gone.id) {
            _outsideRadarOfferGone(gone, missed: missed);
          }
        });
        return;
      }
      _outsideRadarOfferGone(null, missed: missed);
    }
    void _outsideRadarOfferGone(_HomeDirectOffer? gone, {bool missed = false}) {
      _rebuild(() {
        _outsideRadarOffer = null;
      });
      _clearDirectOfferRoute();
      _releasePendingRadarOffers();
      // Not accepted in time: Movera picks another driver (Q29).
      if (gone != null && gone.assigned) {
        _HomeScheduled(this)._assignmentMissed(gone);
      // An untaken reservation stays a Radar trip (R22).
      } else if (gone != null && gone.reservation) {
        _HomeReservation(this)._reservationToDeck(gone.id);
      }
      // A ride Movera assigned may be waiting for this place.
      _HomeScheduled(this)._maybeShowAssignment();
      if (missed && gone != null) { _HomeOfferRules(this)._exclusiveMissed(); }
    }
    void _showRadarHomeOffer(_HomeDirectOffer offer) {
      if (!mounted ||
          !_isOnline ||
          !_directOfferFollowsDestination(offer) ||
          !_HomeScheduled(this)._fitsSchedule(offer) ||
          !_HomeOfferRules(this)._offerAllowed(offer) ||
          _radarHomeOffers.any((item) => item.id == offer.id) ||
          _pendingRadarHomeOffers.any((item) => item.id == offer.id) ||
          _radarHomeOffers.length + _pendingRadarHomeOffers.length >=
              _DriverHomeState._maxHomeRadarOffers) {
        return;
      }

      // Dispatch owns offer expiry and claim state for both Home and Radar.

      if (RideCheckGate.open ||
          _outsideRadarOffer != null ||
          _HomeReservation(this)._reservationUp) {
        _rebuild(() {
          _hasRideOffers = true;
          _pendingRadarHomeOffers.add(offer);
        });
        return;
      }

      // New trips join the back of the deck, so the front card the driver
      // reads never changes under them.
      if (_radarHomeOffers.length < _DriverHomeState._maxHomeRadarOffers) {
        _activateRadarHomeOffer(offer);
        return;
      }

      _rebuild(() {
        _hasRideOffers = true;
        _pendingRadarHomeOffers.add(offer);
      });
    }
    void _activateRadarHomeOffer(_HomeDirectOffer offer) {
      if (!mounted ||
          !_isOnline ||
          _radarHomeOffers.length >= _DriverHomeState._maxHomeRadarOffers ||
          _radarHomeOffers.any((item) => item.id == offer.id)) {
        return;
      }

      _rebuild(() {
        _hasRideOffers = true;
        _radarHomeOffers.add(offer);
        _pendingRadarHomeOffers.removeWhere((item) => item.id == offer.id);
      });
      _startRadarPickWindow(offer);
      // Demo: with a full deck, one trip behind gets taken elsewhere.
      if (_radarHomeOffers.length >= 3) { _scheduleHomeRadarExternalClaimDemo(); }
    }
    void _refreshRadarHomeOffers() {
      if (!mounted ||
          !_isOnline ||
          RideCheckGate.open ||
          _outsideRadarOffer != null ||
          _HomeReservation(this)._reservationUp ||
          _pendingRadarHomeOffers.isEmpty) {
        return;
      }

      final refreshed = <_HomeDirectOffer>[
        ..._radarHomeOffers,
        ..._pendingRadarHomeOffers,
      ];

      final seen = <String>{};
      final next = <_HomeDirectOffer>[];
      for (final offer in refreshed) {
        if (seen.add(offer.id)) {
          next.add(offer);
        }
        if (next.length >= _DriverHomeState._maxHomeRadarOffers) { break; }
      }

      // Trips whose pick window ran out leave on refresh.
      next.removeWhere((offer) => _radarOfferExpired.contains(offer.id));
      _radarOfferExpired.clear();
      _radarOfferDeadlines.removeWhere(
          (id, _) => !next.any((offer) => offer.id == id));
      for (final offer in next) {
        _startRadarPickWindow(offer);
      }

      _rebuild(() {
        _radarHomeOffers
          ..clear()
          ..addAll(next);
        _pendingRadarHomeOffers.clear();
        _hasRideOffers = _radarHomeOffers.isNotEmpty;
      });

      _dispatch.refreshOffers();
      _scheduleHomeRadarExternalClaimDemo();
    }
    /// Starts [offer]'s pick window once; when it ends, Match fades.
    /// D-04: the window has one deadline, set when the trip is listed. A
    /// pause cancels the timer only; back on screen it gets the time left,
    /// or Match fades at once when the window ran out meanwhile.
    void _startRadarPickWindow(_HomeDirectOffer offer) {
      if (_radarOfferTimeoutTimers.containsKey(offer.id) ||
          _radarOfferExpired.contains(offer.id)) {
        return;
      }
      final now = ScheduledClock.realNow();
      final deadline = _radarOfferDeadlines.putIfAbsent(
          offer.id, () => now.add(_DriverHomeState._radarOfferPickWindow));
      final left = deadline.difference(now);
      _radarOfferTimeoutTimers[offer.id] = Timer(
        left.isNegative ? Duration.zero : left,
        () {
          // driver-u128: a window that ends during a Match claim can be
          // armed again (at once) if the claim leaves the card available.
          _radarOfferTimeoutTimers.remove(offer.id);
          if (!mounted ||
              !_radarHomeOffers.any((item) => item.id == offer.id) ||
              _homeRadarStateFor(offer.id) != _HomeRadarMatchState.available) {
            return;
          }
          _rebuild(() => _radarOfferExpired.add(offer.id));
        },
      );
    }
    void _releasePendingRadarOffers() {
      if (!mounted ||
          !_isOnline ||
          RideCheckGate.open ||
          _outsideRadarOffer != null ||
          _HomeReservation(this)._reservationUp) {
        return;
      }
      // Q16: an admin direct assign that waited behind them comes first.
      final admin = _pendingAdminAssign;
      if (admin != null && _radarHomeOffers.isEmpty) {
        unawaited(_showOutsideRadarOffer(admin));
        if (_outsideRadarOffer != null) { return; }
      }
      if (_pendingRadarHomeOffers.isEmpty) { return; }

      // Nothing on screen: load the new trips and open the offers popup.
      // With trips already listed, new ones wait behind the "new" button
      // so the list never jumps while the driver reads it.
      if (_radarHomeOffers.isEmpty) {
        _refreshRadarHomeOffers();
        return;
      }
      _rebuild(() {
        _hasRideOffers = true;
      });
    }
    /// R10-2: offers that waited for the Ride check answer come up now.
    void _onRideCheckGate() {
      if (!mounted || RideCheckGate.open) { return; }
      _rebuild(() {});
      _releasePendingRadarOffers();
      _maybeShowSoonReservation();
    }
    void _dismissRadarHomeOffer(_HomeDirectOffer offer) {
      // A Match already sent is answered first: its card stays until the
      // claim is won (the trip opens) or lost (it leaves then).
      if (offer.id == _homeRadarMatchingOfferId) { return; }
      _radarOfferTimeoutTimers.remove(offer.id)?.cancel();
      if (!mounted) { return; }

      _rebuild(() {
        _radarHomeOffers.removeWhere((item) => item.id == offer.id);
        _pendingRadarHomeOffers.removeWhere((item) => item.id == offer.id);
        _homeRadarMatchStates.remove(offer.id);
        _homeRadarGoneReasons.remove(offer.id);
        _radarOfferExpired.remove(offer.id);
        _radarOfferDeadlines.remove(offer.id);
        _hasRideOffers =
            _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty;
      });

      if (_radarHomeOffers.isEmpty && _pendingRadarHomeOffers.isNotEmpty) {
        _releasePendingRadarOffers();
      }
      // R13-3: the last card left (×, taken elsewhere, gone from dispatch):
      // its route and pins go too, and the map follows the car again.
      _clearRadarRouteIfNoCards();
      if (_radarHomeOffers.isEmpty && _pendingRadarHomeOffers.isEmpty) {
        _maybeShowSoonReservation();
        _HomeScheduled(this)._maybeShowAssignment();
      }
    }
    /// No Radar card left and no other offer owns the route: clear it.
    void _clearRadarRouteIfNoCards() {
      if (!mounted ||
          _radarHomeOffers.isNotEmpty ||
          _outsideRadarOffer != null ||
          _reservation.routeId != null) {
        return;
      }
      _radarExpandedOfferId = null;
      if (_isDirectOfferRoutePreview ||
          _directOfferRouteMarkers.isNotEmpty ||
          _directOfferRoutePolylines.isNotEmpty) {
        _clearDirectOfferRoute();
      }
    }
    _HomeRadarMatchState _homeRadarStateFor(String id) =>
        _homeRadarMatchStates[id] ?? _HomeRadarMatchState.available;
    void _startHomeRadarMatch(_HomeDirectOffer offer) {
      if (!_radarHomeOffers.any((item) => item.id == offer.id) ||
          _homeRadarStateFor(offer.id) != _HomeRadarMatchState.available ||
          _homeRadarMatchingOfferId != null) {
        return;
      }
      // R15-5: Match stops the radar sound.
      _offerSound.silence();

      _rebuild(() {
        _homeRadarMatchingOfferId = offer.id;
        _homeRadarMatchStates[offer.id] = _HomeRadarMatchState.resolving;
      });
      IslandMessages.show(HomeIslandNotices.matching);

      unawaited(_claimHomeRadarOffer(offer));
    }
    Future<void> _claimHomeRadarOffer(_HomeDirectOffer offer) async {
      ClaimResult result;
      try {
        result = await _dispatch.claimOffer(offer.id);
      } catch (_) {
        result = const ClaimResult.networkError();
      }
      if (!mounted || _homeRadarMatchingOfferId != offer.id) { return; }
      if (offer.reservation) {
        _HomeReservation(this)._reservationClaimedOnRadar(offer.id, result);
      }
      switch (result.outcome) {
        case ClaimOutcome.success:
          _resolveHomeRadarMatchWon(offer);
        case ClaimOutcome.alreadyClaimed:
          _resolveHomeRadarMatchLost(offer, _RadarOfferGone.lostOwnMatch);
        case ClaimOutcome.expired:
        case ClaimOutcome.unavailable:
          _resolveHomeRadarMatchLost(offer, _RadarOfferGone.unavailable);
        case ClaimOutcome.networkError:
          // Nothing was decided; let the driver try again.
          _rebuild(() {
            _homeRadarMatchingOfferId = null;
            _homeRadarMatchStates.remove(offer.id);
          });
          _startRadarPickWindow(offer); // its time left, or Match fades
          IslandMessages.show(HomeIslandNotices.noConnection);
      }
      if (_homeRadarMatchingOfferId == null) {
        _HomeScheduled(this)._afterClaimResolved();
      }
    }
    void _watchDispatchRadar() {
      _withdrawalSubscription?.cancel();
      _withdrawalSubscription =
          _dispatch.watchWithdrawals().listen(_onOfferWithdrawn);
      _radarSubscription?.cancel();
      _radarSubscription = _dispatch.watchNearbyOffers().listen((offers) {
        if (!mounted || !_isOnline) { return; }
        final known = {for (final offer in _latestDispatchOffers) offer.id};
        final open = _radarTripsOpen;
        _latestDispatchOffers = offers;
        // The radar button's trip count (D-16: counted per build, not per
        // frame) redraws only when it changes.
        if (_hasRideOffers && _radarTripsOpen == 0 &&
            _radarHomeOffers.isEmpty && _pendingRadarHomeOffers.isEmpty) {
          // driver-u117: the trips the Radar list had when it closed left
          // dispatch; with none left anywhere, Home is scanning again.
          _rebuild(() => _hasRideOffers = false);
        } else if (_radarTripsOpen != open) { _rebuild(() {}); }
        // A reservation that just joined Radar (its Radar time, or back
        // after a cancel) comes onto the deck too, once its Exclusive step
        // on this phone is over.
        for (final offer in offers) {
          // Q16: an admin direct assign or dispatch's Exclusive offer
          // arriving now is an Exclusive offer.
          if (offer.isExclusive && !known.contains(offer.id) &&
              !_adminAssignsShown.contains(offer.id)) {
            unawaited(_showOutsideRadarOffer(_adminAssignOffer(offer)));
          }
          if (offer.isReservation &&
              !known.contains(offer.id) &&
              _outsideRadarOffer?.id != offer.id &&
              _HomeScheduled(this)._exclusiveStepReached(offer.id)) {
            _HomeReservation(this)._reservationToDeck(offer.id);
          }
        }
        final ids = offers.map((item) => item.id).toSet();
        // An admin direct assign on screen that left dispatch is gone.
        final up = _outsideRadarOffer;
        if (up != null && up.claimedViaDispatch && !ids.contains(up.id) &&
            _exclusive.claimingId != up.id && !_exclusive.leaving) {
          IslandMessages.show(HomeIslandNotices.tripUnavailable);
          _dismissOutsideRadarOffer();
        }
        // driver-u116: the full Radar list's own Match took it; the trip
        // that begins clears the deck. A lost Match sweeps afterwards.
        if (_radarListClaiming.value) { return; }
        _sweepGoneRadarOffers();
      });
    }
    /// Deck and waiting Radar offers that left dispatch without a claim of
    /// ours are gone. driver-r5-32: also run when a full Radar list Match
    /// ends with no trip, since the sweep was skipped while it was out.
    void _sweepGoneRadarOffers() {
      final ids = _latestDispatchOffers.map((item) => item.id).toSet();
      for (final offer in [..._radarHomeOffers, ..._pendingRadarHomeOffers]) {
        if (ids.contains(offer.id) ||
            _homeRadarStateFor(offer.id) != _HomeRadarMatchState.available) {
          continue;
        }
        if (_pendingRadarHomeOffers.contains(offer)) {
          // Waiting off screen: there is no card to show as taken, so
          // it just leaves. A "Taken" state with a removal timer could
          // outlive a pause and land on the deck for good (driver-u129).
          _dismissRadarHomeOffer(offer);
          continue;
        }
        // Gone from Radar without a claim of ours: the reason is not
        // known here (rider cancelled, expired, taken elsewhere…).
        _resolveHomeRadarMatchLost(offer, _RadarOfferGone.unavailable);
      }
    }
    /// Radar trips open right now, the ones the full Radar screen lists.
    int get _radarTripsOpen => _latestDispatchOffers
        .where((offer) =>
            offer.isNearby &&
            !offer.isExclusive &&
            _followsDestination(offer.dropoffPosition.toLatLng()) &&
            _HomeOfferRules(this)._rideAllowed(offer))
        .length;
    void _showDispatchOfferAt(int index) {
      final offers = _latestDispatchOffers.where((offer) => offer.isNearby &&
          !offer.isExclusive &&
          _followsDestination(offer.dropoffPosition.toLatLng())).toList();
      if (index >= offers.length) { return; }
      _showRadarHomeOffer(_homeOfferFromDispatch(offers[index]));
    }
    /// An admin direct assign (contract §3.1) or dispatch's own Exclusive
    /// offer (§3, with its `reasonCode`) as an Exclusive offer. It runs to
    /// the server's `expiresAt` when dispatch sent one.
    _HomeDirectOffer _adminAssignOffer(RideOffer offer) {
      final left = offer.expiresAt?.difference(DateTime.now());
      return _HomeDirectOffer.fromRide(
        offer,
        reason: offer.isAdminDirectAssign
            ? ExclusiveReasons.assigned
            : offer.reasonCode ?? '',
        dispatchExclusive: true,
        lifetime: left != null && left > Duration.zero ? left : null,
      );
    }
    /// The first dispatch Exclusive offer not shown yet.
    _HomeDirectOffer? get _pendingAdminAssign {
      for (final offer in _latestDispatchOffers) {
        if (offer.isExclusive && !_adminAssignsShown.contains(offer.id)) {
          return _adminAssignOffer(offer);
        }
      }
      return null;
    }
    /// A Radar trip from dispatch as a Home deck card.
    _HomeDirectOffer _homeOfferFromDispatch(RideOffer offer) =>
        _HomeDirectOffer.fromRide(offer);
    void _resolveHomeRadarMatchWon(_HomeDirectOffer offer) {
      _homeRadarNoticeTimer?.cancel();

      _rebuild(() {
        // Keep ownership until the active ride opens. Other offers and the
        // dispatch removal of our own claimed offer cannot steal this handoff.
        _homeRadarMatchingOfferId = offer.id;
        _homeRadarMatchStates[offer.id] = _HomeRadarMatchState.resolving;
        _claimedHomeOffer = offer;
      });
      IslandMessages.show(HomeIslandNotices.matched);
      _openClaimedHomeOffer();
    }
    void _openClaimedHomeOffer() {
      final offer = _claimedHomeOffer;
      if (!mounted || !_liveVisible || offer == null) { return; }
      _homeRadarNoticeTimer?.cancel();
      _homeRadarNoticeTimer = Timer(
        const Duration(milliseconds: 850),
        () {
          if (!mounted || !_liveVisible || _claimedHomeOffer?.id != offer.id) { return; }
          // driver-r5-24: a sheet or dialog is over Home. The trip cannot
          // open yet; the claim waits and [_backOnTop] opens it.
          if (ModalRoute.of(context)?.isCurrent == false) { return; }
          final source = _claimedHomeSource;
          if (source == null) {
            _acceptRadarHomeOffer(offer);
          } else {
            _openOfferTrip(offer, source);
          }
        },
      );
    }
    /// A won Exclusive Accept (a reservation close to pickup, an admin
    /// direct assign) opens its trip now. With a screen over Home (a
    /// drawer item, a dialog) it waits like a won Radar Match and opens
    /// as soon as Home is back on top (driver-73). Dispatch gave the trip
    /// to this driver: it is never dropped, even when the offer left the
    /// screen while dispatch decided (driver-u131, driver-u140).
    void _openWonOffer(_HomeDirectOffer offer, String matchedVia) {
      if (_liveVisible && ModalRoute.of(context)?.isCurrent != false) {
        _openOfferTrip(offer, matchedVia);
        return;
      }
      _homeRadarNoticeTimer?.cancel();
      _rebuild(() {
        _claimedHomeOffer = offer;
        _claimedHomeSource = matchedVia;
      });
    }
    void _resolveHomeRadarMatchLost(
      _HomeDirectOffer offer,
      _RadarOfferGone reason,
    ) {
      final wasMatching = _homeRadarMatchingOfferId == offer.id;
      if (wasMatching) { _homeRadarNoticeTimer?.cancel(); }
      _rebuild(() {
        _homeRadarGoneReasons[offer.id] = reason;
        if (wasMatching) { _homeRadarMatchingOfferId = null; }
        _homeRadarMatchStates[offer.id] =
            _HomeRadarMatchState.claimedElsewhere;
      });
      // The island says why when this driver tapped Match, or when the
      // trip was the front card they were reading.
      final wasFront = offer.id == _radarExpandedOfferId;
      if (reason == _RadarOfferGone.lostOwnMatch ||
          reason == _RadarOfferGone.takenElsewhere) {
        IslandMessages.show(HomeIslandNotices.takenByOther);
      } else if (wasMatching || wasFront) {
        IslandMessages.show(HomeIslandNotices.tripUnavailable);
      }

      // Each lost offer leaves on its own timer: two lost together both go.
      _homeRadarLostMatchTimers.remove(offer.id)?.cancel();
      _homeRadarLostMatchTimers[offer.id] = Timer(
        const Duration(milliseconds: 2800),
        () {
          _homeRadarLostMatchTimers.remove(offer.id);
          if (!mounted ||
              _homeRadarStateFor(offer.id) !=
                  _HomeRadarMatchState.claimedElsewhere) {
            return;
          }
          _dismissRadarHomeOffer(offer);
        },
      );
    }
    void _scheduleHomeRadarExternalClaimDemo() {
      _homeRadarExternalClaimTimer?.cancel();

      _HomeDirectOffer? offer;
      for (final item in _radarHomeOffers) {
        if (item.id == 'home-radar-match-3' || item.id == 'nearby-3') {
          offer = item;
          break;
        }
      }
      offer ??= _radarHomeOffers.isEmpty ? null : _radarHomeOffers.last;
      if (offer == null ||
          _homeRadarStateFor(offer.id) != _HomeRadarMatchState.available) {
        return;
      }

      final matchedOffer = offer;
      _homeRadarExternalClaimTimer = Timer(
        const Duration(milliseconds: 4200),
        () {
          if (!mounted ||
              !_radarHomeOffers.any((item) => item.id == matchedOffer.id) ||
              _homeRadarStateFor(matchedOffer.id) !=
                  _HomeRadarMatchState.available) {
            return;
          }

          _rebuild(() {
            _homeRadarMatchStates[matchedOffer.id] =
                _HomeRadarMatchState.claimedElsewhere;
          });
          if (matchedOffer.id == _radarExpandedOfferId) {
            IslandMessages.show(HomeIslandNotices.takenByOther);
          }

          _homeRadarExternalClaimCleanupTimer?.cancel();
          _homeRadarExternalClaimCleanupTimer = Timer(
            const Duration(milliseconds: 2800),
            () {
              if (!mounted ||
                  _homeRadarStateFor(matchedOffer.id) !=
                      _HomeRadarMatchState.claimedElsewhere) {
                return;
              }
              _dismissRadarHomeOffer(matchedOffer);
            },
          );
        },
      );
    }
    /// R13-3 (C): back on screen after a pause, which cancelled the offer
    /// timers. The Exclusive offer gets its time left; Radar cards taken
    /// elsewhere meanwhile leave; the others get their pick window again.
    void _resumeOfferTimers() {
      if (!mounted) { return; }
      _HomeExclusive(this)._resumeExclusiveTimeout();
      for (final offer in _radarHomeOffers) {
        if (_homeRadarStateFor(offer.id) == _HomeRadarMatchState.available) {
          _startRadarPickWindow(offer);
        }
      }
      final taken = [
        for (final offer in _radarHomeOffers)
          if (_homeRadarStateFor(offer.id) ==
              _HomeRadarMatchState.claimedElsewhere)
            offer,
      ];
      if (taken.isEmpty) { return; }
      _homeRadarExternalClaimCleanupTimer?.cancel();
      _homeRadarExternalClaimCleanupTimer = Timer(
        const Duration(milliseconds: 1200),
        () {
          for (final offer in taken) {
            if (mounted &&
                _homeRadarStateFor(offer.id) ==
                    _HomeRadarMatchState.claimedElsewhere) {
              _dismissRadarHomeOffer(offer);
            }
          }
        },
      );
    }
    void _cancelAllOfferTimers({bool preserveClaim = false}) {
      _outsideOfferTimeoutTimer?.cancel();
      _outsideOfferTimeoutTimer = null;
      _reservationOfferTimer?.cancel();
      _reservationOfferTimer = null;
      _homeRadarMatchResolutionTimer?.cancel();
      _homeRadarNoticeTimer?.cancel();
      _homeRadarExternalClaimTimer?.cancel();
      _homeRadarExternalClaimCleanupTimer?.cancel();
      for (final timer in _homeRadarLostMatchTimers.values) {
        timer.cancel();
      }
      _homeRadarLostMatchTimers.clear();
      if (!preserveClaim) {
        _homeRadarMatchingOfferId = null;
        _claimedHomeOffer = null;
        _claimedHomeSource = null;
        _homeRadarMatchStates.clear();
        _syncClaimLock();
      }
      for (final timer in _radarOfferTimeoutTimers.values) {
        timer.cancel();
      }
      _radarOfferTimeoutTimers.clear();
      // D-04: a pause (preserveClaim) keeps each pick window's deadline and
      // the trips whose window already ran out: resume must not revive them.
      if (!preserveClaim) {
        _radarOfferExpired.clear();
        _radarOfferDeadlines.clear();
      }
    }
    void _acceptOutsideRadarOffer() {
      final offer = _outsideRadarOffer;
      if (offer == null) { return; }
      // Answered: the row of missed Exclusive offers starts again (Q16).
      ExclusiveAnswers.instance.accepted();
      // A ride Movera assigned is kept for later, through dispatch (Q29).
      if (offer.assigned) {
        _HomeScheduled(this)._acceptAssignment(offer);
        return;
      }
      // An admin direct assign or dispatch's Exclusive offer: dispatch
      // decides, like any claim (§3, §3.1).
      if (offer.claimedViaDispatch) {
        if (_exclusive.claimingId == null) {
          unawaited(_claimAdminAssign(offer));
        }
        return;
      }
      // A reservation goes to the first driver who claims it (R25).
      if (offer.reservation &&
          _HomeReservation(this)._exclusiveNeedsClaim(offer)) {
        return;
      }
      if (!offer.reservation) { _exclusiveDemoTaken = true; }
      _openOfferTrip(
        offer,
        // A stable key, not the label: the waiting rules read it (driver-u130).
        offer.reservation
            ? WaybillRecord.exclusiveReservationSource
            : WaybillRecord.exclusiveOfferSource,
      );
    }
    /// Contract §3.1: Accept on an admin direct assign is the offer's
    /// accept. Won: the trip opens. Lost or gone: it leaves with why, and
    /// it is not a miss. No answer: it counts down again.
    Future<void> _claimAdminAssign(_HomeDirectOffer offer) async {
      _outsideOfferTimeoutTimer?.cancel();
      _exclusive.clock.stop();
      _rebuild(() => _exclusive.claimingId = offer.id);
      IslandMessages.show(HomeIslandNotices.matching);
      ClaimResult result;
      try {
        result = await _dispatch.claimOffer(offer.id);
      } catch (_) {
        result = const ClaimResult.networkError();
      }
      if (!mounted) { return; }
      _rebuild(() => _exclusive.claimingId = null);
      final up = _outsideRadarOffer?.id == offer.id;
      // Not won, and the offer left the screen meanwhile: nothing to show.
      if (!up && !result.isSuccess) {
        _HomeScheduled(this)._afterClaimResolved();
        return;
      }
      switch (result.outcome) {
        case ClaimOutcome.success:
          IslandMessages.show(HomeIslandNotices.matched);
          // A reservation keeps the scheduled waiting rules.
          _openWonOffer(
            offer,
            !offer.adminAssigned
                ? (offer.reservation
                    ? WaybillRecord.exclusiveReservationSource
                    : WaybillRecord.exclusiveOfferSource)
                : offer.reservation
                ? WaybillRecord.assignedReservationSource
                : WaybillRecord.assignedByMoveraSource,
          );
          return;
        case ClaimOutcome.alreadyClaimed:
          IslandMessages.show(HomeIslandNotices.takenByOther);
          _dismissOutsideRadarOffer();
        case ClaimOutcome.expired:
        case ClaimOutcome.unavailable:
          IslandMessages.show(HomeIslandNotices.tripUnavailable);
          _dismissOutsideRadarOffer();
        case ClaimOutcome.networkError:
          IslandMessages.show(HomeIslandNotices.noConnection);
          _HomeExclusive(this)._restartExclusiveTimeout(
            offer,
            offer.lifetime ?? _DriverHomeState._outsideOfferLifetime,
            missed: true,
          );
      }
      // Not won: a late scheduled ride held back by this Accept starts.
      _HomeScheduled(this)._afterClaimResolved();
    }
    /// The down arrow, × or Back on the Exclusive offer: skipped like a
    /// time out (Q16/Q46). An admin direct assign also tells dispatch No.
    void _declineOutsideRadarOffer() {
      final offer = _outsideRadarOffer;
      if (offer != null && offer.viaDispatchAnswer && !_exclusive.leaving) {
        unawaited(_dispatch.declineOffer(offer.id));
      }
      _dismissOutsideRadarOffer(missed: true);
    }
    /// × on a Radar card hides it (never a miss, Q17); for an admin radar
    /// group it is the driver's No to dispatch.
    void _closeRadarHomeOffer(_HomeDirectOffer offer) {
      if (offer.groupId != null &&
          _homeRadarStateFor(offer.id) == _HomeRadarMatchState.available) {
        unawaited(_dispatch.declineOffer(offer.id));
      }
      _dismissRadarHomeOffer(offer);
    }
    /// Dispatch withdrew an offer: another driver took it (a radar group's
    /// first Accept, or the trip locked), it expired, or it was taken back.
    void _onOfferWithdrawn(OfferWithdrawal gone) {
      if (!mounted || !_isOnline) { return; }
      final taken = gone.reason == OfferGoneReason.claimedElsewhere;
      final up = _outsideRadarOffer;
      if (up != null && up.id == gone.offerId) {
        if (_exclusive.claimingId == up.id || _exclusive.leaving) { return; }
        // Ran out on the server: a miss, like the phone's own time out.
        if (gone.reason == OfferGoneReason.expired) {
          _dismissOutsideRadarOffer(missed: true);
          return;
        }
        IslandMessages.show(taken
            ? HomeIslandNotices.takenByOther
            : HomeIslandNotices.tripUnavailable);
        _dismissOutsideRadarOffer();
        return;
      }
      _rebuild(() {
        _pendingRadarHomeOffers.removeWhere((o) => o.id == gone.offerId);
        // Nothing waiting any more: no "Trip found" and no Exclusive
        // offer held back by it (driver-u132).
        _hasRideOffers =
            _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty;
      });
      for (final offer in _radarHomeOffers.toList()) {
        if (offer.id == gone.offerId &&
            _homeRadarStateFor(offer.id) == _HomeRadarMatchState.available) {
          _resolveHomeRadarMatchLost(offer,
              taken ? _RadarOfferGone.takenElsewhere : _RadarOfferGone.unavailable);
        }
      }
    }
    void _acceptRadarHomeOffer(_HomeDirectOffer offer) {
      if (!_radarHomeOffers.any((item) => item.id == offer.id)) { return; }
      _openOfferTrip(offer, WaybillRecord.moveraRadarSource);
    }
    /// Opens the trip for [offer], with its rider and stops, and clears
    /// the offers on Home behind it.
    ///
    /// A scheduled ride opened at "Leave now" passes its pickup time
    /// [scheduledPickupAt] and reservation [scheduledRideId]: the trip
    /// watches the ETA to that pickup.
    void _openOfferTrip(
      _HomeDirectOffer offer,
      String matchedVia, {
      DateTime? scheduledPickupAt,
      String? scheduledRideId,
      Money? acceptedPickupPay,
    }) {
      _cancelAllOfferTimers();
      // An Exclusive card slides back down behind the trip.
      _HomeExclusive(this)._sinkExclusive();
      _expandedDirectOfferTimer?.cancel();
      _offerSimulationTimer?.cancel();
      _radarOfferTwoTimer?.cancel();
      _radarOfferThreeTimer?.cancel();
      // The total its card showed, pickup pay in it (driver-12). "Leave
      // now" shows no card: its scheduled ride keeps its fare, plus the
      // pickup pay an Exclusive card showed when it was saved for later
      // (driver-r5-12).
      final quote = scheduledPickupAt == null && scheduledRideId == null
          ? _pickupPayOf(
              offer,
              onRadar: matchedVia == WaybillRecord.moveraRadarSource ||
                  _radarHomeOffers.any((item) => item.id == offer.id),
            )
          : acceptedPickupPay == null
          ? null
          : PickupPayQuote(
              pay: acceptedPickupPay,
              leg: PickupLeg(km: offer.pickupKm, minutes: offer.pickupMinutes),
            );
      final terms = quote?.termsOf(
            fare: offer.fare,
            driverBonus: offer.driverBonus,
            cashToCollect: offer.cashToCollect,
            paidByCash: offer.cash,
          ) ??
          (
            fare: offer.fare,
            driverBonus: offer.driverBonus,
            cashToCollect: offer.cashToCollect,
          );

      pushSingle(
        context,
        ActiveRideTransition(
          AcceptRide(
            // X9: the offer and the trip keep their own ids. Until a backend
            // sends the trip id, the demo makes one per accepted occurrence.
            // A sample scheduled ride has no dispatch id.
            offerId: offer.id.isEmpty ? null : offer.id,
            tripId: offer.tripId ??
                tripOccurrenceId(offer.id.isEmpty ? 'scheduled' : offer.id),
            dispatchRepository: _dispatch,
            riderName: offer.riderName.isEmpty ? tr.rider : offer.riderName,
            // driver-u133: no usable rating stays unknown ("New").
            riderRating: double.tryParse(offer.rating),
            riderTrips: offer.riderTrips,
            fare: terms.fare,
            paidByCash: offer.cash,
            cashToCollect: terms.cashToCollect,
            driverBonus: terms.driverBonus,
            category: offer.category,
            matchedVia: matchedVia,
            waybillRepository: _waybills,
            sessionController: _driverSession,
            locationRepository: _driverLocationService,
            routeRepository: _roadRouteService,
            activeRideRepository: widget.activeRideRepository,
            pickupAddress: offer.pickup,
            pickupArea: offer.pickup.split(',').last.trim(),
            dropoffAddress: offer.dropoff,
            stopAddresses: [for (final stop in offer.stops) stop.address],
            stopPositions: [
              for (final stop in offer.stops) stop.point.toLatLng(),
            ],
            pickupPosition: offer.pickupPosition,
            dropoffPosition: offer.dropoffPosition,
            pickupKm: offer.pickupKm,
            bags: offer.bags,
            destinationModeActive: _destinationModeActive,
            destinationAddress: _destinationAddress,
            destinationPosition: _destinationPosition,
            scheduledPickupAt: scheduledPickupAt,
            scheduledRideId: scheduledRideId,
          ),
        ),
      );

      _clearHomeOffersAfterFrame();
    }
    /// A trip began: Home's offers (deck, waiting trips, the Exclusive
    /// offer and its route) are done with. Also when the trip was matched
    /// from the full Radar list, not the deck (driver-u116).
    void _clearHomeOffersAfterFrame() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        _rebuild(() {
          _outsideRadarOffer = null;
          _radarHomeOffers.clear();
          _pendingRadarHomeOffers.clear();
          _hasRideOffers = false;
          _mapPreviews.cancel();
        _camera.endPreview();
        _isDirectOfferRoutePreview = false;
          _directOfferRouteMarkers = {};
          _directOfferRoutePolylines = {};
        });
      });
    }
    /// Every Radar trip open right now, not only the ones on the deck.
    int _radarTripTotal() {
      final listed = _radarHomeOffers
          .where((offer) =>
              _homeRadarStateFor(offer.id) !=
              _HomeRadarMatchState.claimedElsewhere)
          .length;
      // driver-u134: the same dispatch trips the radar button and the Radar
      // list count; an admin direct assign is an Exclusive offer.
      return math.max(listed + _pendingRadarHomeOffers.length, _radarTripsOpen);
    }
    /// The front card of the deck: the one the radar's Accept takes.
    _HomeDirectOffer? _radarFrontOffer() {
      bool open(_HomeDirectOffer offer) =>
          _homeRadarStateFor(offer.id) == _HomeRadarMatchState.available &&
          !_radarOfferExpired.contains(offer.id);
      final chosen = _radarExpandedOfferId;
      for (final offer in _radarHomeOffers) {
        if (offer.id == chosen) { return open(offer) ? offer : null; }
      }
      for (final offer in _radarHomeOffers) {
        if (open(offer)) { return offer; }
      }
      return null;
    }
    void _onRadarDeckFront(String? id) {
      if (!mounted) { return; }
      if (id == null || !_radarHomeOffers.any((offer) => offer.id == id)) {
        // No front card: nothing of a Radar route may stay on the map.
        if (_radarExpandedOfferId != null) {
          _rebuild(() => _radarExpandedOfferId = null);
        }
        _clearRadarRouteIfNoCards();
        return;
      }
      if (id == _radarExpandedOfferId) { return; }
      _rebuild(() => _radarExpandedOfferId = id);
      // R15-10: Radar offers put nothing on the map (no line, no pins);
      // a route the driver opened for another card goes away.
      if (_outsideRadarOffer == null &&
          _reservation.routeId == null &&
          (_isDirectOfferRoutePreview ||
              _directOfferRouteMarkers.isNotEmpty ||
              _directOfferRoutePolylines.isNotEmpty)) {
        _clearDirectOfferRoute();
      }
    }
    RadarOfferView _radarOfferView(_HomeDirectOffer offer) => RadarOfferView(
          id: offer.id,
          category: offer.category,
          // The wire value, never the word in the driver's language: the
          // card works the badge out from it (driver-u135).
          payment: offer.cash ? RadarOfferView.cashPayment : offer.payment,
          rating: offer.rating,
          fare: offer.fare,
          pickupMinutes: offer.pickupMinutes,
          pickupKm: offer.pickupKm,
          tripMinutes: offer.tripMinutes,
          tripKm: offer.tripKm,
          pickup: offer.pickup,
          dropoff: offer.dropoff,
          bags: offer.bags,
          reservationTime: offer.reservation ? offer.pickupTime : null,
          fareBoost: offer.fareBoost,
          stops: offer.stops.length,
          riderTrips: offer.riderTrips,
          priority: offer.priority,
          driverBonus: WaybillRecord.bonusLabel(offer.driverBonus),
          driverEarnings: offer.driverEarnings,
          // Worked out now, from the offer's pickup leg (never cached).
          pickupPay: _pickupPayOf(offer),
        );
    /// The pickup pay [offer]'s card adds to its fare. [onRadar] when the
    /// card was a Radar card (it may have left the deck since).
    PickupPayQuote _pickupPayOf(_HomeDirectOffer offer, {bool? onRadar}) =>
        PickupPayCalculator.quote(
          category: offer.category,
          kind: PickupPayOfferKind.forHomeOffer(
            onRadar: onRadar ??
                _radarHomeOffers.any((item) => item.id == offer.id),
            reservation: offer.reservation,
            assigned: offer.assigned,
            driverSigned: offer.driverSigned,
          ),
          leg: PickupLeg(km: offer.pickupKm, minutes: offer.pickupMinutes),
          serverPay: offer.serverPickupPay,
        );
    /// Radar offers on Home: a deck of cards above the radar, with the
    /// total count on top (tap it for the full-screen list).
    Widget _buildRadarOffersTray() {
      final offers = List<_HomeDirectOffer>.unmodifiable(_radarHomeOffers);
      final taken = <String>{
        for (final offer in offers)
          if (_homeRadarStateFor(offer.id) ==
              _HomeRadarMatchState.claimedElsewhere)
            offer.id,
      };
      final blocked = _homeRadarMatchingOfferId;
      return RepaintBoundary(
        child: RadarOfferDeck(
          key: const ValueKey<String>('radar-home-deck'),
          ids: [for (final offer in offers) offer.id],
          taken: taken,
          onFrontChanged: _onRadarDeckFront,
          // driver-u136: a button, taking touches in a 44 px tall box (the
          // room is above the badge, so the badge stays where it was).
          top: Semantics(
            button: true,
            child: GestureDetector(
              key: const ValueKey<String>('radar-home-all-offers'),
              behavior: HitTestBehavior.opaque,
              onTap: _openRideOffers,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1,
                  child: LedCountBadge(
                    count: _radarTripTotal(),
                    label: tr.allOffers,
                    tone: LedCountTone.grey,
                    trailing: SvgPicture.asset(
                      AppAssets.offerChevron,
                      width: 13,
                      height: 13,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF5F6B72),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          cardFor: (id) {
            final offer = offers.firstWhere((item) => item.id == id);
            final state = _homeRadarStateFor(id);
            return RadarOfferCard(
              offer: _radarOfferView(offer),
              state: state == _HomeRadarMatchState.resolving
                  ? RadarOfferCardState.matching
                  : state == _HomeRadarMatchState.claimedElsewhere
                  ? RadarOfferCardState.taken
                  : _radarOfferExpired.contains(id)
                  ? RadarOfferCardState.expired
                  : RadarOfferCardState.available,
              onMatch: blocked != null && blocked != id
                  ? null
                  : () => _startHomeRadarMatch(offer),
              onRoute: () => _previewDirectOfferRoute(offer),
              // The radar's orange, and a small × that removes the offer;
              // none while its Match is being sent.
              contour: MoveraRadarOrb.offerAccent,
              onClose: blocked == id ? null : () => _closeRadarHomeOffer(offer),
            );
          },
        ),
      );
    }
    /// The Exclusive offer's content on its Home sheet (the same sheet as
    /// a reservation request). The grey orb on its top edge accepts; the
    /// down arrow skips it.
    Widget _buildOutsideRadarOfferCard(
      _HomeDirectOffer offer, {
      required int secondsLeft,
    }) {
      final reservation = offer.reservation && !offer.driverSigned;
      final reason = ExclusiveReasons.text(offer.reason);
      return ExclusiveRequestSheet(
        offer: _radarOfferView(offer),
        secondsLeft: secondsLeft,
        reservation: reservation,
        reservationTime: reservation ? offer.pickupTime : null,
        // Destination mode, or trips toward the next scheduled pickup.
        onYourWay: _destinationModeActive ||
            (!offer.assigned && _HomeScheduled(this)._towardPickupTime != null),
        // A ride Movera assigned says so (Q29).
        // Dispatch's Exclusive offer says why it is this driver's.
        lead: offer.assigned || offer.adminAssigned
            ? ExclusiveReasons.text(ExclusiveReasons.assigned)
            : offer.dispatchExclusive && reason.isNotEmpty
            ? reason
            : ExclusiveRequestSheet.defaultLead,
      );
    }
    void _scheduleVisibleOffers() {
      if(!mounted || !_liveVisible || !_driverSession.availableForOffers) return;
      _cancelAllOfferTimers(preserveClaim: true);
      _directOfferTimer?.cancel();_offerSimulationTimer?.cancel();
      _radarOfferTwoTimer?.cancel();_radarOfferThreeTimer?.cancel();_expandedDirectOfferTimer?.cancel();
          _watchDispatchRadar();
          if (_claimedHomeOffer != null) {
            _openClaimedHomeOffer();
            return;
          }
          // Close to pickup (job L3, [ScheduledRideRules.exclusiveBeforeMinutes]
          // before its pickup time) the untaken reservation becomes an
          // Exclusive offer; it waits while other offers are on screen.
          // driver-r3-15: armed also while a Match claim is in flight.
          final untilExclusive = _HomeScheduled(this)._untilExclusiveStep();
          if (untilExclusive != null) {
            _reservationOfferTimer = Timer(untilExclusive, () {
              if (!mounted || !_isOnline) { return; }
              _soonReservationReady = true;
              _maybeShowSoonReservation();
            });
          }
          if (_homeRadarMatchingOfferId != null) { return; }

          // Frontend demo only. Outside-Radar offers remain exclusive and
          // never enter the Trip Radar list.
          _directOfferTimer = Timer(
            const Duration(milliseconds: 2200),
            () {
              if (!mounted || !_isOnline) { return; }
              // After one was accepted, the cash Exclusive (R9).
              const cash = _DriverHomeState._expandedDirectOffer;
              // R13-9 demo: in Destination mode, the trip toward it.
              final toward = _destinationModeActive ? _destinationDemoExclusive : null;
              // Q16: an admin direct assign from dispatch comes first.
              _showOutsideRadarOffer(toward ?? _pendingAdminAssign ?? (_exclusiveDemoTaken &&
                      _HomeOfferRules(this)._offerAllowed(cash)
                  ? cash
                  : _DriverHomeState._veryCloseDirectOffer));
            },
          );

          // Radar offers start only after the exclusive outside-Radar offer
          // has had its own presentation window: its time to accept from
          // Dispatch, then 3 s apart.
          final radarFrom = const Duration(milliseconds: 3000) +
              _DriverHomeState._outsideOfferLifetime;
          _offerSimulationTimer = Timer(
            radarFrom,
            () {
              if (!mounted || !_isOnline) { return; }
              _showDispatchOfferAt(0);
            },
          );

          _radarOfferTwoTimer = Timer(
            radarFrom + const Duration(seconds: 3),
            () {
              if (!mounted || !_isOnline) { return; }
              _showDispatchOfferAt(1);
            },
          );

          _radarOfferThreeTimer = Timer(
            radarFrom + const Duration(seconds: 6),
            () {
              if (!mounted || !_isOnline) { return; }
              _showDispatchOfferAt(2);
            },
          );

          // Keep a second outside-Radar example available later, but never
          // show it while Radar offers are active.
          _expandedDirectOfferTimer = Timer(
            const Duration(milliseconds: 50000),
            () {
              if (!mounted ||
                  !_isOnline ||
                  _radarHomeOffers.isNotEmpty ||
                  _hasRideOffers) {
                return;
              }
              _showOutsideRadarOffer(_DriverHomeState._expandedDirectOffer);
            },
          );

          // Radar is live: the smart gap may start the next scheduled ride,
          // and rides Movera assigns come in.
          _HomeScheduled(this)._onRadarLive();
    }
}
