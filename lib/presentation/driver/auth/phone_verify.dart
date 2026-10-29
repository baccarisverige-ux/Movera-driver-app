import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_error_message.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_scaffold.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/auth/widgets/slow_server_note.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:pinput/pinput.dart';

/// Step 2: enter the 4-digit code. Verify unlocks at four digits; resend
/// unlocks when the server's retry window has passed.
class DriverPhoneVerification extends StatefulWidget {
  /// Whether this build runs in a browser (tests set it).
  @visibleForTesting
  static bool? debugWeb;

  /// iPhone Safari (and Chrome on Android) open the keyboard only for a
  /// field the driver taps: a field the page focuses by itself gets no
  /// keyboard, and the first tap then lands on a field that is already
  /// focused, so nothing happens until a tap elsewhere and a second tap
  /// (owner, live test 2026-10-26). In a browser the code field waits for
  /// the tap; the installed apps open the keyboard at once.
  static bool get autofocusCode => !(debugWeb ?? kIsWeb);

  /// Owner 2026-10-29, decision 9b: in a browser EVERY tap on the code
  /// field must open the keyboard, also when the field still has focus
  /// (after a wrong code, after "Resend code", after the keyboard was
  /// closed by a swipe or a tap outside). A tap on a focused field asks
  /// for nothing new, so the browser keeps its keyboard closed; the tap
  /// therefore lets go of the focus and takes it again, inside the tap.
  static bool get refocusOnTap => debugWeb ?? kIsWeb;

  const DriverPhoneVerification({
    super.key,
    this.challenge,
    this.controller,
    this.clock,
  });

  final OtpChallenge? challenge;

  /// Null: the app root's controller ([DriverRuntimeScope.auth]).
  final AuthController? controller;

  /// The wall clock the resend window is measured on (tests).
  final DateTime Function()? clock;

  @override
  State<DriverPhoneVerification> createState() =>
      _DriverPhoneVerificationState();
}

class _DriverPhoneVerificationState extends State<DriverPhoneVerification> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  OtpChallenge? _challenge;
  int _secondsUntilResend = 0;
  Timer? _ticker;
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _info;

  /// Owner decision 3: 5 wrong codes spent the code; the resend control is
  /// highlighted until a new code is sent.
  bool _tooManyWrong = false;

  AuthController? get _auth => widget.controller ?? authControllerOf(context);

  String? get _phone => _challenge?.phone;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    final challenge = _challenge;
    if (challenge != null) _startResendWindow(challenge.retryAfter);
    _pin.addListener(_pinChanged);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _pinChanged() {
    setState(() {
      if (_error != null) _error = null;
    });
  }

  /// Counts the server's retry window down once a second.
  ///
  /// A suspended app or a throttled web tab fires the timer once after a
  /// long gap, so the wait left is measured, not counted per callback:
  /// whichever of the wall clock and the timer's own tick count has seen
  /// more time pass.
  void _startResendWindow(Duration wait) {
    _ticker?.cancel();
    final seconds = wait.inSeconds + (wait.inMilliseconds % 1000 == 0 ? 0 : 1);
    _secondsUntilResend = seconds;
    if (seconds <= 0) return;
    final now = widget.clock ?? DateTime.now;
    final allowedAt = now().add(Duration(seconds: seconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final byClock = allowedAt.difference(now()).inMilliseconds;
      final left = min(seconds - timer.tick, (byClock / 1000).ceil());
      setState(() => _secondsUntilResend = max(0, left));
      if (_secondsUntilResend <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    if (_resending) return;
    final phone = _phone?.trim();
    final auth = _auth;
    if (phone == null || phone.isEmpty || auth == null) {
      setState(() => _error = tr.authReenterPhone);
      return;
    }
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final next = await auth.requestCode(phone);
      if (!mounted) return;
      _pin.clear();
      setState(() {
        _challenge = next;
        _info = tr.authNewCodeSent;
        _tooManyWrong = false;
      });
      _startResendWindow(next.retryAfter);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(error, AuthAction.sendCode));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    if (_submitting) return;
    final challenge = _challenge;
    final code = _pin.text.trim();
    final auth = _auth;
    if (challenge == null || auth == null) {
      setState(() => _error = tr.authRequestNewCode);
      return;
    }
    // No device-clock expiry check: the server answers 410 for an expired
    // code and authErrorMessage says so.
    if (!AuthRepository.isValidCode(code)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });
    try {
      await auth.verify(challenge: challenge, code: code);
      if (!mounted) return;
      _ticker?.cancel();
      // enterDriverApp decides: the details screen for a new or still
      // pending driver, else Home.
      await enterDriverApp(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error, AuthAction.verifyCode);
        if (isTooManyWrongCodes(error)) _tooManyWrong = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    final complete = AuthRepository.isValidCode(_pin.text.trim());
    // No way back while the code is being checked: leaving here would
    // unmount the screen that opens the app once the verify signs the
    // driver in.
    return PopScope(
      canPop: !_submitting,
      child: _content(context, phone, complete),
    );
  }

  Widget _content(BuildContext context, String? phone, bool complete) {
    return AuthScaffold(
      step: 2,
      onBack: () => maybePopOwned(context),
      headline: tr.authEnterYourCodeHead,
      headlineAccent: tr.authEnterYourCodeAccent,
      lede: phone == null || phone.trim().isEmpty
          ? Text(tr.authCodeSentToPhone)
          : Text.rich(
              TextSpan(
                text: tr.authSentTo,
                children: [
                  TextSpan(
                    text: displayPhoneNumber(phone.trim()),
                    style: const TextStyle(
                      color: AuthColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pinput(
            key: const ValueKey('auth-code'),
            length: 4,
            controller: _pin,
            focusNode: _pinFocus,
            autofocus: DriverPhoneVerification.autofocusCode,
            onTap: _refocus,
            // Owner decision 7: one-time-code autofill (iOS, the web's
            // autocomplete="one-time-code", Android autofill services).
            autofillHints: const [AutofillHints.oneTimeCode],
            keyboardType: TextInputType.number,
            forceErrorState: _error != null,
            onCompleted: (_) => setState(() {}),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            defaultPinTheme: _box(),
            focusedPinTheme: _box(focused: true),
            submittedPinTheme: _box(),
            errorPinTheme: _box(error: true),
          ),
          if (_error != null) AuthErrorText(_error!),
          if (_info != null && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _info!,
                  textAlign: TextAlign.center,
                  style: AuthText.cardSub().copyWith(color: AuthColors.green),
                ),
              ),
            ),
          SlowServerNote(busy: _submitting || _resending),
          const SizedBox(height: 16),
          Center(child: _resendRow()),
          const SizedBox(height: 16),
          AuthNote(
            icon: Icons.verified_user_outlined,
            text: tr.authNeverAskCode,
          ),
          const SizedBox(height: 14),
          AuthPrimaryButton(
            key: const ValueKey('auth-verify'),
            label: tr.authVerify,
            showArrow: false,
            busy: _submitting,
            onPressed: complete ? _verify : null,
          ),
        ],
      ),
    );
  }

  void _refocus() {
    if (!DriverPhoneVerification.refocusOnTap || !_pinFocus.hasFocus) return;
    // Both changes are applied at once, not in the next microtask, so the
    // browser sees its text field blurred and focused again while the tap
    // (pointerup) is still being handled; only then does it open the
    // keyboard.
    _pinFocus.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    _pinFocus.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  /// Each digit on its own underline, ink while focused.
  PinTheme _box({bool focused = false, bool error = false}) {
    return PinTheme(
      width: 68,
      height: 66,
      textStyle: AuthText.urbanist(size: 26, weight: FontWeight.w800),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: authUnderlineColor(focused: focused, error: error),
            width: focused ? 2 : 1.2,
          ),
        ),
      ),
    );
  }

  Widget _resendRow() {
    final wait = _secondsUntilResend;
    final style = AuthText.cardSub();
    if (_resending) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AuthColors.ink),
      );
    }
    if (wait > 0 && _tooManyWrong) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AuthColors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _waitRow(wait, style),
        ),
      );
    }
    if (wait > 0) return _waitRow(wait, style);
    return _resendButton();
  }

  Widget _waitRow(int wait, TextStyle style) {
    final mm = wait ~/ 60;
    final ss = (wait % 60).toString().padLeft(2, '0');
    return Row(
      key: ValueKey(
        _tooManyWrong ? 'auth-resend-wait-highlight' : 'auth-resend-wait',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: AuthColors.muted),
        const SizedBox(width: 7),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: tr.authResendCodeIn,
              children: [
                TextSpan(
                  text: '$mm:$ss',
                  style: const TextStyle(
                    color: AuthColors.green,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _resendButton() {
    return TextButton(
      key: ValueKey(_tooManyWrong ? 'auth-resend-highlight' : 'auth-resend'),
      onPressed: _resend,
      style: TextButton.styleFrom(
        foregroundColor: _tooManyWrong ? Colors.white : AuthColors.green,
        backgroundColor: _tooManyWrong ? AuthColors.green : null,
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: _tooManyWrong ? 18 : 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        tr.authResendCode,
        style: AuthText.urbanist(size: 13.5, weight: FontWeight.w600),
      ),
    );
  }
}
