part of 'home.dart';

// Scheduled rides on Home (notes Q9–Q13, Q29), on the real clock of
// [ScheduledClock.instance] (a fast day only in tests):
// - the open reservation's near-pickup steps count the minutes before its
//   pickup time, never the drive to it;
// - the smart gap before the next accepted ride: reminders, "leave now"
//   (the ride lands on screen as the active trip, heading to pickup, at
//   the latest moment to set off: the drive plus the spare minutes before
//   its pickup), then the late warning and the backup driver;
// - before that ride, only trips that leave the gap and head toward its
//   pickup;
// - rides Movera assigns arrive like an Exclusive offer: Accept in time.

class _HomeScheduledState {
  /// Reminder, "leave now" and backup timers of [ride].
  final List<Timer> timers = <Timer>[];

  /// The accepted ride the timers are for.
  ReservationRequestPreview? ride;

  /// "Leave now" passed and the trip could not open: since then the
  /// driver was warned; the backup driver follows.
  DateTime? lateSince;

  /// Planning right now: a store change it causes waits for the next plan.
  bool planning = false;

  /// The ride "Go online" was said for: a plan after the phone slept
  /// through its time says it then, once (driver-r5-7).
  ReservationRequestPreview? onlineReminded;

  VoidCallback? storeListener;
  StreamSubscription<ReservationRequestPreview>? assignments;

  /// Assigned rides by id, and the ones still waiting for their card.
  final Map<String, ReservationRequestPreview> assigned = {};
  final List<String> waiting = <String>[];

  /// Answered assignments: their card leaving is not a miss.
  final Set<String> answered = <String>{};

  /// The assignment whose Accept is with dispatch.
  String? claimingId;

  void cancelTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }

  void dispose() {
    cancelTimers();
    final listener = storeListener;
    if (listener != null) {
      ScheduledRideStore.changes.removeListener(listener);
    }
    assignments?.cancel();
    assignments = null;
  }
}

extension _HomeScheduled on _DriverHomeState {
    ScheduledClock get _clock => ScheduledClock.instance;
    ScheduledRideRules get _rules => ScheduledRideRules.current;
    GeoPoint get _driverPoint => GeoPointMaps.fromLatLng(_driverPosition);

    /// After the first frame: follow Scheduled rides and plan.
    void _startScheduled() {
      void changed() {
        if (mounted && !_scheduled.planning) { _planScheduled(); }
      }
      _scheduled.storeListener = changed;
      ScheduledRideStore.changes.addListener(changed);
      // A Radar list Match held a due ride back: its answer decides.
      _radarListClaiming.addListener(() {
        if (!_radarListClaiming.value) { _afterClaimResolved(); }
      });
      _planScheduled();
      _watchAssignments();
    }

    /// The open reservation Home shows (the admin's newest request), as
    /// its Exclusive offer.
    _HomeDirectOffer? _soonReservationOffer() {
      final request = _HomeReservation(this)._homeRequest;
      if (request == null || request.id.isEmpty) { return null; }
      return _HomeDirectOffer.fromRide(
        RideOffer.reservation(request),
        reason: ExclusiveReasons.pickupSoon,
      );
    }

    /// Reservation [id] is close enough to its pickup time for its
    /// Exclusive step, by the clock. True for offers whose pickup time Home
    /// does not know: dispatch already decided those.
    bool _exclusiveStepReached(String id) {
      final request = _HomeReservation(this)._homeRequestById(id) ??
          ScheduledRideStore.routeOf(id);
      if (request == null) { return true; }
      final left = request.untilPickup(_clock.now());
      return left != null &&
          left <= Duration(minutes: _rules.exclusiveBeforeMinutes);
    }

    /// Real time until the open reservation's Exclusive step; null when
    /// its time is unknown or its pickup has passed.
    Duration? _untilExclusiveStep() {
      final request = _HomeReservation(this)._homeRequest;
      if (request == null || request.id.isEmpty) { return null; }
      final now = _clock.now();
      final at = request.pickupAt(now);
      if (at == null || !at.isAfter(now)) { return null; }
      return _clock.realUntil(
        at.subtract(Duration(minutes: _rules.exclusiveBeforeMinutes)),
      );
    }

    /// The next accepted ride the smart gap works for.
    ReservationRequestPreview? get _nextScheduledRide {
      final upcoming = ScheduledRideStore.upcoming;
      return upcoming.isEmpty ? null : upcoming.first;
    }

    /// Plans reminders, "be online", "leave now" and the backup for the
    /// next accepted ride. [catchUp] after the app resumes: a "be online"
    /// whose time passed while the phone slept is said now, once
    /// (driver-r5-7); a reminder of the time left is not, as it is stale.
    void _planScheduled({bool catchUp = false}) {
      final state = _scheduled;
      state.cancelTimers();
      // An open request whose pickup time passes leaves the list and the
      // dot (driver-u164).
      // So does a pause or admin's "off until" that ends (driver-r3-9).
      for (final at in [
        ScheduledRideStore.nextRequestPickup(),
        ScheduledRideStore.accessChangeAt(),
      ]) {
        if (at == null) continue;
        state.timers.add(
          Timer(_clock.realUntil(at), ScheduledRideStore.refresh),
        );
      }
      final ride = _nextScheduledRide;
      if (!identical(ride, state.ride)) {
        state
          ..ride = ride
          ..lateSince = null;
      }
      if (ride == null || !mounted) { return; }
      final now = _clock.now();
      final pickupAt = ride.pickupAt(now);
      final leave = SmartGap.leaveAt(
        ride,
        driver: _driverPoint,
        now: now,
        rules: _rules,
      );
      if (pickupAt == null || leave == null) { return; }
      // A pickup that has passed never lands as the trip by itself. A ride
      // that became the next one after its time (accepted late, or an
      // assignment answered late) leaves Accepted for a backup driver:
      // kept, nothing would ever be planned for it and it would hold every
      // trip offer back (driver-u143).
      if (state.lateSince == null && !pickupAt.isAfter(now)) {
        state.planning = true;
        ScheduledRideStore.giveToBackup(ride);
        state.planning = false;
        IslandMessages.show(HomeIslandNotices.givenToBackup);
        if (!identical(_nextScheduledRide, ride)) { _planScheduled(); }
        return;
      }
      void at(DateTime time, VoidCallback run) =>
          state.timers.add(Timer(_clock.realUntil(time), run));
      final rule = SmartGap.ruleOf(ride, _rules);
      for (final minutes in rule.reminderMinutes) {
        final time = pickupAt.subtract(Duration(minutes: minutes));
        if (time.isAfter(now) && time.isBefore(leave)) {
          at(time, () => _remindScheduled(ride, minutes));
        }
      }
      final onlineBy = pickupAt.subtract(
        Duration(minutes: rule.onlineBeforeMinutes),
      );
      // A drive longer than the "be online" window: the driver must be
      // online and on the way at [leave], so "Go online" comes then at the
      // latest (driver-u144).
      final goOnlineAt = onlineBy.isBefore(leave) ? onlineBy : leave;
      if (goOnlineAt.isAfter(now)) {
        at(goOnlineAt, () => _remindOnline(ride));
      } else if (catchUp &&
          now.isBefore(leave) &&
          !identical(state.onlineReminded, ride)) {
        _remindOnline(ride);
      }
      // "Leave now" by the clock, at the latest moment to set off. With a
      // long drive that is before the "be online" window; it waited for
      // the window and the driver was late (driver-u144).
      if (state.lateSince != null || !now.isBefore(leave)) {
        _leaveNow(ride);
      } else {
        at(leave, () => _leaveNow(ride));
      }
    }

    /// The driver can take the ride onto the screen now. Home must be on
    /// top: with a screen or sheet over it the trip cannot open, so the
    /// ride stays in Accepted, late, and starts when Home is back on top.
    bool get _canStartScheduled =>
        ModalRoute.of(context)?.isCurrent != false &&
        _recoveryResolved &&
        _driverSession.availableForOffers &&
        _claimedHomeOffer == null &&
        _homeRadarMatchingOfferId == null &&
        !_radarListClaiming.value &&
        // An Exclusive Accept (reservation, assigned ride or admin direct
        // assign) waits for dispatch: a won trip must not be dropped.
        !_HomeExclusive(this)._exclusiveClaiming;

    /// A Match or Exclusive Accept that held "Leave now" back was
    /// answered: unless it won a trip (which keeps Home covered or busy),
    /// the late ride starts now, not at the backup timer.
    void _afterClaimResolved() {
      // Outside the claim's own build or setState.
      Timer.run(() {
        if (!mounted) { return; }
        // Decision 3: a rule that waited for this answer applies now.
        _HomeOfferRules(this)._releaseHeldOffline();
        if (_scheduled.ride == null || _scheduled.lateSince == null) {
          return;
        }
        _planScheduled();
      });
    }

    /// "Leave now" (Q10 S1): the ride lands on screen as the active trip,
    /// heading to pickup. Always: there is no admin switch for it (owner
    /// decision 1, driver-fixrev-5). Not possible right now: the island
    /// warns once. An offline driver loses the ride to a backup driver
    /// after the admin's minutes; an online one keeps it, and it starts as
    /// soon as Home is free.
    void _leaveNow(ReservationRequestPreview ride) {
      if (!mounted || !identical(_scheduled.ride, ride)) { return; }
      if (!_canStartScheduled) {
        _lateScheduled(ride);
        return;
      }
      // Outside the current build or navigation: the trip opens next.
      Timer.run(() {
        if (!mounted || !identical(_scheduled.ride, ride)) { return; }
        if (_canStartScheduled) {
          _startScheduledTrip(ride);
        } else {
          _lateScheduled(ride);
        }
      });
    }

    /// Q10 S3: "Head to your 07:40 pickup", then the backup driver.
    void _lateScheduled(ReservationRequestPreview ride) {
      final now = _clock.now();
      if (_scheduled.lateSince == null) {
        _scheduled.lateSince = now;
        if (_rules.lateWarning) { _warnLateScheduled(ride); }
      }
      final backupAt = _scheduled.lateSince!.add(
        Duration(minutes: _rules.backupAfterMinutes),
      );
      if (!now.isBefore(backupAt)) {
        _giveToBackup(ride);
        return;
      }
      _scheduled.timers.add(
        Timer(_clock.realUntil(backupAt), () => _giveToBackup(ride)),
      );
    }

    /// Admin "Late warning": the island, Scheduled rides and Notifications.
    void _warnLateScheduled(ReservationRequestPreview ride) {
      IslandMessages.show(HomeIslandNotices.headToPickup(ride.pickupTime));
      ScheduledRideStore.remind(ride, () =>
          tr.headToYourPickupTimePickup(ride.pickupTime, ride.pickupAddress));
      _noteRideAlert(
        () => tr.headToYourPickupTimePickup2(ride.pickupTime),
        ride.pickupAddress,
      );
    }

    void _startScheduledTrip(ReservationRequestPreview ride) {
      _scheduled.planning = true;
      final started = ScheduledRideStore.start(ride);
      _scheduled.planning = false;
      if (!started) { return; }
      _scheduled
        ..ride = null
        ..lateSince = null;
      ScheduledRideStore.reminder.value = null;
      IslandMessages.show(HomeIslandNotices.leaveNow(ride.pickupTime));
      _noteRideAlert(
        () => tr.leaveNowForPickupTimePickup(ride.pickupTime),
        ride.pickupAddress,
        leaveNow: true,
      );
      final offer = RideOffer.reservation(ride);
      // The trip knows its pickup time: from here to the pickup it watches
      // the driver's ETA (admin "Late ETA").
      _HomeOfferRadar(this)._openOfferTrip(
        _HomeDirectOffer.fromRide(offer),
        WaybillRecord.scheduledRideSource,
        scheduledPickupAt: ride.pickupAt(_clock.now()),
        scheduledRideId: ride.id,
        acceptedPickupPay: ScheduledRideStore.acceptedPickupPay(ride.id),
      );
      _planScheduled();
    }

    /// Late and still not on the way (Q10 S3). Only an offline driver
    /// loses the ride; online, it stays theirs.
    void _giveToBackup(ReservationRequestPreview ride) {
      if (!mounted || !identical(_scheduled.ride, ride)) { return; }
      if (_canStartScheduled) {
        _leaveNow(ride);
        return;
      }
      if (_driverSession.isOnline) { return; }
      _scheduled.planning = true;
      ScheduledRideStore.giveToBackup(ride);
      ScheduledRideStore.reminder.value = null;
      _scheduled.planning = false;
      IslandMessages.show(HomeIslandNotices.givenToBackup);
      _planScheduled();
    }

    /// The driver went offline while late: the backup rule applies again,
    /// now if the admin's minutes have passed, otherwise when they do.
    void _recheckLateScheduled() {
      final ride = _scheduled.ride;
      if (ride == null ||
          _scheduled.lateSince == null ||
          _driverSession.isOnline) {
        return;
      }
      _lateScheduled(ride);
    }

    void _remindScheduled(ReservationRequestPreview ride, int minutes) {
      if (!mounted) { return; }
      final left = minutes >= 60 && minutes % 60 == 0
          ? '${minutes ~/ 60} h'
          : '$minutes min';
      IslandMessages.show(
        HomeIslandNotices.scheduledReminder(ride.pickupTime, left),
      );
      ScheduledRideStore.remind(ride, () =>
          tr.pickupAtPickupTimeInLeft(ride.pickupTime, left, ride.pickupAddress));
      _noteRideAlert(() => tr.pickupTimePickupInLeft(ride.pickupTime, left), ride.pickupAddress);
    }

    /// Reminders and "Leave now" are in Notifications too (Q31, N1); the
    /// island already said them.
    void _noteRideAlert(NoticeText title, String body, {bool leaveNow = false}) {
      final feed = DriverNotificationFeed.instance;
      feed.add(
        DriverNotices.scheduledReminder(
          at: feed.now,
          title: title,
          body: () => body,
          leaveNow: leaveNow,
        ),
        popup: false,
      );
    }

    void _remindOnline(ReservationRequestPreview ride) {
      if (!mounted || _driverSession.isOnline) { return; }
      _scheduled.onlineReminded = ride;
      IslandMessages.show(HomeIslandNotices.goOnlineFor(ride.pickupTime));
      ScheduledRideStore.remind(
          ride, () => tr.goOnlineNowForYourPickup(ride.pickupTime));
      _noteRideAlert(
        () => tr.goOnlineForPickupTimePickup(ride.pickupTime),
        ride.pickupAddress,
      );
    }

    /// Radar went live: a late ride can start now; a waiting assigned ride
    /// shows.
    void _onRadarLive() {
      _planScheduled();
      _maybeShowAssignment();
    }

    /// Before the next accepted ride, a trip must leave the smart gap; in
    /// the admin's `towardPickupBeforeMin` before it, it must also head
    /// toward the pickup (like destination mode, aimed at the pickup).
    bool _fitsSchedule(_HomeDirectOffer offer) {
      final ride = _nextScheduledRide;
      if (offer.assigned || ride == null || ride.id == offer.id) {
        return true;
      }
      final now = _clock.now();
      final dropoff = GeoPointMaps.fromLatLng(offer.dropoffPosition);
      final fits = SmartGap.offerFits(
        offerPickupMinutes: offer.pickupMinutes,
        offerTripMinutes: offer.tripMinutes,
        offerDropoff: dropoff,
        ride: ride,
        now: now,
        rules: _rules,
      );
      if (!fits) { return false; }
      final pickupAt = ride.pickupAt(now);
      final window = _rules.towardPickupBeforeMinutes;
      final inWindow = pickupAt != null &&
          now.isAfter(pickupAt.subtract(Duration(minutes: window)));
      return !_rules.towardPickupBeforeRide ||
          !inWindow ||
          SmartGap.headsToward(
            from: _driverPoint,
            dropoff: dropoff,
            target: ride.pickup,
          );
    }

    bool _rideFitsSchedule(RideOffer offer) =>
        _fitsSchedule(_HomeDirectOffer.fromRide(offer));

    /// "07:40" while trips are filtered toward that pickup, else null.
    String? get _towardPickupTime {
      final ride = _nextScheduledRide;
      if (ride == null || !_rules.towardPickupBeforeRide) { return null; }
      final now = _clock.now();
      final pickupAt = ride.pickupAt(now);
      final window = _rules.towardPickupBeforeMinutes;
      return pickupAt != null &&
              now.isAfter(pickupAt.subtract(Duration(minutes: window)))
          ? ride.pickupTime
          : null;
    }

    void _watchAssignments() {
      if (_scheduled.assignments != null) { return; }
      _scheduled.assignments = _dispatch.watchAssignments().listen((ride) {
        if (!mounted || _scheduled.assigned.containsKey(ride.id)) { return; }
        _scheduled.assigned[ride.id] = ride;
        _scheduled.waiting.add(ride.id);
        _maybeShowAssignment();
      });
    }

    /// The next assigned ride shows as its Exclusive card, "Assigned by
    /// Movera", with the admin's time to accept.
    void _maybeShowAssignment() {
      if (_scheduled.waiting.isEmpty || !mounted || !_isOnline) { return; }
      final ride = _scheduled.assigned[_scheduled.waiting.first];
      if (ride == null) { return; }
      unawaited(_HomeOfferRadar(this)._showOutsideRadarOffer(
        _HomeDirectOffer.fromRide(
          RideOffer.reservation(ride),
          reason: ExclusiveReasons.assigned,
          assigned: true,
          lifetime: _rules.assignAcceptTime,
        ),
      ));
      if (_outsideRadarOffer?.id == ride.id) { _scheduled.waiting.remove(ride.id); }
    }

    void _acceptAssignment(_HomeDirectOffer offer) {
      if (_scheduled.claimingId != null) { return; }
      unawaited(_claimAssignment(offer));
    }

    Future<void> _claimAssignment(_HomeDirectOffer offer) async {
      _outsideOfferTimeoutTimer?.cancel();
      _exclusive.clock.stop();
      _rebuild(() => _scheduled.claimingId = offer.id);
      ClaimResult result;
      try {
        result = await _dispatch.claimOffer(offer.id);
      } catch (_) {
        result = const ClaimResult.networkError();
      }
      if (!mounted) { return; }
      _rebuild(() => _scheduled.claimingId = null);
      // An assigned ride is only kept for later: never a trip now.
      _afterClaimResolved();
      final ride = _scheduled.assigned[offer.id];
      if (result.outcome == ClaimOutcome.networkError) {
        IslandMessages.show(HomeIslandNotices.reservationNoConnection);
        // Nothing decided: the card counts down again.
        _HomeExclusive(this)._restartExclusiveTimeout(
          offer,
          offer.lifetime ?? _DriverHomeState._outsideOfferLifetime,
        );
        return;
      }
      _scheduled.answered.add(offer.id);
      if (result.isSuccess && ride != null) {
        // The pickup pay its card showed is paid at "Leave now"
        // (driver-r5-12).
        ScheduledRideStore.acceptAssigned(ride,
            pickupPay: _HomeOfferRadar(this)._pickupPayOf(offer).pay);
        IslandMessages.show(HomeIslandNotices.assignmentAccepted);
      } else {
        IslandMessages.show(HomeIslandNotices.reservationUnavailable);
      }
      if (_outsideRadarOffer?.id == offer.id) {
        _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      }
    }

    /// The assigned ride's card left without Accept: admin sees it and
    /// picks someone else.
    void _assignmentMissed(_HomeDirectOffer offer) {
      _scheduled.waiting.remove(offer.id);
      if (_scheduled.answered.remove(offer.id)) { return; }
      _scheduled.answered.add(offer.id);
      IslandMessages.show(HomeIslandNotices.assignmentNotAccepted);
    }
}
