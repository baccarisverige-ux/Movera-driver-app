import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the registrar keeps its two small facts on this device.
abstract class PushStore {
  Future<bool> explained();
  Future<void> setExplained();
  Future<String?> token();
  Future<void> setToken(String? token);
}

class PrefsPushStore implements PushStore {
  static const _explained = 'push.explained';
  static const _token = 'push.token';

  @override
  Future<bool> explained() async =>
      (await SharedPreferences.getInstance()).getBool(_explained) ?? false;

  @override
  Future<void> setExplained() async =>
      (await SharedPreferences.getInstance()).setBool(_explained, true);

  @override
  Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_token);

  @override
  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_token);
    } else {
      await prefs.setString(_token, token);
    }
  }
}

/// The calls the registrar makes (contract §8 and v0.18.3 R7).
abstract class PushApi {
  Future<PushConfig> config();
  Future<void> register(String token, String platform);
  Future<void> unregister(String token);
}

class ApiPushApi implements PushApi {
  ApiPushApi(this._api, {required this.app, this.appVersion, this.locale});

  static const configPath = '/api/v1/push/config';
  static const registerPath = '/api/v1/push/devices';
  static const unregisterPath = '/api/v1/push/devices/unregister';
  static final _version = RegExp(r'^\d+\.\d+\.\d+$');

  final ApiClient _api;
  final String app;
  final String? appVersion;
  final String Function()? locale;

  @override
  Future<PushConfig> config() async => PushConfig.fromJson(
    await _api.get('$configPath?app=$app', authenticated: false),
  );

  @override
  Future<void> register(String token, String platform) async {
    final version = appVersion;
    final language = locale?.call();
    await _api.post(
      registerPath,
      body: {
        'token': token,
        'provider': 'fcm',
        'platform': platform,
        if (version != null && _version.hasMatch(version))
          'appVersion': version,
        if (language != null && const {'sv', 'fr', 'en'}.contains(language))
          'locale': language,
      },
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _api.post(unregisterPath, body: {'token': token});
  }
}

/// Contract v0.18.3 `auth.devices.appFlow` (owner decision R7): after
/// sign-in the app explains why (sv / fr / en), the system asks once, the
/// FCM token is registered with `POST /push/devices`, registered again when
/// it changes, and unregistered on sign-out. Nothing here ever throws into
/// the app: push is a bonus, the bell list stays the source.
class PushRegistrar {
  PushRegistrar({
    required this.platform,
    required this.api,
    required this.store,
    required this.explain,
  });

  final PushPlatform platform;
  final PushApi api;
  final PushStore store;

  /// Shows the short explanation; true when the driver wants push.
  final Future<bool> Function() explain;

  Future<void>? _running;

  /// After every sign-in and app start with a session. Returns the token
  /// registered, or null.
  Future<String?> signedIn() async {
    final previous = _running;
    if (previous != null) await previous;
    final run = _signedIn();
    _running = run;
    try {
      return await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<String?> _signedIn() async {
    try {
      if (!platform.supported) return null;
      final config = await api.config();
      final web = config.webConfig;
      if (!config.enabled || web == null) return null;
      final permission = await platform.permission();
      if (permission == 'denied') return null;
      if (permission != 'granted') {
        if (await store.explained()) return null;
        await store.setExplained();
        if (!await explain()) return null;
        if (!await platform.requestPermission()) return null;
      }
      final token = await platform.token(web);
      if (token == null) return null;
      final old = await store.token();
      if (old != null && old != token) {
        try {
          await api.unregister(old);
        } catch (_) {
          // The server forgets a dead token on its own.
        }
      }
      await api.register(token, platform.platformName);
      await store.setToken(token);
      return token;
    } catch (error) {
      DriverLog.warn('push not set up: ${error.runtimeType}', name: 'push');
      return null;
    }
  }

  /// Before the session ends: forget this device's token on the server.
  Future<void> signingOut() async {
    try {
      final token = await store.token();
      if (token == null) return;
      await store.setToken(null);
      await api.unregister(token);
    } catch (error) {
      DriverLog.warn(
        'push not unregistered: ${error.runtimeType}',
        name: 'push',
      );
    }
  }
}
