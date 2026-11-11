import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D14-7: Android 13+ shows the "Movera is online" notice (G3 decision 1)
/// only once POST_NOTIFICATIONS is allowed. Nothing else asks for it on a
/// phone (no native push yet), so Go online asks the system once per
/// install through `MainActivity` (no extra plugin).
class NotificationPermission {
  NotificationPermission({MethodChannel? channel, bool Function()? isAndroid})
    : _channel = channel ?? const MethodChannel(channelName),
      _isAndroid =
          isAndroid ??
          (() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const String channelName = 'se.movera.driver/notifications';
  static const String askedPref = 'd14_notifications_asked';

  static NotificationPermission instance = NotificationPermission();

  final MethodChannel _channel;
  final bool Function() _isAndroid;

  /// Asks once on Android 13+ (the native side answers true at once on
  /// older Android, where nothing needs asking). True when allowed.
  Future<bool> requestOnce() async {
    if (!_isAndroid()) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedPref) ?? false) return false;
      await prefs.setBool(askedPref, true);
      return await _channel.invokeMethod<bool>('request') ?? false;
    } catch (_) {
      // An old build without the channel: going online goes on.
      return false;
    }
  }
}
