part of 'home.dart';

// The reservation request on Home (notes R11–R26). It first sits in every
// driver's Scheduled rides; untaken after a demo delay it is also sent to
// Home, where it rises from under the dock as an extension of the Home
// sheet while Radar is live. The radar is its Accept button; the × only
// hides it. Close to pickup it becomes an Exclusive offer and a Radar trip.
// Every take goes through dispatch, which gives it to the first claim.
// The demo timings are in [ReservationDemoTimings].

/// Where the Home reservation stands. One object on the state, so the
/// popup's fields stay together.
class _HomeReservationState {
  /// Sent to Home and not hidden: it rises while Radar is live.
  ReservationRequestPreview? request;

  /// It was sent to Home once; × does not bring it back.
  bool sent = false;

  /// The island said "New reservation" for this round.
  bool announced = false;

  /// The sheet is (nearly) up: the radar is Accept, the dock black.
  bool raised = false;

  /// Seen taken (not open in Scheduled rides). Open again later means the
  /// driver cancelled it and it went back out (R24).
  bool seenTaken = false;

  /// The reservation whose claim is with dispatch right now.
  String? claimingId;

  /// Won through its Exclusive offer: Accept may open the ride.
  String? wonId;

  /// Lets the Radar trips that waited behind the sheet come in.
  Timer? release;
}

extension _HomeReservation on _DriverHomeState {
    ReservationRequestPreview? get _homeRequest =>
        _adminHomeConfig.scheduledRides.newRequest;

    /// Sends the open reservation to Home once it has waited in Scheduled
    /// rides for [ReservationDemoTimings.homePopupAfter] (job L2).
    void _scheduleReservationPopup() {
      final request = _homeRequest;
      if (!DriverRuntimeConfig.current.reservationPopup ||
          !_adminHomeConfig.scheduledRides.hasOpenRequests ||
          request == null ||
          _reservation.sent) {
        return;
      }
      _reservationPopupTimer?.cancel();
      _reservationPopupTimer = Timer(ReservationDemoTimings.homePopupAfter, () {
        // Taken in the meantime, here or by another driver: nothing to send.
        // Close to pickup it is an Exclusive offer, no longer the popup.
        if (!mounted ||
            _reservation.sent ||
            !ScheduledRideStore.isOpen(request.id) ||
            _HomeScheduled(this)._exclusiveStepReached(request.id)) {
          return;
        }
        _rebuild(() {
          _reservation.sent = true;
          _reservation.request = request;
        });
      });
    }

    /// The reservation is up on Home right now: only while Radar is live
    /// (R13), the Home sheet closed and nothing else in the dock's place.
    /// It stays up while another screen covers Home, so Back from the
    /// full route returns to it.
    bool get _reservationUp {
      final request = _reservation.request;
      return request != null &&
          _recoveryResolved &&
          _driverSession.availableForOffers &&
          _outsideRadarOffer == null &&
          _radarHomeOffers.isEmpty &&
          !showRideRequests &&
          !hideMainPanel &&
          !_HomeMapSheet(this)._homeSheetInactive &&
          _mainPanelPosition <= 0.04 &&
          ScheduledRideStore.isOpen(request.id);
    }

    /// Risen on the dock: the radar is Accept and the dock contour black,
    /// from the moment the sheet starts to rise.
    bool get _reservationOnDock => _reservation.raised && _reservationUp;

    /// The sheet behind the dock; its content ends above the radar orb.
    Widget _reservationLayer() {
      final viewport = MediaQuery.sizeOf(context);
      final safeTop = MediaQuery.paddingOf(context).top;
      const bottomInset = 178.0;
      return Positioned(
        key: const ValueKey<String>('home-reservation-slot'),
        // One pixel past each side: only the top contour shows.
        left: -1,
        right: -1,
        bottom: 0,
        child: ValueListenableBuilder<double>(
          valueListenable: _panelSlidePosition,
          builder: (context, _, __) => HomeReservationSheet(
            request: _reservation.request,
            visible: _reservationUp,
            bottomInset: bottomInset,
            // Leaves the top island and some map above the sheet.
            maxContentHeight: math.max(
              160.0,
              viewport.height - safeTop - 72 - bottomInset,
            ),
            onHide: _reservation.claimingId != null
                ? null
                : _hideHomeReservation,
            onShown: _onReservationRising,
            onHidden: () {
              if (mounted && _reservation.raised) {
                _rebuild(() => _reservation.raised = false);
              }
            },
          ),
        ),
      );
    }

    /// The sheet is nearly up: the radar turns into Accept; once per round
    /// the island says so.
    void _onReservationRising() {
      if (!mounted) { return; }
      _rebuild(() => _reservation.raised = true);
      if (_reservation.announced) { return; }
      _reservation.announced = true;
      IslandMessages.show(HomeIslandNotices.newReservation);
    }

    /// While the reservation is up the radar reads "Accept · TAP" on a
    /// black orb; tapping it takes the reservation.
    Widget _reserveRadar() {
      final claiming = _reservation.claimingId != null;
      return KeyedSubtree(
        key: const ValueKey<String>('home-radar-reserve'),
        child: MoveraRadarOrb(
          title: claiming ? 'Matching' : 'Accept',
          status: claiming ? 'WAIT' : 'TAP',
          subtitle: 'Accept the reservation',
          reserve: true,
          active: true,
          loading: claiming,
          onTap: claiming ? null : () => unawaited(_acceptHomeReservation()),
        ),
      );
    }

    /// Asks dispatch for reservation [id]; the server gives it to one
    /// driver (R25). A failed call decides nothing.
    Future<ClaimResult> _claimReservation(String id) async {
      _rebuild(() => _reservation.claimingId = id);
      IslandMessages.show(HomeIslandNotices.reservationMatching);
      ClaimResult result;
      try {
        result = await _dispatch.claimOffer(id);
      } catch (_) {
        result = const ClaimResult.networkError();
      }
      if (mounted) { _rebuild(() => _reservation.claimingId = null); }
      if (result.outcome == ClaimOutcome.networkError) {
        IslandMessages.show(HomeIslandNotices.reservationNoConnection);
      } else if (!result.isSuccess) {
        // Another driver was first: it leaves Scheduled rides too.
        ScheduledRideStore.take(id);
        IslandMessages.show(HomeIslandNotices.reservationUnavailable);
      }
      return result;
    }

    /// The radar's Accept: won, the reservation moves to Accepted in
    /// Scheduled rides; lost, it is gone. Either way the sheet goes down.
    Future<void> _acceptHomeReservation() async {
      final request = _reservation.request;
      if (request == null ||
          _reservation.claimingId != null ||
          !_reservationOnDock) {
        return;
      }
      final result = await _claimReservation(request.id);
      if (!mounted || result.outcome == ClaimOutcome.networkError) {
        // Nothing was decided; the driver can tap Accept again.
        return;
      }
      if (result.isSuccess) {
        ScheduledRideStore.take(request.id, upcoming: true);
        IslandMessages.show(HomeIslandNotices.reservationAccepted);
      }
      _closeHomeReservation();
    }

    /// The ×: the sheet goes back down; the reservation is not declined
    /// and stays open in Scheduled rides (R20).
    void _hideHomeReservation() {
      if (_reservation.claimingId != null) { return; }
      _closeHomeReservation();
    }

    void _closeHomeReservation() {
      if (!mounted) { return; }
      final wasUp = _reservation.request != null;
      _rebuild(() {
        _reservation.request = null;
        _reservation.raised = false;
      });
      if (!wasUp) { return; }
      // Radar trips that waited behind it come in once it is down.
      _reservation.release?.cancel();
      _reservation.release = Timer(const Duration(milliseconds: 320), () {
        if (mounted) { _HomeOfferRadar(this)._releasePendingRadarOffers(); }
      });
    }

    /// Scheduled rides changed. Taken there while on Home, it goes; open
    /// again after this driver cancelled it, it is sent to Home again.
    void _onScheduledRequestsChanged() {
      final request = _homeRequest;
      if (request != null) {
        final open = ScheduledRideStore.isOpen(request.id);
        if (!open) {
          _reservation.seenTaken = true;
          if (_reservation.claimingId == null) { _closeHomeReservation(); }
        } else if (_reservation.seenTaken) {
          _reservation
            ..seenTaken = false
            ..sent = false
            ..announced = false
            ..wonId = null;
          _scheduleReservationPopup();
        }
      }
      _rebuild(() {});
    }

    /// Close to pickup the reservation becomes an Exclusive offer: the
    /// popup gives it its place.
    void _reservationBecomesExclusive(String id) {
      if (_reservation.request?.id == id) { _closeHomeReservation(); }
    }

    /// Accept on a reservation's Exclusive offer asks dispatch first.
    /// True while that claim runs (Accept waits); false once it is won,
    /// so Accept opens the ride.
    bool _exclusiveNeedsClaim(_HomeDirectOffer offer) {
      if (_reservation.wonId == offer.id) { return false; }
      if (_reservation.claimingId == null) {
        unawaited(_claimExclusiveReservation(offer));
      }
      return true;
    }

    Future<void> _claimExclusiveReservation(_HomeDirectOffer offer) async {
      // The offer stays on screen while the server decides.
      _outsideOfferTimeoutTimer?.cancel();
      final result = await _claimReservation(offer.id);
      if (!mounted || _outsideRadarOffer?.id != offer.id) { return; }
      switch (result.outcome) {
        case ClaimOutcome.success:
          // Taken now: it is this driver's trip, not a later one.
          ScheduledRideStore.take(offer.id);
          _reservation.wonId = offer.id;
          IslandMessages.show(HomeIslandNotices.reservationAccepted);
          _HomeOfferRadar(this)._acceptOutsideRadarOffer();
        case ClaimOutcome.networkError:
          // Nothing decided: the offer counts down again.
          _outsideOfferTimeoutTimer = Timer(
            _DriverHomeState._outsideOfferLifetime,
            () {
              if (mounted && _outsideRadarOffer?.id == offer.id) {
                _HomeOfferRadar(this)._dismissOutsideRadarOffer();
              }
            },
          );
        case ClaimOutcome.alreadyClaimed:
        case ClaimOutcome.expired:
        case ClaimOutcome.unavailable:
          _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      }
    }

    /// Its Exclusive offer went untaken: the reservation joins the Home
    /// deck too, as the Radar trip it already is (R22), with only its
    /// "Reservation" badge.
    void _reservationToDeck(String id) {
      if (!mounted || !ScheduledRideStore.isOpen(id)) { return; }
      for (final offer in _latestDispatchOffers) {
        if (offer.id == id && offer.isReservation) {
          _HomeOfferRadar(this)._showRadarHomeOffer(
            _HomeOfferRadar(this)._homeOfferFromDispatch(offer),
          );
          return;
        }
      }
    }

    /// A reservation taken from the Radar trips (Home deck or Live list)
    /// leaves Scheduled rides; won or lost, it is gone (R23).
    void _reservationClaimedOnRadar(String id, ClaimResult result) {
      if (result.outcome != ClaimOutcome.networkError) {
        ScheduledRideStore.take(id);
      }
    }
}
