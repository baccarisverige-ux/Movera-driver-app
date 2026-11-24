import 'dart:async';

import 'package:flutter/widgets.dart';
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
  /// [platform] `android` asks for the Android settings (v0.18.105),
  /// `ios` for the iOS ones (v0.18.156).
  Future<PushConfig> config({String platform = 'web'});
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
  Future<PushConfig> config({String platform = 'web'}) async =>
      PushConfig.fromJson(
        await _api.get(
          '$configPath?app=$app'
          '${platform == 'web' ? '' : '&platform=$platform'}',
          authenticated: false,
        ),
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
    void Function(void Function() callback)? whenResumed,
  }) : _whenResumed = whenResumed ?? _nextResume {
    platform.onTokenRefresh(_tokenChanged);
  }

  /// v0.18.156 (iOS): push was allowed but the phone had no token yet (the
  /// APNs token was not there after 5 s): try once more the next time the
  /// app comes to the foreground, while still signed in.
  final void Function(void Function() callback) _whenResumed;
  bool _active = false;
  bool _retryPending = false;

  static void _nextResume(void Function() callback) {
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        callback();
      },
    );
  }

  void _retryOnResume() {
    if (_retryPending) return;
    _retryPending = true;
    try {
      _whenResumed(() {
        _retryPending = false;
        if (_active) unawaited(signedIn());
      });
    } catch (_) {
      _retryPending = false;
    }
  }

  final PushPlatform platform;
  final PushApi api;
  final PushStore store;

  /// Shows the short explanation; true when the driver wants push.
  final Future<bool> Function() explain;

  Future<void>? _running;

  /// After every sign-in and app start with a session. Returns the token
  /// registered, or null.
  Future<String?> signedIn() async {
    _active = true;
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
      if (!platform.supported) {
        DriverLog.info(
          'push off on ${platform.platformName}: not supported here yet',
          name: 'push',
        );
        return null;
      }
      final config = await api.config(platform: platform.platformName);
      final web = platform.settingsFrom(config);
      if (!config.enabled || web == null) {
        DriverLog.info(
          'push off: the server has no ${platform.platformName} '
          'push settings',
          name: 'push',
        );
        return null;
      }
      if (!await platform.prepare(web)) return null;
      final permission = await platform.permission();
      if (permission == 'denied') return null;
      if (permission != 'granted') {
        if (await store.explained()) return null;
        await store.setExplained();
        if (!await explain()) return null;
        if (!await platform.requestPermission()) return null;
      }
      final token = await platform.token(web);
      if (token == null) {
        _retryOnResume();
        return null;
      }
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

  /// BQ-V43: FCM gave this phone a new token while signed in (a token is
  /// saved): the old one goes, the new one is registered.
  Future<void> _tokenChanged(String token) async {
    try {
      final old = await store.token();
      if (old == null || old == token || token.isEmpty) return;
      try {
        await api.unregister(old);
      } catch (_) {
        // The server forgets a dead token on its own.
      }
      await api.register(token, platform.platformName);
      await store.setToken(token);
    } catch (error) {
      DriverLog.warn(
        'push token not updated: ${error.runtimeType}',
        name: 'push',
      );
    }
  }

  /// Before the session ends: forget this device's token on the server.
  /// [server] false: the sign-out already removed the session's devices
  /// on the server (`POST /auth/sign-out`), only this phone forgets it.
  Future<void> signingOut({bool server = true}) async {
    _active = false;
    try {
      final token = await store.token();
      if (token == null) return;
      await store.setToken(null);
      if (server) await api.unregister(token);
    } catch (error) {
      DriverLog.warn(
        'push not unregistered: ${error.runtimeType}',
        name: 'push',
      );
    }
  }
}
