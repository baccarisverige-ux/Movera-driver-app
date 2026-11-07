part of 'home.dart';

extension _HomeMapIsland on _DriverHomeState {
  /// Online on Home with no offer, no trip and no request up.
  bool get _waitingForTrips =>
      _isOnline &&
      _islandWake >= 2 &&
      _driverSession.activeTripId == null &&
      !_hasRideOffers &&
      _radarHomeOffers.isEmpty &&
      _outsideRadarOffer == null &&
      !_HomeExclusive(this)._exclusiveLive &&
      !_HomeReservation(this)._reservationOnDock;

  Widget _islandFaceView() {
    switch (_islandFace) {
      case _IslandFace.hidden:
        return DigitalIslandParts.hiddenFace(label: _waybills.last?.fare);
      case _IslandFace.lastTrip:
        if (_lastTripSettling) {
          return DigitalUpdatingFace(
            key: const ValueKey<String>('island-updating'),
            unit: DigitalIslandParts.unitOf(_waybills.last?.fare),
          );
        }
        return DigitalIslandParts.amountFace(
          'island-last-trip',
          tr.lastTrip,
          _lastTripFareLabel,
        );
      case _IslandFace.today:
        return DigitalIslandParts.todayFace();
      case _IslandFace.history:
        return DigitalIslandParts.historyFace();
    }
  }

  Widget _islandMessageView(IslandMessage message, {bool hold = false}) {
    final (color, toneIcon) = DigitalIslandParts.toneLook(message.tone);
    return DigitalMessageFace(
      key: ValueKey<String>(
        hold
            ? 'island-hold-${message.title}'
            : 'island-message-$_islandMessageSeq',
      ),
      title: message.title,
      color: color,
      icon: message.icon ?? toneIcon,
      pulse: message.live,
      tappable: hold,
    );
  }

  void _endIslandMessage() {
    _islandMessageTimer?.cancel();
    if (!mounted) {
      return;
    }
    _rebuild(() => _islandMessage = null);
    _showNextIslandMessage();
  }

  /// Tapping a message closes it; the first-launch hint and notification
  /// popups also open what they are about.
  void _onIslandMessageTap(IslandMessage message) {
    _endIslandMessage();
    message.onTap?.call();
  }

  /// Hidden total → last trip → today's total → Ride history → hidden.
  /// Left untouched for 5 s, the island goes back to the hidden total.
  void _onIslandEarningsTap() {
    // The touch only closed "Finding trips" or a waiting message.
    if (_islandWaiting.takeSwallowedTap()) {
      return;
    }
    // A screen reader's tap sends no pointer: it closes the waiting face
    // like a touch, so Menu and Search come back (driver-u124).
    if (_islandWaiting.touch()) {
      _islandWaiting.takeSwallowedTap();
      return;
    }
    if (_islandWake < 2) {
      // A tap during the launch animation just finishes it.
      _islandWakeTimer?.cancel();
      _rebuild(() => _islandWake = 2);
      return;
    }
    HapticFeedback.selectionClick();
    _rebuild(() {
      _islandFace = _IslandFace
          .values[(_islandFace.index + 1) % _IslandFace.values.length];
    });
    if (_islandFace == _IslandFace.today) {
      unawaited(DigitalIslandParts.refreshToday());
    }
    // Owner 2026-11-07: fare + tip, a tip given after the trip included.
    if (_islandFace == _IslandFace.lastTrip) {
      unawaited(LastTripTip.refresh(_waybills));
    }
    _restartIslandIdle();
  }

  void _restartIslandIdle() {
    _islandIdleTimer?.cancel();
    if (_islandFace == _IslandFace.hidden) {
      return;
    }
    _islandIdleTimer = Timer(_islandIdleTimeout, () {
      if (!mounted || _islandFace == _IslandFace.hidden) {
        return;
      }
      _rebuild(() => _islandFace = _IslandFace.hidden);
    });
  }

  /// First launch only: tell the driver the middle shows the earnings.
  Future<void> _showIslandHintOnce() async {
    if (!DriverRuntimeConfig.current.islandHint) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_islandHintSeenKey) ?? false)) {
      return;
    }
    await prefs.setBool(_islandHintSeenKey, true);
    IslandMessages.show(HomeIslandNotices.earningsHint(_onIslandEarningsTap));
  }

  /// A trip that just ended still has its money updating.
  bool get _lastTripSettling {
    final pending = _lastTripPendingId;
    return pending != null && pending == _waybills.last?.tripId;
  }

  String get _lastTripFareLabel {
    final fare = _waybills.last?.fare;
    if (fare == null || !fare.contains(RegExp(r'\d'))) {
      return DigitalIslandParts.noAmount;
    }
    return fare;
  }

  void _scheduleLastTripSettle() {
    _lastTripSettleTimer?.cancel();
    final last = _waybills.last;
    final left = last == null
        ? Duration.zero
        : _lastTripSettleTime - DateTime.now().difference(last.issuedAt);
    if (left <= Duration.zero) {
      _lastTripPendingId = null;
      return;
    }
    _lastTripPendingId = last!.tripId;
    _lastTripSettleTimer = Timer(left, () {
      if (!mounted) {
        return;
      }
      // The money is in: show it, and give the driver 5 s to read it.
      _rebuild(() => _lastTripPendingId = null);
      if (_islandFace == _IslandFace.lastTrip) {
        _restartIslandIdle();
      }
    });
  }

  void _openRideHistoryFromIsland() {
    _islandIdleTimer?.cancel();
    _rebuild(() => _islandFace = _IslandFace.hidden);
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => rideHistoryScreen()),
    );
  }

  void _onRadarSheetDragStart(DragStartDetails details) {
    _sheetPointerStartPos = _panelController.isAttached
        ? _panelController.panelPosition
        : 0;
  }
}
