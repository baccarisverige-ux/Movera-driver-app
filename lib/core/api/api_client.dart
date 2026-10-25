import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/logging/driver_log.dart';

/// JSON calls to the Movera API with the contract's headers
/// (`contract.json#headers`): `Authorization: Bearer`, `X-Api-Version`,
/// `X-Request-Id` on every request and an `Idempotency-Key` on every
/// POST and PATCH.
///
/// A 401 on a signed request refreshes the session once
/// (`POST /api/v1/auth/refresh`) and retries; a 400, 401 or 403 from the
/// refresh ends the session (tokens cleared, [onSessionExpired] called).
/// Error answers become an [ApiError]; so do no answer at all
/// ([ApiError.network]) and a late one ([ApiError.timeout]).
class ApiClient {
  ApiClient({
    required http.Client client,
    required Uri baseUri,
    required TokenStore tokens,
    Future<void> Function()? onSessionExpired,
    String Function()? requestId,
    String Function()? idempotencyKey,
    Duration timeout = requestTimeout,
  }) : _client = client,
       _base = baseUri,
       _tokens = tokens,
       _onSessionExpired = onSessionExpired,
       _requestId = requestId ?? randomKey,
       _idempotencyKey = idempotencyKey ?? randomKey,
       _timeout = timeout;

  /// `X-Api-Version` on every request: contract v0.5.
  static const apiVersion = '0.5';

  /// The longest a request waits for the server's answer.
  static const requestTimeout = Duration(seconds: 15);

  static const refreshPath = '/api/v1/auth/refresh';

  final http.Client _client;
  final Uri _base;
  final TokenStore _tokens;
  final Future<void> Function()? _onSessionExpired;
  final String Function() _requestId;
  final String Function() _idempotencyKey;
  final Duration _timeout;
  Future<_Refresh>? _refreshInFlight;
  String? _expiredAccess;

  static final math.Random _random = math.Random.secure();

  /// 32 hex characters, for `X-Request-Id` and `Idempotency-Key`.
  static String randomKey() => List<String>.generate(
    32,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  /// `GET path`.
  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  /// `POST path` with a JSON [body] and an `Idempotency-Key`. Sign-in calls
  /// pass `authenticated: false`: no bearer token, and their 401 is a
  /// refusal, never an expired session.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => _send(
    'POST',
    path,
    body: body,
    idempotencyKey: idempotencyKey ?? _idempotencyKey(),
    authenticated: authenticated,
  );

  /// `PATCH path` with a JSON [body] and an `Idempotency-Key`.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    bool authenticated = true,
  }) => _send(
    'PATCH',
    path,
    body: body,
    idempotencyKey: idempotencyKey ?? _idempotencyKey(),
    authenticated: authenticated,
  );

  /// `DELETE path`.
  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = true,
  }) => _send('DELETE', path, authenticated: authenticated);

  Uri uriFor(String path) =>
      _base.replace(path: '${_base.path.replaceFirst(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    required bool authenticated,
  }) async {
    final requestId = _requestId();
    final uri = uriFor(path);
    try {
      final access = authenticated ? await _tokens.readAccess() : null;
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
        'X-Api-Version': apiVersion,
        if (access != null && access.isNotEmpty)
          'Authorization': 'Bearer $access',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };
      var response = await _request(method, uri, headers, body);
      if (response.statusCode == 401 && access != null && access.isNotEmpty) {
        final refresh = await _refreshAccess(access);
        if (refresh.unavailable) {
          // Offline, timed out or a server fault: the refresh token may still
          // be good, so the driver stays signed in and the caller sees an
          // ordinary network error it can retry.
          throw ApiError(
            code: ApiError.network,
            message: 'Could not reach Movera to renew the session.',
            requestId: requestId,
          );
        }
        final replacement = refresh.access;
        if (replacement != null) {
          response = await _request(method, uri, {
            ...headers,
            'Authorization': 'Bearer $replacement',
          }, body);
        }
        if (replacement == null || response.statusCode == 401) {
          await _expireSession(
            replacement ?? access,
            cause: replacement == null ? refresh.cause : 'retry_401',
          );
        }
      }
      DriverLog.info(
        '$method $path -> ${response.statusCode} ($requestId)',
        name: 'api',
      );
      if (response.statusCode >= 400) {
        throw _errorFromResponse(response, requestId);
      }
      if (response.body.trim().isEmpty) return {'requestId': requestId};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded, 'requestId': requestId};
    } on TimeoutException {
      DriverLog.warn('$method $path timed out ($requestId)', name: 'api');
      throw ApiError(
        code: ApiError.timeout,
        message: 'Request timed out.',
        requestId: requestId,
      );
    } on http.ClientException catch (error) {
      DriverLog.warn(
        '$method $path failed: ${error.runtimeType} ($requestId)',
        name: 'api',
      );
      throw ApiError(
        code: ApiError.network,
        message: 'Could not reach Movera.',
        requestId: requestId,
      );
    } on FormatException {
      throw ApiError(
        code: 'bad_response',
        message: 'Movera sent an unreadable answer.',
        requestId: requestId,
      );
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (method != 'GET' && method != 'DELETE') {
      request.body = jsonEncode(body ?? <String, dynamic>{});
    }
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(_timeout);
  }

  /// One refresh at a time: a burst of concurrent 401s shares it.
  Future<_Refresh> _refreshAccess(String failedAccess) async {
    final active = _refreshInFlight;
    if (active != null) return active;
    final pending = _performRefresh(failedAccess);
    _refreshInFlight = pending;
    try {
      return await pending;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Only a definitive answer from the refresh endpoint ends the session.
  /// Anything that says nothing about the token itself (no network, timeout,
  /// 5xx, 429, an unreadable 200) keeps the tokens for a later retry.
  Future<_Refresh> _performRefresh(String failedAccess) async {
    final current = await _tokens.readAccess();
    if (current != null && current.isNotEmpty && current != failedAccess) {
      // Another request already renewed the session.
      return _Refresh.refreshed(current);
    }
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      return const _Refresh.rejected('no_refresh_token');
    }
    try {
      final response = await _client
          .post(
            uriFor(refreshPath),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Request-Id': _requestId(),
              'X-Api-Version': apiVersion,
            },
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(_timeout);
      final status = response.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return _Refresh.rejected('refresh_$status');
      }
      if (status != 200) return const _Refresh.unavailable();
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return const _Refresh.unavailable();
      final access = payload['accessToken'];
      final nextRefresh = payload['refreshToken'];
      if (access is! String ||
          access.isEmpty ||
          nextRefresh is! String ||
          nextRefresh.isEmpty) {
        return const _Refresh.unavailable();
      }
      await _tokens.save(access: access, refresh: nextRefresh);
      return _Refresh.refreshed(access);
    } catch (error) {
      DriverLog.warn('refresh unavailable: ${error.runtimeType}', name: 'api');
      return const _Refresh.unavailable();
    }
  }

  /// Runs once per rejected access token, so a burst of concurrent 401s
  /// does not clear the session and open Sign in several times.
  Future<void> _expireSession(
    String failedAccess, {
    required String? cause,
  }) async {
    if (_expiredAccess == failedAccess) return;
    _expiredAccess = failedAccess;
    // Why the driver was signed out (never the tokens).
    DriverLog.warn('session expired: ${cause ?? 'unknown'}', name: 'auth');
    await _tokens.clear();
    await _onSessionExpired?.call();
  }

  ApiError _errorFromResponse(http.Response response, String requestId) {
    var code = 'http_${response.statusCode}';
    var message = 'Request failed.';
    String? reason;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawCode = decoded['code'] ?? decoded['error'];
        final rawMessage = decoded['message'];
        final rawReason = decoded['reason'];
        if (rawCode is String && rawCode.trim().isNotEmpty) {
          code = rawCode.trim();
        }
        if (rawMessage is String && rawMessage.trim().isNotEmpty) {
          message = rawMessage.trim();
        }
        if (rawReason is String && rawReason.trim().isNotEmpty) {
          reason = rawReason.trim();
        }
      }
    } on FormatException {
      // A non-JSON error body still keeps the HTTP status and request id.
    }
    final retrySeconds = int.tryParse(
      response.headers['retry-after']?.trim() ?? '',
    );
    return ApiError(
      code: code,
      message: message,
      reason: reason,
      requestId: requestId,
      statusCode: response.statusCode,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
    );
  }
}

class _Refresh {
  const _Refresh.refreshed(String this.access)
    : unavailable = false,
      cause = null;
  const _Refresh.rejected(String this.cause)
    : access = null,
      unavailable = false;
  const _Refresh.unavailable()
    : access = null,
      unavailable = true,
      cause = null;

  final String? access;

  /// Why the refresh was refused (`refresh_401`, `no_refresh_token`, …).
  final String? cause;

  /// The refresh endpoint could not answer; the tokens are kept.
  final bool unavailable;
}
