part of 'home.dart';

// System Back on Home (UI-03). Home is the app's first route, so Back
// would leave the app. The overlays drawn in place on Home (the Radar
// list, the destination panel, an Exclusive offer, a reservation request
// and the Home sheet) are not routes; Back closes the one on top first,
// with the same rule as its own close control, and only leaves Home once
// none of them is up. The side menu is a drawer and closes itself.

extension _HomeBack on _DriverHomeState {
    /// The Home sheet (or the account-hold sheet) is raised.
    bool get _homeSheetRaised =>
        !showRideRequests &&
        !hideMainPanel &&
        _panelController.isAttached &&
        _panelSlidePosition.value > 0.02;

    /// An Exclusive offer is on screen and waiting for the driver.
    bool get _backSeesExclusive =>
        _outsideRadarOffer != null && !_exclusive.leaving;

    /// A reservation request sheet is up.
    bool get _backSeesReservation =>
        _reservation.request != null && _HomeReservation(this)._reservationUp;

    /// Something Back should close before it leaves Home.
    bool get _backHasOverlay =>
        showRideRequests ||
        hideMainPanel ||
        _backSeesExclusive ||
        _backSeesReservation ||
        _homeSheetRaised;

    /// Wraps Home so Back closes the top overlay first.
    Widget _backScope(Widget child) {
      return ValueListenableBuilder<double>(
        // The sheet moves without a rebuild of Home: follow its position.
        valueListenable: _panelSlidePosition,
        builder: (context, _, child) => PopScope(
          canPop: !_backHasOverlay,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) { _closeTopOverlay(); }
          },
          child: child!,
        ),
        child: child,
      );
    }

    /// "Unresolved trip": true resumes, false closes it. System Back
    /// does neither: the dialog stays until the driver picks one
    /// (driver-u113), since closing marks the saved trip as ended.
    Future<bool?> _askUnresolvedTrip(PersistedActiveRide snapshot) =>
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(tr.unresolvedTrip),
              content: Text(snapshot.hasVerifiedEndpoints
                  ? tr.thisSavedTripIsOlderThan
                  : tr.savedRouteCoordinatesAreUnavailableClose),
              actions: [
                TextButton(
                  onPressed: () => popOwned(context, false),
                  child: Text(tr.closeTrip),
                ),
                FilledButton(
                  onPressed: snapshot.hasVerifiedEndpoints
                      ? () => popOwned(context, true)
                      : null,
                  child: Text(tr.resumeTrip),
                ),
              ],
            ),
          ),
        );

    void _closeTopOverlay() {
      if (!mounted) { return; }
      final scaffold = _scaffoldKey.currentState;
      if (scaffold != null && scaffold.isDrawerOpen) {
        scaffold.closeDrawer();
        return;
      }
      if (showRideRequests) {
        // While its Match is being sent, Back waits (like the Exclusive's
        // Accept): the claim's answer must reach the Radar list.
        if (!_radarListClaiming.value) {
          _rebuild(() => showRideRequests = false);
        }
        return;
      }
      if (hideMainPanel) {
        if (_destinationPanelController.isAttached) {
          unawaited(_destinationPanelController.close());
        }
        _rebuild(() => hideMainPanel = false);
        return;
      }
      if (_backSeesExclusive) {
        // Same as its down arrow: skipped like a time out (Q16). While
        // Accept is being sent, Back waits like the arrow does.
        if (!_HomeExclusive(this)._exclusiveClaiming) {
          _HomeOfferRadar(this)._declineOutsideRadarOffer();
        }
        return;
      }
      if (_backSeesReservation) {
        // Same as its Decline: only hides the request.
        _HomeReservation(this)._hideHomeReservation();
        return;
      }
      if (_homeSheetRaised) {
        unawaited(_HomeMapSheet(this)._closeDriverSheet());
      }
    }
}
