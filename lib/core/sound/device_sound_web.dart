import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:movera/core/sound/phone_sound.dart';
import 'package:web/web.dart' as web;

/// The web build: `navigator.vibrate(pattern)` (Android browsers; iPhone
/// Safari has no vibration and ignores it).
void deviceVibrate(List<int> pattern) {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('vibrate')) return;
  navigator.vibrate([for (final ms in pattern) ms.toJS].toJS);
}

/// A browser cannot read the phone's ringer or volume. What it can tell:
/// it plays no sound at all until the driver has tapped the page once
/// (`navigator.userActivation`); until then offers ring silently.
Future<PhoneSound> deviceSoundState() async {
  try {
    final navigator = web.window.navigator;
    if (!(navigator as JSObject).has('userActivation')) {
      return PhoneSound.unknown;
    }
    return navigator.userActivation.hasBeenActive
        ? PhoneSound.on
        : PhoneSound.off;
  } catch (_) {
    return PhoneSound.unknown;
  }
}
