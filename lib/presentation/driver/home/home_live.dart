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
    final found = await live.activeTrip.fetch();
    if (found == null) return null;
    live.trips.observe(found.projection);
    return found.ride.stamped();
  }

  /// Asks the server to go online while the switch animates; null in the
  /// demo.
  Future<String?>? _askServerOnline() =>
      LiveDriverServices.instance?.presence.goOnline();

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
    _showLiveProblem(refused);
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
