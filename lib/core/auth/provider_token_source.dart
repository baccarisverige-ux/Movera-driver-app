import 'package:flutter/foundation.dart';

import 'provider_sdk.dart'
    if (dart.library.js_interop) 'provider_sdk_web.dart'
    deferred as sdk;
import 'provider_sign_in_config.dart';

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

/// The provider's SDK is not usable here: a desktop host, or a build
/// without that provider's client id (ProviderSignInConfig). The button then shows
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

/// The real SDKs: `sign_in_with_apple` (native sheet on iOS and macOS, the
/// Services ID web flow on the web and Android) and `google_sign_in`
/// (Android, iOS, and Google One Tap on the web), loaded on first use
/// (provider_sdk.dart, deferred). A provider whose client id
/// was not given at build time ([ProviderSignInConfig]) answers
/// [ProviderUnavailable], so its button keeps saying "coming soon"; nothing
/// here throws past the sign-in screen's error handling.
class PlatformProviderTokenSource implements ProviderTokenSource {
  PlatformProviderTokenSource({
    ProviderSignInConfig config = ProviderSignInConfig.fromEnvironment,
    bool? isWeb,
    TargetPlatform? platform,
    Duration webGoogleTimeout = const Duration(minutes: 2),
  }) : _config = config,
       _isWeb = isWeb,
       _platform = platform,
       _webGoogleTimeout = webGoogleTimeout;

  final ProviderSignInConfig _config;
  final bool? _isWeb;
  final TargetPlatform? _platform;
  final Duration _webGoogleTimeout;

  bool get _web => _isWeb ?? kIsWeb;
  TargetPlatform get _target => _platform ?? defaultTargetPlatform;

  @override
  Future<ProviderIdentityToken?> obtain(String provider) => switch (provider) {
    'apple' => _obtainApple(),
    'google' => _obtainGoogle(),
    _ => throw ArgumentError.value(provider, 'provider'),
  };

  Future<void> _loadSdk(String provider) async {
    try {
      await sdk.loadLibrary();
    } catch (error) {
      throw ProviderUnavailable(provider, error);
    }
  }

  Future<ProviderIdentityToken?> _obtainApple() async {
    if (!_config.appleAvailable(web: _web, platform: _target)) {
      throw const ProviderUnavailable('apple');
    }
    await _loadSdk('apple');
    return sdk.obtainApple(_config, web: _web, target: _target);
  }

  Future<ProviderIdentityToken?> _obtainGoogle() async {
    if (!_config.googleAvailable(web: _web, platform: _target)) {
      throw const ProviderUnavailable('google');
    }
    await _loadSdk('google');
    return sdk.obtainGoogle(
      _config,
      web: _web,
      target: _target,
      webGoogleTimeout: _webGoogleTimeout,
    );
  }
}
