import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Phone sign-in over the contract's auth endpoints, saving the session
/// in a [TokenStore] once the server accepts the code.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore tokens})
    : _api = api,
      _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  /// Review #683 (SHOULD): counts the sessions saved by a sign-in on this
  /// device. A sign-out that finishes after a newer sign-in (the details
  /// screen stops waiting after 8 s) must not clear that newer session.
  int _signIns = 0;

  /// See [_signIns].
  int get signInCount => _signIns;

  static const requestPath = '/api/v1/auth/otp/request';
  static const verifyPath = '/api/v1/auth/otp/verify';
  static const providerPath = '/api/v1/auth/provider';
  static const signOutPath = '/api/v1/auth/sign-out';
  static const waitlistPath = '/api/v1/auth/waitlist';

  /// The languages the server writes the code SMS in (contract `languages`).
  static const _smsLanguages = {'sv', 'fr', 'en'};

  /// A code of exactly [length] digits, as the server checks it: 4 (a test
  /// number's code) or 6 (a code sent by SMS, contract v0.18.133
  /// `smsSignIn.codeLength`). The length comes from the code request's
  /// answer ([OtpChallenge.codeLength]).
  static bool isValidCode(
    String code, {
    int length = OtpChallenge.defaultCodeLength,
  }) => RegExp('^[0-9]{$length}\$').hasMatch(code);

  /// Sends a code to [phone] (E.164) for the driver app. With
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
        // Contract §8 OtpRequest.locale (v0.18.133 smsSignIn.language): the
        // SMS with the code is written in the app's language.
        if (_smsLanguages.contains(DriverAppTexts.language))
          'locale': DriverAppTexts.language,
      },
      authenticated: false,
      timeout: ApiClient.signInTimeout,
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
      // Contract v0.18.133 `smsSignIn.codeLengthNote`: the server says how
      // many digits this code has; no field (an older server) = 4.
      codeLength: OtpChallenge.codeLengthOf(response['codeLength']),
    );
  }

  /// Verifies [code] for [sessionId] and saves the session only after the
  /// server accepts it. Expiry is the server's call (`410 otp_expired`).
  Future<DriverSignInResult> verify(
    String phone,
    String sessionId,
    String code, {
    ProviderLink? link,
    int codeLength = OtpChallenge.defaultCodeLength,
  }) async {
    final normalizedCode = code.trim();
    if (!isValidCode(normalizedCode, length: codeLength)) {
      throw ArgumentError.value(
        code,
        'code',
        'A $codeLength-digit code is required.',
      );
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
      timeout: ApiClient.signInTimeout,
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
      timeout: ApiClient.signInTimeout,
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
    // Counted before the save, so a late sign-out never clears it mid-save.
    _signIns++;
    await _tokens.save(access: access, refresh: refresh);
    final actor = response['actor'];
    final expiresIn = response['expiresIn'];
    return DriverSignInResult(
      isNewDriver: response['isNewDriver'] == true,
      actor: actor is Map ? Map<String, dynamic>.from(actor) : null,
      expiresIn: expiresIn is num ? Duration(seconds: expiresIn.toInt()) : null,
    );
  }

  /// Contract v0.15.0 (owner 2026-10-29, decision 5): a number answered
  /// `403 sign_in_restricted` joins the waiting list; the admin sees it.
  Future<void> joinWaitlist(String phone, {String? locale}) async {
    await _api.post(
      waitlistPath,
      body: {
        'phone': phone.replaceAll(' ', '').trim(),
        'app': 'driver',
        if (locale != null) 'locale': locale,
      },
      authenticated: false,
      timeout: ApiClient.signInTimeout,
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

  /// A session this phone must not keep (post-merge S1 round 2, SF1: the
  /// last driver's data could not be cleared for it). The tokens go
  /// FIRST, so a kill during the server call leaves no session here; then
  /// the server ends that session (with its token, best effort: an
  /// unanswered call only leaves it to expire). [session]: the access
  /// token of the session judged (default: the stored one).
  Future<void> endSessionHereFirst({String? session}) async {
    final access = session ?? await _tokens.readAccess();
    await _tokens.clear();
    if (access == null || access.isEmpty) return;
    try {
      await _api.post(
        signOutPath,
        bearer: access,
        timeout: const Duration(seconds: 5),
      );
    } catch (error) {
      DriverLog.warn(
        'refused session not ended: ${error.runtimeType}',
        name: 'auth',
      );
    }
  }

  /// Ends the session: `POST /api/v1/auth/sign-out` while the token is
  /// still there, then the tokens go, whatever the server answered (or
  /// did not). Without a session nothing is sent.
  ///
  /// v0.18.49 §71 (owner Q8, S8 R4): a driver with a current trip is
  /// refused (409 `sign_out_on_trip`): the session stays on the server, so
  /// it stays here too (the tokens are kept) and [SignOutOnTrip] is thrown.
  /// Any other failure still clears this phone.
  Future<void> signOut() async {
    final signIns = _signIns;
    try {
      if (await hasSession()) {
        // Follow-up #686 (a): this session's own token, no refresh on a
        // 401, so a newer sign-in's refresh token is never spent here.
        final access = await _tokens.readAccess();
        try {
          await _api.post(signOutPath, bearer: access);
        } on ApiError catch (error) {
          // Expired token, same session still here: renew it and retry.
          if (error.statusCode != 401 || _signIns != signIns) rethrow;
          await _api.post(signOutPath);
        }
      }
    } on ApiError catch (error) {
      if (error.statusCode == 409 && error.reason == SignOutOnTrip.reason) {
        throw SignOutOnTrip(error.message);
      }
      DriverLog.warn('sign-out not confirmed: ${error.code}', name: 'auth');
    } catch (error) {
      DriverLog.warn(
        'sign-out not confirmed: ${error.runtimeType}',
        name: 'auth',
      );
    }
    // Review #683: a newer sign-in overtook this late sign-out; its
    // session stays.
    if (_signIns != signIns) return;
    await _tokens.clear();
  }
}

/// The server refused the sign-out: the driver has a current trip
/// (`contract.json#auth.signOutOnTrip`). Nothing changed on the phone; the
/// app says « Terminez d’abord la course. » (`fleetOnTrip`).
class SignOutOnTrip implements Exception {
  const SignOutOnTrip(this.message);

  static const reason = 'sign_out_on_trip';

  /// The server's words, in the driver's language.
  final String message;

  @override
  String toString() => 'SignOutOnTrip: $message';
}
