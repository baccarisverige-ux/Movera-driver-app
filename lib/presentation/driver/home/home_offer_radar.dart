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
}

class _HomeDirectOffer {
  final String id;
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

  const _HomeDirectOffer({
    required this.id,
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
  });

  /// A dispatch offer on Home. A reservation keeps its pickup time for
  /// its "Reservation" badge.
  factory _HomeDirectOffer.fromRide(
    RideOffer offer, {
    String reason = '',
    bool assigned = false,
    Duration? lifetime,
  }) => _HomeDirectOffer(
    id: offer.id,
    category: offer.category,
    reason: reason,
    fare: offer.fare,
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
    cashToCollect: offer.cashToCollect,
    reservation: offer.isReservation,
    pickupTime: offer.reservationTime,
    riderName: offer.riderName,
    riderTrips: offer.riderTrips,
    stops: offer.stops,
    fareBoost: offer.fareBoost,
    assigned: assigned,
    lifetime: lifetime,
  );
}

extension _HomeOfferRadar on _DriverHomeState {
    void _maybeShowSoonReservation() {
      if (!_soonReservationReady || !mounted || !_isOnline) { return; }
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
      }
    }
    bool _directOfferFollowsDestination(_HomeDirectOffer offer) {
      if (!_destinationModeActive) { return true; }
      final destination = _destinationPosition;
      if (destination == null) { return true; }

      final latitudeRadians = _driverPosition.latitude * math.pi / 180;
      final longitudeScale = math.cos(latitudeRadians);

      final destinationX =
          (destination.longitude - _driverPosition.longitude) * longitudeScale;
      final destinationY = destination.latitude - _driverPosition.latitude;
      final offerX =
          (offer.dropoffPosition.longitude - _driverPosition.longitude) *
          longitudeScale;
      final offerY =
          offer.dropoffPosition.latitude - _driverPosition.latitude;

      final destinationLength = math.sqrt(
        destinationX * destinationX + destinationY * destinationY,
      );
      final offerLength = math.sqrt(offerX * offerX + offerY * offerY);
      if (destinationLength == 0 || offerLength == 0) { return true; }

      final cosine =
          (destinationX * offerX + destinationY * offerY) /
          (destinationLength * offerLength);
      return cosine >= 0.45;
    }
    void _clearDirectOfferRoute() {
      if (!mounted) { return; }
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
      if (mounted && _HomeReservation(this)._reservationUp) {
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
          // One Exclusive offer at a time: a waiting one never replaces it.
          (_outsideRadarOffer != null && _outsideRadarOffer!.id != offer.id) ||
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
      final arriving = _outsideRadarOffer?.id != offer.id;
      _rebuild(() {
        _outsideRadarOffer = offer;
      });
      // The card grows out of the sheet; the radar's ring starts full.
      _HomeExclusive(this)._raiseExclusive(offer, lifetime);
      // The island says it too while the card arrives.
      if (arriving) {
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
      }

      _outsideOfferTimeoutTimer = Timer(
        lifetime,
        () {
          if (!mounted || _outsideRadarOffer?.id != offer.id) { return; }
          // Ran out without Accept: it counts as missed (Q16).
          _dismissOutsideRadarOffer(missed: true);
        },
      );

      await _previewDirectOfferRoute(
        offer.pickupPosition,
        offer.dropoffPosition,
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

      if (_outsideRadarOffer != null || _HomeReservation(this)._reservationUp) {
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
      for (final offer in next) {
        _startRadarPickWindow(offer);
      }

      _rebuild(() {
        _radarOfferExpired.clear();
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
    void _startRadarPickWindow(_HomeDirectOffer offer) {
      if (_radarOfferTimeoutTimers.containsKey(offer.id)) { return; }
      _radarOfferTimeoutTimers[offer.id] = Timer(
        _DriverHomeState._radarOfferPickWindow,
        () {
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
          _outsideRadarOffer != null ||
          _HomeReservation(this)._reservationUp ||
          _pendingRadarHomeOffers.isEmpty) {
        return;
      }

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
    void _dismissRadarHomeOffer(_HomeDirectOffer offer) {
      _radarOfferTimeoutTimers.remove(offer.id)?.cancel();
      if (!mounted) { return; }

      _rebuild(() {
        _radarHomeOffers.removeWhere((item) => item.id == offer.id);
        _pendingRadarHomeOffers.removeWhere((item) => item.id == offer.id);
        _homeRadarMatchStates.remove(offer.id);
        _homeRadarGoneReasons.remove(offer.id);
        _radarOfferExpired.remove(offer.id);
        _hasRideOffers =
            _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty;
      });

      if (_radarHomeOffers.isEmpty && _pendingRadarHomeOffers.isNotEmpty) {
        _releasePendingRadarOffers();
      }
      if (_radarHomeOffers.isEmpty && _pendingRadarHomeOffers.isEmpty) {
        _maybeShowSoonReservation();
        _HomeScheduled(this)._maybeShowAssignment();
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
          IslandMessages.show(HomeIslandNotices.noConnection);
      }
    }
    void _watchDispatchRadar() {
      _radarSubscription?.cancel();
      _radarSubscription = _dispatch.watchNearbyOffers().listen((offers) {
        if (!mounted || !_isOnline) { return; }
        final known = {for (final offer in _latestDispatchOffers) offer.id};
        _latestDispatchOffers = offers;
        // A reservation that just joined Radar (its Radar time, or back
        // after a cancel) comes onto the deck too, once its Exclusive step
        // on this phone is over.
        for (final offer in offers) {
          if (offer.isReservation &&
              !known.contains(offer.id) &&
              _outsideRadarOffer?.id != offer.id &&
              _HomeScheduled(this)._exclusiveStepReached(offer.id)) {
            _HomeReservation(this)._reservationToDeck(offer.id);
          }
        }
        final ids = offers.map((item) => item.id).toSet();
        for (final offer in [..._radarHomeOffers, ..._pendingRadarHomeOffers]) {
          if (!ids.contains(offer.id) &&
              _homeRadarStateFor(offer.id) == _HomeRadarMatchState.available) {
            // Gone from Radar without a claim of ours: the reason is not
            // known here (rider cancelled, expired, taken elsewhere…).
            _resolveHomeRadarMatchLost(offer, _RadarOfferGone.unavailable);
          }
        }
      });
    }
    void _showDispatchOfferAt(int index) {
      final offers = _latestDispatchOffers.where((offer) => offer.isNearby &&
          (!_destinationModeActive || offer.followsDestination)).toList();
      if (index >= offers.length) { return; }
      _showRadarHomeOffer(_homeOfferFromDispatch(offers[index]));
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
          _acceptRadarHomeOffer(offer);
        },
      );
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
      if (reason == _RadarOfferGone.lostOwnMatch) {
        IslandMessages.show(HomeIslandNotices.takenByOther);
      } else if (wasMatching || wasFront) {
        IslandMessages.show(HomeIslandNotices.tripUnavailable);
      }

      _homeRadarLostMatchTimer?.cancel();
      _homeRadarLostMatchTimer = Timer(
        const Duration(milliseconds: 2800),
        () {
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
    void _cancelAllOfferTimers({bool preserveClaim = false}) {
      _outsideOfferTimeoutTimer?.cancel();
      _outsideOfferTimeoutTimer = null;
      _reservationOfferTimer?.cancel();
      _reservationOfferTimer = null;
      _homeRadarMatchResolutionTimer?.cancel();
      _homeRadarNoticeTimer?.cancel();
      _homeRadarExternalClaimTimer?.cancel();
      _homeRadarExternalClaimCleanupTimer?.cancel();
      _homeRadarLostMatchTimer?.cancel();
      if (!preserveClaim) {
        _homeRadarMatchingOfferId = null;
        _claimedHomeOffer = null;
        _homeRadarMatchStates.clear();
      }
      for (final timer in _radarOfferTimeoutTimers.values) {
        timer.cancel();
      }
      _radarOfferTimeoutTimers.clear();
      _radarOfferExpired.clear();
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
      // A reservation goes to the first driver who claims it (R25).
      if (offer.reservation &&
          _HomeReservation(this)._exclusiveNeedsClaim(offer)) {
        return;
      }
      _openOfferTrip(
        offer,
        offer.reservation ? 'Exclusive reservation' : 'Exclusive offer',
      );
    }
    void _acceptRadarHomeOffer(_HomeDirectOffer offer) {
      if (!_radarHomeOffers.any((item) => item.id == offer.id)) { return; }
      _openOfferTrip(offer, 'Movera Radar');
    }
    /// Opens the trip for [offer], with its rider and stops, and clears
    /// the offers on Home behind it.
    void _openOfferTrip(_HomeDirectOffer offer, String matchedVia) {
      _cancelAllOfferTimers();
      // An Exclusive card slides back down behind the trip.
      _HomeExclusive(this)._sinkExclusive();
      _expandedDirectOfferTimer?.cancel();
      _offerSimulationTimer?.cancel();
      _radarOfferTwoTimer?.cancel();
      _radarOfferThreeTimer?.cancel();

      pushSingle(
        context,
        ActiveRideTransition(
          AcceptRide(
            // A sample scheduled ride has no dispatch id.
            offerId: tripOccurrenceId(offer.id.isEmpty ? 'scheduled' : offer.id),
            riderName: offer.riderName.isEmpty ? 'Rider' : offer.riderName,
            riderRating: double.tryParse(offer.rating) ?? 4.9,
            riderTrips: offer.riderTrips,
            fare: offer.fare,
            paidByCash: offer.cash,
            cashToCollect: offer.cashToCollect,
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
            destinationModeActive: _destinationModeActive,
            destinationAddress: _destinationAddress,
            destinationPosition: _destinationPosition,
          ),
        ),
      );

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
      final nearby = _latestDispatchOffers
          .where((offer) =>
              offer.isNearby &&
              (!_destinationModeActive || offer.followsDestination) &&
              _HomeOfferRules(this)._rideAllowed(offer))
          .length;
      return math.max(listed + _pendingRadarHomeOffers.length, nearby);
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
      if (!mounted || id == _radarExpandedOfferId) { return; }
      _rebuild(() => _radarExpandedOfferId = id);
      for (final offer in _radarHomeOffers) {
        if (offer.id == id) {
          _previewDirectOfferRoute(offer.pickupPosition, offer.dropoffPosition);
          return;
        }
      }
    }
    RadarOfferView _radarOfferView(_HomeDirectOffer offer) => RadarOfferView(
          id: offer.id,
          category: offer.category,
          payment: offer.cash ? 'Cash' : offer.payment,
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
          // Worked out now, from the offer's pickup leg (never cached).
          pickupPay: PickupPayCalculator.quote(
            category: offer.category,
            kind: PickupPayOfferKind.forHomeOffer(
              onRadar: _radarHomeOffers.any((item) => item.id == offer.id),
              reservation: offer.reservation,
              assigned: offer.assigned,
              driverSigned: offer.driverSigned,
            ),
            leg: PickupLeg(km: offer.pickupKm, minutes: offer.pickupMinutes),
          ),
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
          top: GestureDetector(
            key: const ValueKey<String>('radar-home-all-offers'),
            onTap: _openRideOffers,
            child: LedCountBadge(
              count: _radarTripTotal(),
              label: 'ALL OFFERS',
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
              onRoute: () => _previewDirectOfferRoute(
                offer.pickupPosition,
                offer.dropoffPosition,
              ),
              // The radar's orange, and a small × that removes the offer.
              contour: MoveraRadarOrb.offerAccent,
              onClose: () => _dismissRadarHomeOffer(offer),
            );
          },
        ),
      );
    }
    /// The Exclusive offer's card on top of the Home sheet. The radar is
    /// its Accept; × hides it.
    Widget _buildOutsideRadarOfferCard(
      _HomeDirectOffer offer, {
      double bottomInset = 22,
      double? maxContentHeight,
      double contour = 0,
    }) {
      final reservation = offer.reservation && !offer.driverSigned;
      return ExclusiveOfferCard(
        key: ValueKey<String>('direct-offer-${offer.id}'),
        offer: _radarOfferView(offer),
        bottomInset: bottomInset,
        maxContentHeight: maxContentHeight,
        contour: contour,
        // The reason's text comes from the admin's list (Q15).
        reason: offer.reason.isEmpty ? null : ExclusiveReasons.text(offer.reason),
        reservation: reservation,
        reservationTime: reservation ? offer.pickupTime : null,
        // Destination mode, or trips toward the next scheduled pickup.
        onYourWay: _destinationModeActive ||
            (!offer.assigned && _HomeScheduled(this)._towardPickupTime != null),
        onDismiss: () => _dismissOutsideRadarOffer(missed: true),
        onRoute: () => _previewDirectOfferRoute(
          offer.pickupPosition,
          offer.dropoffPosition,
        ),
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
          if (_homeRadarMatchingOfferId != null) { return; }

          // Frontend demo only. Outside-Radar offers remain exclusive and
          // never enter the Trip Radar list.
          _directOfferTimer = Timer(
            const Duration(milliseconds: 2200),
            () {
              if (!mounted || !_isOnline) { return; }
              _showOutsideRadarOffer(_DriverHomeState._veryCloseDirectOffer);
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

          // Close to pickup (job L3, [ScheduledRideRules.exclusiveBeforeMinutes]
          // before its pickup time) the untaken reservation becomes an
          // Exclusive offer; it waits while other offers are on screen.
          final untilExclusive = _HomeScheduled(this)._untilExclusiveStep();
          if (untilExclusive != null) {
            _reservationOfferTimer = Timer(untilExclusive, () {
              if (!mounted || !_isOnline) { return; }
              _soonReservationReady = true;
              _maybeShowSoonReservation();
            });
          }
          // Radar is live: the smart gap may start the next scheduled ride,
          // and rides Movera assigns come in.
          _HomeScheduled(this)._onRadarLive();
    }
}
