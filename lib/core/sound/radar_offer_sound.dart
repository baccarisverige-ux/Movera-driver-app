import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

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

/// R15-5: the radar sound while Radar offers are on Home.
///
/// It starts when an offer the driver has not heard yet shows, and stops
/// when no offers are left, when the driver taps Match, or on any tap on
/// the screen ([silence]). A new offer after that starts it again.
class RadarOfferSound {
  RadarOfferSound({RadarSoundPlayer? player})
      : _ownsPlayer = player == null && debugPlayer == null,
        _player = player ??
            debugPlayer ??
            (DriverRuntimeConfig.current.radarSound
                ? AudioRadarSound()
                : _SilentSound());

  /// Tests put a fake player here.
  @visibleForTesting
  static RadarSoundPlayer? debugPlayer;

  final RadarSoundPlayer _player;
  final bool _ownsPlayer;
  final Set<String> _heard = <String>{};
  bool _playing = false;

  bool get playing => _playing;

  /// [ids]: the Radar offers on Home now (empty: none, or covered).
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
      unawaited(_player.prime().catchError((Object _) {}));
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
  Future<void> _then(Future<void> Function(AudioPlayer audio) op,
      {bool create = true}) {
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
        await audio.play(_sound);
        await audio.stop();
        await audio.setVolume(1);
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
