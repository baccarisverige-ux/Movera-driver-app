import 'package:firebase_core/firebase_core.dart';
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
      ),
    );
  }

  @override
  Future<String> permission() async =>
      _status((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<bool> requestPermission() async {
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
