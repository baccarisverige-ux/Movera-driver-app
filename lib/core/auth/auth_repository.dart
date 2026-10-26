import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Phone sign-in over the contract's auth endpoints, saving the session
/// in a [TokenStore] once the server accepts the code.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore tokens})
    : _api = api,
      _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  static const requestPath = '/api/v1/auth/otp/request';
  static const verifyPath = '/api/v1/auth/otp/verify';
  static const providerPath = '/api/v1/auth/provider';
  static const signOutPath = '/api/v1/auth/sign-out';

  /// A 4-digit code, as the server checks it.
  static bool isValidCode(String code) => RegExp(r'^\d{4}$').hasMatch(code);

  /// Sends a 4-digit code to [phone] (E.164) for the driver app. With
  /// [link] (round 4b) the phone confirms an Apple / Google identity.
  Future<OtpChallenge> requestCode(String phone, {ProviderLink? link}) async {
    final normalized = phone.replaceAll(' ', '').trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(phone, 'phone', 'Phone number is required.');
    }
    final response = await _api.post(
      requestPath,
      body: {
        'phone': normalized,
        'app': 'driver',
        if (link != null) 'linkToken': link.linkToken,
      },
      authenticated: false,
    );
    final sessionId = response['sessionId'];
    final expiresAt = DateTime.tryParse('${response['expiresAt'] ?? ''}');
    final retryAfterSeconds = (response['retryAfterSeconds'] as num?)?.toInt();
    if (sessionId is! String ||
        sessionId.isEmpty ||
        expiresAt == null ||
        retryAfterSeconds == null ||
        retryAfterSeconds < 0) {
      throw StateError('OTP request response was incomplete.');
    }
    return OtpChallenge(
      phone: normalized,
      sessionId: sessionId,
      expiresAt: expiresAt.toUtc(),
      retryAfter: Duration(seconds: retryAfterSeconds),
      link: link,
    );
  }

  /// Verifies [code] for [sessionId] and saves the session only after the
  /// server accepts it. Expiry is the server's call (`410 otp_expired`).
  Future<DriverSignInResult> verify(
    String phone,
    String sessionId,
    String code, {
    ProviderLink? link,
  }) async {
    final normalizedCode = code.trim();
    if (!isValidCode(normalizedCode)) {
      throw ArgumentError.value(code, 'code', 'A 4-digit code is required.');
    }
    final response = await _api.post(
      verifyPath,
      body: {
        'phone': phone,
        'sessionId': sessionId,
        'code': normalizedCode,
        if (link != null) 'linkToken': link.linkToken,
      },
      authenticated: false,
    );
    return _saveSession(response);
  }

  /// Round 4b (contract §8): `POST /auth/provider { provider, idToken, app,
  /// name? }`. An identity the server already knows signs in at once
  /// ([ProviderSignedIn]); a new one answers `PHONE_REQUIRED` with the
  /// link token and whatever names and e-mail the provider gave
  /// ([ProviderPhoneRequired]); nothing is saved until the phone's code is
  /// verified. A provider without keys on the server is `503 unavailable`
  /// (`provider_not_configured`), thrown as an [ApiError].
  Future<ProviderSignInResult> signInWithProvider({
    required String provider,
    required String idToken,
    String? name,
  }) async {
    if (idToken.trim().isEmpty) {
      throw ArgumentError.value(idToken, 'idToken', 'A token is required.');
    }
    final response = await _api.post(
      providerPath,
      body: {
        'provider': provider,
        'idToken': idToken,
        'app': 'driver',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      authenticated: false,
    );
    if (response['code'] == 'PHONE_REQUIRED') {
      final linkToken = response['linkToken'];
      if (linkToken is! String || linkToken.isEmpty) {
        throw StateError('PHONE_REQUIRED answer had no link token.');
      }
      String? text(Object? value) =>
          value is String && value.trim().isNotEmpty ? value.trim() : null;
      return ProviderPhoneRequired(
        ProviderLink(
          provider: provider,
          linkToken: linkToken,
          firstName: text(response['firstName']),
          lastName: text(response['lastName']),
          email: text(response['email']),
        ),
      );
    }
    return ProviderSignedIn(await _saveSession(response));
  }

  Future<DriverSignInResult> _saveSession(Map<String, dynamic> response) async {
    final access = response['accessToken'];
    final refresh = response['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw StateError('Sign-in response did not contain valid tokens.');
    }
    await _tokens.save(access: access, refresh: refresh);
    final actor = response['actor'];
    final expiresIn = response['expiresIn'];
    return DriverSignInResult(
      isNewDriver: response['isNewDriver'] == true,
      actor: actor is Map ? Map<String, dynamic>.from(actor) : null,
      expiresIn: expiresIn is num ? Duration(seconds: expiresIn.toInt()) : null,
    );
  }

  Future<String?> readAccessToken() => _tokens.readAccess();

  /// True with both tokens on this device.
  Future<bool> hasSession() async {
    final access = await _tokens.readAccess();
    final refresh = await _tokens.readRefresh();
    return access?.isNotEmpty == true && refresh?.isNotEmpty == true;
  }

  /// Forgets the session on this device only.
  Future<void> clearLocalSession() => _tokens.clear();

  /// Ends the session: `POST /api/v1/auth/sign-out` while the token is
  /// still there, then the tokens go, whatever the server answered (or
  /// did not). Without a session nothing is sent.
  Future<void> signOut() async {
    try {
      if (await hasSession()) await _api.post(signOutPath);
    } catch (error) {
      DriverLog.warn(
        'sign-out not confirmed: ${error.runtimeType}',
        name: 'auth',
      );
    } finally {
      await _tokens.clear();
    }
  }
}
