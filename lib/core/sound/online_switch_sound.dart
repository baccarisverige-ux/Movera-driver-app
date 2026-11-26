import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/app_tones.dart';
import 'package:movera/core/sound/offer_alert.dart';
import 'package:movera/core/sound/phone_sound.dart';

/// Owner 2026-11-26: a short sound when the driver goes online
/// (`assets/sounds/radar_on.mp3`) and offline (`radar_off.mp3`), with a
/// light haptic. The owner's chosen sound (Pixabay "notification center",
/// Pixabay content licence); offline is the same, lower pitch. Quiet while the
/// phone is on silent (or very low) and while the driver's Sound & voice
/// "General volume" is at 0; the haptic follows his Vibration setting.
abstract final class OnlineSwitchSound {
  static const String online = 'sounds/radar_on.mp3';
  static const String offline = 'sounds/radar_off.mp3';

  /// Tests see what plays here instead of the device (`sound:<asset>`,
  /// `haptic`).
  @visibleForTesting
  static void Function(String what)? debugAlert;

  @visibleForTesting
  static SettingsRepository Function()? debugSettings;

  static TonePlayer? _player;

  static Future<void> wentOnline() => _play(online);
  static Future<void> wentOffline() => _play(offline);

  static Future<void> _play(String asset) async {
    if (OfferAlertSettings.vibrate.value) {
      _do('haptic', () => unawaited(HapticFeedback.lightImpact()));
    }
    try {
      if (await PhoneSoundCheck.read() == PhoneSound.off) return;
      if (!await _soundOn()) return;
    } catch (_) {
      return;
    }
    _do('sound:$asset', () {
      // Like the radar offer sound: machines without a sound device
      // (integration tests) turn the radar sounds off.
      if (!DriverRuntimeConfig.current.radarSound) return;
      unawaited(
        (_player ??= AppTones.create())
            .playOnce(asset)
            .catchError((Object _) {}),
      );
    });
  }

  /// Sound & voice › General volume above 0 (on when never saved).
  static Future<bool> _soundOn() async {
    try {
      final data = await (debugSettings?.call() ?? SettingsRepository()).read(
        'sound',
      );
      final volume = data['generalVolume'];
      return volume is! num || volume > 0;
    } catch (_) {
      return true;
    }
  }

  static void _do(String what, void Function() device) {
    final debug = debugAlert;
    if (debug != null) {
      debug(what);
      return;
    }
    try {
      device();
    } catch (_) {
      // No sound on this device: the switch still happened.
    }
  }

  @visibleForTesting
  static void debugReset() {
    _player = null;
    debugAlert = null;
    debugSettings = null;
  }
}
