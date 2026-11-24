import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:movera/core/push/native_push_platform.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';

/// BQ-V43: the real [NativePushGateway] (FlutterFire). Started only from
/// the server's public settings, never from a file in the app.
class FirebasePushGateway implements NativePushGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> start(PushWebConfig settings) async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: settings.apiKey,
        appId: settings.appId,
        messagingSenderId: settings.messagingSenderId,
        projectId: settings.projectId,
        iosBundleId: settings.iosBundleId,
      ),
    );
    if (_isIos) {
      // v0.18.160: a push that comes while the app is open is not shown
      // (the offer stream and the bell list show it), as on Android.
      await _messaging.setForegroundNotificationPresentationOptions();
    }
  }

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// v0.18.160: on iOS FCM gives a token only once APNs gave this phone
  /// its own token (right after the permission); wait for it a little.
  Future<void> _apnsReady() async {
    if (!_isIos) return;
    for (var i = 0; i < 10; i++) {
      if (await _messaging.getAPNSToken() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<String> permission() async =>
      _status((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<bool> requestPermission() async {
    // iOS: alert, sound and badge (the defaults); Android 13+: the system
    // notification permission.
    final settings = await _messaging.requestPermission();
    return _status(settings.authorizationStatus) == 'granted';
  }

  static String _status(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => 'granted',
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => 'denied',
    AuthorizationStatus.notDetermined => 'default',
  };

  @override
  Future<String?> token() async {
    await _apnsReady();
    final token = await _messaging.getToken();
    return token == null || token.isEmpty ? null : token;
  }

  @override
  Future<PushOpen?> initialOpen() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _open(message);
  }

  @override
  Stream<PushOpen> get onOpened => FirebaseMessaging.onMessageOpenedApp
      .map(_open)
      .where((open) => open != null)
      .cast<PushOpen>();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Contract `auth.devices.sending.data` / `driverOffers.push.data`.
  static PushOpen? _open(RemoteMessage message) {
    final id = message.data['notificationId'];
    if (id is! String || id.isEmpty) return null;
    final link = message.data['deepLink'];
    return PushOpen(
      notificationId: id,
      deepLink: link is String && link.isNotEmpty ? link : null,
    );
  }
}
