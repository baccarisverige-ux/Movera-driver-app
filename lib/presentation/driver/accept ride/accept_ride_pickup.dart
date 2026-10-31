part of 'accept_ride.dart';

/// Driver group 5 (contract v0.18.7 `pickupWaiting`): what the trip screen
/// reads from the server's projection — the rider summary (Q1), the
/// server's ETA (Q4) and the trip's own waiting terms.
extension _AcceptRidePickup on _AcceptRideState {
  /// Q1: the rider's first name from the server once the trip carries it;
  /// the offer's name before (the demo's sample name).
  String get _riderName => _live?.rider?.firstName ?? widget.riderName;

  /// Q1: the rider's rating as the server sends it (only while the zone's
  /// `offers.offerCard.riderRating` is on); none → no chip, never 4.9.
  double? get _riderRating => _live?.rider?.rating ?? widget.riderRating;

  /// Q4: the server's road-route ETA for the leg on screen: to the pickup
  /// while heading there, to the drop-off on the last leg. None while
  /// waiting (the car is there) or heading to a middle stop (the server
  /// routes to the drop-off only).
  TripEta? get _serverEta {
    final eta = _live?.eta;
    if (eta == null || _countingWait) return null;
    // Checker round 1: a `stale` ETA (no driver position for 2 min) gives
    // way to the phone's own route time when the phone has one.
    if (eta.isStale && _routeDurationSeconds != null) return null;
    return switch (_stage) {
      ActiveRideStage.headingToPickup => eta.toPickup ? eta : null,
      ActiveRideStage.waitingForRider => null,
      ActiveRideStage.onTrip =>
        !eta.toPickup && _stopCursor >= widget.stopAddresses.length
            ? eta
            : null,
    };
  }

  /// Contract v0.18.7: a live trip carries its own `terms` (the booking
  /// snapshot of the zone's pricing, in the zone's currency: a Paris trip
  /// is in euro); they win over the zone's served config. Nothing here is
  /// an app constant (owner rule 16).
  WaitingTerms get _waitTerms {
    final terms = _live?.terms?.waiting ?? _zoneWaitTerms;
    // Checker round 1: the free / no-show moments are the server's
    // (`waiting.freeUntil` / `noShowAt`); the local count only without them.
    final waiting = _live?.waiting;
    final free = waiting?.secondsAfterArrival(waiting.freeUntil);
    final noShow = waiting?.secondsAfterArrival(waiting.noShowAt);
    return free == null && noShow == null
        ? terms
        : terms.anchored(freeSeconds: free, noShowSeconds: noShow);
  }

  /// What the server already told this phone (the accept answer, a read
  /// at restore), the navigation app choice, and the follow poll.
  void _beginPickupWaiting() {
    // What the server already told this phone about the trip (the accept
    // answer, a read at restore): rider, terms, ETA, pickup.
    final known = LiveDriverServices.instance?.trips.projectionOf(
      widget.tripId,
    );
    if (known != null) {
      _AcceptRideTrip(
        this,
      )._applyLive(TripLiveDetails.fromProjection(known), initial: true);
    }
    unawaited(NavigationAppSetting.load());
    if (LiveDriverServices.active) {
      _followPoll = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_AcceptRideTrip(this)._followTick()),
      );
    }
  }

  String get _routeEtaText {
    // Q4 (contract v0.18.7 `pickupWaiting.eta`): the server's road-route
    // ETA, the same number the rider and the admin see; the app's own
    // route time only on a build without one (the demo, an older server).
    if (_serverEta case final eta?) {
      return eta.isStale ? tr.etaLastKnown(eta.minutesLabel) : eta.minutesLabel;
    }
    final seconds = _routeDurationSeconds;
    // Until a road route arrives, a calm word instead of a placeholder.
    if (seconds == null) {
      return tr.enRoute;
    }
    final left = seconds * (1 - (_navigation.routeFraction ?? 0));
    final minutes = math.max(1, (left / 60).ceil());
    return '$minutes min';
  }

  String get _nextStopDetail {
    // Q4: "Arrives in 4 min · 1,2 km" from the server while driving.
    if (_serverEta case final eta?) {
      return eta.isStale ? tr.etaLastKnown(eta.line) : eta.line;
    }
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return tr.pickUpRiderName(_riderName);
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? tr.riderNameIsOnWay(_riderName)
            : tr.holdForRiderName(_riderName);
      case ActiveRideStage.onTrip:
        if (widget.stopAddresses.isEmpty) {
          return _riderName;
        }
        if (widget.stopAddresses.length == 1) {
          return tr.thenDropOff;
        }
        return tr.stop1OfStopAddressesLength(widget.stopAddresses.length);
    }
  }
}
