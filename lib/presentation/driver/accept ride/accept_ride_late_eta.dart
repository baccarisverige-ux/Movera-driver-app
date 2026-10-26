part of 'accept_ride.dart';

// Late ETA (`reservations.lateEta`, owner rule): an ONLINE driver who
// accepted a reservation is watched from "Leave now" until they arrive at
// the pickup. When now plus their ETA is later than the pickup time plus
// the admin's tolerance, the ride goes to another driver early, not at the
// pickup time, and the driver is told why. (An OFFLINE driver who never
// set off loses it on Home after the offline backup minutes instead.)
//
// Only a scheduled trip ([AcceptRide.scheduledPickupAt]) is watched, and
// only while heading to the pickup. The check runs every
// `checkEverySeconds` of the scheduled clock, once right after the trip
// opens and once at the first GPS fix. Stage changes, the trip ending and
// dispose stop it.

extension _AcceptRideLateEta on _AcceptRideState {
  bool get _watchesLateEta =>
      widget.scheduledPickupAt != null &&
      ScheduledRideRules.current.lateEta.on &&
      _stage == ActiveRideStage.headingToPickup &&
      !_rideLifecycle.terminal &&
      !_lateEtaReassigning;

  /// The late-ETA reassign was saved: this phone released the ride to
  /// dispatch and is leaving the trip.
  bool get _releasedForLateEta =>
      _lateEtaReassigning && _rideLifecycle.releasedToDispatch;

  /// Follows the stage: arms the next check while watched, stops it
  /// otherwise. [checkNow]: check at once (the trip just opened).
  void _syncLateEtaWatch({bool checkNow = false}) {
    if (!mounted || !_watchesLateEta) {
      _stopLateEtaWatch();
      return;
    }
    if (checkNow) {
      unawaited(_checkLateEta());
    } else if (_lateEtaTimer == null) {
      _armLateEtaCheck();
    }
  }

  void _stopLateEtaWatch() {
    _lateEtaTimer?.cancel();
    _lateEtaTimer = null;
  }

  void _armLateEtaCheck() {
    _lateEtaTimer?.cancel();
    final clock = ScheduledClock.instance;
    final every = ScheduledRideRules.current.lateEta.checkEvery;
    _lateEtaTimer = Timer(clock.realUntil(clock.now().add(every)), () {
      _lateEtaTimer = null;
      unawaited(_checkLateEta());
    });
  }

  /// The first GPS fix gives the first ETA: check without waiting for the
  /// next tick.
  void _checkLateEtaOnFirstFix() {
    if (_lateEtaMeasured || !_watchesLateEta) {
      return;
    }
    unawaited(_checkLateEta());
  }

  /// Time still to drive to the pickup: what is left of the road route,
  /// or the smart-gap estimate from the car's live position. Null without
  /// a live fix (no decision on a guess): a route asked from the fallback
  /// position says nothing about where the car is.
  Duration? _lateEtaLeft() {
    if (!_hasLiveLocation) {
      return null;
    }
    final seconds = _routeDurationSeconds;
    if (seconds != null && _navigation.route != null && _routeFromLiveFix) {
      final left = seconds * (1 - (_navigation.routeFraction ?? 0));
      return Duration(seconds: math.max(0, left.ceil()));
    }
    return Duration(
      minutes: SmartGap.driveMinutes(
        GeoPointMaps.fromLatLng(_driverPosition),
        GeoPointMaps.fromLatLng(widget.pickupPosition),
      ),
    );
  }

  Future<void> _checkLateEta() async {
    if (!mounted) {
      return;
    }
    if (!_watchesLateEta) {
      _stopLateEtaWatch();
      return;
    }
    // Hidden (stale position) or another trip change in flight: next tick.
    final busy =
        _liveUpdatesPaused ||
        _stageTransitioning ||
        _completionInFlight ||
        _cancellationInFlight ||
        _rideLifecycle.saving ||
        _pendingProjection != null;
    final eta = busy ? null : _lateEtaLeft();
    if (eta == null) {
      _armLateEtaCheck();
      return;
    }
    _lateEtaMeasured = true;
    final pickupAt = widget.scheduledPickupAt!;
    final now = ScheduledClock.instance.now();
    if (!SmartGap.wouldBeLate(
      now: now,
      pickupAt: pickupAt,
      eta: eta,
      rules: ScheduledRideRules.current,
    )) {
      _armLateEtaCheck();
      return;
    }
    await _reassignLate(lateBy: now.add(eta).difference(pickupAt));
  }

  /// The ride goes to another driver. The demo has no backend, so this
  /// phone ends the trip the way a server release does (`requested`, a
  /// reservation back to dispatch): the same exit as an admin reassign,
  /// with the reason on the island, in Scheduled rides and in
  /// Notifications. The admin's `reassignTo` is only recorded; sending the
  /// Exclusive offer (or Radar trip) to the next driver is the backend's.
  Future<void> _reassignLate({required Duration lateBy}) async {
    _lateEtaReassigning = true;
    _stopLateEtaWatch();
    const status = TripStatus.requested;
    if (!await _rideLifecycle.applyProjection(status)) {
      // Not saved (another write won): try again at the next tick.
      _lateEtaReassigning = false;
      if (mounted) {
        _syncLateEtaWatch();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final minutes = math.max(1, (lateBy.inSeconds / 60).ceil());
    final pickupAt = widget.scheduledPickupAt!;
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(pickupAt.hour)}:${two(pickupAt.minute)}';
    ScheduledRideStore.reassignLate(
      id: widget.scheduledRideId ?? '',
      pickupTime: time,
      lateMinutes: minutes,
      reassignTo: ScheduledRideRules.current.lateEta.reassignTo,
    );
    final feed = DriverNotificationFeed.instance;
    feed.add(
      DriverNotices.scheduledReminder(
        at: feed.now,
        title: () => tr.lateEtaReassignedTitle,
        body: () => tr.lateEtaReassignedNote(time, minutes),
      ),
      popup: false,
    );
    await _AcceptRideTrip(this)._leaveAfterRelease(
      status,
      notice: HomeIslandNotices.lateReassigned(minutes),
    );
  }
}
