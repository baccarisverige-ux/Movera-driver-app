import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What the provider's SDK gave the app: the identity token the server
/// verifies, and the name Apple shows only the first time (sent as `name`).
class ProviderIdentityToken {
  const ProviderIdentityToken({
    required this.provider,
    required this.idToken,
    this.name,
  });

  final String provider;
  final String idToken;
  final String? name;
}

/// The provider's SDK is not usable here: the web build, a desktop host,
/// or Google without the native configuration. The button then shows
/// "Coming soon", like a server without provider keys.
class ProviderUnavailable implements Exception {
  const ProviderUnavailable(this.provider, [this.cause]);
  final String provider;
  final Object? cause;

  @override
  String toString() => 'ProviderUnavailable($provider, $cause)';
}

/// Gets the identity token from Apple or Google. Null when the driver
/// closed the provider's sheet without choosing an account.
abstract class ProviderTokenSource {
  Future<ProviderIdentityToken?> obtain(String provider);
}

/// The real SDKs: `sign_in_with_apple` on iOS and macOS, `google_sign_in`
/// on Android and iOS. Everything else is [ProviderUnavailable]; nothing
/// here throws past the sign-in screen's error handling.
class PlatformProviderTokenSource implements ProviderTokenSource {
  PlatformProviderTokenSource();

  bool _googleReady = false;

  static bool get _apple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get _google =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ProviderIdentityToken?> obtain(String provider) => switch (provider) {
    'apple' => _obtainApple(),
    'google' => _obtainGoogle(),
    _ => throw ArgumentError.value(provider, 'provider'),
  };

  Future<ProviderIdentityToken?> _obtainApple() async {
    if (!_apple) throw const ProviderUnavailable('apple');
    final AuthorizationCredentialAppleID credential;
    try {
      if (!await SignInWithApple.isAvailable()) {
        throw const ProviderUnavailable('apple');
      }
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw ProviderUnavailable('apple', error);
    } on ProviderUnavailable {
      rethrow;
    } catch (error) {
      throw ProviderUnavailable('apple', error);
    }
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw const ProviderUnavailable('apple', 'no identity token');
    }
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    return ProviderIdentityToken(
      provider: 'apple',
      idToken: token,
      name: name.isEmpty ? null : name.join(' '),
    );
  }

  Future<ProviderIdentityToken?> _obtainGoogle() async {
    if (!_google) throw const ProviderUnavailable('google');
    final signIn = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await signIn.initialize();
        _googleReady = true;
      }
      if (!signIn.supportsAuthenticate()) {
        throw const ProviderUnavailable('google');
      }
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ProviderUnavailable('google', 'no identity token');
      }
      return ProviderIdentityToken(
        provider: 'google',
        idToken: token,
        name: account.displayName,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw ProviderUnavailable('google', error);
    } on ProviderUnavailable {
      rethrow;
    } catch (error) {
      throw ProviderUnavailable('google', error);
    }
  }
}
