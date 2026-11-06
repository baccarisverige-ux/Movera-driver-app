import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/l10n/app_localizations.dart';

// Job L-c (owner 2026-11-06, decisions/driver-g15.md "Owner answers
// 2026-11-06 (L-c follow-ups, #515)": "Split first, then fix (Safe)").
// Every give-back counts (movera-server#106), so the cancel-rate help line
// must not say that reasons marked "Doesn't count" are left out.
void main() {
  const marks = [
    'Doesn’t count',
    "Doesn't count",
    'Räknas inte',
    'Ne compte pas',
  ];
  for (final lang in ['en', 'sv', 'fr']) {
    test(
      '$lang: the cancel-rate help says every cancel counts, no exception',
      () {
        final tr = lookupAppLocalizations(Locale(lang));
        final line = tr.cancelRateEveryCancelCounts;
        for (final mark in marks) {
          expect(line.contains(mark), isFalse, reason: '$lang: "$line"');
        }
        expect(line.isNotEmpty, isTrue);
      },
    );
  }
}
