part of 'home.dart';

// Base job B8 (2026-11-04): moved word for word out of home_offer_radar.dart
// (no behaviour change).
extension _HomeOfferRadarClaims on _DriverHomeState {
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

  Future<void> _claimHomeRadarOffer(_HomeDirectOffer offer) async {
    ClaimResult result;
    try {
      result = await _dispatch.claimOffer(offer.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    if (!mounted || _homeRadarMatchingOfferId != offer.id) {
      return;
    }
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
        IslandMessages.show(HomeIslandNotices.noConnection.forRide(offer.id));
    }
    if (_homeRadarMatchingOfferId == null) {
      _HomeScheduled(this)._afterClaimResolved();
      _retryHeldExclusive();
    }
  }

  /// Job 3 / L4: an Exclusive offer held behind a Radar Match comes up
  /// once the Match settles without a trip, while it is still valid
  /// (`_pendingAdminAssign` skips shown and expired ones).
  void _retryHeldExclusive() {
    if (!mounted ||
        !_isOnline ||
        _homeRadarMatchingOfferId != null ||
        _outsideRadarOffer != null) {
      return;
    }
    final held = _pendingAdminAssign;
    if (held != null) unawaited(_showOutsideRadarOffer(held));
  }

  void _watchDispatchRadar() {
    _withdrawalSubscription?.cancel();
    _withdrawalSubscription = _dispatch.watchWithdrawals().listen(
      _onOfferWithdrawn,
    );
    _radarSubscription?.cancel();
    _radarSubscription = _dispatch.watchNearbyOffers().listen((offers) {
      if (!mounted || !_isOnline) {
        return;
      }
      final known = {for (final offer in _latestDispatchOffers) offer.id};
      final open = _radarTripsOpen;
      _latestDispatchOffers = offers;
      // The radar button's trip count (D-16: counted per build, not per
      // frame) redraws only when it changes.
      if (_hasRideOffers &&
          _radarTripsOpen == 0 &&
          _radarHomeOffers.isEmpty &&
          _pendingRadarHomeOffers.isEmpty) {
        // driver-u117: the trips the Radar list had when it closed left
        // dispatch; with none left anywhere, Home is scanning again.
        _rebuild(() => _hasRideOffers = false);
      } else if (_radarTripsOpen != open) {
        _rebuild(() {});
      }
      // A reservation that just joined Radar (its Radar time, or back
      // after a cancel) comes onto the deck too, once its Exclusive step
      // on this phone is over.
      // G6 live fix 1: an admin Exclusive offer replaces this driver's
      // automatic Radar offer for the same trip (the server withdraws it).
      // The old card leaves at once, without "Trip not available", so the
      // Exclusive offer can come up now instead of being held behind it.
      final ids = offers.map((item) => item.id).toSet();
      final replacedTrips = {
        for (final offer in offers)
          if (offer.isExclusive && !known.contains(offer.id)) offer.tripId,
      }..remove(null);
      if (replacedTrips.isNotEmpty) {
        for (final card in [..._radarHomeOffers, ..._pendingRadarHomeOffers]) {
          if (replacedTrips.contains(card.tripId) &&
              !ids.contains(card.id) &&
              card.id != _homeRadarMatchingOfferId) {
            _dismissRadarHomeOffer(card);
          }
        }
      }
      for (final offer in offers) {
        // Q16: an admin direct assign or dispatch's Exclusive offer
        // arriving now is an Exclusive offer.
        if (offer.isExclusive &&
            !known.contains(offer.id) &&
            !_adminAssignsShown.contains(offer.id) &&
            !_passedServerExpiry(offer)) {
          unawaited(_showOutsideRadarOffer(_adminAssignOffer(offer)));
        }
        if (offer.isReservation &&
            !known.contains(offer.id) &&
            _outsideRadarOffer?.id != offer.id &&
            _HomeScheduled(this)._exclusiveStepReached(offer.id)) {
          _HomeReservation(this)._reservationToDeck(offer.id);
        }
        // A live build: a Radar trip the server just sent joins the deck
        // at once (the demo brings its trips in on timers).
        if (LiveDriverServices.active &&
            !known.contains(offer.id) &&
            !offer.isExclusive &&
            !offer.isReservation &&
            offer.isNearby &&
            _homeRadarMatchingOfferId == null) {
          _showRadarHomeOffer(_homeOfferFromDispatch(offer));
        }
      }
      // An admin direct assign on screen that left dispatch is gone.
      final up = _outsideRadarOffer;
      if (up != null &&
          up.claimedViaDispatch &&
          !ids.contains(up.id) &&
          _exclusive.claimingId != up.id &&
          !_exclusive.leaving) {
        IslandMessages.show(HomeIslandNotices.tripUnavailable.forRide(up.id));
        _dismissOutsideRadarOffer();
      }
      // driver-u116: the full Radar list's own Match took it; the trip
      // that begins clears the deck. A lost Match sweeps afterwards.
      if (_radarListClaiming.value) {
        return;
      }
      _sweepGoneRadarOffers();
    });
  }

  /// An admin direct assign (contract §3.1) or dispatch's own Exclusive
  /// offer (§3) as an Exclusive offer. It runs to the server's
  /// `expiresAt` when dispatch sent one. G4-E7: no "why you" reason.
  _HomeDirectOffer _adminAssignOffer(RideOffer offer) {
    final left = offer.expiresAt?.difference(DateTime.now());
    return _HomeDirectOffer.fromRide(
      offer,
      reason: offer.isAdminDirectAssign ? ExclusiveReasons.assigned : '',
      dispatchExclusive: true,
      lifetime: left != null && left > Duration.zero ? left : null,
    );
  }

  /// driver-r5-2: the server's `expiresAt` has passed: the offer is gone,
  /// even before its withdrawal arrives. It is not shown with the app's
  /// own full time (Accept would only answer "expired").
  bool _passedServerExpiry(RideOffer offer) {
    final expires = offer.expiresAt;
    return expires != null && !expires.isAfter(DateTime.now());
  }

  /// The first dispatch Exclusive offer not shown yet.
  _HomeDirectOffer? get _pendingAdminAssign {
    for (final offer in _latestDispatchOffers) {
      if (offer.isExclusive &&
          !_adminAssignsShown.contains(offer.id) &&
          !_passedServerExpiry(offer)) {
        return _adminAssignOffer(offer);
      }
    }
    return null;
  }

  void _resolveHomeRadarMatchWon(_HomeDirectOffer offer) {
    _homeRadarNoticeTimer?.cancel();

    _rebuild(() {
      // Keep ownership until the active ride opens. Other offers and the
      // dispatch removal of our own claimed offer cannot steal this handoff.
      _homeRadarMatchingOfferId = offer.id;
      _homeRadarMatchStates[offer.id] = _HomeRadarMatchState.resolving;
      _claimedHomeOffer = offer;
    });
    IslandMessages.show(HomeIslandNotices.matched.forRide(offer.id));
    _openClaimedHomeOffer();
  }

  void _resolveHomeRadarMatchLost(
    _HomeDirectOffer offer,
    _RadarOfferGone reason,
  ) {
    final wasMatching = _homeRadarMatchingOfferId == offer.id;
    if (wasMatching) {
      _homeRadarNoticeTimer?.cancel();
    }
    _rebuild(() {
      _homeRadarGoneReasons[offer.id] = reason;
      if (wasMatching) {
        _homeRadarMatchingOfferId = null;
      }
      _homeRadarMatchStates[offer.id] = _HomeRadarMatchState.claimedElsewhere;
    });
    if (wasMatching) _retryHeldExclusive();
    // The island says why when this driver tapped Match, or when the
    // trip was the front card they were reading.
    final wasFront = offer.id == _radarExpandedOfferId;
    if (reason == _RadarOfferGone.lostOwnMatch ||
        reason == _RadarOfferGone.takenElsewhere) {
      IslandMessages.show(HomeIslandNotices.takenByOther.forRide(offer.id));
    } else if (wasMatching || wasFront) {
      _showTripUnavailableUnlessOfferedAgain(offer.id, offer.tripId);
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
    // A live build: only the server says a trip went to someone else.
    if (LiveDriverServices.active) {
      return;
    }

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
          IslandMessages.show(
            HomeIslandNotices.takenByOther.forRide(matchedOffer.id),
          );
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

  /// Contract §3.1: Accept on an admin direct assign is the offer's
  /// accept. Won: the trip opens. Lost or gone: it leaves with why, and
  /// it is not a miss. No answer: it counts down again.
  Future<void> _claimAdminAssign(_HomeDirectOffer offer) async {
    _outsideOfferTimeoutTimer?.cancel();
    _exclusive.clock.stop();
    _rebuild(() => _exclusive.claimingId = offer.id);
    IslandMessages.show(HomeIslandNotices.accepting.forRide(offer.id));
    ClaimResult result;
    try {
      result = await _dispatch.claimOffer(offer.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    if (!mounted) {
      return;
    }
    _rebuild(() => _exclusive.claimingId = null);
    final up = _outsideRadarOffer?.id == offer.id;
    // Not won, and the offer left the screen meanwhile: nothing to show.
    if (!up && !result.isSuccess) {
      _HomeScheduled(this)._afterClaimResolved();
      return;
    }
    switch (result.outcome) {
      case ClaimOutcome.success:
        IslandMessages.show(HomeIslandNotices.matched.forRide(offer.id));
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
      case ClaimOutcome.alreadyClaimed ||
              ClaimOutcome.expired ||
              ClaimOutcome.unavailable
          when result.afterCheck:
        // G4 decision 4: the Accept's answer was lost and the server then
        // said it is gone: "Offer no longer available", 2 s, not a miss.
        IslandMessages.show(HomeIslandNotices.offerGone.forRide(offer.id));
        _dismissOutsideRadarOffer();
      case ClaimOutcome.alreadyClaimed:
        IslandMessages.show(HomeIslandNotices.takenByOther.forRide(offer.id));
        _dismissOutsideRadarOffer();
      case ClaimOutcome.expired:
      case ClaimOutcome.unavailable:
        IslandMessages.show(
          HomeIslandNotices.tripUnavailable.forRide(offer.id),
        );
        _dismissOutsideRadarOffer();
      case ClaimOutcome.networkError:
        IslandMessages.show(HomeIslandNotices.noConnection.forRide(offer.id));
        _HomeExclusive(this)._restartExclusiveTimeout(
          offer,
          offer.lifetime ?? _DriverHomeState._outsideOfferLifetime,
          missed: true,
        );
    }
    // Not won: a late scheduled ride held back by this Accept starts.
    _HomeScheduled(this)._afterClaimResolved();
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

  /// Owner live test 2026-11-01: the automatic radar sends the same trip
  /// again every round (the old offer leaves, a new one comes at once), and
  /// an admin exclusive replaces the automatic offer. That is not "Trip not
  /// available": the island says so only when no offer for the trip came
  /// back within a moment. Tagged with the gone [offerId] so it replaces
  /// that offer's own "Matching…" at once (owner "Keep both" rule).
  void _showTripUnavailableUnlessOfferedAgain(String offerId, String? tripId) {
    if (tripId == null) {
      IslandMessages.show(HomeIslandNotices.tripUnavailable.forRide(offerId));
      return;
    }
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_isOnline || _hasOfferForTrip(tripId)) return;
      IslandMessages.show(HomeIslandNotices.tripUnavailable.forRide(offerId));
    });
  }

  bool _hasOfferForTrip(String tripId) =>
      _outsideRadarOffer?.tripId == tripId ||
      _radarHomeOffers.any(
        (o) =>
            o.tripId == tripId &&
            _homeRadarStateFor(o.id) == _HomeRadarMatchState.available,
      ) ||
      _pendingRadarHomeOffers.any((o) => o.tripId == tripId);

  /// Dispatch withdrew an offer: another driver took it (a radar group's
  /// first Accept, or the trip locked), it expired, or it was taken back.
  void _onOfferWithdrawn(OfferWithdrawal gone) {
    if (!mounted || !_isOnline) {
      return;
    }
    final taken = gone.reason == OfferGoneReason.claimedElsewhere;
    final up = _outsideRadarOffer;
    if (up != null && up.id == gone.offerId) {
      if (_exclusive.claimingId == up.id || _exclusive.leaving) {
        return;
      }
      // Ran out on the server: a miss, like the phone's own time out.
      if (gone.reason == OfferGoneReason.expired) {
        _dismissOutsideRadarOffer(missed: true);
        return;
      }
      if (taken) {
        IslandMessages.show(HomeIslandNotices.takenByOther.forRide(up.id));
      } else {
        _showTripUnavailableUnlessOfferedAgain(up.id, gone.tripId);
      }
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
        _resolveHomeRadarMatchLost(
          offer,
          taken ? _RadarOfferGone.takenElsewhere : _RadarOfferGone.unavailable,
        );
      }
    }
  }

  void _acceptRadarHomeOffer(_HomeDirectOffer offer) {
    if (!_radarHomeOffers.any((item) => item.id == offer.id)) {
      return;
    }
    // Owner 2026-10-27: any accepted trip, Radar too, starts the row of
    // missed Exclusive offers again.
    ExclusiveAnswers.instance.accepted();
    _openOfferTrip(offer, WaybillRecord.moveraRadarSource);
  }

  void _onRadarDeckFront(String? id) {
    if (!mounted) {
      return;
    }
    if (id == null || !_radarHomeOffers.any((offer) => offer.id == id)) {
      // No front card: nothing of a Radar route may stay on the map.
      if (_radarExpandedOfferId != null) {
        _rebuild(() => _radarExpandedOfferId = null);
      }
      _clearRadarRouteIfNoCards();
      return;
    }
    if (id == _radarExpandedOfferId) {
      return;
    }
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
    reservationTime: offer.reservation ? offer.pickupTime : offer.bookedTime,
    fareBoost: offer.fareBoost,
    stops: offer.stops.length,
    riderTrips: offer.riderTrips,
    priority: offer.priority,
    driverBonus: WaybillRecord.bonusLabel(offer.driverBonus),
    driverEarnings: offer.driverEarnings,
    // Worked out now, from the offer's pickup leg (never cached).
    pickupPay: _pickupPayOf(offer),
    onYourWay: _HomeOfferRadar(this)._offerOnYourWay(offer.dropoffPosition),
  );
}
