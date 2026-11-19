/// A code sent to [phone] (`POST /api/v1/auth/otp/request`).
class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.sessionId,
    required this.expiresAt,
    required this.retryAfter,
    this.link,
    this.codeLength = defaultCodeLength,
  });

  /// The fixed test code of a test number, and every code of a server
  /// before contract v0.18.135 (contract `auth.otp.codeLength`).
  static const defaultCodeLength = 4;

  /// A code sent by SMS (contract v0.18.135 `smsSignIn.codeLength`, owner
  /// 2026-11-19 "6 digits (Rec.)").
  static const smsCodeLength = 6;

  /// `OtpChallenge.codeLength` of the code request's answer: 4 or 6, as
  /// the server says; missing (an older server) or anything else = 4. The
  /// app never guesses the length from the phone number.
  static int codeLengthOf(Object? raw) =>
      raw == smsCodeLength && raw is int ? smsCodeLength : defaultCodeLength;

  /// E.164, as sent to the server.
  final String phone;
  final String sessionId;
  final DateTime expiresAt;

  /// How long before another code may be requested.
  final Duration retryAfter;

  /// How many digits this code has, so how many boxes the code screen
  /// shows: 4 (a test number's code) or 6 (a code sent by SMS).
  final int codeLength;

  /// Whether [code] has exactly this challenge's digits (the last digit
  /// sends it; Verify unlocks).
  bool isCompleteCode(String code) =>
      RegExp('^[0-9]{$codeLength}\$').hasMatch(code);

  /// Round 4b: the Apple / Google identity this phone confirms, the first
  /// time (`linkToken` on the OTP calls). Null for a plain phone sign-in.
  final ProviderLink? link;
}

/// A verified code (`POST /api/v1/auth/otp/verify`): the session is saved;
/// [isNewDriver] says whether the server has a driver record yet.
///
/// The screen that collects a new driver's details, and the
/// pending-account hold, read [isNewDriver] and [actor] from
/// `AuthController.signInResult`.
class DriverSignInResult {
  const DriverSignInResult({
    required this.isNewDriver,
    this.actor,
    this.expiresIn,
  });

  final bool isNewDriver;

  /// The server's `actor` object, as sent.
  final Map<String, dynamic>? actor;

  /// Lifetime of the access token.
  final Duration? expiresIn;
}

/// Round 4b (contract §8): `POST /auth/provider` answered `PHONE_REQUIRED`.
/// The phone is confirmed once with [linkToken]; the names and e-mail the
/// provider gave prefill the details step (all editable; Apple may give a
/// hidden relay e-mail).
class ProviderLink {
  const ProviderLink({
    required this.provider,
    required this.linkToken,
    this.firstName,
    this.lastName,
    this.email,
  });

  /// `apple` or `google`.
  final String provider;
  final String linkToken;
  final String? firstName;
  final String? lastName;
  final String? email;

  /// "Apple" / "Google", for the chips on the details step.
  String get providerLabel => provider == 'apple' ? 'Apple' : 'Google';
}

/// The outcome of `POST /auth/provider`.
sealed class ProviderSignInResult {
  const ProviderSignInResult();
}

/// The identity was already linked: signed in like a returning driver.
class ProviderSignedIn extends ProviderSignInResult {
  const ProviderSignedIn(this.result);
  final DriverSignInResult result;
}

/// A new identity: the phone comes next, with the link token.
class ProviderPhoneRequired extends ProviderSignInResult {
  const ProviderPhoneRequired(this.link);
  final ProviderLink link;
}
