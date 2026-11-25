import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/presentation/driver/account/details_pickers.dart';
import 'package:movera/widgets/country_flag.dart';

/// Contract v0.18.162 (contract.json#driverCountryFirst; owner 2026-11-25
/// "Yes": "On the first sign-in ever, when a driver or a fleet owner signs
/// in, the app asks which country do you work?"). Right after the first
/// sign-in and before the details form: only the open countries, none
/// picked by default, Continue saves it (`PUT /driver/country`). Shown once
/// to every driver or fleet owner whose account has no country yet, and
/// again from the details form to change it before approval. Loaded on
/// first open (deferred_screens.dart) and its texts live here, so the
/// first download does not grow (web budget).
class DriverCountryScreen extends StatefulWidget {
  const DriverCountryScreen({
    super.key,
    required this.account,
    required this.onDone,
    this.selected,
  });

  final DriverAccountSession account;

  /// Called with the saved account once the server took the country.
  final void Function(BuildContext context, DriverAccount saved) onDone;

  /// The country already saved (changing it from the details form); null
  /// on the first sign-in: nothing is picked for him.
  final String? selected;

  @override
  State<DriverCountryScreen> createState() => _DriverCountryScreenState();
}

/// en / sv / fr texts of this screen (kept in the deferred part).
const Map<String, Map<String, String>> _texts = {
  'title': {
    'en': 'Which country do you work in?',
    'sv': 'Vilket land arbetar du i?',
    'fr': 'Dans quel pays travaillez-vous ?',
  },
  'body': {
    'en':
        'Your cars and trips belong to this country. You can change it only until your account is approved.',
    'sv':
        'Dina bilar och resor hör till detta land. Du kan bara ändra det tills ditt konto är godkänt.',
    'fr':
        "Vos voitures et vos courses appartiennent à ce pays. Vous pouvez le changer seulement jusqu'à la validation de votre compte.",
  },
  'continue': {'en': 'Continue', 'sv': 'Fortsätt', 'fr': 'Continuer'},
  'error': {
    'en': 'Could not save the country. Try again.',
    'sv': 'Landet kunde inte sparas. Försök igen.',
    'fr': "Le pays n'a pas pu être enregistré. Réessayez.",
  },
  'locked': {
    'en': 'Your account is approved. Ask support to change your country.',
    'sv': 'Ditt konto är godkänt. Be supporten ändra ditt land.',
    'fr': 'Votre compte est validé. Demandez au support de changer votre pays.',
  },
  'fleet': {
    'en':
        'Your fleet works in another country. Ask your fleet owner or support.',
    'sv':
        'Ditt åkeri arbetar i ett annat land. Fråga åkeriägaren eller supporten.',
    'fr':
        'Votre flotte travaille dans un autre pays. Demandez au propriétaire ou au support.',
  },
};

String countryText(String key) {
  final lang = DriverAppTexts.language;
  final row = _texts[key]!;
  return row[lang] ?? row['en']!;
}

class _DriverCountryScreenState extends State<DriverCountryScreen> {
  String? _picked;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _picked = widget.selected;
  }

  Future<void> _continue() async {
    final picked = _picked;
    if (picked == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.account.repository.setCountry(picked);
      widget.account.replace(saved);
      if (mounted) widget.onDone(context, saved);
    } catch (error) {
      if (!mounted) return;
      final reason = error is ApiError ? error.reason : null;
      setState(() {
        _saving = false;
        _error = reason == 'details_locked'
            ? countryText('locked')
            : reason == 'fleet_other_country'
            ? countryText('fleet')
            : countryText('error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = [
      for (final code in DriverOnboardingRules.countries.keys)
        if (DriverOnboardingRules.isOpen(code)) code,
    ];
    return Scaffold(
      key: const ValueKey('driver-country-screen'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                countryText('title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(countryText('body')),
              const SizedBox(height: 20),
              for (final code in open)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    key: ValueKey('country-$code'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _picked == code ? Colors.black : Colors.black26,
                        width: _picked == code ? 2 : 1,
                      ),
                    ),
                    leading: CountryFlag(code, width: 32),
                    title: Text(countryName(code)),
                    trailing: _picked == code
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: _saving
                        ? null
                        : () => setState(() => _picked = code),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('country-error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('country-continue'),
                onPressed: _picked == null || _saving ? null : _continue,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(countryText('continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owner 2026-11-25 ("OK comme ça"): the driver edited the details and
/// taps Back: "Leave without saving?" with Stay (black, default) and Leave
/// (red). On the root navigator with the keyboard closed first, so it shows
/// on iPad. True = leave. Its texts live here with the country step's
/// (deferred part, web budget).
Future<bool> confirmLeaveWithoutSaving(BuildContext context) async {
  FocusManager.instance.primaryFocus?.unfocus();
  String text(Map<String, String> row) =>
      row[DriverAppTexts.language] ?? row['en']!;
  final leave = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('leave-unsaved'),
      backgroundColor: Colors.white,
      title: Text(
        text(const {
          'en': 'Leave without saving?',
          'sv': 'Lämna utan att spara?',
          'fr': 'Quitter sans enregistrer ?',
        }),
      ),
      content: Text(
        text(const {
          'en': 'Your changes will be lost.',
          'sv': 'Dina ändringar går förlorade.',
          'fr': 'Vos modifications seront perdues.',
        }),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('leave-unsaved-stay'),
          autofocus: true,
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(
            text(const {'en': 'Stay', 'sv': 'Stanna', 'fr': 'Rester'}),
          ),
        ),
        TextButton(
          key: const ValueKey('leave-unsaved-leave'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            text(const {'en': 'Leave', 'sv': 'Lämna', 'fr': 'Quitter'}),
          ),
        ),
      ],
    ),
  );
  return leave == true;
}
