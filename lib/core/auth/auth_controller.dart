import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/provider_token_source.dart';
import 'package:movera/core/auth/signed_out_notice.dart';

/// The sign-in flow's state between its three steps, over [AuthRepository].
///
/// Screens find it in `DriverRuntimeScope.auth`; tests hand one in.
class AuthController {
  AuthController({
    required AuthRepository repository,
    ProviderTokenSource? providerTokens,
    this.onSignedIn,
    this.onSignedOut,
  }) : _auth = repository,
       _providerTokens = providerTokens ?? PlatformProviderTokenSource();

  final AuthRepository _auth;
  final ProviderTokenSource _providerTokens;

  /// Contract v0.18.2 `auth.beforeSignIn`: the calls that need a session
  /// start here, right after a sign-in (the app root hands it in).
  final void Function()? onSignedIn;

  /// And stop here, when the session ends on this device.
  final void Function()? onSignedOut;

  /// The code last sent, until it is verified.
  OtpChallenge? lastChallenge;

  /// Round 4b: the Apple / Google identity being linked (its names and
  /// e-mail prefill the details step); null for a phone sign-in.
  ProviderLink? providerLink;

  /// The phone the session was opened with (shown read-only on the
  /// details step); null when the session came from an earlier launch.
  String? signedInPhone;

  /// The outcome of the last verified code. Round 5 hook: `isNewDriver`
  /// decides whether `enterDriverApp` opens the details screen instead
  /// of Home.
  DriverSignInResult? signInResult;

  Future<OtpChallenge> requestCode(String phone, {ProviderLink? link}) async {
    final challenge = await _auth.requestCode(
      phone,
      link: link ?? providerLink,
    );
    lastChallenge = challenge;
    return challenge;
  }

  Future<DriverSignInResult> verify({
    required OtpChallenge challenge,
    required String code,
  }) async {
    final result = await _auth.verify(
      challenge.phone,
      challenge.sessionId,
      code,
      link: challenge.link,
    );
    lastChallenge = null;
    signInResult = result;
    signedInPhone = challenge.phone;
    onSignedIn?.call();
    return result;
  }

  /// Round 4b: Apple or Google. Gets the identity token from the
  /// provider's SDK, then `POST /auth/provider`. Null when the driver
  /// closed the provider's sheet. A [ProviderPhoneRequired] answer keeps
  /// its link in [providerLink] for the phone step and the details step.
  Future<ProviderSignInResult?> signInWithProvider(String provider) async {
    final token = await _providerTokens.obtain(provider);
    if (token == null) return null;
    final result = await _auth.signInWithProvider(
      provider: provider,
      idToken: token.idToken,
      name: token.name,
    );
    switch (result) {
      case ProviderSignedIn(:final result):
        providerLink = null;
        signInResult = result;
        signedInPhone = null;
        onSignedIn?.call();
      case ProviderPhoneRequired(:final link):
        providerLink = link;
    }
    return result;
  }

  /// Back from the phone step to step 1: the provider identity is let go.
  void forgetProvider() {
    providerLink = null;
  }

  Future<bool> hasSession() => _auth.hasSession();

  /// Contract v0.15.0 (decision 5): `POST /auth/waitlist`.
  Future<void> joinWaitlist(String phone, {String? locale}) =>
      _auth.joinWaitlist(phone, locale: locale);

  /// Contract v0.15.0 (decision 6): the test numbers, test builds only.
  Future<List<TestAccount>> testAccounts() => _auth.testAccounts();

  /// Ends the session on the server and on this device.
  Future<void> signOut() async {
    // Contract v0.18.5 `auth.signedOut.ownSignOut`: no message after the
    // driver's own Sign out.
    SignedOutNotice.clear();
    signInResult = null;
    lastChallenge = null;
    providerLink = null;
    signedInPhone = null;
    onSignedOut?.call();
    await _auth.signOut();
  }
}
