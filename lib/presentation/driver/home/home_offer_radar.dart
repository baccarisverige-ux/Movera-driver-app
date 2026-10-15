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
  final String reason;
  final String detail;
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
  final int bags;
  final String payment;

  /// A reservation's pickup time, e.g. "07:40".
  final String? pickupTime;
  final bool driverSigned = false;

  const _HomeDirectOffer({
    required this.id,
    required this.category,
    required this.reason,
    required this.detail,
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
    this.bags = 0,
    this.payment = 'Card',
    this.pickupTime,
  });
}

extension _HomeOfferRadar on _DriverHomeState {
    void _maybeShowSoonReservation() {
      if (!_soonReservationReady || !mounted || !_isOnline) { return; }
      final offer = _DriverHomeState._soonReservationOffer;
      if (offer.driverSigned || offer.pickupMinutes > 30) { return; }
      if (!_directOfferFollowsDestination(offer)) { return; }

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
      _rebuild(() {
        _mapPreviews.cancel();
        _camera.endPreview();
        _isDirectOfferRoutePreview = false;
        _directOfferRouteMarkers = {};
        _directOfferRoutePolylines = {};
      });
    }
    Future<void> _showOutsideRadarOffer(
      _HomeDirectOffer offer,
    ) async {
      if (!mounted ||
          !_isOnline ||
          showRideRequests ||
          _radarHomeOffers.isNotEmpty ||
          _pendingRadarHomeOffers.isNotEmpty ||
          _hasRideOffers ||
          !_directOfferFollowsDestination(offer) ||
          (offer.reservation &&
              (offer.driverSigned || offer.pickupMinutes > 30)) ||
          _mainPanelPosition > 0.04 ||
          isPanelOpen) {
        return;
      }

      _outsideOfferTimeoutTimer?.cancel();
      final arriving = _outsideRadarOffer?.id != offer.id;
      _rebuild(() {
        _outsideRadarOffer = offer;
      });
      // The island says it too while the card arrives.
      if (arriving) {
        IslandMessages.show(offer.reservation
            ? HomeIslandNotices.exclusiveReservation
            : HomeIslandNotices.exclusiveRide);
      }

      _outsideOfferTimeoutTimer = Timer(
        _DriverHomeState._outsideOfferLifetime,
        () {
          if (!mounted || _outsideRadarOffer?.id != offer.id) { return; }
          _dismissOutsideRadarOffer();
        },
      );

      await _previewDirectOfferRoute(
        offer.pickupPosition,
        offer.dropoffPosition,
      );
    }
    void _dismissOutsideRadarOffer() {
      _outsideOfferTimeoutTimer?.cancel();
      _outsideOfferTimeoutTimer = null;
      if (!mounted) { return; }

      _rebuild(() {
        _outsideRadarOffer = null;
      });
      _clearDirectOfferRoute();
      _releasePendingRadarOffers();
    }
    void _showRadarHomeOffer(_HomeDirectOffer offer) {
      if (!mounted ||
          !_isOnline ||
          !_directOfferFollowsDestination(offer) ||
          _radarHomeOffers.any((item) => item.id == offer.id) ||
          _pendingRadarHomeOffers.any((item) => item.id == offer.id) ||
          _radarHomeOffers.length + _pendingRadarHomeOffers.length >=
              _DriverHomeState._maxHomeRadarOffers) {
        return;
      }

      // Dispatch owns offer expiry and claim state for both Home and Radar.

      if (_outsideRadarOffer != null) {
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
        _latestDispatchOffers = offers;
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
      final offer = offers[index];
      _showRadarHomeOffer(_HomeDirectOffer(
        id: offer.id,
        category: offer.category,
        reason: 'Trip Radar match',
        detail: 'Detected in your live radar coverage',
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
      ));
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

      _cancelAllOfferTimers();
      _expandedDirectOfferTimer?.cancel();
      _offerSimulationTimer?.cancel();
      _radarOfferTwoTimer?.cancel();
      _radarOfferThreeTimer?.cancel();

      pushSingle(
        context,
        ActiveRideTransition(
          AcceptRide(
            offerId: tripOccurrenceId(offer.id),
            fare: offer.fare,
            paidByCash: offer.cash,
            category: offer.category,
            matchedVia: offer.reservation ? 'Reservation' : 'Exclusive Radar',
            waybillRepository: _waybills,
            sessionController: _driverSession,
            locationRepository: _driverLocationService,
            routeRepository: _roadRouteService,
            activeRideRepository: widget.activeRideRepository,
            pickupAddress: offer.pickup,
            pickupArea: offer.pickup.split(',').last.trim(),
            dropoffAddress: offer.dropoff,
            pickupPosition: offer.pickupPosition,
            dropoffPosition: offer.dropoffPosition,
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
    void _acceptRadarHomeOffer(_HomeDirectOffer offer) {
      if (!_radarHomeOffers.any((item) => item.id == offer.id)) { return; }

      _cancelAllOfferTimers();
      _expandedDirectOfferTimer?.cancel();
      _offerSimulationTimer?.cancel();
      _radarOfferTwoTimer?.cancel();
      _radarOfferThreeTimer?.cancel();

      pushSingle(
        context,
        ActiveRideTransition(
          AcceptRide(
            offerId: tripOccurrenceId(offer.id),
            fare: offer.fare,
            paidByCash: offer.cash,
            category: offer.category,
            matchedVia: 'Movera Radar',
            waybillRepository: _waybills,
            sessionController: _driverSession,
            locationRepository: _driverLocationService,
            routeRepository: _roadRouteService,
            activeRideRepository: widget.activeRideRepository,
            pickupAddress: offer.pickup,
            pickupArea: offer.pickup.split(',').last.trim(),
            dropoffAddress: offer.dropoff,
            pickupPosition: offer.pickupPosition,
            dropoffPosition: offer.dropoffPosition,
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
              (!_destinationModeActive || offer.followsDestination))
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
            );
          },
        ),
      );
    }
    /// The Exclusive offer on Home, in the Radar card style. Its Accept
    /// counts down the offer's lifetime; × hides it.
    Widget _buildOutsideRadarOfferCard(_HomeDirectOffer offer) {
      final reservation = offer.reservation && !offer.driverSigned;
      return ExclusiveOfferCard(
        key: ValueKey<String>('direct-offer-${offer.id}'),
        offer: _radarOfferView(offer),
        lifetime: _DriverHomeState._outsideOfferLifetime,
        reservation: reservation,
        reservationTime: reservation ? offer.pickupTime : null,
        onYourWay: _destinationModeActive,
        onDismiss: _dismissOutsideRadarOffer,
        onRoute: () => _previewDirectOfferRoute(
          offer.pickupPosition,
          offer.dropoffPosition,
        ),
        onAccept: _acceptOutsideRadarOffer,
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
          // has had its own presentation window.
          _offerSimulationTimer = Timer(
            const Duration(milliseconds: 11500),
            () {
              if (!mounted || !_isOnline) { return; }
              _showDispatchOfferAt(0);
            },
          );

          _radarOfferTwoTimer = Timer(
            const Duration(milliseconds: 14500),
            () {
              if (!mounted || !_isOnline) { return; }
              _showDispatchOfferAt(1);
            },
          );

          _radarOfferThreeTimer = Timer(
            const Duration(milliseconds: 17500),
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

          _soonReservationReady = true;
          _reservationOfferTimer = Timer(
            const Duration(milliseconds: 40000),
            () {
              if (!mounted || !_isOnline) { return; }
              _maybeShowSoonReservation();
            },
          );
    }
}
