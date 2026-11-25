import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/early_end_distance.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Owner 2026-11-25 ("km, m under 100"): km with one decimal and the
/// locale's decimal separator; metres only below 100 m.
void main() {
  const cases = {
    'fr': {
      4226: '4,2 km',
      350: '0,4 km',
      100: '0,1 km',
      99: '99 m',
      80: '80 m',
      0: '0 m',
    },
    'sv': {
      4226: '4,2 km',
      350: '0,4 km',
      100: '0,1 km',
      99: '99 m',
      80: '80 m',
      0: '0 m',
    },
    'en': {
      4226: '4.2 km',
      350: '0.4 km',
      100: '0.1 km',
      99: '99 m',
      80: '80 m',
      0: '0 m',
    },
  };
  cases.forEach((lang, expected) {
    final tr = lookupAppLocalizations(Locale(lang));
    expected.forEach((meters, text) {
      test('$meters m in $lang -> $text', () {
        expect(formatEarlyEndDistance(meters, tr.localeName), text);
      });
    });
  });

  test('the full warning in fr, sv and en', () {
    String warn(String lang, int m) {
      final tr = lookupAppLocalizations(Locale(lang));
      return tr.arrivedFarWarning(formatEarlyEndDistance(m, tr.localeName));
    }

    expect(
      warn('fr', 4226),
      'Vous êtes à 4,2 km de la destination – la course se termine plus tôt',
    );
    expect(
      warn('sv', 350),
      'Du är 0,4 km från destinationen – resan avslutas tidigt',
    );
    expect(
      warn('en', 80),
      'You are 80 m from the destination – the trip ends early',
    );
  });
}
