import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';

/// The sign-in flow's state between its two screens, over [AuthRepository].
///
/// Screens find it in `DriverRuntimeScope.auth`; tests hand one in.
class AuthController {
  AuthController({required AuthRepository repository}) : _auth = repository;

  final AuthRepository _auth;

  /// The code last sent, until it is verified.
  OtpChallenge? lastChallenge;

  /// The outcome of the last verified code. Round 5 hook: `isNewDriver`
  /// decides whether `enterDriverApp` opens the details screen instead
  /// of Home.
  DriverSignInResult? signInResult;

  Future<OtpChallenge> requestCode(String phone) async {
    final challenge = await _auth.requestCode(phone);
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
    );
    lastChallenge = null;
    signInResult = result;
    return result;
  }

  Future<bool> hasSession() => _auth.hasSession();

  /// Ends the session on the server and on this device.
  Future<void> signOut() async {
    signInResult = null;
    lastChallenge = null;
    await _auth.signOut();
  }
}
