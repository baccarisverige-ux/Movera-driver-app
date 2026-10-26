part of 'home.dart';

// R15-5: the radar sound while Radar offers are on Home.
extension _HomeOfferSound on _DriverHomeState {
  /// After each Home frame: the Radar offers the driver can take now.
  /// Exclusive, a reservation request, or Home hidden keep it quiet.
  void _syncOfferSound() {
    if (_offerSoundQueued) {
      return;
    }
    _offerSoundQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offerSoundQueued = false;
      if (!mounted) {
        return;
      }
      if (!_liveVisible ||
          !_isOnline ||
          _outsideRadarOffer != null ||
          _HomeReservation(this)._reservationUp) {
        _offerSound.silence();
        return;
      }
      _offerSound.sync([
        for (final offer in _radarHomeOffers)
          if (_HomeOfferRadar(this)._homeRadarStateFor(offer.id) ==
                  _HomeRadarMatchState.available &&
              !_radarOfferExpired.contains(offer.id))
            offer.id,
      ]);
    });
  }
}
