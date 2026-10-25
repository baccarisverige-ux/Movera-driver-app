import 'package:movera/core/auth/token_store.dart';
import 'package:web/web.dart' as web;

TokenStore? createWebSessionTokenStore() => _SessionStorageTokenStore();

/// This tab's sessionStorage (see `web_session_token_store.dart`).
class _SessionStorageTokenStore implements TokenStore {
  static const _accessKey = 'movera_driver_access_token';
  static const _refreshKey = 'movera_driver_refresh_token';

  web.Storage get _storage => web.window.sessionStorage;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _storage.setItem(_accessKey, access);
    _storage.setItem(_refreshKey, refresh);
  }

  @override
  Future<String?> readAccess() async => _storage.getItem(_accessKey);

  @override
  Future<String?> readRefresh() async => _storage.getItem(_refreshKey);

  @override
  Future<void> clear() async {
    _storage.removeItem(_accessKey);
    _storage.removeItem(_refreshKey);
  }
}
