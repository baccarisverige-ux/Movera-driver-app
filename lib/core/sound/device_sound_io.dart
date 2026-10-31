import 'package:flutter/services.dart';
import 'package:movera/core/sound/phone_sound.dart';

/// Android and iOS: one system vibration ([pattern] is the web's).
void deviceVibrate(List<int> pattern) {
  HapticFeedback.vibrate();
}

/// The phone's ringer, from the native side of a store build
/// (`movera/phone_sound`, method `state` → `{silent, volume}`, volume
/// 0–1). Until a store build answers it, nothing is known: no notice.
const MethodChannel phoneSoundChannel = MethodChannel('movera/phone_sound');

/// Below this share of the full volume the phone counts as "very low".
const double lowVolume = 0.15;

Future<PhoneSound> deviceSoundState() async {
  try {
    final state = await phoneSoundChannel.invokeMapMethod<String, Object?>(
      'state',
    );
    if (state == null) return PhoneSound.unknown;
    final volume = state['volume'];
    if (state['silent'] == true || (volume is num && volume < lowVolume)) {
      return PhoneSound.off;
    }
    return PhoneSound.on;
  } on MissingPluginException {
    return PhoneSound.unknown;
  } on PlatformException {
    return PhoneSound.unknown;
  }
}
