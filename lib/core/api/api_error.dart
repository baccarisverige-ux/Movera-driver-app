/// A failed API call, as the contract's error shape describes it
/// (`contract.json#errors`): a `code`, a `message`, and sometimes a more
/// specific `reason` beside the code.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.reason,
    this.requestId,
    this.statusCode,
    this.retryAfter,
  });

  /// Client code for a request that never got an answer from the server.
  static const network = 'NETWORK';

  /// Client code for a request whose answer did not arrive in time.
  static const timeout = 'TIMEOUT';

  /// The contract error code (`invalid_request`, `otp_expired`,
  /// `rate_limited`, …, lower case), or [network] / [timeout] for a
  /// failure that never reached the server.
  final String code;
  final String message;

  /// The server's more specific reason beside [code], when it sends one
  /// (`invalid_otp_code`, `sign_in_restricted`, …).
  final String? reason;

  /// The `X-Request-Id` the app sent, for support.
  final String? requestId;
  final int? statusCode;

  /// `Retry-After` of a 429, when the server sent one.
  final Duration? retryAfter;

  /// True when the request never got an answer (offline, timed out).
  bool get neverReachedServer => code == network || code == timeout;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  /// [reason] when the server sent one, else [code], in lower case: what
  /// screens match on.
  String get detail => (reason ?? code).trim().toLowerCase();

  bool get isRetryable =>
      neverReachedServer ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() => 'ApiError($code, $statusCode, $message, $requestId)';
}
