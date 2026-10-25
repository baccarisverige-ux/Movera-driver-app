import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/auth/web_session_token_store.dart';
import 'package:movera/core/logging/driver_log.dart';

/// The driver's session tokens: iOS Keychain / Android Keystore through
/// flutter_secure_storage; on web this tab's sessionStorage (see
/// [webSessionTokenStore]); memory anywhere else (tests, Linux CI).
///
/// A store that fails (a missing plugin, a locked Keychain) falls back to
/// memory for that call and logs it without the tokens.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({TokenStore? override, SecureKeyValue? native})
    : _override = override,
      _native = native;

  final TokenStore? _override;
  final SecureKeyValue? _native;
  final MemoryTokenStore _memory = MemoryTokenStore();
  late final TokenStore? _web = kIsWeb ? webSessionTokenStore() : null;

  /// One entry holding both tokens as JSON (native).
  static const sessionKey = 'movera_driver_session';

  bool get _nativeSecure =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  late final TokenStore _active = () {
    final override = _override;
    if (override != null) return override;
    final web = _web;
    if (web != null) return web;
    if (!_nativeSecure) return _memory;
    return NativeSecureTokenStore(
      _native ?? const _FlutterSecureKeyValue(FlutterSecureStorage()),
    );
  }();

  @override
  Future<void> save({required String access, required String refresh}) async {
    try {
      await _active.save(access: access, refresh: refresh);
    } catch (error) {
      DriverLog.warn(
        'secure save failed: ${error.runtimeType}',
        name: 'auth.tokens',
      );
      await _memory.save(access: access, refresh: refresh);
    }
  }

  @override
  Future<String?> readAccess() async {
    try {
      return await _active.readAccess();
    } catch (error) {
      DriverLog.warn(
        'secure read failed: ${error.runtimeType}',
        name: 'auth.tokens',
      );
      return _memory.readAccess();
    }
  }

  @override
  Future<String?> readRefresh() async {
    try {
      return await _active.readRefresh();
    } catch (error) {
      DriverLog.warn(
        'secure read failed: ${error.runtimeType}',
        name: 'auth.tokens',
      );
      return _memory.readRefresh();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _active.clear();
    } catch (error) {
      DriverLog.warn(
        'secure clear failed: ${error.runtimeType}',
        name: 'auth.tokens',
      );
    } finally {
      await _memory.clear();
    }
  }
}

/// The few calls [NativeSecureTokenStore] makes on Keychain/Keystore.
abstract class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureKeyValue implements SecureKeyValue {
  const _FlutterSecureKeyValue(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Both tokens live in one entry ([SecureTokenStore.sessionKey]), so a kill
/// between two writes can never pair a new access token with the refresh
/// token the server just rotated away. Reads never write.
class NativeSecureTokenStore implements TokenStore {
  NativeSecureTokenStore(this._storage);
  final SecureKeyValue _storage;

  @override
  Future<void> save({required String access, required String refresh}) =>
      _storage.write(
        SecureTokenStore.sessionKey,
        jsonEncode({'access': access, 'refresh': refresh}),
      );

  @override
  Future<String?> readAccess() async => (await _read())?.access;

  @override
  Future<String?> readRefresh() async => (await _read())?.refresh;

  @override
  Future<void> clear() => _storage.delete(SecureTokenStore.sessionKey);

  Future<({String access, String refresh})?> _read() async {
    final raw = await _storage.read(SecureTokenStore.sessionKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded['access'] is String &&
          decoded['refresh'] is String) {
        return (
          access: decoded['access'] as String,
          refresh: decoded['refresh'] as String,
        );
      }
    } on FormatException {
      // Unreadable entry: treated as no session, like a missing one.
    }
    return null;
  }
}
