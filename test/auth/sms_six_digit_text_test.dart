import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/l10n/app_localizations.dart';

// SMS-alone (contract v0.18.133 smsSignIn.codeLength): a code sent by SMS is
// 6 digits. Owner 2026-11-20 "Yes, 4 → 6 only (Rec.)": on the phone screen only
// the digit changes from 4 to 6, in sv / en / fr; nothing else in the line.
void main() {
  const phoneLine = {
    'en': "We'll text you a 6-digit code.",
    'sv': 'Vi skickar en sexsiffrig kod via sms.',
    'fr': 'Nous vous enverrons un code à 6 chiffres par SMS.',
  };
  const providerLine = {
    'en':
        'Confirm your phone number once to finish signing in with Apple. We’ll text you a 6-digit code.',
    'sv':
        'Bekräfta ditt telefonnummer en gång för att slutföra inloggningen med Apple. Vi skickar en sexsiffrig kod via sms.',
    'fr':
        'Confirmez votre numéro une seule fois pour terminer la connexion avec Apple. Nous vous envoyons un code à 6 chiffres par SMS.',
  };

  for (final lang in phoneLine.keys) {
    test('$lang: the phone screen says a 6-digit code (only 4 → 6)', () {
      final t = lookupAppLocalizations(Locale(lang));
      expect(t.authTextFourDigitCode, phoneLine[lang]);
      expect(t.authProviderPhoneOnce('Apple'), providerLine[lang]);
    });
  }
}
