import 'package:flutter/foundation.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/phone_sound.dart';

import 'package:movera/core/sound/device_sound_io.dart'
    if (dart.library.js_interop) 'package:movera/core/sound/device_sound_web.dart';

/// G4 decision 1 + E6 (owner "Sound + vibration", contract v0.18.6
/// `driverOffers.push.rule`): Exclusive and hand-sent (assigned) offers
/// play the Movera offer sound and vibrate (vibration only while the
/// driver's own Vibrate setting is on), in the app and in the push; Radar
/// offers stay quiet. The same in SE and FR.
abstract final class OfferAlertRule {
  /// `driverOffers.push.sound` / `vibrate`: true for an offer that rings.
  static bool loud(OfferKind? kind) =>
      kind == OfferKind.exclusive || kind == OfferKind.assigned;

  /// The same rule for a push's `offerKind` (FCM data, a string).
  static bool loudWire(String? offerKind) =>
      loud(OfferKind.fromWire(offerKind));

  /// `driverOffers.push.native.webVibratePattern`, in ms.
  static const List<int> vibratePattern = <int>[300, 150, 300];
}

/// The driver's own Vibrate setting (Settings › Accessibility, "Vibration
/// for requests", kept on this phone): the offer alert and the web push
/// vibrate only while it is on (G4-E6).
abstract final class OfferAlertSettings {
  /// Owner 2026-10-31: on for every driver until he turns it off.
  static final ValueNotifier<bool> vibrate = ValueNotifier<bool>(true);

  /// Reads the saved setting (on when there is none).
  static Future<void> restore({SettingsRepository? repository}) async {
    try {
      final data = await (repository ?? SettingsRepository()).read(
        'accessibility',
      );
      vibrate.value = data['vibration'] != false;
    } catch (_) {
      // Unreadable settings: keep what is known.
    }
  }

  /// Sign-out: the next driver starts with the default (on).
  static void reset() => vibrate.value = true;
}

/// One vibration for an offer that rings, only with the setting on.
abstract final class OfferVibration {
  /// Tests see the vibrations here instead of the device.
  @visibleForTesting
  static void Function(List<int> pattern)? debugVibrate;

  /// True when it vibrated.
  static bool forNewOffer() {
    if (!OfferAlertSettings.vibrate.value) return false;
    try {
      (debugVibrate ?? deviceVibrate)(OfferAlertRule.vibratePattern);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// G4 decision 2: is the phone's sound off right now? See [PhoneSound].
abstract final class PhoneSoundCheck {
  /// Tests answer here instead of the device.
  @visibleForTesting
  static Future<PhoneSound> Function()? debugRead;

  static Future<PhoneSound> read() async {
    try {
      return await (debugRead ?? deviceSoundState)();
    } catch (_) {
      return PhoneSound.unknown;
    }
  }
}
