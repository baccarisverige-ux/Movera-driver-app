import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/logging/driver_log.dart';

/// App-lifecycle audit 2026-11-20 item 2: the screen stays on while a trip
/// is active (heading to pickup, at pickup, in trip) and only then. Each
/// trip screen holds it; the screen may sleep again once none does. The
/// phone side is `MainActivity` (FLAG_KEEP_SCREEN_ON) and `AppDelegate`
/// (idle timer off): no plugin and no permission (a window flag is not a
/// WAKE_LOCK).
class ScreenAwake {
  ScreenAwake({MethodChannel? channel, bool Function()? supported})
    : _channel = channel ?? const MethodChannel(channelName),
      _supported =
          supported ??
          (() =>
              !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS));

  static const String channelName = 'se.movera.driver/screen';

  static ScreenAwake instance = ScreenAwake();

  final MethodChannel _channel;
  final bool Function() _supported;
  final Set<Object> _holders = <Object>{};
  bool? _sent;

  /// Whether some trip screen holds the screen on now.
  bool get on => _holders.isNotEmpty;

  /// [owner] wants the screen on ([keep]) or no longer.
  void hold(Object owner, {required bool keep}) {
    if (keep) {
      _holders.add(owner);
    } else {
      _holders.remove(owner);
    }
    _apply();
  }

  void release(Object owner) => hold(owner, keep: false);

  void _apply() {
    final want = on;
    if (_sent == want || !_supported()) return;
    _sent = want;
    _channel.invokeMethod<void>('keepOn', want).catchError((Object error) {
      // An old build without the channel: the trip goes on.
      DriverLog.warn('screen keep-on failed: $error');
      _sent = null;
    });
  }
}
