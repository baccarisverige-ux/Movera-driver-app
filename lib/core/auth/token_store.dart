import 'dart:convert';

/// Where the session's tokens live. Tokens never go in SharedPreferences,
/// URLs, logs or git.
abstract class TokenStore {
  Future<void> save({required String access, required String refresh});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> clear();
}

/// Tokens for the life of the process (tests, Linux CI, and the fallback
/// when the secure store is unavailable).
class MemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// The driver id in an access token (a JWT's `sub`, movera-server
/// `src/auth/service.ts`); null when the token cannot be read.
Object? tokenDriver(String? token) {
  try {
    // A JWT's middle part: base64url without its padding.
    final part = token!.split('.')[1];
    return jsonDecode(
      utf8.decode(base64.decode(part.padRight(part.length + 3 & ~3, '='))),
    )['sub'];
  } catch (_) {
    return null;
  }
}
