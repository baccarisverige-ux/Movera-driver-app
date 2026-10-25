part of 'accept_ride.dart';

/// A live build (`MOVERA_AUTH_REQUIRED`): each trip step is the server's
/// command first (`POST /trips/{tripId}/arrive`, `board` + `start`,
/// `complete`, `no-show`, `cancel`), and the screen moves only once the
/// server took it. A refusal or no connection is shown to the driver and
/// the trip stays where it was. The demo has no [LiveDriverServices]: every
/// step there is local, as before.
extension _AcceptRideLive on _AcceptRideState {
  LiveTripCommands? get _liveTrips => LiveDriverServices.instance?.trips;

  /// The trip screen opened on an accepted trip: on the way to the pickup.
  void _beginLiveTrip() {
    final trips = _liveTrips;
    if (trips == null) { return; }
    unawaited(trips.begin(widget.tripId));
  }

  /// True when the step may go on here: the server recorded it (or this is
  /// the demo; call sites only await it in a live build, so the demo's
  /// steps stay synchronous). Otherwise the driver reads why.
  Future<bool> _serverStep(Future<LiveTripOutcome> Function(LiveTripCommands trips) step) async {
    final trips = _liveTrips;
    if (trips == null) { return true; }
    final LiveTripOutcome outcome;
    try {
      outcome = await step(trips);
    } catch (error, stack) {
      DriverLog.error('Trip step failed', error, stack);
      _showServerRefusal(liveTripErrorMessage(error));
      return false;
    }
    if (outcome.ok) { return true; }
    _showServerRefusal(outcome.message!);
    return false;
  }

  void _showServerRefusal(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _AcceptRideState._ink,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }
}
