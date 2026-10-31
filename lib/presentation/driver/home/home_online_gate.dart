part of 'home.dart';

// Driver group 3 (owner decisions 1–3, G3-R1, R2, R5; contract v0.18.4
// §29 `driverHome`): what Home tells the driver about going online.
// - One reason card above the radar (never over Go online) instead of
//   snackbars: the server's refusal, location off or not allowed with
//   Open Settings, the one-time battery saver warning.
// - Owner 2026-10-31 ("new set offline message"): set offline without
//   asking, the Home sheet shows the "You're offline" card in place of its
//   icons (real reason, Check my phone, Go online, OK) for 2 minutes.
// - "Starting the server…" while going online waits more than 5 s.
// - "You are not eligible to drive in this area" when the server says the
//   driver is outside his zones (once per entry).

/// One reason on the card; [id] tells which one it is.
class _HomeReason {
  const _HomeReason(
    this.id,
    this.text, {
    this.action,
    this.onAction,
    this.onTap,
    this.closable = false,
    this.tone = HomeReasonTone.problem,
  });

  final String id;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool closable;
  final HomeReasonTone tone;
}

/// The gate's own state on Home (extensions carry no fields).
class _HomeGateState {
  /// The reason card above the radar.
  _HomeReason? reason;

  /// Decision 2: Home's location read says location is off or not allowed.
  Object? locationBlock;
  Timer? slowServerTimer;
  bool slowServerShown = false;
  VoidCallback? areaListener;
  VoidCallback? setOfflineListener;

  /// The "You're offline" card is in the sheet; it goes after
  /// [HomeOfflineCard.showsFor].
  bool offlineCard = false;
  Timer? offlineCardTimer;

  /// The card's reason for a held forced offline (`_offlineHeld`), shown
  /// once the driver is really offline.
  VoidCallback? offlineHeldNotice;

  /// The `offlineAt` the card was shown for on open.
  DateTime? offlineSeenAt;
}

/// Decision 2: the battery saver warning is shown once per install.
const String _batterySaverWarnedPref = 'g3_battery_saver_warned';

extension _HomeOnlineGate on _DriverHomeState {
  void _startOnlineGate() {
    final area = _gate.areaListener = _onAreaChanged;
    final setOffline = _gate.setOfflineListener = _onSetOfflineNotice;
    DriverAreaWatch.instance.addListener(area);
    DriverSetOfflineNotice.instance.addListener(setOffline);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onSetOfflineNotice();
      _onAreaChanged();
    });
  }

  void _stopOnlineGate() {
    _gate.slowServerTimer?.cancel();
    _gate.offlineCardTimer?.cancel();
    if (_gate.areaListener case final listener?) {
      DriverAreaWatch.instance.removeListener(listener);
    }
    if (_gate.setOfflineListener case final listener?) {
      DriverSetOfflineNotice.instance.removeListener(listener);
    }
  }

  /// From Go online: location off or not allowed keeps the driver offline
  /// (decision 2); otherwise the last refusal or notice goes, and battery
  /// saver warns once.
  bool _blocksOnline() {
    if (_locationBlocksOnline()) return true;
    DriverSetOfflineNotice.instance.clear();
    _clearReason();
    unawaited(_warnBatterySaverOnce());
    return false;
  }

  void _showReason(_HomeReason reason) {
    if (!mounted) return;
    _rebuild(() => _gate.reason = reason);
  }

  void _clearReason([String? id]) {
    if (!mounted || _gate.reason == null) return;
    if (id != null && _gate.reason?.id != id) return;
    _rebuild(() => _gate.reason = null);
  }

  // Location (decision 2).

  /// What Home's own location read said: off, not allowed, approximate.
  void _locationFailed(Object error) {
    if (error is PreciseLocationRequiredException) {
      _gate.locationBlock = null;
      _showReason(
        _HomeReason(
          'location-precise',
          tr.preciseLocationOff,
          action: tr.settings,
          onAction: () => unawaited(DriverLocationService.openSettings()),
        ),
      );
      return;
    }
    if (error is LocationPermissionDeniedException) {
      _gate.locationBlock = error;
      _showReason(
        _HomeReason(
          'location-permission',
          error.forever ? tr.locationBlockedSettings : tr.locationNotAllowed,
          action: error.forever ? tr.settings : tr.allowLocation,
          onAction: () {
            if (error.forever) {
              unawaited(DriverLocationService.openSettings());
              return;
            }
            DriverLocationService.allowPrompt();
            if (mounted) unawaited(_HomeMapSheet(this)._startDriverLocation());
          },
        ),
      );
      return;
    }
    if (error is DriverLocationException ||
        error is LocationServiceDisabledException) {
      _gate.locationBlock = error;
      _showLocationRequired();
    }
  }

  /// A position arrived: location is on and allowed again.
  void _locationWorks() {
    if (_gate.locationBlock == null &&
        _gate.reason?.id.startsWith('location-') != true) {
      return;
    }
    _gate.locationBlock = null;
    final id = _gate.reason?.id;
    if (id != null && id.startsWith('location-')) _clearReason(id);
  }

  /// "Turn on location to go online" + Open Settings.
  void _showLocationRequired() {
    final block = _gate.locationBlock;
    _showReason(
      _HomeReason(
        'location-required',
        tr.locationRequired,
        action: tr.locationOpenSettings,
        onAction: () {
          if (block is LocationPermissionDeniedException && !block.forever) {
            DriverLocationService.allowPrompt();
            unawaited(_HomeMapSheet(this)._startDriverLocation());
            return;
          }
          unawaited(DriverLocationService.openLocationSettings());
        },
      ),
    );
  }

  /// Decision 2: location off or not allowed blocks Go online before the
  /// server is asked; Home tries to read it again at once.
  bool _locationBlocksOnline() {
    if (_gate.locationBlock == null) return false;
    _showLocationRequired();
    unawaited(_HomeMapSheet(this)._startDriverLocation());
    return true;
  }

  /// Decision 2: battery saver on (where the phone tells) warns once per
  /// install; going online goes on.
  Future<void> _warnBatterySaverOnce() async {
    if (_driverLocationService is! DriverLocationService) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_batterySaverWarnedPref) ?? false) return;
      if (!await Battery().isInBatterySaveMode) return;
      await prefs.setBool(_batterySaverWarnedPref, true);
    } catch (_) {
      // Browsers and some phones cannot tell: nothing to warn about.
      return;
    }
    if (!mounted || _gate.reason != null) return;
    _showReason(
      _HomeReason(
        'battery-saver',
        tr.batterySaverWarning,
        closable: true,
        tone: HomeReasonTone.warning,
      ),
    );
  }

  // The server's answer.

  /// Going online was refused: the reason stays on the card until the
  /// next try (owner: no 6 s snackbar). A tap opens the reminders, where
  /// each fix is.
  void _showServerRefusal(String message) {
    final location = message == tr.locationRequired;
    _showReason(
      _HomeReason(
        'server-refusal',
        message,
        action: location ? tr.locationOpenSettings : null,
        onAction: location
            ? () => unawaited(DriverLocationService.openLocationSettings())
            : null,
        onTap: location ? null : _HomeAccount(this)._showReminders,
        closable: !location,
      ),
    );
  }

  /// G3-R1: the profile read every 60 s says the server set the driver
  /// offline (no position for `autoOffline.noFixMinutes`, or an admin).
  void _checkServerSetOffline(DriverAccountSession session) {
    final presence = LiveDriverServices.instance?.presence;
    final account = session.account;
    if (presence == null || account == null || !_driverSession.isOnline) {
      return;
    }
    if (!presence.serverSetOffline(
      onlineStatus: account.onlineStatus,
      version: account.version,
    )) {
      return;
    }
    unawaited(_goOffline(notice: false));
    _explainServerOffline(session);
  }

  /// Why the server set him offline: `Driver.offlineReason` (+ note) of the
  /// profile (contract v0.18.6, owner "Send the real reason"), read only
  /// when sent (an older server: "Movera set you offline").
  void _explainServerOffline(DriverAccountSession session) {
    final account = session.account;
    _showServerReason(
      DriverOfflineReason.fromServer(account?.offlineReason) ??
          DriverOfflineReason.movera,
      note: account?.offlineNote,
    );
    if (account?.offlineAt case final at?) _gate.offlineSeenAt = at;
  }

  /// The card with a server reason; the counts are the zone's settings,
  /// as the server's (contract: minutes = noFixMinutes, count =
  /// missedExclusive).
  void _showServerReason(DriverOfflineReason reason, {String? note}) {
    DriverSetOfflineNotice.instance.show(
      reason: reason,
      count: switch (reason) {
        DriverOfflineReason.noPosition =>
          LiveDriverServices.instance?.config.current?.noFixMinutes,
        DriverOfflineReason.missedOffers =>
          DriverOfferRules.current.autoOfflineAfter,
        _ => null,
      },
      note: reason == DriverOfflineReason.vehicleBlocked ? note : null,
    );
  }

  /// Contract v0.18.6: the app opens (or comes back) offline and the
  /// server set him offline a short while ago (a push "You were set
  /// offline" brought him here): the card says why, once per time.
  void _serverOfflineOnOpen(DriverAccountSession session) {
    final account = session.account;
    final told = DriverOfflineReason.fromServer(account?.offlineReason);
    final at = account?.offlineAt;
    if (told == null ||
        at == null ||
        account?.onlineStatus != 'offline' ||
        _driverSession.isOnline ||
        _isGoingOnline ||
        _gate.offlineSeenAt == at ||
        _alreadyShownFor(at) ||
        DateTime.now().difference(at).abs() > serverOfflineFresh) {
      return;
    }
    _gate.offlineSeenAt = at;
    _showServerReason(told, note: account?.offlineNote);
  }

  /// Checker MEDIUM 1: the app showed the card itself (missed offers, a
  /// restart) and the server's offlineAt is from that same moment or
  /// later: the same offline, not told twice.
  bool _alreadyShownFor(DateTime at) {
    final shown = DriverSetOfflineNotice.instance.shownAt;
    return shown != null &&
        !at.isBefore(shown.subtract(const Duration(seconds: 10)));
  }

  /// How long after the server set him offline the card still comes when
  /// the app opens.
  static const serverOfflineFresh = Duration(minutes: 30);

  /// The notice changed: the "You're offline" card comes (for
  /// [HomeOfflineCard.showsFor]) or goes.
  void _onSetOfflineNotice() {
    if (!mounted) return;
    final notice = DriverSetOfflineNotice.instance;
    if (!notice.value) {
      _gate.offlineCardTimer?.cancel();
      _gate.offlineCardTimer = null;
      if (_gate.offlineCard) _rebuild(() => _gate.offlineCard = false);
      return;
    }
    if (_driverSession.isOnline || _isGoingOnline) {
      notice.clear();
      return;
    }
    _gate.offlineCardTimer?.cancel();
    _gate.offlineCardTimer = Timer(HomeOfflineCard.showsFor, notice.clear);
    _rebuild(() => _gate.offlineCard = true);
  }

  /// The "You're offline" card is in the sheet.
  /// Not while the radar must say HOLD, REST or paused: that is the
  /// reason then.
  bool get _offlineCardShown =>
      _gate.offlineCard &&
      !_isOnline &&
      !_HomeMapSheet(this)._homeSheetInactive &&
      !_driverSession.isSuspended &&
      _HomeAccount(this)._onlineHold() == null;

  /// The risen Home sheet with the card, Home's radar in its notch reading
  /// "Go online" (closed sheet only); [_HomeMapSheet._homeRadarLayer] puts
  /// it in the radar's place.
  Widget _offlineCardLayer() {
    final notice = DriverSetOfflineNotice.instance;
    // LOW 2: slid up, the sheet shows its own content under the usual
    // radar; the card waits for the sheet to close again.
    return ValueListenableBuilder<double>(
      valueListenable: _panelSlidePosition,
      builder: (context, position, child) =>
          position > 0.05 ? _HomeMapSheet(this)._homeRadarLayerPlain() : child!,
      child: Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: PointerInterceptor(
          child: HomeOfflineCard(
            reason: offlineReasonText(notice),
            radar: AnimatedBuilder(
              animation: _goOnlinePulseController,
              builder: (context, _) => _buildRadarOrb(
                title: tr.radar,
                status: tr.offlineGoOnline,
                subtitle: tr.tapToScan,
                onTap: () {
                  notice.clear();
                  _goOnline();
                },
                pulse: _goOnlinePulseController.value,
              ),
            ),
            onOk: notice.clear,
            // Checker MEDIUM 2: no second prompt; the check already ran
            // the guarded one, Home only reads the location again.
            onLocationFixed: () {
              if (!mounted) return;
              unawaited(_HomeMapSheet(this)._startDriverLocation());
            },
          ),
        ),
      ),
    );
  }

  // Outside his zones (G3-R2).

  void _onAreaChanged() {
    if (!mounted) return;
    final zones = DriverAreaWatch.instance.take();
    if (zones == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => MoveraDialogTheme(
          child: AlertDialog(
            key: const ValueKey<String>('home-outside-area'),
            title: Text(tr.outsideAreaTitle),
            content: Text(tr.outsideAreaBody(zones.join(', '))),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr.outsideAreaOk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v0.18.4 `auth.slowStart` covers going online: after
  /// `showAfterSeconds` (5 s) without the server's answer, "Starting the
  /// server…" says why the driver waits (up to 60 s).
  void _serverWaitStarted() {
    _gate.slowServerTimer?.cancel();
    _gate.slowServerTimer = Timer(SlowServerNote.defaultShowAfter, () {
      if (mounted) _rebuild(() => _gate.slowServerShown = true);
    });
  }

  void _serverWaitEnded() {
    _gate.slowServerTimer?.cancel();
    _gate.slowServerTimer = null;
    if (mounted && _gate.slowServerShown) {
      _rebuild(() => _gate.slowServerShown = false);
    }
  }

  // Layout.

  /// The card and "Starting the server…", above the radar.
  Widget _reasonLayer() {
    final reason = _gate.reason;
    final slow = _gate.slowServerShown;
    if (reason == null && !slow) return const SizedBox.shrink();
    // The offline card has the sheet; nothing sits over it.
    if (_offlineCardShown) return const SizedBox.shrink();
    if (_isOnline &&
        (_hasRideOffers ||
            _radarHomeOffers.isNotEmpty ||
            _outsideRadarOffer != null)) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      // Over the radar and the map buttons beside it, so Go online (and
      // recenter, safety) is never covered, and over the bell (live test
      // 2026-10-30: the location card covered it).
      bottom: math.max(
        MoveraSheetMetrics.collapsedHeight -
            50 +
            HomeOfferSheet.orbSize +
            14 +
            _homeMapButtonSize,
        HomeMapButtonLayout.reasonBottom,
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _panelSlidePosition,
        builder: (context, position, child) =>
            position > 0.05 ? const SizedBox.shrink() : child!,
        child: PointerInterceptor(
          child: Column(
            key: const ValueKey<String>('home-reason-layer'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reason != null)
                HomeReasonCard(
                  key: ValueKey<String>('home-reason-${reason.id}'),
                  text: reason.text,
                  actionLabel: reason.action,
                  onAction: reason.onAction,
                  onTap: reason.onTap,
                  tone: reason.tone,
                  onClose: reason.closable ? () => _clearReason() : null,
                ),
              if (slow)
                Padding(
                  padding: EdgeInsets.only(top: reason == null ? 0 : 8),
                  child: DecoratedBox(
                    key: const ValueKey<String>('home-slow-server'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 8),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7D898F),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tr.authStartingServer,
                                style: const TextStyle(
                                  color: Color(0xFF1D2427),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
