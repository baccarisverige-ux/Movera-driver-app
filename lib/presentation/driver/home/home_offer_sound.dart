part of 'home.dart';

// G4-E6 (owner "Sound + vibration", contract v0.18.6
// `driverOffers.push.rule`): the Movera offer sound (and one vibration
// while the driver's Vibrate setting is on) for an Exclusive or hand-sent
// offer on Home. Radar offers and reservations stay quiet (until v0.18.6
// the sound rang for Radar offers, R15-5).
extension _HomeOfferSound on _DriverHomeState {
  /// After each Home frame: the offer that rings now, if any. Home hidden,
  /// offline, a reservation request up, or the Accept sent keep it quiet.
  void _syncOfferSound() {
    // G4 decision 2: the "Sound is off" checks follow Home too.
    _HomeSoundNotice(this)._syncSoundNotice();
    if (_offerSoundQueued) {
      return;
    }
    _offerSoundQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offerSoundQueued = false;
      if (!mounted) {
        return;
      }
      final up = _outsideRadarOffer;
      if (!_liveVisible ||
          !_isOnline ||
          up == null ||
          _exclusive.leaving ||
          _HomeExclusive(this)._exclusiveClaiming ||
          _HomeReservation(this)._reservationUp ||
          !_ringsOnHome(up)) {
        if (up == null) {
          // No offer left: quiet, and a next one rings again.
          _offerSound.sync(const <String>[]);
        } else {
          _offerSound.silence();
        }
        return;
      }
      _offerSound.sync([up.id]);
    });
  }

  /// E6: an Exclusive or hand-sent offer rings; a reservation close to
  /// pickup (kind `reservation`) and a ride Movera assigned for later
  /// stay quiet like Radar.
  bool _ringsOnHome(_HomeDirectOffer offer) =>
      !offer.reservation && !offer.assigned;
}

// G4 decision 2 (owner "Notification on top of screen"): online with the
// phone's sound off (silent, very low, or a browser that plays nothing
// before a tap), a notice at the top of Home: "Sound is off – you may miss
// offers". The text is the app's own (sv / fr / en; contract v0.18.6 has
// none). On the web a tap on the page allows sound, so a tap on the notice
// (any tap on Home) fixes it and it goes.
/// G4 decision 2: the phone's sound is off while online, and the timer
/// that looks at it.
class _SoundNoticeState {
  bool off = false;
  Timer? timer;
}

final Expando<_SoundNoticeState> _soundNotices = Expando<_SoundNoticeState>();

extension _HomeSoundNotice on _DriverHomeState {
  _SoundNoticeState get _soundNotice =>
      _soundNotices[this] ??= _SoundNoticeState();

  /// Home is going: no more checks, and the offer sound is released.
  void _disposeSound() {
    _soundNotice.timer?.cancel();
    _offerSound.dispose();
  }

  /// G4-E6: the offer sound, and one vibration per new ringing offer while
  /// the driver's Vibrate setting is on.
  static RadarOfferSound newOfferSound() =>
      RadarOfferSound(onNewOffer: OfferVibration.forNewOffer);

  /// Any tap on Home stops the offer sound (R15-5, G4-E6) and, on the web,
  /// allows sound (decision 2).
  void _homeTapped() {
    _offerSound.tap();
    _soundNoticeTapped();
  }

  /// How often the phone's sound is looked at while online on Home.
  static const Duration every = Duration(seconds: 10);

  /// After each Home build: checks run only while online and on screen.
  void _syncSoundNotice() {
    final wanted = _isOnline && _liveVisible;
    if (!wanted) {
      _soundNotice.timer?.cancel();
      _soundNotice.timer = null;
      if (_soundNotice.off) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _soundNotice.off && !(_isOnline && _liveVisible)) {
            _rebuild(() => _soundNotice.off = false);
          }
        });
      }
      return;
    }
    if (_soundNotice.timer != null) return;
    _soundNotice.timer = Timer.periodic(every, (_) => _checkPhoneSound());
    unawaited(_checkPhoneSound());
  }

  Future<void> _checkPhoneSound() async {
    final sound = await PhoneSoundCheck.read();
    if (!mounted) return;
    final off = sound == PhoneSound.off && _isOnline && _liveVisible;
    if (off != _soundNotice.off) {
      _rebuild(() => _soundNotice.off = off);
    }
  }

  /// A tap on Home: on the web it allows sound, so look again at once.
  void _soundNoticeTapped() {
    if (_soundNotice.off) {
      Timer(const Duration(milliseconds: 250), () {
        if (mounted) unawaited(_checkPhoneSound());
      });
    }
  }

  /// The notice under the island, while the sheet is down; nothing while
  /// the sound is on.
  Widget _soundNoticeLayer() {
    if (!_soundNotice.off) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }
    final top =
        math.max(MediaQuery.paddingOf(context).top - 4, 10.0) +
        DigitalIslandParts.height * _islandScale +
        10;
    return Positioned(
      key: const ValueKey<String>('home-sound-off-slot'),
      left: 16,
      right: 16,
      top: top,
      child: ValueListenableBuilder<double>(
        valueListenable: _panelSlidePosition,
        builder: (context, position, child) =>
            position > 0.05 ? const SizedBox.shrink() : child!,
        child: PointerInterceptor(
          child: Center(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                key: const ValueKey<String>('home-sound-off-notice'),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2329),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.volume_off_rounded,
                      size: 20,
                      color: Color(0xFFFFB84D),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.soundOffNotice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          if (kIsWeb)
                            Text(
                              tr.soundOffTapToAllow,
                              style: const TextStyle(
                                color: Color(0xFFB9C3C9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
