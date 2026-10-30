part of 'home.dart';

// Driver group 3 (owner decisions 1–3, G3-R1, R2, R5; contract v0.18.4
// §29 `driverHome`): what Home tells the driver about going online.
// - One reason card above the radar (never over Go online) instead of
//   snackbars: the server's refusal, location off or not allowed with
//   Open Settings, "You were set offline – tap to go online again", the
//   one-time battery saver warning.
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
  /// offline (no position for `autoOffline.noFixMinutes`).
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
    DriverSetOfflineNotice.instance.show();
  }

  /// Decision 3 + G3-R1: "You were set offline – tap to go online again".
  void _onSetOfflineNotice() {
    if (!mounted) return;
    if (!DriverSetOfflineNotice.instance.value) {
      _clearReason('set-offline');
      return;
    }
    if (_driverSession.isOnline || _isGoingOnline) {
      DriverSetOfflineNotice.instance.clear();
      return;
    }
    _showReason(
      _HomeReason(
        'set-offline',
        tr.setOfflineLine,
        tone: HomeReasonTone.info,
        onTap: () {
          DriverSetOfflineNotice.instance.clear();
          _goOnline();
        },
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
