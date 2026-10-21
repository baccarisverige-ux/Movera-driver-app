part of 'home.dart';

// Offer rules on Home (Round 3): the driver's Cash switch in the Home
// sheet (Q23), the categories the driver drives (Q27), and the row of
// missed Exclusive offers that takes the driver offline (Q16). Radar trips
// never count in that row.

extension _HomeOfferRules on _DriverHomeState {
    /// An offer on Home: no cash offers with cash rides off, and only the
    /// categories this driver drives.
    bool _offerAllowed(_HomeDirectOffer offer) =>
        (!offer.cash || DriverOfferPreferences.acceptsCash.value) &&
        DriverCategoryChoice.takes(offer.category);

    /// A dispatch trip this driver gets now, in the Live list and the
    /// counts: cash only with cash rides on, in a category the driver
    /// drives, and within the smart gap.
    bool _rideAllowed(RideOffer offer) =>
        (DriverOfferPreferences.acceptsCash.value ||
            !RadarOfferView.isCash(offer.payment)) &&
        DriverCategoryChoice.takes(offer.category) &&
        _HomeScheduled(this)._rideFitsSchedule(offer);

    /// Ride preferences changed (Q27): offers of a category switched off
    /// leave Home.
    void _onCategoriesChanged() {
      if (!mounted) { return; }
      ScheduledRideStore.categoriesChanged();
      bool off(_HomeDirectOffer offer) =>
          !DriverCategoryChoice.takes(offer.category);
      final gone = _radarHomeOffers.where(off).toList();
      _rebuild(() {
        _pendingRadarHomeOffers.removeWhere(off);
        _hasRideOffers =
            _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty;
      });
      for (final offer in gone) {
        _HomeOfferRadar(this)._dismissRadarHomeOffer(offer);
      }
      // An Exclusive offer whose Accept is with dispatch stays: its
      // answer decides, and a won trip is never dropped (driver-u140).
      if (_outsideRadarOffer case final offer?
          when off(offer) && !_HomeExclusive(this)._exclusiveClaiming) {
        _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      }
    }

    /// The Cash switch in the Home sheet. Off: cash trips on Home leave.
    void _setAcceptsCash(bool on) {
      if (DriverOfferPreferences.acceptsCash.value == on) { return; }
      DriverOfferPreferences.acceptsCash.value = on;
      IslandMessages.show(
        on ? HomeIslandNotices.cashOn : HomeIslandNotices.cashOff,
      );
      if (on) {
        _rebuild(() {});
        return;
      }
      final cash = _radarHomeOffers.where((offer) => offer.cash).toList();
      _rebuild(() {
        _pendingRadarHomeOffers.removeWhere((offer) => offer.cash);
        _hasRideOffers =
            _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty;
      });
      for (final offer in cash) {
        _HomeOfferRadar(this)._dismissRadarHomeOffer(offer);
      }
      if ((_outsideRadarOffer?.cash ?? false) &&
          !_HomeExclusive(this)._exclusiveClaiming) {
        _HomeOfferRadar(this)._dismissOutsideRadarOffer();
      }
    }

    /// An Exclusive offer went by without Accept. At the admin's number in
    /// a row the driver goes offline, with a notice on the island; one
    /// before it, the island warns.
    void _exclusiveMissed() {
      final answers = ExclusiveAnswers.instance;
      if (answers.missed()) {
        IslandMessages.show(HomeIslandNotices.offlineAfterMissed(
          DriverOfferRules.current.autoOfflineAfter,
        ));
        _forcedOffline();
        return;
      }
      if (answers.lastBeforeOffline()) {
        IslandMessages.show(HomeIslandNotices.lastMissedBeforeOffline);
      }
    }

    /// Decision 3 ("the accept wins"): a rule takes the driver offline
    /// (the driving limit, the row of missed Exclusive offers). With a
    /// Match or Accept with dispatch the app waits for its answer: won,
    /// the driver does that trip and is offline once it ends; lost,
    /// offline at once. Nothing dispatch gave this driver is dropped.
    void _forcedOffline() {
      if (_claimInFlight) {
        _offlineHeld = true;
        return;
      }
      unawaited(_goOffline());
    }

    /// The claim that held [_forcedOffline] back was answered.
    void _releaseHeldOffline() {
      if (!_offlineHeld || !mounted || _claimInFlight) { return; }
      if (_driverSession.activeTripId != null) {
        // Won: offline once this trip ends, like the driving limit on a
        // trip ([_drivingLimitReached]).
        _offlineHeld = false;
        _driverSession.setOnline(false);
        return;
      }
      // A won trip is opening over Home: its start settles this.
      if (ModalRoute.of(context)?.isCurrent == false) { return; }
      _offlineHeld = false;
      unawaited(_goOffline());
    }
}
