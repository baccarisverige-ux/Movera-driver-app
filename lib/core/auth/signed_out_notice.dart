import 'package:flutter/foundation.dart';

/// Contract v0.18.5 `auth.signedOut` (owner G1-D3 "Show a message
/// (Recommended)"): when `POST /auth/refresh` answers 401 the app signs out
/// and the sign-in screen says why: "You were signed out – please sign in
/// again" and, when the reason is known, one more line (30 days unused, or
/// Movera ended the session). After the driver's own Sign out there is no
/// message.
abstract final class SignedOutNotice {
  /// `auth.signedOut.reasons`: the 401 reason → kind.
  static const Map<String, String> reasons = <String, String>{
    'session_expired': expired,
    'session_ended': revoked,
    'refresh_token_reused': revoked,
    'refresh_token_unknown': revoked,
  };

  static const String expired = 'expired';
  static const String revoked = 'revoked';

  /// The kind to show on Sign in ([expired], [revoked], or '' when the
  /// server gave no known reason: the message without a detail line);
  /// null shows nothing.
  static final ValueNotifier<String?> kind = ValueNotifier<String?>(null);

  /// The refresh was refused with this 401 [reason].
  static void sessionRefused(String? reason) {
    kind.value = reasons[reason] ?? '';
  }

  /// The driver's own Sign out, or a new sign-in: nothing to say.
  static void clear() => kind.value = null;
}
