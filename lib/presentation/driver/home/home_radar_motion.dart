part of 'home.dart';

/// P7-D1 (owner decision 2026-10-27): the Radar pulse, sweep and motion run
/// only while the driver is online or going online. Offline, on hold or
/// with an account that is not active the orb stands still, so an idle
/// Home schedules no frames.
extension _HomeRadarMotion on _DriverHomeState {
  void _syncRadarAnimation({bool checkMotion = true}) {
    final scanning = _driverSession.availableForOffers || _isGoingOnline;
    final run =
        scanning &&
        _liveVisible &&
        !(checkMotion && MediaQuery.disableAnimationsOf(context));
    if (!run) {
      _goOnlinePulseController.stop();
      _radarSweepController.stop();
      _radarMotionController.stop();
      if (!scanning) _goOnlinePulseController.value = 0;
      return;
    }
    if (!_goOnlinePulseController.isAnimating) {
      _goOnlinePulseController.repeat(reverse: true);
    }
    if (!_radarSweepController.isAnimating) _radarSweepController.repeat();
    if (!_radarMotionController.isAnimating) _radarMotionController.repeat();
  }
}
