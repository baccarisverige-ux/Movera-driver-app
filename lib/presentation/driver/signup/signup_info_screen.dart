import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/details_pickers.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/signup/signup_checklist_screen.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';

/// Contract v0.18.166 (`signupV2.infoScreen`, owner 2026-11-26 "Oui, tout
/// construire" + "Oui, ajouter l'adresse (Recommandé)"): after the SMS code,
/// ONE scrollable screen "Vos informations" / "Dina uppgifter": Pays then
/// Région (bottom-sheet lists of the open countries / regions, one region =
/// picked by itself), the locked phone, first and last name, e-mail, the
/// country's fields (FR date of birth; SE personnummer and the taxi licence
/// number), the home address (under the date of birth / personnummer, with
/// suggestions while typing) and the language. "Continuer" saves country
/// and region (`PUT /driver/country { country, cityId }`) and opens the
/// checklist. Replaces the separate country screen (its route stays).
class SignupInfoScreen extends StatefulWidget {
  const SignupInfoScreen({super.key, required this.flow});

  final SignupFlow flow;

  @override
  State<SignupInfoScreen> createState() => _SignupInfoScreenState();
}

class _SignupInfoScreenState extends State<SignupInfoScreen> {
  SignupFlow get flow => widget.flow;
  SignupData get data => flow.data;

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _date = TextEditingController();
  final _personal = TextEditingController();
  final _taxi = TextEditingController();
  final _street = TextEditingController();
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final Map<String, String> _errors = {};
  String? _formError;
  bool _countryFromPhone = false;
  bool _busy = false;
  bool _ready = false;
  OnboardingSettings? _settings;
  Timer? _searchTimer;
  List<DestinationPlace> _suggestions = const [];
  int _searchRun = 0;

  List<String> get _open => [
    for (final code in DriverOnboardingRules.countries.keys)
      if (DriverOnboardingRules.isOpen(code)) code,
  ];

  @override
  void initState() {
    super.initState();
    later(_start());
  }

  Future<void> _start() async {
    await flow.restore();
    final profile = flow.profile;
    String? known(String? v) => v != null && v.trim().isNotEmpty ? v : null;
    data.country ??= profile?.country;
    if (data.country == null) {
      data.country = countryOfPhone(flow.phone);
      _countryFromPhone = data.country != null;
    } else {
      _countryFromPhone = countryOfPhone(flow.phone) == data.country;
    }
    if (data.country == null) {
      // Only when the location permission is ALREADY granted (never asked).
      final device = await flow.deviceCountry?.call();
      if (device != null && DriverOnboardingRules.isOpen(device)) {
        data.country = device;
      }
    }
    data.cityId ??= profile?.cityId;
    _fixRegion();
    if (data.firstName.isEmpty) {
      data.firstName = known(profile?.firstName) ?? '';
    }
    if (data.lastName.isEmpty) data.lastName = known(profile?.lastName) ?? '';
    if (data.email.isEmpty) data.email = known(profile?.email) ?? '';
    if (data.dateOfBirth.isEmpty) data.dateOfBirth = profile?.dateOfBirth ?? '';
    if (data.personalNumber.isEmpty) {
      data.personalNumber = profile?.personalNumber ?? '';
    }
    if (data.taxiLicenseNumber.isEmpty) {
      data.taxiLicenseNumber = profile?.taxiLicenseNumber ?? '';
    }
    final address = profile?.address;
    if (data.street.isEmpty && address != null) {
      data
        ..street = address.street
        ..postalCode = address.postalCode
        ..city = address.city;
    }
    data.language ??= profile?.language ?? DriverAppTexts.language;
    if (!DriverLanguage.supported.contains(data.language)) data.language = 'en';
    _first.text = data.firstName;
    _last.text = data.lastName;
    _email.text = data.email;
    _date.text = data.dateOfBirth.isEmpty
        ? ''
        : typedOfIsoDate(data.dateOfBirth);
    _personal.text = data.personalNumber;
    _taxi.text = data.taxiLicenseNumber;
    _street.text = data.street;
    _postal.text = data.postalCode;
    _city.text = data.city;
    await _loadSettings();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _loadSettings() async {
    final country = data.country;
    if (country == null) return;
    final settings = await flow.settingsOf(country);
    if (mounted) setState(() => _settings = settings);
  }

  /// A region of another country is dropped; a single region is picked.
  void _fixRegion() {
    final country = data.country;
    if (country == null) {
      data.cityId = null;
      return;
    }
    final cities = DriverOnboardingRules.citiesOf(country);
    if (!cities.any((c) => c.cityId == data.cityId)) data.cityId = null;
    if (cities.length == 1) data.cityId = cities.single.cityId;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    for (final c in [
      _first,
      _last,
      _email,
      _date,
      _personal,
      _taxi,
      _street,
      _postal,
      _city,
    ]) {
      c.dispose();
    }
    later(flow.draft.flush());
    super.dispose();
  }

  void _keep() {
    data
      ..firstName = _first.text
      ..lastName = _last.text
      ..email = _email.text
      ..personalNumber = _personal.text
      ..taxiLicenseNumber = _taxi.text
      ..street = _street.text
      ..postalCode = _postal.text
      ..city = _city.text;
    final iso = isoOfTypedDate(_date.text);
    if (iso != null) data.dateOfBirth = iso;
    flow.save();
  }

  bool _on(String field) =>
      _settings?.signUpField(field).on ??
      OnboardingSettings(country: data.country ?? '').signUpField(field).on;

  bool _required(String field) {
    final sw =
        _settings?.signUpField(field) ??
        OnboardingSettings(country: data.country ?? '').signUpField(field);
    return sw.on && sw.required;
  }

  Future<void> _pickCountry() async {
    final picked = await showSignupList<String>(
      context,
      title: st('country'),
      rows: [for (final code in _open) (code, countryName(code))],
      selected: data.country,
      keyPrefix: 'pick-country',
    );
    if (picked == null || picked == data.country) return;
    setState(() {
      data.country = picked;
      _countryFromPhone = countryOfPhone(flow.phone) == picked;
      _errors.remove('country');
      _fixRegion();
      _settings = flow.settingsHeld(picked);
    });
    flow.save();
    await _loadSettings();
  }

  Future<void> _pickRegion() async {
    final country = data.country;
    if (country == null) return;
    final picked = await showSignupList<String>(
      context,
      title: st('region'),
      rows: [
        for (final city in DriverOnboardingRules.citiesOf(country))
          (city.cityId, city.name),
      ],
      selected: data.cityId,
      keyPrefix: 'pick-region',
    );
    if (picked == null) return;
    setState(() {
      data.cityId = picked;
      _errors.remove('region');
    });
    flow.save();
  }

  Future<void> _pickLanguage() async {
    final picked = await showSignupList<String>(
      context,
      title: st('language'),
      rows: [
        for (final code in DriverLanguage.supported)
          (code, DriverLanguage.names[code] ?? code),
      ],
      selected: data.language,
      keyPrefix: 'pick-language',
    );
    if (picked == null) return;
    setState(() => data.language = picked);
    flow.save();
  }

  /// Suggestions while typing the street (the places search the app
  /// already uses for Destination mode); plain fields without it.
  void _streetChanged(String text) {
    _keep();
    final places = flow.places;
    if (places == null) return;
    _searchTimer?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      final run = ++_searchRun;
      try {
        final found = await places.search(text);
        if (!mounted || run != _searchRun) return;
        setState(() => _suggestions = found.take(5).toList());
      } catch (_) {
        if (mounted) setState(() => _suggestions = const []);
      }
    });
  }

  void _pickSuggestion(DestinationPlace place) {
    final parts = parseSuggestedAddress(place.name, place.address);
    setState(() {
      _street.text = parts.street;
      if (parts.postalCode.isNotEmpty) _postal.text = parts.postalCode;
      if (parts.city.isNotEmpty) _city.text = parts.city;
      _suggestions = const [];
      _errors.remove('address');
    });
    _keep();
    FocusScope.of(context).unfocus();
  }

  bool _validate() {
    _errors.clear();
    _keep();
    final need = st('required');
    if (data.country == null) _errors['country'] = st('noCountryOpen');
    if (data.cityId == null) _errors['region'] = need;
    if (_first.text.trim().isEmpty) _errors['firstName'] = need;
    if (_last.text.trim().isEmpty) _errors['lastName'] = need;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      _errors['email'] = _email.text.trim().isEmpty ? need : st('badEmail');
    }
    if (_on('personalNumber')) {
      final typed = _personal.text.trim();
      final normalized = normalizePersonalNumber(typed);
      if (typed.isEmpty && _required('personalNumber')) {
        _errors['personalNumber'] = need;
      } else if (typed.isNotEmpty && normalized == null) {
        _errors['personalNumber'] = st('badPersonalNumber');
      } else if (normalized != null) {
        data.personalNumber = normalized;
        data.dateOfBirth = dateOfPersonalNumber(normalized);
      }
    }
    if (_on('dateOfBirth')) {
      final iso = isoOfTypedDate(_date.text);
      if (_date.text.trim().isEmpty && _required('dateOfBirth')) {
        _errors['dateOfBirth'] = need;
      } else if (_date.text.trim().isNotEmpty && iso == null) {
        _errors['dateOfBirth'] = st('badDate');
      } else if (iso != null) {
        data.dateOfBirth = iso;
      }
    }
    final dob = DateTime.tryParse(data.dateOfBirth);
    if (dob != null &&
        DriverOnboardingRules.ageAt(dob, DateTime.now()) <
            DriverOnboardingRules.minAge) {
      _errors[_on('personalNumber') ? 'personalNumber' : 'dateOfBirth'] = st(
        'tooYoung',
        [DriverOnboardingRules.minAge],
      );
    }
    if (_on('taxiLicenseNumber')) {
      final t = _taxi.text.trim();
      if (t.isEmpty && _required('taxiLicenseNumber')) {
        _errors['taxiLicenseNumber'] = need;
      } else if (t.isNotEmpty &&
          !RegExp(
            r'^[\p{L}\p{N}][\p{L}\p{N} -]{0,29}$',
            unicode: true,
          ).hasMatch(t)) {
        _errors['taxiLicenseNumber'] = st('badTaxiNumber');
      }
    }
    if (_on('address')) {
      final filled = [
        _street,
        _postal,
        _city,
      ].where((c) => c.text.trim().isNotEmpty).length;
      if ((filled > 0 || _required('address')) && filled < 3) {
        _errors['address'] = need;
      }
    }
    flow.save();
    return _errors.isEmpty;
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() {
      _formError = null;
      _validate();
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final profile = flow.profile;
      if (profile?.country != data.country || profile?.cityId != data.cityId) {
        final saved = await flow.account.repository.setCountry(
          data.country!,
          cityId: data.cityId,
        );
        flow.account.replace(saved);
      }
      data.detailsDone = true;
      flow.save();
      await flow.draft.flush();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'signup-checklist'),
          builder: (_) => SignupChecklistScreen(flow: flow),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final reason = error is ApiError ? error.reason : null;
      setState(() {
        _formError = switch (reason) {
          'details_locked' => st('countryLocked'),
          'fleet_other_country' => st('fleetCountry'),
          'invalid_city' => st('required'),
          _ => st('saveError'),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
    bool locked = false,
  }) {
    return TextField(
      key: ValueKey('signup-$key'),
      controller: controller,
      readOnly: locked,
      keyboardType: keyboard,
      onChanged: onChanged ?? (_) => _keep(),
      style: AuthText.urbanist(
        size: 15,
        color: locked ? AccountStyle.muted : AccountStyle.ink,
      ),
      decoration: AccountStyle.decoration(hint: hint, error: _errors[key])
          .copyWith(
            suffixIcon: locked
                ? const Icon(Icons.lock_outline, size: 18)
                : null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AccountStyle.ink)),
      );
    }
    final country = data.country;
    final cities = country == null
        ? const <OnboardingCity>[]
        : DriverOnboardingRules.citiesOf(country);
    final regionName = cities
        .where((c) => c.cityId == data.cityId)
        .map((c) => c.name)
        .firstOrNull;
    final phone = TextEditingController(text: flow.phone ?? '');
    return SignupScaffold(
      key: const ValueKey('signup-info-screen'),
      title: st('infoTitle'),
      body: st('infoBody'),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      topRight: Text(st('step1'), style: AccountStyle.hint()),
      button: SignupButton(
        key: const ValueKey('signup-info-continue'),
        label: st('continue'),
        busy: _busy,
        onPressed: _continue,
      ),
      children: [
        SignupLabel(st('country')),
        SignupSelectBox(
          key: const ValueKey('signup-country'),
          value: country == null ? null : countryName(country),
          placeholder: st('choose'),
          error: _errors['country'],
          onTap: _busy ? null : _pickCountry,
        ),
        if (_countryFromPhone && flow.phone != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              st('countryFromPhone', [flow.phone!.substring(0, 3)]),
              style: AccountStyle.hint().copyWith(fontSize: 12),
            ),
          ),
        SignupLabel(st('region')),
        SignupSelectBox(
          key: const ValueKey('signup-region'),
          value: regionName,
          placeholder: st('choose'),
          error: _errors['region'],
          onTap: country == null || _busy ? null : _pickRegion,
        ),
        const SizedBox(height: 20),
        Text(st('you'), style: AccountStyle.section()),
        SignupLabel(st('phone')),
        _field('phone', phone, locked: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignupLabel(st('firstName')),
                  _field('firstName', _first, hint: st('firstName')),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignupLabel(st('lastName')),
                  _field('lastName', _last, hint: st('lastName')),
                ],
              ),
            ),
          ],
        ),
        SignupLabel(st('email')),
        _field(
          'email',
          _email,
          hint: st('emailHint'),
          keyboard: TextInputType.emailAddress,
        ),
        if (_on('dateOfBirth')) ...[
          SignupLabel(st('dateOfBirth')),
          _field(
            'dateOfBirth',
            _date,
            hint: st('dateHint'),
            keyboard: TextInputType.datetime,
          ),
        ],
        if (_on('personalNumber')) ...[
          SignupLabel(st('personalNumber')),
          _field(
            'personalNumber',
            _personal,
            hint: st('personalNumberHint'),
            keyboard: TextInputType.number,
          ),
        ],
        // Owner 2026-11-26: the address under the date of birth (SE: under
        // the personnummer).
        if (_on('address')) ...[
          SignupLabel(st('address')),
          _field(
            'address',
            _street,
            hint: st('streetHint'),
            keyboard: TextInputType.streetAddress,
            onChanged: _streetChanged,
          ),
          for (final place in _suggestions)
            ListTile(
              key: ValueKey('address-suggestion-${place.id}'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: const Icon(Icons.place_outlined, size: 20),
              title: Text(place.name, style: AccountStyle.body()),
              subtitle: Text(place.address, style: AccountStyle.hint()),
              onTap: () => _pickSuggestion(place),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(
                  'postalCode',
                  _postal,
                  hint: st('postalCode'),
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _field('city', _city, hint: st('city'))),
            ],
          ),
        ],
        if (_on('taxiLicenseNumber')) ...[
          SignupLabel(st('taxiNumber')),
          _field('taxiLicenseNumber', _taxi, hint: st('taxiNumberHint')),
        ],
        if (_on('language')) ...[
          SignupLabel(st('language')),
          SignupSelectBox(
            key: const ValueKey('signup-language'),
            value: DriverLanguage.names[data.language] ?? data.language,
            placeholder: st('choose'),
            onTap: _busy ? null : _pickLanguage,
          ),
        ],
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _formError!,
              key: const ValueKey('signup-info-error'),
              style: AuthText.urbanist(size: 13.5, color: AccountStyle.error),
            ),
          ),
      ],
    );
  }
}

/// A suggestion's street, postal code and city: the title is the street,
/// the line after it starts with the postal code (SE "111 22", FR
/// "75001") then the city. Missing parts stay empty (typed by hand).
({String street, String postalCode, String city}) parseSuggestedAddress(
  String title,
  String full,
) {
  final rest = full.startsWith(title)
      ? full.substring(title.length).replaceFirst(RegExp(r'^\s*,\s*'), '')
      : full;
  final first = rest.split(',').first.trim();
  final match = RegExp(r'^(\d{3}\s?\d{2}|\d{5})\s+(.+)$').firstMatch(first);
  if (match == null) return (street: title.trim(), postalCode: '', city: '');
  return (
    street: title.trim(),
    postalCode: match.group(1)!,
    city: match.group(2)!.trim(),
  );
}
