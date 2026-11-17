// J11 (contract v0.18.84 `debtModel.driverOwes`): the Accept refusal
// `409 driver_owes_movera` reads as the Home line, with the owed and the
// limit from the server's details (never worked out on the phone). Uses
// the J11 API (ClaimResult.owesMovera), so before J11 it does not build.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/owes_movera_refusal.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/contracts/zone_settings.dart';

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  tearDown(DriverLanguage.resetForTest);

  Map<String, dynamic> body({List<Object?>? details}) => {
    'code': 'conflict',
    'reason': 'driver_owes_movera',
    'details': details ?? ['owed:152000 TND', 'limit:150000 TND'],
  };

  for (final (language, country) in [
    ('en', null),
    ('fr', 'FR'),
    ('sv', 'SE'),
  ]) {
    test('[$language] the refusal is the contract owes line with the '
        'server\'s amounts', () {
      if (country != null) {
        DriverLanguage.applyZone(AppLanguages.forCountry(country));
      }
      final owes = OwesMoveraRefusal.fromConflict(body())!;
      expect(owes.owed, const Money(minorUnits: 152000, currency: 'TND'));
      expect(owes.limit, const Money(minorUnits: 150000, currency: 'TND'));
      final text =
          ((_contract['debtModel'] as Map)['texts']
                  as Map)['owesMoveraLine'][language]
              .toString()
              .replaceAll('{owed}', '152.000 DT')
              .replaceAll('{limit}', '150.000 DT');
      expect(owes.text, text);
      final result = ClaimResult.owesMovera(owes);
      expect(result.outcome, ClaimOutcome.unavailable);
      expect(result.owesMovera, same(owes));
    });
  }

  test('another reason, or amounts missing, is not this refusal', () {
    expect(
      OwesMoveraRefusal.fromConflict({
        'code': 'conflict',
        'reason': 'version_mismatch',
      }),
      isNull,
    );
    expect(OwesMoveraRefusal.fromConflict(body(details: [])), isNull);
    expect(
      OwesMoveraRefusal.fromConflict(body(details: ['owed:abc TND'])),
      isNull,
    );
    expect(OwesMoveraRefusal.fromConflict(null), isNull);
  });

  test('the contract names the reason and its details', () {
    final cash =
        ((_contract['debtModel'] as Map)['driverOwes'] as Map)['cashOffers']
            as String;
    expect(cash, contains('driver_owes_movera'));
    expect(cash, contains('"owed:<minor> <CUR>", "limit:<minor> <CUR>"'));
    expect(cash, contains('Going online is never refused'));
  });
}
