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
}

/// R15-5: the radar sound while Radar offers are on Home.
///
/// It starts when an offer the driver has not heard yet shows, and stops
/// when no offers are left, when the driver taps Match, or on any tap on
/// the screen ([silence]). A new offer after that starts it again.
class RadarOfferSound {
  RadarOfferSound({RadarSoundPlayer? player})
      : _player = player ??
            debugPlayer ??
            (DriverRuntimeConfig.current.radarSound
                ? _AudioRadarSound()
                : _SilentSound());

  /// Tests put a fake player here.
  @visibleForTesting
  static RadarSoundPlayer? debugPlayer;

  final RadarSoundPlayer _player;
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
}

/// The owner's radar sound (assets/sounds/radar_offer.mp3), looped.
class _AudioRadarSound implements RadarSoundPlayer {
  AudioPlayer? _audio;

  @override
  Future<void> startLoop() async {
    final audio = _audio ??= AudioPlayer();
    await audio.setReleaseMode(ReleaseMode.loop);
    await audio.play(AssetSource('sounds/radar_offer.mp3'));
  }

  @override
  Future<void> stop() async {
    await _audio?.stop();
  }

  @override
  Future<void> prime() async {
    final audio = _audio ??= AudioPlayer();
    await audio.setVolume(0);
    await audio.play(AssetSource('sounds/radar_offer.mp3'));
    await audio.stop();
    await audio.setVolume(1);
  }
}
