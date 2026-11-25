// The provider SDKs (google_sign_in, sign_in_with_apple), loaded only on the
// first Apple / Google tap: provider_token_source.dart imports this file
// `deferred`, so the web's main.dart.js does not carry them.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'google_web_script_stub.dart'
    if (dart.library.js_interop) 'google_web_script_web.dart';
import 'provider_sign_in_config.dart';
import 'provider_token_source.dart';

bool _googleReady = false;

Future<ProviderIdentityToken?> obtainApple(
  ProviderSignInConfig config, {
  required bool web,
  required TargetPlatform target,
}) async {
  final native =
      !web && (target == TargetPlatform.iOS || target == TargetPlatform.macOS);
  final AuthorizationCredentialAppleID credential;
  try {
    if (native && !await SignInWithApple.isAvailable()) {
      throw const ProviderUnavailable('apple');
    }
    credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: native
          ? null
          : WebAuthenticationOptions(
              clientId: config.appleServiceId,
              redirectUri: config.appleRedirectUri!,
            ),
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

Future<ProviderIdentityToken?> obtainGoogle(
  ProviderSignInConfig config, {
  required bool web,
  required TargetPlatform target,
  required Duration webGoogleTimeout,
}) async {
  final signIn = GoogleSignIn.instance;
  try {
    if (!_googleReady) {
      if (web) releaseGoogleSignInScript();
      await signIn.initialize(
        clientId: config.googleClientIdFor(web: web, platform: target),
        serverClientId: config.googleServerClientIdFor(
          web: web,
          platform: target,
        ),
      );
      _googleReady = true;
    }
    final GoogleSignInAccount? account;
    if (signIn.supportsAuthenticate()) {
      account = await signIn.authenticate();
    } else {
      account = await _googleWebOneTap(signIn, webGoogleTimeout);
      if (account == null) return null;
    }
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

/// The web has no `authenticate()`: Google's One Tap prompt answers on
/// the event stream. No answer in time (closed, or Google holds the
/// prompt back after earlier closes) is the same as a closed sheet.
Future<GoogleSignInAccount?> _googleWebOneTap(
  GoogleSignIn signIn,
  Duration webGoogleTimeout,
) async {
  final event = signIn.authenticationEvents
      .where((e) => e is GoogleSignInAuthenticationEventSignIn)
      .cast<GoogleSignInAuthenticationEventSignIn>()
      .first
      .timeout(webGoogleTimeout);
  final prompt = signIn.attemptLightweightAuthentication();
  if (prompt != null) unawaited(prompt.then((_) {}, onError: (_) {}));
  try {
    return (await event).user;
  } on TimeoutException {
    return null;
  }
}
