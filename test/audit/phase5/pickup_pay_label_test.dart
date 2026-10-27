import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';

/// Owner decision 2026-10-27 (replaces M6's "paid by Movera" note): the
/// driver sees no breakdown. The pickup pay is in the one amount the
/// driver gets, and no text of the app names it, or calls it a bonus.
void main() {
  test('the pickup pay is in the one total', () {
    final terms = const PickupPayQuote(
      pay: Money(minorUnits: 155),
      leg: PickupLeg(km: 2.4, minutes: 5),
    ).termsOf(fare: '120,00 kr');
    expect(terms.fare, '121,55 kr');
  });

  for (final language in ['en', 'fr', 'sv']) {
    test('$language: no breakdown texts are left', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in [
        'moveraBonus',
        'inclBonusMoveraBonus',
        'earningsBaseService',
        'includesFeeWaitingFee',
      ]) {
        expect(arb.containsKey(key), isFalse, reason: key);
      }
      for (final text in arb.values.whereType<String>()) {
        final lower = text.toLowerCase();
        expect(lower, isNot(contains('paid by movera')));
        expect(lower, isNot(contains('betalt av movera')));
        expect(lower, isNot(contains('payés par movera')));
        expect(lower, isNot(contains('pickup pay')), reason: text);
      }
    });
  }
}
