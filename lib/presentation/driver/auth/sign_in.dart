import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_error_message.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/status_words.g.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_scaffold.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/auth/widgets/need_help.dart';
import 'package:movera/presentation/driver/auth/widgets/balloon_brand_intro.dart';
import 'package:movera/presentation/driver/auth/widgets/slow_server_note.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Step 1 of the driver sign-in: one phone field for new and returning
/// drivers, the consent tick and Continue, then Apple and Google (round
/// 4b). The rider app's sign-in with "Driver" under the wordmark.
class DriverSignIn extends StatefulWidget {
  const DriverSignIn({super.key, this.controller, this.showTestAccounts});

  /// Null: the app root's controller ([DriverRuntimeScope.auth]).
  final AuthController? controller;

  /// Owner 2026-10-29, decision 6 ("Only in test builds"): the test
  /// numbers with their account status under the form. Null: a build with
  /// a server (`MOVERA_API_BASE_URL`) that is not a store build
  /// (`MOVERA_PRODUCTION`).
  final bool? showTestAccounts;

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

  /// Owner decision 5: the number answered `sign_in_restricted`; it can
  /// join the waiting list.
  String? _restrictedNumber;
  bool _waitlistBusy = false;
  bool _waitlistSaved = false;

  /// Owner decision 6: the test numbers (test builds only).
  List<TestAccount> _testAccounts = const [];
  bool _testAccountsAsked = false;

  /// Round 4b: which provider button is working, and which ones the
  /// server or this platform said are not ready ("Coming soon").
  String? _providerBusy;
  final Set<String> _providerSoon = {};
  String? _providerError;

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
    if (!_testAccountsAsked) {
      _testAccountsAsked = true;
      _loadTestAccounts();
    }
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
    if (_phoneError != null || _restrictedNumber != null) {
      setState(() {
        _phoneError = null;
        _restrictedNumber = null;
        _waitlistSaved = false;
      });
    }
  }

  Future<void> _loadTestAccounts() async {
    final auth = _auth;
    // A test build that talks to a server (not a store build, not the demo).
    final testBuild =
        !driverProductionRequested &&
        DriverRuntimeConfig.current.apiBaseUrl.isNotEmpty;
    if (!(widget.showTestAccounts ?? testBuild) || auth == null) {
      return;
    }
    try {
      final accounts = await auth.testAccounts();
      if (mounted) setState(() => _testAccounts = accounts);
    } catch (_) {
      // A production server has no such list (404); nothing to show.
    }
  }

  void _useTestNumber(String e164) {
    final digits = e164.replaceAll('+', '');
    final country = PhoneCountries.ofInternational(digits) ?? _country;
    setState(() => _country = country);
    _phone.text = digits.substring(country.dial.length);
  }

  Future<void> _joinWaitlist() async {
    final number = _restrictedNumber;
    final auth = _auth;
    if (number == null || auth == null || _waitlistBusy) return;
    setState(() => _waitlistBusy = true);
    try {
      await auth.joinWaitlist(number, locale: DriverAppTexts.language);
      if (mounted) setState(() => _waitlistSaved = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _phoneError = authErrorMessage(error, AuthAction.sendCode),
        );
      }
    } finally {
      if (mounted) setState(() => _waitlistBusy = false);
    }
  }

  /// Round 4b: Apple or Google. A linked identity signs in at once; a new
  /// one goes on to the phone step with the link token, and the details
  /// step is prefilled with what the provider gave.
  Future<void> _provider(String provider) async {
    if (_busy || _providerBusy != null) return;
    final auth = _auth;
    if (auth == null) {
      setState(() => _providerError = tr.authErrProvider);
      return;
    }
    setState(() {
      _providerBusy = provider;
      _providerError = null;
      _phoneError = null;
    });
    try {
      final result = await auth.signInWithProvider(provider);
      if (!mounted || result == null) return;
      switch (result) {
        case ProviderSignedIn():
          await enterDriverApp(context);
        case ProviderPhoneRequired():
          _phoneFocus.requestFocus();
          setState(() {});
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isProviderComingSoon(error)) _providerSoon.add(provider);
        _providerError = authErrorMessage(error, AuthAction.providerSignIn);
      });
    } finally {
      if (mounted) setState(() => _providerBusy = null);
    }
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
    setState(() {
      _busy = true;
      _restrictedNumber = null;
      _waitlistSaved = false;
    });
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
      setState(() {
        _phoneError = authErrorMessage(error, AuthAction.sendCode);
        if (isSignInRestricted(error)) _restrictedNumber = number;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idle = !_busy && _providerBusy == null && _agreed;
    final link = _auth?.providerLink;
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
          Text(
            // After Apple / Google: the phone is confirmed once.
            link == null
                ? tr.authTextFourDigitCode
                : tr.authProviderPhoneOnce(link.providerLabel),
            key: ValueKey(link == null ? 'auth-sub-phone' : 'auth-sub-link'),
            style: AuthText.cardSub(),
          ),
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
          if (_restrictedNumber != null) _waitlistRow(),
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
          SlowServerNote(busy: _busy || _providerBusy != null || _waitlistBusy),
          if (link == null) ...[
            const SizedBox(height: 14),
            const AuthOrDivider(),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _agreed ? null : _nudgeConsent,
              child: Row(
                children: [
                  Expanded(
                    child: AuthProviderButton(
                      key: const ValueKey('auth-apple'),
                      label: 'Apple',
                      leading: const Icon(
                        Icons.apple,
                        color: AuthColors.ink,
                        size: 20,
                      ),
                      busy: _providerBusy == 'apple',
                      comingSoon: _providerSoon.contains('apple'),
                      onPressed: idle ? () => _provider('apple') : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthProviderButton(
                      key: const ValueKey('auth-google'),
                      label: 'Google',
                      leading: Image.asset('assets/images/google.png'),
                      busy: _providerBusy == 'google',
                      comingSoon: _providerSoon.contains('google'),
                      onPressed: idle ? () => _provider('google') : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_providerError != null) AuthErrorText(_providerError!),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                button: true,
                label: tr.authUsePhoneInstead,
                onTap: () => setState(_auth!.forgetProvider),
                excludeSemantics: true,
                child: TextButton(
                  key: const ValueKey('auth-forget-provider'),
                  onPressed: () => setState(_auth!.forgetProvider),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.muted,
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    tr.authUsePhoneInstead,
                    style: AuthText.urbanist(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AuthColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          if (_testAccounts.isNotEmpty) _testAccountList(),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: NeedHelpLink(),
          ),
        ],
      ),
    );
  }

  Widget _waitlistRow() {
    if (_waitlistSaved) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Semantics(
          liveRegion: true,
          child: Text(
            tr.authWaitlistSaved,
            key: const ValueKey('auth-waitlist-saved'),
            style: AuthText.small().copyWith(color: AuthColors.green),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: const ValueKey('auth-join-waitlist'),
          onPressed: _waitlistBusy ? null : _joinWaitlist,
          style: OutlinedButton.styleFrom(
            foregroundColor: AuthColors.ink,
            side: const BorderSide(color: AuthColors.ink),
            minimumSize: const Size(0, 40),
          ),
          child: _waitlistBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr.authJoinWaitlist),
        ),
      ),
    );
  }

  Widget _testAccountList() {
    return Padding(
      key: const ValueKey('auth-test-accounts'),
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr.authTestNumbersTitle, style: AuthText.small()),
          for (final account in _testAccounts)
            InkWell(
              key: ValueKey('auth-test-${account.phone}'),
              onTap: () => _useTestNumber(account.phone),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          displayPhoneNumber(account.phone),
                          if (account.name != null) account.name!,
                        ].join(' · '),
                        style: AuthText.small().copyWith(color: AuthColors.ink),
                      ),
                    ),
                    Text(
                      account.status == 'test'
                          ? tr.authTestStatusNew
                          : statusWord(
                                  tr,
                                  'driverAccountStatus',
                                  account.status,
                                ) ??
                                account.status,
                      style: AuthText.small().copyWith(
                        color: account.status == 'active'
                            ? AuthColors.green
                            : AuthColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
