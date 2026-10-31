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
    if (trips == null) {
      return;
    }
    unawaited(trips.begin(widget.tripId));
  }

  /// True when the step may go on here: the server recorded it (or this is
  /// the demo; call sites only await it in a live build, so the demo's
  /// steps stay synchronous). Otherwise the driver reads why.
  Future<bool> _serverStep(
    Future<LiveTripOutcome> Function(LiveTripCommands trips) step,
  ) async {
    final trips = _liveTrips;
    if (trips == null) {
      return true;
    }
    final LiveTripOutcome outcome;
    try {
      outcome = await step(trips);
    } catch (error, stack) {
      DriverLog.error('Trip step failed', error, stack);
      _showServerRefusal(liveTripErrorMessage(error));
      return false;
    }
    if (outcome.ok) {
      // G5 live test: the answer's projection (after `arrive`: the
      // server's `waiting.freeUntil` / `noShowAt`) reaches the screen
      // here; its echo on the stream is this phone's own and is dropped.
      if (trips.projectionOf(widget.tripId) case final known?) {
        _AcceptRideTrip(this)._applyLive(TripLiveDetails.fromProjection(known));
      }
      return true;
    }
    _showServerRefusal(outcome.message!);
    return false;
  }

  /// The server's final money for this trip once it is completed (the
  /// answer to `complete`, or the completed event), else null: the demo,
  /// a projection without the money, or a trip not completed.
  LiveTripMoney? _settledMoney() {
    final projection = _liveTrips?.projectionOf(widget.tripId);
    if (projection == null || projection['status'] != 'completed') {
      return null;
    }
    return LiveTripMoney.tryParse(projection);
  }

  /// Owner N11 (live test 2026-10-26): a rider app that could not name its
  /// pickup sends the coordinates as the address ("59.195885, 17.597423").
  /// The trip then asks the server for the address at that point
  /// (`POST /locations/reverse-geocode`); the waybill, the trip and its
  /// save show it. A named address is never looked up; the demo has none.
  Future<void> _resolvePickupAddress() async {
    final places = LiveDriverServices.instance?.places;
    if (places == null || !LiveAddressLookup.unnamed(widget.pickupAddress)) {
      return;
    }
    final found = await places.reverseGeocode(
      _pickupPosition.latitude,
      _pickupPosition.longitude,
    );
    if (!mounted || found == null) {
      return;
    }
    _rebuild(() => _resolvedPickup = found);
    final current = _waybills.current;
    if (current != null && current.tripId == widget.tripId) {
      _waybills.beginCurrent(current.copyWith(pickup: found));
    }
    await _rideLifecycle.persistNow();
  }

  void _showServerRefusal(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AcceptRideState._ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
