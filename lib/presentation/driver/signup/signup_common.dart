import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/document_scanner.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';

/// Contract v0.18.166 (`contract.json#signupV2`): what the driver typed on
/// "Vos informations" and chose on "Votre profil", kept on the phone (the
/// details draft, cleared at sign-out) until `POST /driver/onboarding`
/// took it ("Continuer plus tard" loses nothing).
class SignupData {
  SignupData();

  factory SignupData.fromMap(Map<String, dynamic> map) {
    String? read(String key) {
      final value = map['v2.$key'];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return SignupData()
      ..country = read('country')
      ..cityId = read('cityId')
      ..firstName = read('firstName') ?? ''
      ..lastName = read('lastName') ?? ''
      ..email = read('email') ?? ''
      ..dateOfBirth = read('dateOfBirth') ?? ''
      ..personalNumber = read('personalNumber') ?? ''
      ..taxiLicenseNumber = read('taxiLicenseNumber') ?? ''
      ..street = read('street') ?? ''
      ..postalCode = read('postalCode') ?? ''
      ..city = read('city') ?? ''
      ..language = read('language')
      ..accountType = read('accountType')
      ..companyName = read('companyName') ?? ''
      ..orgNumber = read('orgNumber') ?? ''
      ..companyAddress = read('companyAddress') ?? ''
      ..detailsDone = map['v2.detailsDone'] == true;
  }

  String? country;
  String? cityId;
  String firstName = '';
  String lastName = '';
  String email = '';

  /// `YYYY-MM-DD` (France); for Sweden it comes from the personnummer.
  String dateOfBirth = '';
  String personalNumber = '';
  String taxiLicenseNumber = '';
  String street = '';
  String postalCode = '';
  String city = '';
  String? language;

  /// The EXISTING account type: `fleet` (avec Kbis / med eget företag) or
  /// `driver` (sans Kbis / utan eget företag).
  String? accountType;
  String companyName = '';
  String orgNumber = '';
  String companyAddress = '';

  /// "Vos informations" passed its checks (the checklist's first ✓).
  bool detailsDone = false;

  Map<String, Object?> toMap() => {
    'v2.country': country,
    'v2.cityId': cityId,
    'v2.firstName': firstName,
    'v2.lastName': lastName,
    'v2.email': email,
    'v2.dateOfBirth': dateOfBirth,
    'v2.personalNumber': personalNumber,
    'v2.taxiLicenseNumber': taxiLicenseNumber,
    'v2.street': street,
    'v2.postalCode': postalCode,
    'v2.city': city,
    'v2.language': language,
    'v2.accountType': accountType,
    'v2.companyName': companyName,
    'v2.orgNumber': orgNumber,
    'v2.companyAddress': companyAddress,
    'v2.detailsDone': detailsDone,
  };

  bool get companyFilled =>
      companyName.trim().isNotEmpty &&
      orgNumber.trim().isNotEmpty &&
      companyAddress.trim().isNotEmpty;

  /// "Vous êtes" is done: a choice, and a company named for `fleet`.
  bool get accountTypeDone =>
      accountType == 'driver' || (accountType == 'fleet' && companyFilled);
}

/// Contract v0.18.166 (`signupV2.personalNumber.format`): 12 digits
/// `YYYYMMDD-XXXX` (also typed without the dash); the last digit passes
/// the Luhn check over the 10 digits after the century. Null when wrong.
String? normalizePersonalNumber(String typed) {
  final digits = typed.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d{12}$').hasMatch(digits)) return null;
  final date = DateTime.tryParse(
    '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}',
  );
  if (date == null ||
      date.month != int.parse(digits.substring(4, 6)) ||
      date.day != int.parse(digits.substring(6, 8))) {
    return null;
  }
  final ten = digits.substring(2);
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    var v = int.parse(ten[i]) * (i.isEven ? 2 : 1);
    if (v > 9) v -= 9;
    sum += v;
  }
  if (sum % 10 != 0) return null;
  return '${digits.substring(0, 8)}-${digits.substring(8)}';
}

/// `YYYY-MM-DD` of a personnummer `YYYYMMDD-XXXX`.
String dateOfPersonalNumber(String normalized) =>
    '${normalized.substring(0, 4)}-${normalized.substring(4, 6)}-${normalized.substring(6, 8)}';

/// `JJ/MM/AAAA` (the French date field) as `YYYY-MM-DD`, or null.
String? isoOfTypedDate(String typed) {
  final match = RegExp(
    r'^\s*(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{4})\s*$',
  ).firstMatch(typed);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  if (year < 1900) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '$year-${two(month)}-${two(day)}';
}

/// `YYYY-MM-DD` shown as `JJ/MM/AAAA`.
String typedOfIsoDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Contract v0.18.166 (`signupV2.infoScreen.countryFromPhone`): +46 = SE,
/// +33 = FR, only when that country is open; else null.
String? countryOfPhone(String? phone) {
  final p = (phone ?? '').replaceAll(' ', '');
  final code = p.startsWith('+46')
      ? 'SE'
      : p.startsWith('+33')
      ? 'FR'
      : null;
  if (code == null || !DriverOnboardingRules.isOpen(code)) return null;
  return code;
}

/// Everything the sign-up screens share: the account, the draft on the
/// phone, the country's onboarding settings, the pickers and where to go
/// when done.
class SignupFlow {
  SignupFlow({
    required this.account,
    required this.phone,
    required this.onHome,
    DetailsDraft? draft,
    DocumentFilePicker? picker,
    DocumentScanner? scanner,
    this.places,
    this.settingsLoader,
    this.deviceCountry,
    this.joiner = joinSides,
  }) : draft = draft ?? DetailsDraft(),
       picker = picker ?? const DeviceDocumentFilePicker(),
       scanner = scanner ?? const DeviceDocumentScanner();

  final DriverAccountSession account;

  /// The number confirmed by SMS (shown locked).
  final String? phone;

  /// "Continuer plus tard" and after "Envoyer l'inscription": Home.
  final void Function(BuildContext context) onHome;
  final DetailsDraft draft;
  final DocumentFilePicker picker;
  final DocumentScanner scanner;

  /// The address suggestions (`POST /locations/autocomplete`); null = plain
  /// fields only.
  final DestinationSearch? places;

  /// Tests hand in settings; the app reads `GET /driver/onboarding/settings`.
  final Future<OnboardingSettings> Function(String country)? settingsLoader;

  /// The device's country when the location permission is ALREADY granted
  /// (never asked here); null otherwise.
  final Future<String?> Function()? deviceCountry;

  /// Joins recto + verso into one file (`signupV2.twoSided.upload`).
  final Future<PickedDocumentFile> Function(
    PickedDocumentFile front,
    PickedDocumentFile back,
  )
  joiner;

  SignupData data = SignupData();
  final Map<String, OnboardingSettings> _settings = {};

  Future<void> restore() async {
    data = SignupData.fromMap(await draft.restore());
  }

  void save() => draft.save(data.toMap());

  Future<OnboardingSettings> settingsOf(String country) async {
    final held = _settings[country];
    if (held != null) return held;
    OnboardingSettings read;
    try {
      read =
          await (settingsLoader?.call(country) ??
              account.repository.onboardingSettings(country: country));
    } catch (_) {
      // Offline: the contract defaults still name the fields.
      read = OnboardingSettings(country: country);
    }
    _settings[country] = read;
    return read;
  }

  OnboardingSettings? settingsHeld(String country) => _settings[country];

  DriverAccount? get profile => account.account;

  /// The profile photo the server holds (any status), or null.
  DocumentSummary? get profilePhoto {
    for (final document in profile?.documents ?? const <DocumentSummary>[]) {
      if (document.type == 'profile_photo') return document;
    }
    return null;
  }

  /// Contract v0.18.166 (`signupV2.profilePhoto.locked`, owner "Peut pas"):
  /// approved (or approved then expired) = only support changes it.
  bool get profilePhotoLocked {
    final status = profilePhoto?.status;
    return status == 'approved' || status == 'expired';
  }

  bool get profilePhotoDone {
    final status = profilePhoto?.status;
    return status != null && status != 'rejected' && status != 'missing';
  }
}

/// The white, professional frame of the new sign-up screens (mockup:
/// white ground, very light grey fields, ink button at the bottom).
class SignupScaffold extends StatelessWidget {
  const SignupScaffold({
    super.key,
    required this.children,
    this.title,
    this.body,
    this.onBack,
    this.topRight,
    this.button,
  });

  final String? title;
  final String? body;
  final VoidCallback? onBack;
  final Widget? topRight;
  final Widget? button;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      key: const ValueKey('signup-back'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Icons.chevron_left, size: 28),
                      onPressed: onBack,
                    )
                  else
                    const SizedBox(width: 20),
                  const Spacer(),
                  ?topRight,
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (title != null) Text(title!, style: AccountStyle.title()),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    Text(body!, style: AccountStyle.hint()),
                  ],
                  const SizedBox(height: 18),
                  ...children,
                ],
              ),
            ),
            if (button != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: button,
              ),
          ],
        ),
      ),
    );
  }
}

/// The ink button of the mockups.
class SignupButton extends StatelessWidget {
  const SignupButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AccountStyle.ink,
          disabledBackgroundColor: AccountStyle.ink.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: AuthText.urbanist(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// A field label above its box.
class SignupLabel extends StatelessWidget {
  const SignupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Text(text, style: AccountStyle.label()),
  );
}

/// A box that opens a bottom-sheet list (Pays, Région, Langue, Vous êtes).
class SignupSelectBox extends StatelessWidget {
  const SignupSelectBox({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.error,
  });

  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AccountStyle.field,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: error != null ? AccountStyle.error : AccountStyle.line,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: AuthText.urbanist(
                        size: 15,
                        color: value == null
                            ? const Color(0xFF9AA79F)
                            : AccountStyle.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              error!,
              style: AuthText.urbanist(size: 12.5, color: AccountStyle.error),
            ),
          ),
      ],
    );
  }
}

/// A white card with a light line, as in the mockup's checklist.
class SignupCard extends StatelessWidget {
  const SignupCard({super.key, required this.children, this.title, this.tag});

  final String? title;
  final String? tag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AccountStyle.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: AuthText.urbanist(
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tag != null) SignupTag(tag!),
                ],
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class SignupTag extends StatelessWidget {
  const SignupTag(this.text, {super.key, this.green = false});
  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: green ? const Color(0xFFE6F4EA) : AccountStyle.field,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: AuthText.urbanist(
        size: 11.5,
        weight: FontWeight.w600,
        color: green ? const Color(0xFF1E7B3A) : AccountStyle.muted,
      ),
    ),
  );
}

/// The mockup's "Vous êtes" sheet: two boxed rows with a round check.
Future<String?> showAccountTypeSheet(
  BuildContext context, {
  required String country,
  required String? selected,
}) {
  final se = country == 'SE';
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AccountStyle.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              st('youAre'),
              style: AuthText.urbanist(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            for (final type in const ['fleet', 'driver'])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AccountStyle.field,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected == type
                          ? AccountStyle.ink
                          : AccountStyle.line,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('account-type-$type'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(type),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountTypeLabel(type, country),
                                  style: AuthText.urbanist(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  st('$type${se ? 'SE' : 'FR'}Hint'),
                                  style: AccountStyle.hint(),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected == type
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected == type
                                ? AccountStyle.ink
                                : AccountStyle.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// `contract.json#signupV2.accountTypeLabels`: fleet = avec Kbis / med
/// eget företag, driver = sans Kbis / utan eget företag.
String accountTypeLabel(String type, String country) =>
    st('$type${country == 'SE' ? 'SE' : 'FR'}');

/// A bottom-sheet list of plain rows (Pays, Région, Langue).
Future<T?> showSignupList<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> rows,
  required T? selected,
  String keyPrefix = 'pick',
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AuthText.urbanist(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Divider(color: AccountStyle.line),
            for (final (value, label) in rows)
              ListTile(
                key: ValueKey('$keyPrefix-$value'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(label, style: AccountStyle.rowTitle()),
                trailing: value == selected
                    ? const Icon(Icons.check, color: AccountStyle.ink)
                    : null,
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Keeps one pending future from running twice (a double tap).
class OneAtATime {
  Future<void>? _running;
  bool get busy => _running != null;

  Future<void> run(Future<void> Function() job) async {
    if (_running != null) return;
    final future = job();
    _running = future;
    try {
      await future;
    } finally {
      _running = null;
    }
  }
}

/// Fire and forget.
void later(Future<void> future) => unawaited(future);
