import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';

import '../../integration_test/staging/pay_verdict.dart';

/// Firebase run 51 (main 2611dd1): PAY failed "you get ... shown=false"
/// because owner 2026-11-21 14:55 hid the earnings card on the collect
/// screen (cash_collect_sheet.dart showEarnings: false). The share is
/// checked on Ride completed (`ride-completed-fare`) now.
void main() {
  const share = Money(minorUnits: 7360, currency: 'SEK');

  bool pay(bool? shown) => PayVerdict.good(
    shownCash: '92 kr',
    wantCash: '92 kr',
    shareShown: shown,
    completed: true,
    fareMatches: true,
    finishedShown: true,
  );

  test('share shown on Ride completed passes; no collect balance needed', () {
    final shown = PayVerdict.shareShown(share, [share.formatted]);
    expect(shown, isTrue);
    expect(pay(shown), isTrue);
  });

  test('share missing on Ride completed still fails', () {
    final shown = PayVerdict.shareShown(share, ['12,00 kr']);
    expect(shown, isFalse);
    expect(pay(shown), isFalse);
  });

  test('no share from the server is not judged', () {
    expect(PayVerdict.shareShown(null, const []), isNull);
    expect(pay(null), isTrue);
  });

  test('PAY no longer reads the hidden collect-screen balance', () {
    final src = File(
      'integration_test/staging/trip_money.dart',
    ).readAsStringSync();
    expect(src, isNot(contains("byKey('cash-collect-balance')")));
    expect(src, contains("textsUnder(byKey('ride-completed-fare'))"));
  });
}
