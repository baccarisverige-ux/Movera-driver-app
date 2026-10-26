import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/provider_token_source.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// What the driver was doing when sign-in failed.
enum AuthAction { sendCode, verifyCode, providerSignIn }

/// Round 4b: the provider cannot be used yet, here or on the server (the
/// server's keys are not set: `503 unavailable`, `provider_not_configured`;
/// or the SDK is not usable on this platform). The button then says
/// "Coming soon" and the phone keeps working.
bool isProviderComingSoon(Object error) {
  if (error is ProviderUnavailable) return true;
  return error is ApiError && error.detail == 'provider_not_configured';
}

/// A specific, honest message for a sign-in failure: whether the code was
/// wrong (`400 invalid_request` / `invalid_otp_code`), expired
/// (`410 otp_expired`), rate limited (`429`, with the server's wait), the
/// number is not on the test list yet (`403` / `sign_in_restricted`), or
/// the request never reached the server.
String authErrorMessage(Object error, AuthAction action) {
  if (error is TimeoutException || error is http.ClientException) {
    return tr.authErrOffline;
  }
  if (error is ApiError) {
    if (error.neverReachedServer) return tr.authErrOffline;
    final status = error.statusCode ?? 0;
    if (status == 429 || error.detail == 'rate_limited') {
      final wait = error.retryAfter;
      if (wait == null || wait <= Duration.zero) return tr.authErrTooManyWait;
      final seconds =
          wait.inSeconds + (wait.inMilliseconds % 1000 == 0 ? 0 : 1);
      return tr.authErrTooManyIn(tr.authRetrySeconds(seconds));
    }
    // A provider without keys answers 503: "coming soon", not a fault.
    if (error.detail == 'provider_not_configured') {
      return tr.authProviderComingSoon;
    }
    if (status >= 500) return tr.authErrServer;
    switch (error.detail) {
      case 'invalid_provider_token' ||
          'invalid_provider_issuer' ||
          'invalid_provider_audience' ||
          'provider_token_expired' ||
          'unknown_provider_key':
        return tr.authErrProvider;
      case 'provider_unavailable':
        return tr.authErrServer;
      case 'invalid_link_token' || 'link_token_expired' || 'link_token_used':
        return tr.authLinkExpired;
      case 'invalid_otp_code' || 'invalid_otp':
        return tr.authErrWrongCode;
      case 'otp_expired' || 'invalid_otp_session':
        return tr.authCodeExpired;
      case 'invalid_phone':
        return tr.authInvalidMobileNumber;
      case 'sign_in_restricted':
        return tr.authSignInRestricted;
    }
    if (status == 403) return tr.authSignInRestricted;
    if (status == 410) return tr.authCodeExpired;
  }
  if (error is ProviderUnavailable) return tr.authProviderComingSoon;
  return switch (action) {
    AuthAction.sendCode => tr.authErrSendCode,
    AuthAction.verifyCode => tr.authErrCheckCode,
    AuthAction.providerSignIn => tr.authErrProvider,
  };
}
