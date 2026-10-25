import 'package:movera/core/auth/token_store.dart';

/// Not a browser: native builds use Keychain/Keystore.
TokenStore? createWebSessionTokenStore() => null;
