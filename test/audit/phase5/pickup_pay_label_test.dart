import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

/// M6 (Phase 3 cross-app, S4): the 1,55 kr pickup pay is folded into the
/// trip's Movera-paid extra ([PickupPayQuote.termsOf]) and the done
/// screen called it "Movera-bonus". It is pickup pay, not a bonus: the
/// label says only what is true of both, "paid by Movera".
void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  final terms = const PickupPayQuote(
    pay: Money(minorUnits: 155),
    leg: PickupLeg(km: 2.4, minutes: 5),
  ).termsOf(fare: '120,00 kr');

  for (final (language, expected) in [
    ('sv', 'inkl. +1,55 kr betalt av Movera'),
    ('fr', 'dont +1,55 kr payés par Movera'),
    ('en', 'incl. +1,55 kr paid by Movera'),
  ]) {
    test('$language: pickup pay is not called a bonus', () {
      DriverAppTexts.language = language;
      final note = WaybillRecord.bonusNote(terms.driverBonus!.formatted);
      expect(note, expected);
      expect(note.toLowerCase(), isNot(contains('bonus')));
    });
  }
}
