part of 'home.dart';

// Offer rules on Home (Round 3): the driver's Cash switch in the Home
// sheet (Q23), and the row of missed Exclusive offers that takes the
// driver offline (Q16). Radar trips never count in that row.

extension _HomeOfferRules on _DriverHomeState {
    /// Cash rides off: no cash offers on Home.
    bool _paymentAllowed(_HomeDirectOffer offer) =>
        !offer.cash || DriverOfferPreferences.acceptsCash.value;

    /// A dispatch trip this driver gets now, in the Live list and the
    /// counts: cash only with cash rides on, and within the smart gap.
    bool _rideAllowed(RideOffer offer) =>
        (DriverOfferPreferences.acceptsCash.value ||
            !RadarOfferView.isCash(offer.payment)) &&
        _HomeScheduled(this)._rideFitsSchedule(offer);

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
      _rebuild(() => _pendingRadarHomeOffers.removeWhere((offer) => offer.cash));
      for (final offer in cash) {
        _HomeOfferRadar(this)._dismissRadarHomeOffer(offer);
      }
      if (_outsideRadarOffer?.cash ?? false) {
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
        unawaited(_goOffline());
        return;
      }
      if (answers.lastBeforeOffline()) {
        IslandMessages.show(HomeIslandNotices.lastMissedBeforeOffline);
      }
    }
}
