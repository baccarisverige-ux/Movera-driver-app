import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// What the driver was doing when sign-in failed.
enum AuthAction { sendCode, verifyCode }

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
    if (status >= 500) return tr.authErrServer;
    switch (error.detail) {
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
  return switch (action) {
    AuthAction.sendCode => tr.authErrSendCode,
    AuthAction.verifyCode => tr.authErrCheckCode,
  };
}
