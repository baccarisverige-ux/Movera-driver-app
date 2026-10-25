import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_error_message.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_scaffold.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/auth/widgets/balloon_brand_intro.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Step 1 of the driver sign-in: one phone field for new and returning
/// drivers, the consent tick and Continue. The rider app's sign-in with the
/// owner's changes: "Driver" under the wordmark, no Apple or Google.
class DriverSignIn extends StatefulWidget {
  const DriverSignIn({super.key, this.controller});

  /// Null: the app root's controller ([DriverRuntimeScope.auth]).
  final AuthController? controller;

  @override
  State<DriverSignIn> createState() => _DriverSignInState();
}

class _DriverSignInState extends State<DriverSignIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _story = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );
  bool _storyStarted = false;
  final _sceneKey = GlobalKey();
  final _wordmarkKey = GlobalKey();

  final _phone = TextEditingController();
  final _phoneFocus = FocusNode();

  /// The driver's market at first (Sweden in the demo), until they pick
  /// another country.
  PhoneCountry _country = defaultPhoneCountry();

  /// The consent line names the Terms and the Privacy policy, so both open
  /// the app's legal pages.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.privacy);

  bool _busy = false;
  String? _phoneError;

  /// The terms box must be ticked before Continue works.
  bool _agreed = false;
  bool _consentNudge = false;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_clearPhoneError);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_storyStarted) {
      _storyStarted = true;
      if (MediaQuery.of(context).disableAnimations) {
        _story.value = 1;
      } else {
        _story.forward();
      }
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _story.dispose();
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  AuthController? get _auth => widget.controller ?? authControllerOf(context);

  void _openLegal(Widget page) {
    pushSingle(context, RightToLeftTransition(page));
  }

  void _pickCountry(PhoneCountry country) {
    setState(() {
      _country = country;
      _phoneError = null;
    });
  }

  void _toggleAgreed() => setState(() {
    _agreed = !_agreed;
    if (_agreed) _consentNudge = false;
  });

  /// A tap on a waiting button: say why it waits.
  void _nudgeConsent() {
    if (!_agreed && !_consentNudge) setState(() => _consentNudge = true);
  }

  void _clearPhoneError() {
    if (_phoneError != null) setState(() => _phoneError = null);
  }

  Future<void> _continue() async {
    if (_busy) return;
    final number = phoneNumberFromField(_phone.text, _country);
    if (number == null) {
      setState(() => _phoneError = tr.authInvalidMobileNumber);
      return;
    }
    final auth = _auth;
    if (auth == null) {
      // No controller in this host: there is no server to send a code.
      setState(() => _phoneError = tr.authErrSendCode);
      return;
    }
    setState(() => _busy = true);
    try {
      final challenge = await auth.requestCode(number);
      if (!mounted) return;
      _phoneFocus.unfocus();
      await Navigator.of(context).push(
        RightToLeftTransition(
          DriverPhoneVerification(challenge: challenge, controller: auth),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _phoneError = authErrorMessage(error, AuthAction.sendCode),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idle = !_busy && _agreed;
    return AuthScaffold(
      step: 1,
      headline: '',
      headlineAccent: '',
      hero: BalloonBrandIntro(progress: _story, wordmarkKey: _wordmarkKey),
      sceneProgress: _story,
      sceneKey: _sceneKey,
      overlay: BalloonFlight(
        progress: _story,
        sceneKey: _sceneKey,
        wordmarkKey: _wordmarkKey,
      ),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr.authEnterPhone, style: AuthText.cardTitle()),
          const SizedBox(height: 2),
          Text(tr.authTextFourDigitCode, style: AuthText.cardSub()),
          const SizedBox(height: 14),
          AuthPhoneField(
            controller: _phone,
            focusNode: _phoneFocus,
            country: _country,
            onCountryChanged: _pickCountry,
            hasError: _phoneError != null,
            onSubmitted: (_) => _continue(),
          ),
          if (_phoneError != null) AuthErrorText(_phoneError!),
          const SizedBox(height: 16),
          // The driver must tick the box before Continue works (stores
          // expect an explicit consent).
          Semantics(
            key: const ValueKey('auth-consent'),
            checked: _agreed,
            label: tr.authConsentLabel,
            onTap: _toggleAgreed,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleAgreed,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _agreed ? AuthColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _agreed
                            ? AuthColors.ink
                            : const Color(0xFFB8C4BC),
                        width: 1.5,
                      ),
                    ),
                    child: _agreed
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: tr.authConsentPrefix,
                        children: [
                          TextSpan(
                            text: tr.authConsentTerms,
                            recognizer: _termsTap,
                            style: AuthText.urbanist(weight: FontWeight.w800),
                          ),
                          TextSpan(text: tr.authAnd),
                          TextSpan(
                            text: tr.authConsentPrivacy,
                            recognizer: _privacyTap,
                            style: AuthText.urbanist(weight: FontWeight.w800),
                          ),
                        ],
                      ),
                      style: AuthText.small().copyWith(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_consentNudge)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  tr.authConsentTickFirst,
                  style: AuthText.small().copyWith(color: AuthColors.error),
                ),
              ),
            ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _agreed ? null : _nudgeConsent,
            child: AuthPrimaryButton(
              key: const ValueKey('auth-continue'),
              label: tr.authContinue,
              busy: _busy,
              onPressed: idle ? _continue : null,
            ),
          ),
        ],
      ),
    );
  }
}
