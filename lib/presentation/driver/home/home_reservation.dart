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

  /// The requests sent to Home this round, in order. One shows at a time;
  /// after Accept or × the next one rises ("2 of 2").
  List<ReservationRequestPreview> round = const <ReservationRequestPreview>[];

  /// Hidden (×) or answered this round: it does not rise again.
  final Set<String> passed = <String>{};

  /// A round was sent to Home; × does not bring it back.
  bool sent = false;

  /// The island said "New reservation" for this round.
  bool announced = false;

  /// The sheet is (nearly) up: the radar is Accept, the dock black.
  bool raised = false;

  /// Seen taken (not open in Scheduled rides). Open again later means the
  /// driver cancelled it and it went back out (R24).
  final Set<String> seenTaken = <String>{};

  /// The reservation whose claim is with dispatch right now.
  String? claimingId;

  /// Won through its Exclusive offer: Accept may open the ride.
  String? wonId;

  /// Lets the Radar trips that waited behind the sheet come in, or the
  /// next request rise.
  Timer? release;
}

extension _HomeReservation on _DriverHomeState {
    /// The requests admin sends to the Home popup, in order.
    List<ReservationRequestPreview> get _homeRequests =>
        _adminHomeConfig.scheduledRides.homeRequests;

    /// The first of them: the one whose Exclusive step Home runs.
    ReservationRequestPreview? get _homeRequest =>
        _homeRequests.isEmpty ? null : _homeRequests.first;

    ReservationRequestPreview? _homeRequestById(String id) {
      for (final request in _homeRequests) {
        if (request.id.isNotEmpty && request.id == id) { return request; }
      }
      return null;
    }

    /// Sends the open reservations to Home once they have waited in
    /// Scheduled rides for [ReservationDemoTimings.homePopupAfter] (job L2):
    /// all of them, or [only] the ones that went back out.
    void _scheduleReservationPopup([List<ReservationRequestPreview>? only]) {
      final requests = only ?? _homeRequests;
      if (!DriverRuntimeConfig.current.reservationPopup ||
          !_adminHomeConfig.scheduledRides.hasOpenRequests ||
          requests.isEmpty ||
          _reservation.sent) {
        return;
      }
      _reservationPopupTimer?.cancel();
      _reservationPopupTimer = Timer(ReservationDemoTimings.homePopupAfter, () {
        if (!mounted || _reservation.sent) { return; }
        // Taken in the meantime, here or by another driver: nothing to send.
        // Close to pickup it is an Exclusive offer, no longer the popup.
        final round = [
          for (final request in requests)
            if (_waitsForHome(request)) request,
        ];
        if (round.isEmpty) { return; }
        _rebuild(() {
          _reservation
            ..sent = true
            ..round = round
            ..request = round.first;
          _reservation.passed.clear();
        });
      });
    }

    /// [request] can still rise on Home.
    bool _waitsForHome(ReservationRequestPreview request) =>
        ScheduledRideStore.isOpen(request.id) &&
        DriverCategoryChoice.takes(request.category) &&
        !_HomeScheduled(this)._exclusiveStepReached(request.id);

    /// The next request of this round still waiting, or null.
    ReservationRequestPreview? _nextHomeRequest() {
      for (final request in _reservation.round) {
        if (!_reservation.passed.contains(request.id) &&
            _waitsForHome(request)) {
          return request;
        }
      }
      return null;
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
          // Only a category this driver drives (Q27).
          DriverCategoryChoice.takes(request.category) &&
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
        // One pixel past each side: only the top contour shows. The map
        // behind is dimmed while it is up.
        left: -1,
        right: -1,
        top: 0,
        bottom: 0,
        child: ValueListenableBuilder<double>(
          valueListenable: _panelSlidePosition,
          builder: (context, _, __) => HomeReservationSheet(
            request: _reservation.request,
            visible: _reservationUp,
            bottomInset: bottomInset,
            clock: ScheduledClock.instance.now,
            position: _reservationPosition,
            count: _reservation.round.length,
            picture: _reservationPicture,
            // Leaves the top island and some map above the sheet.
            maxContentHeight: math.max(
              160.0,
              viewport.height - safeTop - 72 - bottomInset,
            ),
            // View details: full height, just under the top island.
            fullContentHeight: math.max(
              160.0,
              viewport.height - safeTop - 40 - bottomInset,
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

    /// "2 of 2": the shown request's place in this round.
    int get _reservationPosition {
      final request = _reservation.request;
      if (request == null) { return 1; }
      final index = _reservation.round.indexWhere((r) => r.id == request.id);
      return index < 0 ? 1 : index + 1;
    }

    /// Airport rides get the plane; the others switch pictures, one after
    /// another.
    ReservationPicture? get _reservationPicture {
      final request = _reservation.request;
      if (request == null) { return null; }
      var order = 0;
      for (final other in _reservation.round) {
        if (other.id == request.id) { break; }
        if (ReservationPicture.forRequest(other) !=
            ReservationPicture.airport) { order++; }
      }
      return ReservationPicture.forRequest(request, order: order);
    }

    /// The sheet is nearly up: the radar turns into Accept; once per round
    /// the island says so.
    void _onReservationRising() {
      if (!mounted) { return; }
      _rebuild(() => _reservation.raised = true);
      if (_reservation.announced) { return; }
      _reservation.announced = true;
      IslandMessages.show(HomeIslandNotices.newReservation);
      // And it is in Notifications (Q31, N1).
      if (_reservation.request case final request?) {
        final feed = DriverNotificationFeed.instance;
        feed.add(
          DriverNotices.newScheduledRide(
            at: feed.now,
            day: request.pickupDay,
            time: request.pickupTime,
            fare: request.fare,
          ),
          popup: false,
        );
      }
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

    /// The radar's Accept: won, the reservation is only saved to Scheduled
    /// rides › Accepted; it becomes the trip at its time ("Leave now" by
    /// the real clock), never right after Accept. Lost, it is gone. Either
    /// way the sheet goes down and the next request, if any, rises.
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
        IslandMessages.show(
          HomeIslandNotices.reservationAcceptedAt(request.pickupTime),
        );
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
      final shown = _reservation.request;
      _rebuild(() {
        _reservation.request = null;
        _reservation.raised = false;
        if (shown != null) { _reservation.passed.add(shown.id); }
      });
      if (shown == null) { return; }
      // Once it is down the next request rises; with none left, Radar
      // trips that waited behind it come in.
      _reservation.release?.cancel();
      _reservation.release = Timer(const Duration(milliseconds: 320), () {
        if (!mounted) { return; }
        final next = _nextHomeRequest();
        if (next != null) {
          _rebuild(() => _reservation.request = next);
          return;
        }
        _HomeOfferRadar(this)._releasePendingRadarOffers();
      });
    }

    /// Scheduled rides changed. Taken there while on Home, it goes; open
    /// again after this driver cancelled it, it is sent to Home again.
    void _onScheduledRequestsChanged() {
      final back = <ReservationRequestPreview>[];
      for (final request in _homeRequests) {
        if (!ScheduledRideStore.isOpen(request.id)) {
          _reservation.seenTaken.add(request.id);
          if (_reservation.request?.id == request.id &&
              _reservation.claimingId == null) {
            _closeHomeReservation();
          }
        } else if (_reservation.seenTaken.remove(request.id)) {
          back.add(request);
        }
      }
      if (back.isNotEmpty) {
        _reservation
          ..sent = false
          ..announced = false
          ..wonId = null;
        _scheduleReservationPopup(back);
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
          final ride = _homeRequestById(offer.id) ??
              ScheduledRideStore.routeOf(offer.id);
          if (ride != null &&
              !_HomeScheduled(this)._exclusiveStepReached(offer.id)) {
            // Pickup is not near yet by the real clock: it is only saved
            // for later, like an Accept on the popup.
            ScheduledRideStore.take(offer.id, upcoming: true);
            IslandMessages.show(
              HomeIslandNotices.reservationAcceptedAt(ride.pickupTime),
            );
            _HomeOfferRadar(this)._dismissOutsideRadarOffer();
            return;
          }
          // Inside its Exclusive window: it is this driver's trip now.
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
