part of 'home.dart';

/// A live build (`MOVERA_AUTH_REQUIRED`): Home's switch is the server's
/// availability (`POST /driver/availability`). The demo has no
/// [LiveDriverServices]; nothing here runs there.
extension _HomeLive on _DriverHomeState {
  /// D11 on the server too: a driver the server still holds online from
  /// before this start is set offline, as Home shows (once per start).
  void _settleServerAfterStart() {
    final presence = LiveDriverServices.instance?.presence;
    if (presence == null || _driverSession.isOnline) return;
    unawaited(presence.settleAfterStart());
  }

  /// D-3: the trip the server holds for this driver when the device has
  /// none saved; null in the demo, with no trip, or no answer.
  Future<PersistedActiveRide?> _serverActiveTrip() async {
    final live = LiveDriverServices.instance;
    if (live == null) return null;
    // G27: through the account's shared profile read (the badges' read of
    // the same back press is shared, not sent twice).
    final account = mounted ? accountSessionOf(context) : null;
    final found = await live.activeTrip.fetch(
      activeTripId: account == null
          ? null
          : () async => (await account.refresh()).activeTripId,
    );
    if (found == null) return null;
    live.trips.observe(found.projection);
    // Audit 2026-11-07 B2: a server slower than this phone still names a
    // trip that is over here (a newer projection is kept): not re-opened.
    if (_tripIsOver(found.ride.tripId)) return null;
    return found.ride.stamped();
  }

  /// The trip's newest known status is terminal
  /// (`contract.json#tripStatus.terminal`); false in the demo.
  bool _tripIsOver(String tripId) => _finishedStatus(tripId) != null;

  TripStatus? _finishedStatus(String tripId) {
    final status = TripStatusWire.tryParse(
      LiveDriverServices.instance?.trips.statusOf(tripId),
    );
    return status != null && status.isTerminal ? status : null;
  }

  /// Clears the saved snapshot of [tripId], a trip already over, and marks
  /// it terminal so it never comes back.
  /// Audit 2026-11-07 B2: the saved trip, unless it is already over; a stale
  /// snapshot of a finished trip is cleared and never re-opened.
  Future<PersistedActiveRide?> _savedTripUnlessOver(
    ActiveRideRepository repo,
  ) async {
    final saved = await repo.read();
    if (saved == null || !_tripIsOver(saved.tripId)) return saved;
    await _clearFinishedTrip(repo, saved.tripId);
    return null;
  }

  Future<void> _clearFinishedTrip(
    ActiveRideRepository repo,
    String tripId,
  ) async {
    DriverLog.info('Saved trip $tripId is already over: not re-opened');
    if (repo is TerminalRideRepository) {
      final terminal = repo as TerminalRideRepository;
      final status = _finishedStatus(tripId);
      if (status != null) await terminal.markTerminal(tripId, status);
      await terminal.clearForTrip(tripId);
    } else {
      await repo.clear();
    }
  }

  /// Asks the server to go online while the switch animates; null in the
  /// demo.
  Future<String?>? _askServerOnline() {
    final answer = LiveDriverServices.instance?.presence.goOnline();
    if (answer == null) return null;
    _HomeOnlineGate(this)._serverWaitStarted();
    return answer.whenComplete(() => _HomeOnlineGate(this)._serverWaitEnded());
  }

  /// After the animation: true when Home may go online. A refusal (no car,
  /// fleet not approved, no connection…) is said plainly and Home goes back
  /// offline.
  Future<bool> _serverAgreed(Future<String?> answer) async {
    final refused = await answer;
    if (!mounted || !_driverSession.isGoingOnline) {
      return false;
    }
    if (refused == null) {
      return true;
    }
    await _goOffline(notice: false);
    // Driver group 3: a permanent reason card, not a 6 s snackbar.
    _HomeOnlineGate(this)._showServerRefusal(refused);
    return false;
  }

  /// Offline on the server too; Home goes offline either way (the feed
  /// closes at once), and a refusal is shown.
  void _tellServerOffline() {
    final answer = LiveDriverServices.instance?.presence.goOffline();
    if (answer == null) {
      return;
    }
    unawaited(
      answer.then((refused) {
        if (refused != null) {
          _showLiveProblem(refused);
        }
      }),
    );
  }

  void _showLiveProblem(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
