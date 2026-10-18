part of 'home.dart';

// The Exclusive offer on Home (P4). Its card grows up out of the Home
// sheet and stays attached to it, like the reservation popup; while it
// is live the radar in the dock is its blue Accept, ringed by the time
// left. The offer itself (timers, accept, dismiss) stays in
// home_offer_radar.dart; this part moves the card and draws the radar.

/// The Exclusive card's motion and clock, owned by the Home state.
class _HomeExclusiveState {
  _HomeExclusiveState(TickerProvider vsync)
      : rise = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 260),
        ),
        clock = AnimationController(vsync: vsync, value: 1);

  /// 0 under the dock, 1 up.
  final AnimationController rise;

  /// The offer's time left, 1 → 0 over its lifetime.
  final AnimationController clock;

  late final Animation<double> slide = CurvedAnimation(
    parent: rise,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The offer the card shows; kept while it slides back down.
  _HomeDirectOffer? shown;

  /// ×, Accept or time out: the card is on its way down and the radar is
  /// itself again.
  bool leaving = false;

  void dispose() {
    rise.dispose();
    clock.dispose();
  }
}

extension _HomeExclusive on _DriverHomeState {
    bool get _exclusiveReduceMotion =>
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    /// The radar is the Exclusive offer's Accept.
    bool get _exclusiveLive =>
        _outsideRadarOffer != null && !_exclusive.leaving;

    /// How blue the Exclusive contours are (card, dock line, island):
    /// 0 black, 1 blue. It follows the card's slide, so the blue comes in
    /// as it rises and goes as it sinks (×, Accept, time out); with
    /// reduced motion the slide, and so the blue, just switches.
    double get _exclusiveBlue =>
        _exclusive.shown == null ? 0 : _exclusive.slide.value.clamp(0.0, 1.0);

    /// The offer arrived: the card slides up and its clock starts.
    void _raiseExclusive(_HomeDirectOffer offer, Duration lifetime) {
      _rebuild(() {
        _exclusive.shown = offer;
        _exclusive.leaving = false;
      });
      _startExclusiveClock(lifetime);
      if (_exclusiveReduceMotion) {
        _exclusive.rise.value = 1;
      } else {
        unawaited(_exclusive.rise.forward());
      }
    }

    void _startExclusiveClock(Duration lifetime) {
      _exclusive.clock.duration = lifetime;
      unawaited(_exclusive.clock.reverse(from: 1));
    }

    /// Slides the card back into the sheet; [then] runs once it is down.
    void _sinkExclusive({VoidCallback? then}) {
      _exclusive.clock.stop();
      // Cleared first: [then] may already bring the next offer up.
      void down() {
        if (mounted && _exclusive.shown != null) {
          _rebuild(() {
            _exclusive.shown = null;
            _exclusive.leaving = false;
          });
        }
        then?.call();
      }

      if (_exclusive.shown == null ||
          _exclusive.rise.value <= 0 ||
          _exclusiveReduceMotion) {
        _exclusive.rise.value = 0;
        down();
        return;
      }
      _exclusive.rise.reverse().whenCompleteOrCancel(() {
        // A new rise cancelled this one: the card stays.
        if (mounted && _exclusive.rise.status == AnimationStatus.dismissed) {
          down();
        }
      });
    }

    /// The offer was cleared without its own exit (offline, a new
    /// session): the card still slides down.
    void _sinkExclusiveIfGone() {
      if (_outsideRadarOffer == null &&
          _exclusive.shown != null &&
          _exclusive.rise.status != AnimationStatus.reverse) {
        _sinkExclusive();
      }
    }

    /// The card at the top of the Home sheet; its bottom runs behind the
    /// dock and the radar, with no gap.
    Widget _exclusiveLayer() {
      final offer = _exclusive.shown;
      if (offer == null) { return const SizedBox.shrink(); }
      final viewport = MediaQuery.sizeOf(context);
      final safeTop = MediaQuery.paddingOf(context).top;
      const bottomInset = 178.0;
      return Positioned(
        key: const ValueKey<String>('home-exclusive-slot'),
        // One pixel past each side: only the top contour shows.
        left: -1,
        right: -1,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _exclusive.slide,
          // The contour turns blue with the slide, and back with it.
          builder: (context, _) => FractionalTranslation(
            translation: Offset(0, 1 - _exclusive.slide.value),
            // R11-7: the route on the map fits above the card's top.
            child: _HomeOfferRoute(this)._measureOfferCard(PointerInterceptor(
              child: _HomeOfferRadar(this)._buildOutsideRadarOfferCard(
                offer,
                bottomInset: bottomInset,
                // Leaves the top island and some map above the card.
                maxContentHeight: math.max(
                  160.0,
                  viewport.height - safeTop - 72 - bottomInset - 46,
                ),
                contour: _exclusiveBlue,
              ),
            ), (height) =>
                _HomeOfferRoute(this)._offerCardMeasured(exclusive: height)),
          ),
        ),
      );
    }

    /// While the Exclusive offer is live the radar is blue and reads
    /// "Accept" over the seconds left; tapping it accepts the offer.
    Widget _exclusiveRadar() {
      final claiming =
          _reservation.claimingId != null || _scheduled.claimingId != null;
      final lifetime =
          _outsideRadarOffer?.lifetime ?? _DriverHomeState._outsideOfferLifetime;
      return KeyedSubtree(
        key: const ValueKey<String>('home-radar-exclusive'),
        child: AnimatedBuilder(
          // The normal radar's pulse and sweep, in blue.
          animation: Listenable.merge([
            _exclusive.clock,
            _goOnlinePulseController,
            _radarSweepController,
          ]),
          builder: (context, child) {
            final left = _exclusive.clock.value;
            final seconds = (left * lifetime.inMilliseconds / 1000).ceil();
            return MoveraRadarOrb(
              title: claiming
                  ? driverText(DriverTexts.offerMatching)
                  : driverText(DriverTexts.offerAccept),
              status: '$seconds s',
              subtitle: 'Accept the Exclusive offer',
              exclusive: true,
              active: true,
              loading: claiming,
              timeLeft: left,
              pulse: _goOnlinePulseController.value,
              sweep: _radarSweepController.value,
              onTap: claiming
                  ? null
                  : _HomeOfferRadar(this)._acceptOutsideRadarOffer,
            );
          },
        ),
      );
    }
}
