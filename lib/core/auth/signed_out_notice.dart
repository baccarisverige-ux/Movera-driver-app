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
    'signed_in_elsewhere': revoked,
    'signed_out_by_movera': revoked,
  };

  static const String expired = 'expired';
  static const String revoked = 'revoked';

  /// Contract v0.18.14 `auth.signedOut.elsewhereTexts`: one phone at a
  /// time for a driver; a sign-in on another phone ended this one ("Signed
  /// in on another phone" as the detail line).
  static const String elsewhere = 'elsewhere';

  /// Contract v0.18.149 `auth.signedOut.byMoveraTexts` (owner G12 Q6): an
  /// admin signed this phone out ("You were signed out by Movera" as the
  /// detail line), shown once, until the next sign-in.
  static const String byMovera = 'by_movera';

  /// The kind to show on Sign in ([expired], [revoked], or '' when the
  /// server gave no known reason: the message without a detail line);
  /// null shows nothing.
  static final ValueNotifier<String?> kind = ValueNotifier<String?>(null);

  /// The refresh was refused with this 401 [reason].
  static void sessionRefused(String? reason) {
    kind.value = switch (reason) {
      'signed_in_elsewhere' => elsewhere,
      'signed_out_by_movera' => byMovera,
      _ => reasons[reason] ?? '',
    };
  }

  /// The driver's own Sign out, or a new sign-in: nothing to say.
  static void clear() => kind.value = null;
}
