part of 'home.dart';

// The Exclusive offer on Home: the same sheet as the reservation request
// (HomeOfferSheet), with no blue anywhere. The sheet rises over the dock
// to about 40 % of the screen; the grey radar orb on its top edge is its
// Accept, inside a thin dark ring that empties as the time runs out, and
// the grey pill at the bottom counts the seconds down. The Home map shows
// the route once the sheet has settled; going, the route fades first and
// then the sheet slides down. The offer itself (timers, accept, dismiss)
// stays in home_offer_radar.dart.

/// The Exclusive sheet's clock and route, owned by the Home state.
class _HomeExclusiveState {
  _HomeExclusiveState(TickerProvider vsync)
    : clock = AnimationController(vsync: vsync, value: 1);

  /// The offer's time left, 1 → 0 over its lifetime.
  final AnimationController clock;

  /// The offer the sheet shows; kept while it slides back down.
  _HomeDirectOffer? shown;

  /// The down arrow, Accept or time out: the sheet is on its way down.
  bool leaving = false;

  /// The sheet is (nearly) up: the island says "Exclusive".
  bool raised = false;

  /// When the offer's time runs out, so a paused tab can pick it up.
  DateTime? deadline;

  /// Running out on screen counts as a miss (Q16); not after a network
  /// error on a reservation's or an assigned ride's Accept.
  bool timeoutIsMiss = true;

  /// Runs once the sheet is down.
  VoidCallback? onDown;

  /// Takes the sheet down if it never reports back (not on screen).
  Timer? downGuard;

  /// The admin direct assign whose Accept dispatch is deciding (§3.1).
  String? claimingId;

  /// The route on the map fades in once the sheet is up and out before
  /// it goes down.
  final RouteFade fade = RouteFade();

  void dispose() {
    downGuard?.cancel();
    fade.cancel();
    clock.dispose();
  }
}

extension _HomeExclusive on _DriverHomeState {
  bool get _exclusiveReduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Accept is being sent (a reservation, an assigned ride or an admin
  /// direct assign), or won and its trip is opening: the orb waits and
  /// the down arrow is off.
  bool get _exclusiveClaiming =>
      _reservation.claimingId != null ||
      _scheduled.claimingId != null ||
      _exclusive.claimingId != null ||
      _claimedHomeOffer != null;

  /// The Exclusive offer is up and its orb is Accept.
  bool get _exclusiveLive => _outsideRadarOffer != null && !_exclusive.leaving;

  /// The island shows "Exclusive · Pickup 4 min".
  bool get _exclusiveOnIsland =>
      _exclusive.raised && _exclusive.shown != null && _exclusiveLive;

  /// Seconds left to accept, for the pill.
  int get _exclusiveSecondsLeft {
    final lifetime =
        _exclusive.clock.duration ?? _DriverHomeState._outsideOfferLifetime;
    return (_exclusive.clock.value * lifetime.inMilliseconds / 1000).ceil();
  }

  /// The offer arrived: the sheet rises and its clock starts.
  void _raiseExclusive(_HomeDirectOffer offer, Duration lifetime) {
    _exclusive.downGuard?.cancel();
    _rebuild(() {
      _exclusive.shown = offer;
      _exclusive.leaving = false;
      _exclusive.onDown = null;
      _exclusive.timeoutIsMiss = true;
    });
    _startExclusiveClock(lifetime);
  }

  void _startExclusiveClock(Duration lifetime) {
    _exclusive.clock.duration = lifetime;
    _exclusive.deadline = ScheduledClock.realNow().add(lifetime);
    unawaited(_exclusive.clock.reverse(from: 1));
  }

  /// Accept came back undecided (a network error): the offer counts
  /// down again. With Home hidden (a locked phone, another screen) only
  /// its deadline is kept, like the first count down (D-05/R13-3): back
  /// on screen it gets the time left, or it leaves unseen, which is not
  /// a miss. A timer started here would run in the background and could
  /// count a miss, or take the driver offline (driver-r3-14).
  ///
  /// driver-r5-19: the offer keeps the deadline it had (the time spent
  /// waiting for dispatch is gone): no fresh [lifetime], which is only
  /// for an offer that has none. Run out meanwhile, it leaves, not a
  /// miss.
  void _restartExclusiveTimeout(
    _HomeDirectOffer offer,
    Duration lifetime, {
    bool missed = false,
  }) {
    _outsideOfferTimeoutTimer?.cancel();
    _outsideOfferTimeoutTimer = null;
    _exclusive.timeoutIsMiss = missed;
    final now = ScheduledClock.realNow();
    final deadline = _exclusive.deadline ?? now.add(lifetime);
    _exclusive.clock.duration ??= lifetime;
    _exclusive.deadline = deadline;
    // Under the side menu only the deadline is kept (driver-r5-30).
    if (!_liveVisible || _drawerOpen) {
      return;
    }
    final left = deadline.difference(now);
    if (left <= Duration.zero) {
      _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      return;
    }
    final full = _exclusive.clock.duration ?? lifetime;
    final share = left.inMilliseconds / math.max(1, full.inMilliseconds);
    unawaited(_exclusive.clock.reverse(from: share.clamp(0.0, 1.0)));
    _outsideOfferTimeoutTimer = Timer(left, () {
      if (!mounted || _outsideRadarOffer?.id != offer.id) {
        return;
      }
      _HomeOfferRadar(this)._dismissOutsideRadarOffer(missed: missed);
    });
  }

  /// The side menu is open over Home.
  bool get _drawerOpen => _scaffoldKey.currentState?.isDrawerOpen ?? false;

  /// driver-u115: the side menu covers the offer like a screen pushed
  /// over Home: its time out waits (the deadline stays), and when the
  /// menu closes it gets the time left, or leaves unseen (not a miss).
  void _drawerChanged(bool open) {
    if (!open) {
      if (_liveVisible) {
        _resumeExclusiveTimeout();
      }
      return;
    }
    if (_outsideOfferTimeoutTimer == null) {
      return;
    }
    _outsideOfferTimeoutTimer?.cancel();
    _outsideOfferTimeoutTimer = null;
    _exclusive.clock.stop();
  }

  /// R13-3 (C): back from a hidden tab or locked phone, whose pause
  /// cancelled the offer's time out. Gone if its time ran out meanwhile,
  /// else it counts down the time it has left.
  void _resumeExclusiveTimeout() {
    final offer = _outsideRadarOffer;
    final deadline = _exclusive.deadline;
    if (!mounted ||
        offer == null ||
        deadline == null ||
        _exclusive.leaving ||
        _outsideOfferTimeoutTimer != null ||
        _exclusiveClaiming ||
        // An app resume under the open side menu: the menu still covers
        // the offer, and its closing re-arms it (driver-r5-30).
        _drawerOpen) {
      return;
    }
    final left = deadline.difference(ScheduledClock.realNow());
    if (left <= Duration.zero) {
      // It ran out while the driver could not see it: not a miss.
      _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      return;
    }
    final lifetime = _exclusive.clock.duration ?? left;
    final share = left.inMilliseconds / math.max(1, lifetime.inMilliseconds);
    unawaited(_exclusive.clock.reverse(from: share.clamp(0.0, 1.0)));
    final missed = _exclusive.timeoutIsMiss;
    _outsideOfferTimeoutTimer = Timer(left, () {
      if (!mounted || _outsideRadarOffer?.id != offer.id) {
        return;
      }
      _HomeOfferRadar(this)._dismissOutsideRadarOffer(missed: missed);
    });
  }

  /// Takes the sheet down (route first, then the slide); [then] runs
  /// once it is down.
  void _sinkExclusive({VoidCallback? then}) {
    _exclusive.clock.stop();
    if (_exclusive.shown == null) {
      then?.call();
      return;
    }
    final before = _exclusive.onDown;
    _exclusive.onDown = before == null && then == null
        ? null
        : () {
            before?.call();
            then?.call();
          };
    _rebuild(() {
      _exclusive.leaving = true;
      _exclusive.raised = false;
    });
    _exclusive.downGuard?.cancel();
    _exclusive.downGuard = Timer(
      HomeOfferSheet.leaveDuration + const Duration(milliseconds: 150),
      _exclusiveDown,
    );
  }

  /// The sheet is down: the offer is off Home.
  void _exclusiveDown() {
    _exclusive.downGuard?.cancel();
    if (!mounted) {
      return;
    }
    final then = _exclusive.onDown;
    _exclusive.onDown = null;
    _exclusive.fade.set(1);
    // Cleared first: [then] may already bring the next offer up.
    if (_exclusive.shown != null) {
      _rebuild(() {
        _exclusive.shown = null;
        _exclusive.leaving = false;
        _exclusive.raised = false;
      });
    }
    then?.call();
  }

  /// The offer was cleared without its own exit (offline, a new
  /// session): the sheet still slides down.
  void _sinkExclusiveIfGone() {
    if (_outsideRadarOffer == null &&
        _exclusive.shown != null &&
        !_exclusive.leaving) {
      _sinkExclusive();
    }
  }

  /// The sheet over the dock, its grey orb on the top edge. Only the
  /// sheet and the orb take touches: the map above stays free to move.
  Widget _exclusiveLayer() {
    final viewport = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final offer = _exclusive.shown;
    final claiming = _exclusiveClaiming;
    return Positioned(
      key: const ValueKey<String>('home-exclusive-slot'),
      left: 0,
      right: 0,
      bottom: 0,
      child: _HomeOfferRoute(this)._measureOfferCard(
        HomeOfferSheet(
          id: offer?.id,
          visible: offer != null && !_exclusive.leaving,
          // It needs a driver now: up at once.
          riseDelay: Duration.zero,
          content: offer == null
              ? null
              : (context) => AnimatedBuilder(
                  // The pill counts the seconds down.
                  animation: _exclusive.clock,
                  builder: (context, _) =>
                      _HomeOfferRadar(this)._buildOutsideRadarOfferCard(
                        offer,
                        secondsLeft: _exclusiveSecondsLeft,
                      ),
                ),
          orb: _exclusiveRadar(),
          // Leaves the top island and some map above the sheet.
          maxHeight: math.max(
            240.0,
            viewport.height - safeTop - 72 - HomeOfferSheet.orbSize,
          ),
          // The down arrow skips the offer, like a time out (Q16).
          onDecline: claiming
              ? null
              : _HomeOfferRadar(this)._declineOutsideRadarOffer,
          onShown: () {
            if (mounted && !_exclusive.raised && _exclusiveLive) {
              _rebuild(() => _exclusive.raised = true);
            }
          },
          onSettled: _onExclusiveSettled,
          onLeaving: _fadeExclusiveRoute,
          onHidden: () {
            if (mounted && (_exclusive.onDown != null || _exclusive.leaving)) {
              _exclusiveDown();
            }
          },
          sheetKey: const ValueKey<String>('home-exclusive-sheet'),
          closeKey: const ValueKey<String>('direct-offer-dismiss'),
          closeLabel: tr.skipExclusiveOffer,
        ),
        (height) => _HomeOfferRoute(this)._offerCardMeasured(exclusive: height),
      ),
    );
  }

  /// The sheet has settled: the route fades in on the Home map.
  void _onExclusiveSettled() {
    final offer = _exclusive.shown;
    if (!mounted || offer == null || _outsideRadarOffer?.id != offer.id) {
      return;
    }
    unawaited(_showExclusiveRoute(offer));
  }

  /// The Home map shows [offer]'s route, pickup → drop-off, fitted above
  /// the sheet; the chips show the pickup minutes and the trip minutes.
  Future<void> _showExclusiveRoute(_HomeDirectOffer offer) {
    final fade = _exclusive.fade;
    // Drawn from nothing, fading in once its pins are ready.
    if (!_exclusiveReduceMotion) {
      fade.set(0);
    }
    return _HomeMapSheet(this)._previewTripRoute(
      offer.pickupPosition,
      offer.dropoffPosition,
      () async {
        final pins = await _HomeOfferRoute(this)._offerRouteMarkers(offer);
        if (mounted && fade.value < 1 && !fade.running) {
          fade.fadeTo(1, const Duration(milliseconds: 280), () {
            if (mounted) {
              _rebuild(() {});
            }
          });
        }
        return pins;
      },
      labels: (
        OfferRouteMarks.minutes(offer.pickupMinutes),
        OfferRouteMarks.minutes(offer.tripMinutes),
      ),
      stops: [for (final stop in offer.stops) stop.point.toLatLng()],
    );
  }

  /// The sheet is going: the route fades out first.
  void _fadeExclusiveRoute() {
    if (!mounted || !_isDirectOfferRoutePreview) {
      return;
    }
    if (_exclusiveReduceMotion) {
      return;
    }
    _exclusive.fade.fadeTo(0, HomeOfferSheet.routeFadeOut, () {
      if (mounted) {
        _rebuild(() {});
      }
    });
  }

  /// The Exclusive route is the one on the map.
  bool get _exclusiveRouteOnMap =>
      _exclusive.shown != null && _isDirectOfferRoutePreview;

  /// The map's [markers] with the Exclusive route's pins at the fade's
  /// opacity.
  Set<Marker> _exclusiveFadedPins(Set<Marker> markers) =>
      _exclusive.fade.value >= 1 || !_exclusiveRouteOnMap
      ? markers
      : _exclusive.fade.markers(markers, {
          for (final m in _directOfferRouteMarkers) m.markerId,
        });

  /// The map's [lines] with the Exclusive route's at the fade's opacity.
  Set<Polyline> _exclusiveFadedLines(Set<Polyline> lines) =>
      _exclusive.fade.value >= 1 || !_exclusiveRouteOnMap
      ? lines
      : _exclusive.fade.polylines(lines, {
          for (final p in _directOfferRoutePolylines) p.polylineId,
        });

  /// While the Exclusive offer is up its orb, on the sheet's top edge, is
  /// the reservation's grey Radar-offer orb ("Accept / MATCH / Tap to
  /// accept", black Accept, no icon) inside a thin dark time ring;
  /// tapping it accepts the offer.
  Widget _exclusiveRadar() {
    final claiming = _exclusiveClaiming;
    return KeyedSubtree(
      key: const ValueKey<String>('home-radar-exclusive'),
      child: AnimatedBuilder(
        // The normal radar's pulse and sweep, in grey.
        animation: Listenable.merge([
          _exclusive.clock,
          _goOnlinePulseController,
          _radarSweepController,
        ]),
        builder: (context, child) {
          final left = _exclusive.clock.value;
          return MoveraRadarOrb(
            // G4 decision 4: the first tap locks Accept and says
            // "Accepting…" until the server's answer (or its check).
            title: claiming
                ? tr.offerAccepting
                : driverText(DriverTexts.offerAccept),
            status: claiming ? tr.orbWait : tr.orbMatch,
            subtitle: claiming ? tr.pleaseWait : tr.tapToAccept,
            exclusive: true,
            reserve: true,
            active: true,
            loading: claiming,
            timeLeft: left,
            touchKey: const ValueKey<String>('exclusive-radar-touch-target'),
            pulse: _goOnlinePulseController.value,
            sweep: _radarSweepController.value,
            onTap: claiming || !_exclusiveLive
                ? null
                : _HomeOfferRadar(this)._acceptOutsideRadarOffer,
          );
        },
      ),
    );
  }
}
