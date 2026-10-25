/// A code sent to [phone] (`POST /api/v1/auth/otp/request`).
class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.sessionId,
    required this.expiresAt,
    required this.retryAfter,
  });

  /// E.164, as sent to the server.
  final String phone;
  final String sessionId;
  final DateTime expiresAt;

  /// How long before another code may be requested.
  final Duration retryAfter;
}

/// A verified code (`POST /api/v1/auth/otp/verify`): the session is saved;
/// [isNewDriver] says whether the server has a driver record yet.
///
/// Round 5 hook: the screen that collects a new driver's details, and the
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
