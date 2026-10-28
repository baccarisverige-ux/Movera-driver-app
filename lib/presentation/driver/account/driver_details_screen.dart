import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/account/org_number.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/details_pickers.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_scaffold.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Step 3 of the sign-in (round 4b): the details Movera needs once
/// (contract v0.5.3 §14, `POST /driver/onboarding`), on one scrollable
/// screen under the same head as steps 1 and 2 (wordmark, "Driver",
/// headline). Name, date of birth, e-mail, country (a picker with flags),
/// city and language (pickers), the account type (a driver who works for
/// a fleet, or a fleet with its company), an optional fleet request, and
/// the terms.
///
/// Round 4b additions: the phone is shown read-only; Apple / Google
/// prefill the names and e-mail (editable); picking the language switches
/// the app at once; the company number is checked per country; a draft is
/// kept on the phone while the app is closed; Back signs out (step 1);
/// and Profile opens the same screen in [editing] mode while the account
/// is on hold (a resend replaces the details).
class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({
    super.key,
    required this.account,
    required this.onDone,
    this.clock,
    this.phone,
    this.prefill,
    this.editing = false,
    this.onBack,
    this.draft,
  });

  final DriverAccountSession account;

  /// Called once the server took the details: opens the app (or pops,
  /// when [editing]).
  final void Function(BuildContext context) onDone;

  /// Today, for the age check (tests).
  final DateTime Function()? clock;

  /// The number the session was opened with (E.164), shown read-only.
  final String? phone;

  /// What Apple / Google gave: names and e-mail, all editable.
  final ProviderLink? prefill;

  /// Profile › Your details while the account is on hold: Back pops, the
  /// fields start from the account.
  final bool editing;

  /// What Back does; null in the sign-in flow signs out (step 1).
  final VoidCallback? onBack;

  /// The draft store (tests hand in one over a memory settings store).
  final DetailsDraft? draft;

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _email = TextEditingController();
  final _companyName = TextEditingController();
  final _orgNumber = TextEditingController();
  final _companyAddress = TextEditingController();
  final _joinCode = TextEditingController();
  final _joinOwner = TextEditingController();
  final _joinEmail = TextEditingController();

  late String _country;
  String? _cityId;
  late String _language;
  String _accountType = 'driver';
  bool _joinOpen = false;
  bool _agreed = false;
  bool _busy = false;
  bool _leaving = false;
  final Map<DetailsField, String> _errors = {};
  String? _formError;
  late final DetailsDraft _draft = widget.draft ?? DetailsDraft();
  bool _restored = false;

  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.privacy);

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _dateOfBirth,
    _email,
    _companyName,
    _orgNumber,
    _companyAddress,
    _joinCode,
    _joinOwner,
    _joinEmail,
  ];

  @override
  void initState() {
    super.initState();
    final account = widget.account.account;
    final market = DriverAccountRules.current.country;
    _country = account?.country ?? (_open(market) ? market : 'SE');
    _cityId = account?.cityId ?? _onlyCity(_country);
    _language = account?.language ?? DriverAppTexts.language;
    if (!DriverLanguage.supported.contains(_language)) _language = 'en';
    _accountType = account?.accountType ?? 'driver';
    final prefill = widget.prefill;
    String? known(String? value) =>
        value != null && value.trim().isNotEmpty ? value : null;
    _firstName.text = known(account?.firstName) ?? prefill?.firstName ?? '';
    _lastName.text = known(account?.lastName) ?? prefill?.lastName ?? '';
    _dateOfBirth.text = account?.dateOfBirth ?? '';
    _email.text = known(account?.email) ?? prefill?.email ?? '';
    // A resend: the terms were accepted the first time.
    _agreed = account?.accountStatus == 'on_hold';
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
    // A sign-up that was interrupted: what was typed comes back. An
    // account that already has details (editing) starts from them.
    if (!widget.editing &&
        !(account?.canSendDetails == true &&
            account?.accountStatus == 'on_hold')) {
      unawaited(_restoreDraft());
    } else {
      _restored = true;
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    // The last keystrokes, before the screen goes.
    unawaited(_draft.flush());
    _draft.dispose();
    super.dispose();
  }

  static bool _open(String country) => DriverOnboardingRules.isOpen(country);

  static String? _onlyCity(String country) {
    final cities = DriverOnboardingRules.citiesOf(country);
    return cities.length == 1 ? cities.single.cityId : null;
  }

  Future<void> _restoreDraft() async {
    final saved = await _draft.restore();
    if (!mounted) return;
    String? text(String key) {
      final value = saved[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    setState(() {
      // The provider's names and e-mail are fresher than an old draft of
      // the same person; an empty field takes the draft.
      void fill(TextEditingController c, String key) {
        if (c.text.trim().isEmpty) c.text = text(key) ?? '';
      }

      fill(_firstName, 'firstName');
      fill(_lastName, 'lastName');
      fill(_dateOfBirth, 'dateOfBirth');
      fill(_email, 'email');
      fill(_companyName, 'companyName');
      fill(_orgNumber, 'orgNumber');
      fill(_companyAddress, 'companyAddress');
      fill(_joinCode, 'joinCode');
      fill(_joinOwner, 'joinOwner');
      fill(_joinEmail, 'joinEmail');
      final country = text('country');
      if (country != null && _open(country)) {
        _country = country;
        _cityId = _onlyCity(country);
      }
      final city = text('cityId');
      if (city != null && _citiesOf(_country).any((c) => c.cityId == city)) {
        _cityId = city;
      }
      final type = text('accountType');
      if (type != null && DriverOnboardingRules.accountTypes.contains(type)) {
        _accountType = type;
      }
      _joinOpen = saved['joinOpen'] == true;
      _restored = true;
    });
  }

  static List<OnboardingCity> _citiesOf(String country) =>
      DriverOnboardingRules.citiesOf(country);

  /// A field changed: the errors go, the draft is saved.
  void _changed() {
    if (_errors.isNotEmpty || _formError != null) {
      setState(() {
        _errors.clear();
        _formError = null;
      });
    }
    _saveDraft();
  }

  void _saveDraft() {
    if (!_restored || widget.editing) return;
    _draft.save({
      'firstName': _firstName.text,
      'lastName': _lastName.text,
      'dateOfBirth': _dateOfBirth.text,
      'email': _email.text,
      'country': _country,
      'cityId': _cityId,
      'language': _language,
      'accountType': _accountType,
      'companyName': _companyName.text,
      'orgNumber': _orgNumber.text,
      'companyAddress': _companyAddress.text,
      'joinOpen': _joinOpen,
      'joinCode': _joinCode.text,
      'joinOwner': _joinOwner.text,
      'joinEmail': _joinEmail.text,
    });
  }

  void _openLegal(Widget page) {
    pushSingle(context, RightToLeftTransition(page));
  }

  Future<void> _pickCountry() async {
    final picked = await showDetailsCountryPicker(context, selected: _country);
    if (picked == null || !mounted || !_open(picked)) return;
    setState(() {
      _country = picked;
      _cityId = _onlyCity(picked);
      _errors.remove(DetailsField.country);
      _errors.remove(DetailsField.city);
      _errors.remove(DetailsField.company);
    });
    _saveDraft();
  }

  Future<void> _pickCity() async {
    final picked = await showDetailsCityPicker(
      context,
      country: _country,
      selected: _cityId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _cityId = picked;
      _errors.remove(DetailsField.city);
    });
    _saveDraft();
  }

  /// The language the app speaks from now on, and the one saved with the
  /// details (the app opens in it on every phone).
  Future<void> _pickLanguage() async {
    final picked = await showDetailsLanguagePicker(
      context,
      selected: _language,
    );
    if (picked == null || !mounted || picked == _language) return;
    setState(() => _language = picked);
    _saveDraft();
    unawaited(DriverLanguage.choose(picked).catchError((_) {}));
  }

  Future<void> _pickDate() async {
    final now = (widget.clock ?? DateTime.now)();
    final typed = DateTime.tryParse(_dateOfBirth.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: typed ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: tr.acctDateOfBirth,
    );
    if (picked == null || !mounted) return;
    String two(int n) => n.toString().padLeft(2, '0');
    _dateOfBirth.text =
        '${picked.year}-${two(picked.month)}-${two(picked.day)}';
  }

  DateTime? get _birthDate {
    final text = _dateOfBirth.text.trim();
    if (!_datePattern.hasMatch(text)) return null;
    final date = DateTime.tryParse(text);
    if (date == null) return null;
    // `DateTime.parse` rolls 2000-02-31 over; refuse such dates.
    final parts = text.split('-').map(int.parse).toList();
    if (date.month != parts[1] || date.day != parts[2]) return null;
    return date;
  }

  bool get _joinFilled =>
      _joinCode.text.trim().isNotEmpty ||
      _joinOwner.text.trim().isNotEmpty ||
      _joinEmail.text.trim().isNotEmpty;

  /// Client-side checks: the same rules the server applies, so the driver
  /// sees them under the field before a round trip.
  bool _validate() {
    final errors = <DetailsField, String>{};
    if (_firstName.text.trim().isEmpty) {
      errors[DetailsField.firstName] = tr.acctRequired;
    }
    if (_lastName.text.trim().isEmpty) {
      errors[DetailsField.lastName] = tr.acctRequired;
    }
    final birth = _birthDate;
    if (_dateOfBirth.text.trim().isEmpty) {
      errors[DetailsField.dateOfBirth] = tr.acctRequired;
    } else if (birth == null) {
      errors[DetailsField.dateOfBirth] = tr.acctInvalidDate;
    } else if (DriverOnboardingRules.ageAt(
          birth,
          (widget.clock ?? DateTime.now)(),
        ) <
        DriverOnboardingRules.minAge) {
      errors[DetailsField.dateOfBirth] = tr.acctUnderAge(
        DriverOnboardingRules.minAge,
      );
    }
    if (!_emailPattern.hasMatch(_email.text.trim())) {
      errors[DetailsField.email] = tr.acctInvalidEmail;
    }
    if (!_open(_country)) errors[DetailsField.country] = tr.acctCountryNotOpen;
    if (_cityId == null) errors[DetailsField.city] = tr.acctInvalidCity;
    if (_accountType == 'fleet') {
      if (_companyName.text.trim().isEmpty ||
          _orgNumber.text.trim().isEmpty ||
          _companyAddress.text.trim().isEmpty) {
        errors[DetailsField.company] = tr.acctCompanyRequired;
      } else if (!OrgNumber.isValid(_orgNumber.text, _country)) {
        errors[DetailsField.company] = _orgNumberError;
      }
    }
    if (_accountType == 'driver' && _joinOpen && _joinFilled) {
      if (_joinCode.text.trim().isEmpty ||
          _joinOwner.text.trim().isEmpty ||
          !_emailPattern.hasMatch(_joinEmail.text.trim())) {
        errors[DetailsField.fleetJoin] = tr.acctRequired;
      }
    }
    if (!_agreed) errors[DetailsField.terms] = tr.acctTermsRequired;
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _formError = null;
    });
    return errors.isEmpty;
  }

  String get _orgNumberError =>
      _country == 'FR' ? tr.acctOrgNumberFrRule : tr.acctOrgNumberSeRule;

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    final request = DriverDetailsRequest(
      firstName: _firstName.text,
      lastName: _lastName.text,
      dateOfBirth: _dateOfBirth.text.trim(),
      email: _email.text,
      country: _country,
      cityId: _cityId!,
      language: _language,
      accountType: _accountType,
      company: _accountType == 'fleet'
          ? FleetCompany(
              name: _companyName.text,
              orgNumber: _orgNumber.text,
              address: _companyAddress.text,
            )
          : null,
      fleetJoin: _accountType == 'driver' && _joinOpen && _joinFilled
          ? FleetJoinRequest(
              code: _joinCode.text,
              ownerName: _joinOwner.text,
              ownerEmail: _joinEmail.text,
            )
          : null,
    );
    setState(() => _busy = true);
    try {
      final account = await widget.account.repository.submitDetails(request);
      widget.account.replace(account);
      await _draft.clear();
      if (!mounted) return;
      widget.onDone(context);
    } catch (error) {
      if (!mounted) return;
      final message = accountErrorMessage(error, fallback: tr.acctCouldNotSend);
      final field = detailsFieldOf(error);
      setState(() {
        if (field != null) {
          _errors[field] = message;
        } else {
          _formError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back on step 3 is the way out of the sign-in: the session ends and
  /// step 1 comes back (the draft stays on this phone until the sign-out
  /// clears local data).
  Future<void> _back() async {
    if (_busy || _leaving) return;
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(tr.acctLeaveSignUpQ),
        content: Text(tr.acctLeaveSignUpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(tr.stay),
          ),
          FilledButton(
            key: const ValueKey('details-sign-out'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AccountStyle.ink),
            child: Text(tr.logOut),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _leaving = true);
    final scope = DriverRuntimeScope.maybeOf(context);
    try {
      await scope?.logout?.call();
    } catch (_) {
      // The tokens are gone either way (AuthController.signOut clears
      // them before anything else can fail); step 1 is right.
    }
    if (!mounted) return;
    final signIn = driverRootAfterSignOut(scope);
    final navigator = Navigator.of(context, rootNavigator: true);
    if (signIn == null) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      showDriverSignIn(navigator, signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: AuthColors.ground,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const ValueKey('details-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                      child: AuthTopBar(
                        step: 3,
                        totalSteps: 3,
                        showSteps: !widget.editing,
                        onBack: _leaving ? null : _back,
                      ),
                    ),
                    AuthStepHeader(
                      headline: tr.acctDetailsHead,
                      headlineAccent: tr.acctDetailsAccent,
                      headlineSize: 34,
                      lede: Text(
                        widget.editing
                            ? tr.acctDetailsEditIntro
                            : tr.acctDetailsIntro,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 30,
                        offset: Offset(0, -10),
                      ),
                    ],
                  ),
                  child: _form(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final prefill = widget.prefill;
    final phone = widget.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3DE),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (phone != null && phone.isNotEmpty) ...[
          _label(tr.acctPhone),
          _ReadOnlyBox(
            key: const ValueKey('details-phone'),
            text: displayPhoneNumber(phone),
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                key: 'details-first-name',
                label: tr.acctFirstName,
                controller: _firstName,
                error: _errors[DetailsField.firstName],
                capitalization: TextCapitalization.words,
                autofill: AutofillHints.givenName,
                bottom: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                key: 'details-last-name',
                label: tr.acctLastName,
                controller: _lastName,
                error: _errors[DetailsField.lastName],
                capitalization: TextCapitalization.words,
                autofill: AutofillHints.familyName,
                bottom: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _field(
          key: 'details-email',
          label: tr.acctEmail,
          controller: _email,
          error: _errors[DetailsField.email],
          keyboard: TextInputType.emailAddress,
          autofill: AutofillHints.email,
          chip: prefill?.email != null
              ? _ProviderChip(provider: prefill!.provider)
              : null,
        ),
        _field(
          key: 'details-dob',
          label: tr.acctDateOfBirth,
          controller: _dateOfBirth,
          error: _errors[DetailsField.dateOfBirth],
          hint: 'YYYY-MM-DD',
          keyboard: TextInputType.datetime,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
            LengthLimitingTextInputFormatter(10),
          ],
          suffix: IconButton(
            key: const ValueKey('details-pick-date'),
            tooltip: tr.acctPickDate,
            onPressed: _busy ? null : _pickDate,
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: AccountStyle.ink,
              size: 20,
            ),
          ),
        ),
        _label(tr.acctCountry),
        _PickBox(
          key: const ValueKey('details-country'),
          leading: Text(
            countryFlag(_country),
            style: const TextStyle(fontSize: 24, height: 1),
          ),
          title: countryName(_country),
          onTap: _busy ? null : _pickCountry,
          error: _errors[DetailsField.country],
        ),
        const SizedBox(height: 14),
        _label(tr.acctCity),
        _PickBox(
          key: const ValueKey('details-city'),
          title:
              _citiesOf(_country)
                  .where((c) => c.cityId == _cityId)
                  .map((c) => c.name)
                  .firstOrNull ??
              tr.acctChooseCity,
          subtitle: cityHint(_cityId),
          muted: _cityId == null,
          onTap: _busy ? null : _pickCity,
          error: _errors[DetailsField.city],
        ),
        const SizedBox(height: 14),
        _label(tr.acctLanguage),
        _PickBox(
          key: const ValueKey('details-language'),
          title: DriverLanguage.names[_language] ?? _language,
          onTap: _busy ? null : _pickLanguage,
        ),
        const SizedBox(height: 18),
        _label(tr.acctAccountType),
        _TypeCard(
          key: const ValueKey('details-type-driver'),
          title: tr.acctTypeDriverTitle,
          body: tr.acctTypeDriverBody,
          icon: Icons.person_rounded,
          selected: _accountType == 'driver',
          onTap: _busy
              ? null
              : () {
                  setState(() => _accountType = 'driver');
                  _saveDraft();
                },
        ),
        const SizedBox(height: 10),
        _TypeCard(
          key: const ValueKey('details-type-fleet'),
          title: tr.acctTypeFleetTitle,
          body: tr.acctTypeFleetBody,
          icon: Icons.apartment_rounded,
          selected: _accountType == 'fleet',
          onTap: _busy
              ? null
              : () {
                  setState(() => _accountType = 'fleet');
                  _saveDraft();
                },
        ),
        const SizedBox(height: 18),
        if (_accountType == 'fleet') ...[
          _field(
            key: 'details-company-name',
            label: tr.acctCompanyName,
            controller: _companyName,
            capitalization: TextCapitalization.words,
            autofill: AutofillHints.organizationName,
          ),
          _field(
            key: 'details-org-number',
            label: _country == 'FR' ? tr.acctOrgNumberFr : tr.acctOrgNumberSe,
            controller: _orgNumber,
            hint: OrgNumber.hintFor(_country),
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
              LengthLimitingTextInputFormatter(
                OrgNumber.maxLengthFor(_country),
              ),
            ],
          ),
          _field(
            key: 'details-company-address',
            label: tr.acctCompanyAddress,
            controller: _companyAddress,
            error: _errors[DetailsField.company],
            hint: tr.acctCompanyAddressHint,
            capitalization: TextCapitalization.sentences,
            autofill: AutofillHints.fullStreetAddress,
          ),
        ] else ...[
          _JoinBox(
            open: _joinOpen,
            onToggle: _busy
                ? null
                : () {
                    setState(() => _joinOpen = !_joinOpen);
                    _saveDraft();
                  },
            children: [
              _field(
                key: 'details-join-code',
                label: tr.acctFleetCode,
                controller: _joinCode,
                hint: 'MV-',
                capitalization: TextCapitalization.characters,
                white: true,
              ),
              _field(
                key: 'details-join-owner',
                label: tr.acctOwnerName,
                controller: _joinOwner,
                capitalization: TextCapitalization.words,
                white: true,
              ),
              _field(
                key: 'details-join-email',
                label: tr.acctOwnerEmail,
                controller: _joinEmail,
                error: _errors[DetailsField.fleetJoin],
                hint: tr.acctOwnerEmailHint,
                keyboard: TextInputType.emailAddress,
                bottom: 4,
                white: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        _Consent(
          agreed: _agreed,
          onToggle: _busy
              ? null
              : () => setState(() {
                  _agreed = !_agreed;
                  _errors.remove(DetailsField.terms);
                }),
          termsTap: _termsTap,
          privacyTap: _privacyTap,
        ),
        if (_errors[DetailsField.terms] != null)
          AccountErrorLine(_errors[DetailsField.terms]!),
        if (_formError != null) AccountErrorLine(_formError!),
        const SizedBox(height: 18),
        AccountButton(
          key: const ValueKey('details-continue'),
          label: widget.editing ? tr.acctSaveDetails : tr.authContinue,
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _label(String text, {Widget? chip}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Flexible(child: Text(text.toUpperCase(), style: DetailsStyle.label())),
        if (chip != null) ...[const SizedBox(width: 8), chip],
      ],
    ),
  );

  Widget _field({
    required String key,
    required String label,
    required TextEditingController controller,
    String? error,
    String? hint,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    String? autofill,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
    Widget? chip,
    double bottom = 14,
    bool white = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, chip: chip),
          TextField(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            keyboardType: keyboard,
            textCapitalization: capitalization,
            autofillHints: autofill == null ? null : [autofill],
            inputFormatters: formatters,
            style: AuthText.urbanist(size: 16, weight: FontWeight.w600),
            cursorColor: AccountStyle.ink,
            decoration: DetailsStyle.decoration(
              hint: hint,
              error: error,
              white: white,
            ).copyWith(suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}

/// The look of the details step's boxes: soft grey fields with no visible
/// border until focused, uppercase small labels (the approved mock-up).
abstract final class DetailsStyle {
  static const field = Color(0xFFF5F7F4);
  static const label_ = Color(0xFF65716B);

  static TextStyle label() => AuthText.urbanist(
    size: 11.5,
    weight: FontWeight.w800,
    letterSpacing: 1.2,
    color: label_,
  );

  static InputDecoration decoration({
    String? hint,
    String? error,
    bool white = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    final fill = white ? Colors.white : field;
    return InputDecoration(
      hintText: hint,
      hintStyle: AuthText.urbanist(size: 16, color: const Color(0xFF9AA49D)),
      errorText: error,
      errorStyle: AuthText.urbanist(size: 12.5, color: AccountStyle.error),
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(fill),
      enabledBorder: border(fill),
      disabledBorder: border(fill),
      focusedBorder: border(AccountStyle.ink),
      errorBorder: border(AccountStyle.error),
      focusedErrorBorder: border(AccountStyle.error),
    );
  }
}

/// The phone, as it was confirmed: not editable here.
class _ReadOnlyBox extends StatelessWidget {
  const _ReadOnlyBox({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DetailsStyle.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AuthText.urbanist(
                size: 16,
                weight: FontWeight.w600,
                color: AuthColors.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Icon(icon, size: 18, color: AuthColors.muted),
        ],
      ),
    );
  }
}

/// A value that opens a picker sheet: flag or nothing, the value, a small
/// line under it, a chevron.
class _PickBox extends StatelessWidget {
  const _PickBox({
    super.key,
    required this.title,
    required this.onTap,
    this.leading,
    this.subtitle,
    this.muted = false,
    this.error,
  });

  final String title;
  final VoidCallback? onTap;
  final Widget? leading;
  final String? subtitle;
  final bool muted;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: subtitle == null ? title : '$title, $subtitle',
          hint: tr.acctTapToChange,
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: DetailsStyle.field,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: error == null
                    ? null
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AccountStyle.error,
                          width: 1.5,
                        ),
                      ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AuthText.urbanist(
                              size: 16,
                              weight: FontWeight.w600,
                              color: muted
                                  ? const Color(0xFF9AA49D)
                                  : AuthColors.ink,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AuthText.urbanist(
                                size: 12,
                                color: AuthColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AuthColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) AccountErrorLine(error!),
      ],
    );
  }
}

/// "from Google": the e-mail came from the provider (still editable).
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final label = provider == 'apple' ? 'Apple' : 'Google';
    return Container(
      key: ValueKey('details-from-$provider'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider == 'apple')
            const Icon(Icons.apple, size: 13, color: AuthColors.green)
          else
            Image.asset('assets/images/google.png', width: 12, height: 12),
          const SizedBox(width: 5),
          Text(
            tr.acctFromProvider(label),
            style: AuthText.urbanist(
              size: 11,
              weight: FontWeight.w800,
              color: AuthColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $body',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F6F2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AccountStyle.ink : AccountStyle.line,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AuthColors.green : AccountStyle.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuthText.urbanist(
                        size: 16,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: AccountStyle.hint()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AccountStyle.ink : const Color(0xFFC7CFC9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Join your fleet now": a soft box, "Later" leaves it closed.
class _JoinBox extends StatelessWidget {
  const _JoinBox({
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final bool open;
  final VoidCallback? onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DetailsStyle.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('details-join-toggle'),
            borderRadius: BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.acctJoinNow,
                          style: AuthText.urbanist(
                            size: 15,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          open ? tr.acctJoinNowShort : tr.acctJoinNowBody,
                          style: AccountStyle.hint(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    open ? tr.now : tr.later,
                    style: AuthText.urbanist(size: 14, weight: FontWeight.w800),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AccountStyle.ink,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({
    required this.agreed,
    required this.onToggle,
    required this.termsTap,
    required this.privacyTap,
  });

  final bool agreed;
  final VoidCallback? onToggle;
  final TapGestureRecognizer termsTap;
  final TapGestureRecognizer privacyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          key: const ValueKey('details-terms'),
          checked: agreed,
          label: tr.authConsentLabel,
          onTap: onToggle,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 12, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: agreed ? AccountStyle.ink : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: agreed ? AccountStyle.ink : const Color(0xFFC7CFC9),
                    width: 2,
                  ),
                ),
                child: agreed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: tr.authConsentPrefix,
              children: [
                TextSpan(
                  text: tr.authConsentTerms,
                  recognizer: termsTap,
                  style: AuthText.urbanist(
                    weight: FontWeight.w800,
                    color: AuthColors.ink,
                  ),
                ),
                TextSpan(text: tr.authAnd),
                TextSpan(
                  text: tr.authConsentPrivacy,
                  recognizer: privacyTap,
                  style: AuthText.urbanist(
                    weight: FontWeight.w800,
                    color: AuthColors.ink,
                  ),
                ),
              ],
            ),
            style: AuthText.urbanist(
              size: 13.5,
              height: 1.4,
              color: AuthColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}
