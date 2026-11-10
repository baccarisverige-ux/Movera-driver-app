import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/offer_alert.dart';

import 'package:movera/core/chat/chat_speech_io.dart'
    if (dart.library.js_interop) 'package:movera/core/chat/chat_speech_web.dart';
import 'package:movera/core/sound/device_sound_io.dart'
    if (dart.library.js_interop) 'package:movera/core/sound/device_sound_web.dart';

/// Contract v0.18.56 §78 (G9-2.7, G9-2.9): what a new chat message from
/// the rider does on the trip screen: a short sound (admin `chat.sound`),
/// a vibration only while the driver's own Accessibility "Vibration" is
/// on, and, while "Read rider messages" (Settings › Sound & voice) is on,
/// the text read aloud in the app language (start value: admin
/// `readAloudDefault`).
abstract final class ChatMessageAlert {
  /// Tests see the alerts here instead of the device.
  @visibleForTesting
  static void Function(String what)? debugAlert;

  /// The vibration of a new message, in ms (web).
  static const List<int> vibratePattern = <int>[120];

  /// One alert for [text]; [sound] and [readAloudDefault] from the
  /// trip's chat options.
  static Future<void> forMessage(
    String text, {
    required bool sound,
    required bool readAloudDefault,
    SettingsRepository? repository,
  }) async {
    if (sound) _do('sound', () => SystemSound.play(SystemSoundType.alert));
    if (OfferAlertSettings.vibrate.value) {
      _do('vibrate', () => deviceVibrate(vibratePattern));
    }
    if (await readAloud(readAloudDefault, repository: repository)) {
      _do('speak:$text', () => deviceSpeak(text, DriverAppTexts.language));
    }
  }

  /// The driver's own switch, else the admin's start value.
  static Future<bool> readAloud(
    bool fallback, {
    SettingsRepository? repository,
  }) async {
    try {
      final data = await (repository ?? SettingsRepository()).read('sound');
      final own = data['readRiderMessages'];
      return own is bool ? own : fallback;
    } catch (_) {
      return fallback;
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
      // No sound / voice on this device: the card still shows.
    }
  }
}
