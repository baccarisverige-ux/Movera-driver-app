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

// driver-r4-31: routes over Home. Only a full screen (a trip, a menu
// item: an opaque route, driver-r5-28) hides Home and pauses it; a sheet or a dialog leaves Home visible
// and online. Whatever waited for Home to be on top (a won trip, a held
// offline, a late scheduled ride) goes on when any route over it closes.
extension _HomeRoutes on _DriverHomeState {
    void _pageCovered() { _routeVisible = false; _pauseHomeUpdates(); }

    void _pageUncovered() {
      _routeVisible = true;
      _resumeHomeUpdates(); _HomeMapSheet(this)._adoptSessionDestination(); // driver-u65
      // A covering ride may have handed storage to a queued trip before it
      // closed. Re-check ownership so a persisted trip is never hidden behind
      // an available Home.
      if (_recoveryResolved && _driverSession.activeTripId == null) {
        _didAttemptActiveRideRestore = false;
        unawaited(_restoreActiveRideIfNeeded());
      }
      _backOnTop(); // what waited for Home on top goes on, as after a sheet
    }

    /// driver-r5-37: how long the "trip storage unavailable / Retry" bar
    /// stays up. With an action it would persist until swiped away, over
    /// the trip screen too.
    static const Duration storageRetryShown = Duration(seconds: 10);

    /// Its Retry reads the saved trip again only while Home is on top with
    /// no trip: during a trip it would read that trip's own snapshot and
    /// overwrite its waybill with placeholders.
    void _retryActiveRideRestore() {
      if (!mounted || !_routeVisible || _driverSession.activeTripId != null) { return; }
      unawaited(_restoreActiveRideIfNeeded());
    }

    /// A sheet or dialog over Home closed. After a full screen, the page
    /// observer's [_pageUncovered] (told next) resumes everything.
    void _backOnTop() {
      if (!mounted || !_routeVisible) { return; }
      if (_claimedHomeOffer != null) { _HomeOfferRadar(this)._openClaimedHomeOffer(); }
      _HomeOfferRules(this)._releaseHeldOffline();
      if (_isOnline) { _HomeScheduled(this)._planScheduled(); }
      _HomeMapSheet(this)._showNextIslandMessage();
    }
}
