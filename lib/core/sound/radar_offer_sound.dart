import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

// Home reads the offer alert (G4-E6) and the phone's sound (decision 2)
// through this file.
export 'package:movera/core/sound/offer_alert.dart';
export 'package:movera/core/sound/phone_sound.dart';

/// Plays the radar sound again and again while it runs.
abstract class RadarSoundPlayer {
  Future<void> startLoop();
  Future<void> stop();

  /// Unlocks sound during a tap: phones' browsers play sound only after
  /// one has started inside a tap.
  Future<void> prime() async {}

  /// Releases the native player (D-17). Nothing plays after it.
  Future<void> dispose() async {}
}

/// The Movera offer sound on Home (the owner's sound,
/// assets/sounds/radar_offer.mp3), looped while an offer that rings is up.
///
/// G4-E6 (owner "Sound + vibration", contract v0.18.6
/// `driverOffers.push.rule`): it rings for Exclusive and hand-sent
/// (assigned) offers; Radar offers stay quiet (until v0.18.6 it rang for
/// Radar offers, R15-5). Home decides which offers ring
/// (`home_offer_sound.dart`).
///
/// It starts when an offer the driver has not heard yet shows, and stops
/// when no offers are left, when the driver accepts, or on any tap on the
/// screen ([silence]). A new offer after that starts it again; each new
/// offer also calls [onNewOffer] (the vibration).
class RadarOfferSound {
  RadarOfferSound({RadarSoundPlayer? player, this.onNewOffer})
    : _ownsPlayer = player == null && debugPlayer == null,
      _player =
          player ??
          debugPlayer ??
          debugCreate?.call() ??
          (DriverRuntimeConfig.current.radarSound
              ? AudioRadarSound()
              : _SilentSound());

  /// Tests put a fake player here.
  @visibleForTesting
  static RadarSoundPlayer? debugPlayer;

  /// Tests make the sound's own player here; it is released on [dispose].
  @visibleForTesting
  static RadarSoundPlayer Function()? debugCreate;

  final RadarSoundPlayer _player;
  final bool _ownsPlayer;

  /// Called once for each offer heard for the first time.
  final void Function()? onNewOffer;
  final Set<String> _heard = <String>{};
  bool _playing = false;

  bool get playing => _playing;

  /// [ids]: the offers that ring on Home now (empty: none, or covered).
  void sync(Iterable<String> ids) {
    final now = ids.toSet();
    _heard.retainAll(now);
    if (now.isEmpty) {
      _set(false);
      return;
    }
    if (!now.every(_heard.contains)) {
      _heard.addAll(now);
      _set(true);
      onNewOffer?.call();
    }
  }

  /// Match, or a tap anywhere: quiet until a new offer comes.
  void silence() => _set(false);

  bool _primed = false;

  /// A tap on Home: quiet, and (once) unlock sound for later offers.
  void tap() {
    silence();
    if (!_primed) {
      _primed = true;
      // driver-u49: a refused prime (no user activation yet) is tried
      // again on the next tap.
      unawaited(_player.prime().catchError((Object _) => _primed = false));
    }
  }

  void dispose() {
    _set(false);
    _heard.clear();
    if (_ownsPlayer) {
      unawaited(_player.dispose().catchError((Object _) {}));
    }
  }

  void _set(bool on) {
    if (_playing == on) {
      return;
    }
    _playing = on;
    unawaited(
      (on ? _player.startLoop() : _player.stop()).catchError((Object _) {}),
    );
  }
}

class _SilentSound implements RadarSoundPlayer {
  @override
  Future<void> startLoop() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> prime() async {}
  @override
  Future<void> dispose() async {}
}

/// The owner's radar sound (assets/sounds/radar_offer.mp3), looped.
///
/// D-17: each call waits for the one before it, so the silent [prime]
/// (volume 0, play, stop, volume 1) never mixes with [startLoop], and
/// [dispose] releases the native player once the calls before it ran.
class AudioRadarSound implements RadarSoundPlayer {
  AudioRadarSound({@visibleForTesting AudioPlayer Function()? create})
    : _create = create ?? AudioPlayer.new;

  final AudioPlayer Function() _create;
  AudioPlayer? _audio;
  bool _closed = false;
  Future<void> _queue = Future<void>.value();

  /// Runs [op] after every call before it; skipped once disposed.
  Future<void> _then(
    Future<void> Function(AudioPlayer audio) op, {
    bool create = true,
  }) {
    final next = _queue.then((_) async {
      if (_closed) return;
      final audio = create ? (_audio ??= _create()) : _audio;
      if (audio != null) await op(audio);
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  static final Source _sound = AssetSource('sounds/radar_offer.mp3');

  @override
  Future<void> startLoop() => _then((audio) async {
    await audio.setReleaseMode(ReleaseMode.loop);
    await audio.play(_sound);
  });

  @override
  Future<void> stop() => _then((audio) => audio.stop(), create: false);

  @override
  Future<void> prime() => _then((audio) async {
    await audio.setVolume(0);
    try {
      await audio.play(_sound);
      await audio.stop();
    } finally {
      // driver-u49: a refused play must not leave the player muted.
      await audio.setVolume(1);
    }
  });

  @override
  Future<void> dispose() {
    final last = _queue.then((_) async {
      final audio = _audio;
      _audio = null;
      await audio?.dispose();
    });
    _closed = true;
    _queue = last.catchError((Object _) {});
    return last;
  }
}
