import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// The details Movera needs once, after the first sign-in (contract v0.5.3
/// §14, `POST /driver/onboarding`): name, date of birth, e-mail, country
/// and city, language, the account type (a driver who works for a fleet,
/// or a fleet with its company), an optional fleet code, and the terms.
/// Allowed again while the account is pending or on hold (a resend
/// replaces the details). Plain and professional: white, Urbanist, ink.
class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({
    super.key,
    required this.account,
    required this.onDone,
    this.clock,
  });

  final DriverAccountSession account;

  /// Called once the server took the details: opens the app.
  final void Function(BuildContext context) onDone;

  /// Today, for the age check (tests).
  final DateTime Function()? clock;

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
  final Map<DetailsField, String> _errors = {};
  String? _formError;

  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(LegalDocumentScreen.privacy);

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

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
    _firstName.text = account?.firstName ?? '';
    _lastName.text = account?.lastName ?? '';
    _dateOfBirth.text = account?.dateOfBirth ?? '';
    _email.text = account?.email ?? '';
    // A resend: the terms were accepted the first time.
    _agreed = account?.accountStatus == 'on_hold';
    for (final controller in [
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
    ]) {
      controller.addListener(_clearErrors);
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    for (final controller in [
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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static bool _open(String country) =>
      DriverOnboardingRules.countries[country]?.open ?? false;

  static String? _onlyCity(String country) {
    final cities = DriverOnboardingRules.countries[country]?.cities ?? const [];
    return cities.length == 1 ? cities.single.cityId : null;
  }

  void _clearErrors() {
    if (_errors.isEmpty && _formError == null) return;
    setState(() {
      _errors.clear();
      _formError = null;
    });
  }

  void _openLegal(Widget page) {
    pushSingle(context, RightToLeftTransition(page));
  }

  void _pickCountry(String country) {
    if (!_open(country)) return;
    setState(() {
      _country = country;
      _cityId = _onlyCity(country);
      _errors.remove(DetailsField.country);
      _errors.remove(DetailsField.city);
    });
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
    if (_accountType == 'fleet' &&
        (_companyName.text.trim().isEmpty ||
            _orgNumber.text.trim().isEmpty ||
            _companyAddress.text.trim().isEmpty)) {
      errors[DetailsField.company] = tr.acctCompanyRequired;
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

  @override
  Widget build(BuildContext context) {
    final cities =
        DriverOnboardingRules.countries[_country]?.cities ?? const [];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(context, tr.acctDetailsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(tr.acctDetailsIntro, style: AccountStyle.hint()),
            const SizedBox(height: 20),
            _field(
              key: 'details-first-name',
              label: tr.acctFirstName,
              controller: _firstName,
              error: _errors[DetailsField.firstName],
              capitalization: TextCapitalization.words,
              autofill: AutofillHints.givenName,
            ),
            _field(
              key: 'details-last-name',
              label: tr.acctLastName,
              controller: _lastName,
              error: _errors[DetailsField.lastName],
              capitalization: TextCapitalization.words,
              autofill: AutofillHints.familyName,
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
            _field(
              key: 'details-email',
              label: tr.acctEmail,
              controller: _email,
              error: _errors[DetailsField.email],
              keyboard: TextInputType.emailAddress,
              autofill: AutofillHints.email,
            ),
            _label(tr.acctCountry),
            _CountryChoice(
              selected: _country,
              onPick: _busy ? null : _pickCountry,
            ),
            if (_errors[DetailsField.country] != null)
              AccountErrorLine(_errors[DetailsField.country]!),
            const SizedBox(height: 16),
            _label(tr.acctCity),
            DropdownButtonFormField<String>(
              key: const ValueKey('details-city'),
              initialValue: cities.any((c) => c.cityId == _cityId)
                  ? _cityId
                  : null,
              items: [
                for (final city in cities)
                  DropdownMenuItem(
                    value: city.cityId,
                    child: Text(city.name, style: AccountStyle.body()),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _cityId = value;
                      _errors.remove(DetailsField.city);
                    }),
              hint: Text(tr.acctChooseCity, style: AccountStyle.hint()),
              decoration: AccountStyle.decoration(
                error: _errors[DetailsField.city],
              ),
              icon: const Icon(
                Icons.expand_more_rounded,
                color: AccountStyle.ink,
              ),
            ),
            const SizedBox(height: 16),
            _label(tr.acctLanguage),
            _Segments(
              options: [
                for (final code in DriverLanguage.supported)
                  (code, DriverLanguage.names[code] ?? code, true),
              ],
              selected: _language,
              keyPrefix: 'details-language',
              onPick: _busy ? null : (code) => setState(() => _language = code),
            ),
            const SizedBox(height: 20),
            _label(tr.acctAccountType),
            _TypeCard(
              key: const ValueKey('details-type-driver'),
              title: tr.acctTypeDriverTitle,
              body: tr.acctTypeDriverBody,
              icon: Icons.person_outline_rounded,
              selected: _accountType == 'driver',
              onTap: _busy
                  ? null
                  : () => setState(() => _accountType = 'driver'),
            ),
            const SizedBox(height: 10),
            _TypeCard(
              key: const ValueKey('details-type-fleet'),
              title: tr.acctTypeFleetTitle,
              body: tr.acctTypeFleetBody,
              icon: Icons.business_outlined,
              selected: _accountType == 'fleet',
              onTap: _busy
                  ? null
                  : () => setState(() => _accountType = 'fleet'),
            ),
            const SizedBox(height: 20),
            if (_accountType == 'fleet') ...[
              _field(
                key: 'details-company-name',
                label: tr.acctCompanyName,
                controller: _companyName,
                capitalization: TextCapitalization.words,
              ),
              _field(
                key: 'details-org-number',
                label: _country == 'FR'
                    ? tr.acctOrgNumberFr
                    : tr.acctOrgNumberSe,
                controller: _orgNumber,
                keyboard: TextInputType.text,
              ),
              _field(
                key: 'details-company-address',
                label: tr.acctCompanyAddress,
                controller: _companyAddress,
                error: _errors[DetailsField.company],
                capitalization: TextCapitalization.sentences,
                autofill: AutofillHints.fullStreetAddress,
              ),
            ] else ...[
              _JoinBox(
                open: _joinOpen,
                onToggle: _busy
                    ? null
                    : () => setState(() => _joinOpen = !_joinOpen),
                children: [
                  _field(
                    key: 'details-join-code',
                    label: tr.acctFleetCode,
                    controller: _joinCode,
                    hint: 'MV-',
                    capitalization: TextCapitalization.characters,
                  ),
                  _field(
                    key: 'details-join-owner',
                    label: tr.acctOwnerName,
                    controller: _joinOwner,
                    capitalization: TextCapitalization.words,
                  ),
                  _field(
                    key: 'details-join-email',
                    label: tr.acctOwnerEmail,
                    controller: _joinEmail,
                    error: _errors[DetailsField.fleetJoin],
                    keyboard: TextInputType.emailAddress,
                    bottom: 4,
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            AccountButton(
              key: const ValueKey('details-continue'),
              label: tr.authContinue,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AccountStyle.label()),
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
    double bottom = 16,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            keyboardType: keyboard,
            textCapitalization: capitalization,
            autofillHints: autofill == null ? null : [autofill],
            inputFormatters: formatters,
            style: AuthText.urbanist(size: 15),
            cursorColor: AccountStyle.ink,
            decoration: AccountStyle.decoration(
              hint: hint,
              error: error,
            ).copyWith(suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}

/// Sweden, France and Tunisia; a country that is not open yet is shown
/// but cannot be picked ("Coming soon").
class _CountryChoice extends StatelessWidget {
  const _CountryChoice({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    String name(String code) => switch (code) {
      'SE' => tr.acctCountrySweden,
      'FR' => tr.acctCountryFrance,
      'TN' => tr.acctCountryTunisia,
      _ => code,
    };
    return _Segments(
      options: [
        for (final MapEntry(key: code, value: country)
            in DriverOnboardingRules.countries.entries)
          (code, name(code), country.open),
      ],
      selected: selected,
      keyPrefix: 'details-country',
      onPick: onPick,
      closedTag: tr.acctComingSoon,
    );
  }
}

/// A row of equal segments; a closed one shows [closedTag] and is disabled.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.options,
    required this.selected,
    required this.keyPrefix,
    required this.onPick,
    this.closedTag,
  });

  final List<(String code, String label, bool open)> options;
  final String selected;
  final String keyPrefix;
  final ValueChanged<String>? onPick;
  final String? closedTag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _segment(options[i])),
        ],
      ],
    );
  }

  Widget _segment((String, String, bool) option) {
    final (code, label, open) = option;
    final isSelected = code == selected;
    final enabled = open && onPick != null;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: open ? label : '$label, ${closedTag ?? ''}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('$keyPrefix-$code'),
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => onPick!(code) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AccountStyle.ink : AccountStyle.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AccountStyle.ink : AccountStyle.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuthText.urbanist(
                  size: 14,
                  weight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : open
                      ? AccountStyle.ink
                      : AuthColors.disabledText,
                ),
              ),
              if (!open && closedTag != null)
                Text(
                  closedTag!,
                  textAlign: TextAlign.center,
                  style: AuthText.urbanist(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: AccountStyle.amber,
                  ),
                ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F6F3) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AccountStyle.ink : AccountStyle.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AccountStyle.ink, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AccountStyle.rowTitle()),
                    const SizedBox(height: 2),
                    Text(body, style: AccountStyle.hint()),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AccountStyle.ink : AccountStyle.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Join your fleet now": a collapsible box, "Later" leaves it closed.
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AccountStyle.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('details-join-toggle'),
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.acctJoinNow, style: AccountStyle.rowTitle()),
                        const SizedBox(height: 2),
                        Text(tr.acctJoinNowBody, style: AccountStyle.hint()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    open ? '' : tr.later,
                    style: AuthText.urbanist(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AccountStyle.muted,
                    ),
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
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
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
                    color: agreed ? AccountStyle.ink : const Color(0xFFB8C4BC),
                    width: 1.5,
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
                  style: AuthText.urbanist(weight: FontWeight.w800),
                ),
                TextSpan(text: tr.authAnd),
                TextSpan(
                  text: tr.authConsentPrivacy,
                  recognizer: privacyTap,
                  style: AuthText.urbanist(weight: FontWeight.w800),
                ),
              ],
            ),
            style: AuthText.urbanist(
              size: 13,
              height: 1.4,
              color: AuthColors.faint,
            ),
          ),
        ),
      ],
    );
  }
}
