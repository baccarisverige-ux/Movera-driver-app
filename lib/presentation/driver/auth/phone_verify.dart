import 'dart:async';
import 'dart:math';

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
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:pinput/pinput.dart';

/// Step 2: enter the 4-digit code. Verify unlocks at four digits; resend
/// unlocks when the server's retry window has passed.
class DriverPhoneVerification extends StatefulWidget {
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
      setState(() => _error = authErrorMessage(error, AuthAction.verifyCode));
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
            autofocus: true,
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
    if (wait > 0) {
      final mm = wait ~/ 60;
      final ss = (wait % 60).toString().padLeft(2, '0');
      return Row(
        key: const ValueKey('auth-resend-wait'),
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
    return TextButton(
      key: const ValueKey('auth-resend'),
      onPressed: _resend,
      style: TextButton.styleFrom(
        foregroundColor: AuthColors.green,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        tr.authResendCode,
        style: AuthText.urbanist(size: 13.5, weight: FontWeight.w600),
      ),
    );
  }
}
