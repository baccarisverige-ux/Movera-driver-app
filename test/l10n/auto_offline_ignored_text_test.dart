import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Owner 2026-11-16 "It's not when driver decline ! It count when driver
/// ignore" + "And only exclusive / And it's about exclusive ride not radar"
/// (contract v0.18.120 `driverHome.setOffline.reasons.missed_offers`): the
/// offline card no longer tells the driver that declines count. The three
/// texts are the contract's.
void main() {
  test('the missed-offers reason says Exclusive offers he let run out, in '
      'sv, fr and en; no language says "declined"', () {
    String text(String lang) =>
        lookupAppLocalizations(Locale(lang)).offlineReasonMissedOffers(10);
    expect(text('en'), 'You let 10 Exclusive offers run out in a row');
    expect(text('sv'), 'Du lät 10 Exklusiva erbjudanden gå ut i rad');
    expect(
      text('fr'),
      'Vous avez laissé expirer 10 offres Exclusives d’affilée',
    );
    for (final lang in ['en', 'sv', 'fr']) {
      expect(text(lang), isNot(contains('declined')));
      expect(text(lang), isNot(contains('nekade')));
      expect(text(lang), isNot(contains('refusé')));
    }
  });
}
