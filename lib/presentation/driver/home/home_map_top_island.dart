part of 'home.dart';

// Split from home_map_sheet.dart (rule 25, job 9): the top island and the
// map dim / radar layer / inactive dock builders. Same code, no change.
extension _HomeMapTopIsland on _DriverHomeState {
  /// White island at the top of Home: menu, today's earnings and
  /// destination search. The earnings are hidden until tapped; a second
  /// tap grows the island into the full Today details.
  /// Black island drawn like a small live screen: the blue arrow opens
  /// Destination, the middle cycles through the money faces, the menu
  /// sits on the right.
  Widget _buildTopIsland(double viewportWidth) {
    const height = DigitalIslandParts.height;
    // At launch the island is small (menu and arrow), then grows; a
    // message widens it and moves the menu and arrow aside.
    // R10-7: with no message passing, a hold keeps its reason on the
    // island, red, with the menu and search still beside it.
    final hold = _islandMessage == null && _islandWake >= 2
        ? _HomeAccount(this)._islandHold()
        : null;
    final message = _islandMessage ?? hold;
    final maxWidth = viewportWidth - 32;
    // A reservation request up: calendar and "Today 06:35 · Reservation".
    final reservation =
        message == null && _HomeReservation(this)._reservationOnDock
        ? DigitalReservationFace.whenOf(
            _reservation.request!,
            ScheduledClock.instance.now(),
          )
        : null;
    // An Exclusive offer up: check and "Exclusive · Pickup 4 min".
    final exclusive =
        message == null &&
            reservation == null &&
            _HomeExclusive(this)._exclusiveOnIsland
        ? _exclusive.shown!.pickupMinutes
        : null;
    // D4 (owner 2026-11-13 "Show \"No connection\""): online with the
    // offer feed down for more than 10 s, the island says "No connection"
    // until the feed is back. A passing message, an offer or a
    // reservation to answer goes first; menu and search stay.
    final feedDown =
        _feedDown.sync(_isOnline && _driverSession.activeTripId == null) &&
            message == null &&
            reservation == null &&
            exclusive == null &&
            _islandWake >= 2
        ? HomeIslandNotices.offerFeedDown
        : null;
    // Radar offers open (owner N1, live test 2026-10-26): the middle
    // says "1 offer · radar" and opens the full-screen radar; the menu
    // and the search keep their own jobs. It stays while offers remain
    // and leaves on its own when none is left.
    final radarOffers =
        message == null &&
            reservation == null &&
            exclusive == null &&
            feedDown == null &&
            _isOnline &&
            _radarHomeOffers.isNotEmpty
        ? _HomeOfferRadar(this)._radarTripTotal()
        : 0;
    final radar = radarOffers > 0;
    // Destination mode: pin and "Centralplan 15 · 35 min", menu kept.
    final destination =
        message == null &&
        reservation == null &&
        exclusive == null &&
        feedDown == null &&
        !radar &&
        _destinationModeActive;
    // R13-1: online on Home with no offer and no trip, the island says
    // "Finding trips" and now and then a short message. A message passing
    // (e.g. "Radar online") goes first.
    final waitingShown = _islandWaiting.sync(_waitingForTrips);
    final waitingTip = _islandWaiting.tip;
    final waiting =
        waitingShown &&
        message == null &&
        reservation == null &&
        exclusive == null &&
        feedDown == null &&
        !radar &&
        !destination;
    final waitingTitle = waitingTip?.title ?? DigitalWaitingFace.findingTitle;
    // A message sizes the island to its words (never taller): the normal
    // size for short words, a little longer for longer ones. 14 + 14 for the
    // tucked sides, 2 for the border and some air on both ends.
    final width = feedDown != null
        ? (DigitalMessageFace.widthFor(context, feedDown.title) +
                  54 +
                  54 +
                  2 +
                  8)
              .clamp(math.min(244.0, maxWidth), maxWidth)
              .toDouble()
        : hold != null
        ? (DigitalMessageFace.widthFor(context, hold.title, tappable: true) +
                  54 +
                  54 +
                  2 +
                  8)
              .clamp(math.min(244.0, maxWidth), maxWidth)
              .toDouble()
        : message != null
        ? (DigitalMessageFace.widthFor(context, message.title) +
                  14 +
                  14 +
                  2 +
                  36)
              .clamp(
                math.min(244.0, maxWidth),
                math.min(244.0 * 1.15, maxWidth),
              )
              .toDouble()
        : reservation != null
        ? (DigitalReservationFace.widthFor(context, reservation) +
                  14 +
                  14 +
                  2 +
                  36)
              .clamp(math.min(200.0, maxWidth), maxWidth)
              .toDouble()
        : exclusive != null
        ? (DigitalExclusiveFace.widthFor(context, exclusive) + 14 + 14 + 2 + 36)
              .clamp(math.min(200.0, maxWidth), maxWidth)
              .toDouble()
        : radar
        ? (DigitalRadarOffersFace.widthFor(context, radarOffers) +
                  54 +
                  54 +
                  2 +
                  28)
              .clamp(math.min(200.0, maxWidth), maxWidth)
              .toDouble()
        : waiting
        ? (DigitalWaitingFace.widthFor(
                    context,
                    waitingTitle,
                    dots: waitingTip == null,
                  ) +
                  14 +
                  14 +
                  2 +
                  36)
              .clamp(math.min(200.0, maxWidth), maxWidth)
              .toDouble()
        : destination
        ? (DigitalDestinationFace.widthFor(
                    context,
                    _destinationShortLabel,
                    _destinationEta,
                  ) +
                  54 +
                  14 +
                  2 +
                  28)
              .clamp(math.min(200.0, maxWidth), maxWidth)
              .toDouble()
        : _islandWake >= 1
        ? math.min(maxWidth, 244.0)
        : 112.0;
    final tucked =
        _islandMessage != null ||
        reservation != null ||
        exclusive != null ||
        waiting;
    Widget side(Widget button, {bool tuck = false}) => AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: tucked || tuck ? 14 : 54,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 54,
          maxWidth: 54,
          child: IgnorePointer(
            ignoring: tucked || tuck,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: tucked || tuck ? 0 : 1,
              child: button,
            ),
          ),
        ),
      ),
    );
    return PointerInterceptor(
      child: Listener(
        // Any touch on the island: normal behaviour at once (R13-1).
        onPointerDown: (_) => _islandWaiting.touch(),
        // UI-12: menu and search take touches in a 48 x 48 box; the
        // island paints exactly as before.
        child: IslandSideHitSlop(
          target: IslandSideHitSlop.minTarget / _islandScale,
          growth: const EdgeInsets.fromLTRB(
            _islandSideSlopX,
            0,
            _islandSideSlopX,
            _islandSideSlopBottom,
          ),
          child: DigitalIslandShell(
            width: width,
            height: height,
            // Online, the driver is on the road: no light passing over it.
            calm: _isOnline,
            // Every size change, out and back, glides with a soft spring.
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeOutCubic,
            // Radar offers ring it green, like the radar.
            offers:
                _isOnline && (_hasRideOffers || _radarHomeOffers.isNotEmpty),
            child: Row(
              children: [
                side(
                  Builder(
                    builder: (context) => Tooltip(
                      message: tr.menu,
                      child: IslandSideButton(
                        outward: AxisDirection.left,
                        child: InkWell(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: SizedBox(
                            width: 54,
                            height: height,
                            child: DigitalIslandParts.menuIcon(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  // Asleep, the middle is a few pixels wide and shows
                  // nothing: no unlabelled target for a screen reader (UI-12).
                  child: ExcludeSemantics(
                    excluding:
                        message == null &&
                        reservation == null &&
                        exclusive == null &&
                        feedDown == null &&
                        !radar &&
                        !waiting &&
                        !destination &&
                        _islandWake < 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        if (_islandFace == _IslandFace.history &&
                            (details.primaryVelocity ?? 0).abs() > 80) {
                          _openRideHistoryFromIsland();
                        }
                      },
                      child: InkWell(
                        key: const ValueKey<String>('last-trip-launcher'),
                        onTap: hold != null
                            ? hold.onTap
                            : message != null
                            ? () => _onIslandMessageTap(message)
                            : reservation != null ||
                                  exclusive != null ||
                                  feedDown != null
                            ? null
                            : radar
                            ? _openRideOffers
                            : destination
                            ? _openDestinationDetails
                            : _onIslandEarningsTap,
                        // Online, the island is the top of the Radar: holding
                        // it asks "Go offline?" (Q19), unless an offer is up.
                        // Offline, holding it goes straight to Ride history.
                        onLongPress: reservation != null || exclusive != null
                            ? null
                            : _isOnline
                            ? () {
                                HapticFeedback.mediumImpact();
                                unawaited(_confirmGoOffline());
                              }
                            : message != null || destination
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _openRideHistoryFromIsland();
                              },
                        child: SizedBox(
                          height: height,
                          child: DigitalFaceSwitcher(
                            child: hold != null
                                ? _islandMessageView(hold, hold: true)
                                : message != null
                                ? _islandMessageView(message)
                                : feedDown != null
                                ? _islandFeedDownView(feedDown)
                                : reservation != null
                                ? DigitalReservationFace(
                                    key: const ValueKey<String>(
                                      'island-reservation-face',
                                    ),
                                    when: reservation,
                                  )
                                : exclusive != null
                                ? DigitalExclusiveFace(
                                    key: const ValueKey<String>(
                                      'island-exclusive-face',
                                    ),
                                    pickupMinutes: exclusive,
                                  )
                                : radar
                                ? DigitalRadarOffersFace(
                                    key: const ValueKey<String>(
                                      'island-radar-offers-face',
                                    ),
                                    count: radarOffers,
                                  )
                                : waiting
                                ? (waitingTip == null
                                      ? const DigitalWaitingFace.finding(
                                          key: ValueKey<String>(
                                            'island-finding',
                                          ),
                                        )
                                      : DigitalWaitingFace(
                                          key: ValueKey<String>(
                                            'island-tip-${waitingTip.id}',
                                          ),
                                          title: waitingTip.title,
                                          color: islandTipColor(
                                            waitingTip.look,
                                          ),
                                        ))
                                : destination
                                ? DigitalDestinationFace(
                                    key: const ValueKey<String>(
                                      'island-destination-face',
                                    ),
                                    place: _destinationShortLabel,
                                    eta: _destinationEta,
                                  )
                                : _islandWake >= 2
                                ? _islandFaceView()
                                : const SizedBox(
                                    key: ValueKey<String>('island-asleep'),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                side(
                  Tooltip(
                    message: tr.searchDestination,
                    child: IslandSideButton(
                      outward: AxisDirection.right,
                      child: InkWell(
                        key: const ValueKey<String>('destination-mode-open'),
                        // Decision 4: greyed while a Match or Accept is with
                        // dispatch; the mode cannot change until it is answered.
                        onTap: _HomeOfferRules(this)._claimInFlight
                            ? null
                            : _openDestinationModePicker,
                        child: Opacity(
                          opacity: _HomeOfferRules(this)._claimInFlight
                              ? 0.4
                              : 1,
                          child: const SizedBox(
                            width: 54,
                            height: height,
                            child: DigitalIslandParts.searchIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  tuck: destination,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// D4: "No connection" while the offer feed stays down; one face for
  /// the whole outage (no replay of the switch on every build).
  Widget _islandFeedDownView(IslandMessage line) {
    final (color, toneIcon) = DigitalIslandParts.toneLook(line.tone);
    return DigitalMessageFace(
      key: const ValueKey<String>('island-offer-feed-down'),
      title: line.title,
      color: color,
      icon: toneIcon,
    );
  }

  /// The short messages the app has facts for; in the demo, all of them.
  List<IslandWaitingTip> _waitingTips() {
    final dispatch = _dispatch;
    final signals = _ownsDispatch && dispatch is DemoDispatchRepository
        ? IslandWaitingSignals.demo(_adminHomeConfig)
        : IslandWaitingSignals.fromHome(
            _adminHomeConfig,
            now: ScheduledClock.instance.now(),
            // Contract v0.7.2 §17: inside a surge zone or within 3 km.
            boostNearby: nearSurgeZone(
              GeoPoint(_driverPosition.latitude, _driverPosition.longitude),
              _surgeMap?.zones ?? const [],
            ),
            // G4-F6: "Peak hours start at" the real start of an event.
            liveEvents: DriverEvents.instance.visible(),
            // Fix job 9 (§60): his real place in an airport queue.
            airportQueuePlace: AirportQueue.instance.place,
          );
    return signals.tips();
  }

  /// The map darkens a little as the sheet rises over it.
  Widget _homeMapDim() {
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: _panelSlidePosition,
        builder: (context, position, _) => position <= 0.001
            ? const SizedBox.shrink()
            : ColoredBox(
                key: const ValueKey<String>('home-map-dim'),
                color: const Color(
                  0xFF0A0E10,
                ).withValues(alpha: 0.22 * position.clamp(0.0, 1.0)),
              ),
      ),
    );
  }

  /// The radar never moves: it sits in the dock, closed or open. With the
  /// sheet open and Radar on, the same radar reads "Hold · OFF" and a
  /// one-second hold goes offline.
  Widget _homeRadarLayer() {
    // Owner 2026-10-31: set offline, the "You're offline" card takes the
    // place of the radar and the dock's icons.
    if (_HomeOnlineGate(this)._offlineCardShown) {
      return _HomeOnlineGate(this)._offlineCardLayer();
    }
    return _homeRadarLayerPlain();
  }

  /// The radar as always (also under the slid sheet while the card shows).
  Widget _homeRadarLayerPlain() {
    if (_homeSheetInactive) {
      // Account on hold: the radar rides the red sheet's notch.
      return ValueListenableBuilder<double>(
        valueListenable: _panelSlidePosition,
        builder: (context, position, child) => Positioned(
          left: 0,
          right: 0,
          bottom:
              MoveraSheetMetrics.collapsedHeight -
              50 +
              (_homeExpandedHeight(context) -
                      MoveraSheetMetrics.collapsedHeight) *
                  position,
          child: child!,
        ),
        child: Center(child: _radarDragToSheet(child: _buildGoOnlineButton())),
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: MoveraSheetMetrics.collapsedHeight - 50,
      child: Center(
        child: _radarDragToSheet(
          child: ValueListenableBuilder<double>(
            valueListenable: _panelSlidePosition,
            builder: (context, position, _) {
              final holdOff = _isOnline && position >= 0.5;
              // A reservation request or an Exclusive offer brings its
              // own Accept orb on its sheet, over this one. Offers on the deck: the radar takes
              // the front trip.
              final front = !holdOff && _isOnline && _outsideRadarOffer == null
                  ? _HomeOfferRadar(this)._radarFrontOffer()
                  : null;
              final face = _isOnline
                  ? (holdOff
                        ? 'radar-hold-off'
                        : front != null
                        ? 'radar-accept'
                        : 'radar-online')
                  : _isGoingOnline
                  ? 'radar-connecting'
                  : 'radar-offline';
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                reverseDuration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.97,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey<String>(face),
                  child: _isOnline
                      ? (holdOff
                            ? _holdOffRadar()
                            : _radarLongPressOff(
                                front != null
                                    ? _acceptRadar(front)
                                    : _buildTripRadarButton(),
                              ))
                      : _isGoingOnline
                      ? _buildGoingOnlineButton()
                      : _buildGoOnlineButton(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Account on hold: the red dock, faded out as the red sheet opens.
  Widget? _inactiveDock() {
    if (!_homeSheetInactive) {
      return null;
    }
    return _sheetPointer(
      DriverSheetNav.collapsedDock(
        context: context,
        scaffoldKey: _scaffoldKey,
        isOnline: _isOnline,
        hasRideOffers: _hasRideOffers || _radarHomeOffers.isNotEmpty,
        hasScheduledRideOffers: _hasScheduledRideOffers,
        goOnlinePulseController: _goOnlinePulseController,
        onOpenScheduledRides: _openScheduledRides,
        inactive: true,
      ),
    );
  }
}
