import 'dart:io';

import 'package:flutter/material.dart';
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
    expect(
      src,
      contains("PayVerdict.shareTexts(byKey('ride-completed-fare'))"),
    );
  });

  // Firebase run 45126933400 (main 653acef): server driverEarnings 111,03 kr
  // + pickupPay 1,80 kr = driverTotal 112,83 kr; Ride completed showed
  // "Din andel 112,83 kr" in a Text.rich that carries the key itself, and
  // PAY read nothing under it ("112,83 kr shown=false").
  const driverTotal = Money(minorUnits: 11283, currency: 'SEK');

  testWidgets('share read from the keyed Text.rich itself (run 45126933400)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const Text(
              '142,00 kr',
              key: ValueKey<String>('ride-completed-total'),
            ),
            Text.rich(
              key: const ValueKey<String>('ride-completed-fare'),
              TextSpan(text: driverTotal.formatted),
            ),
          ],
        ),
      ),
    );
    final texts = PayVerdict.shareTexts(
      find.byKey(const ValueKey<String>('ride-completed-fare')),
    );
    expect(texts, [driverTotal.formatted]);
    expect(PayVerdict.shareShown(driverTotal, texts), isTrue);
    expect(pay(PayVerdict.shareShown(driverTotal, texts)), isTrue);
  });

  test('exact match: a longer or shorter amount is not the share', () {
    expect(PayVerdict.shareShown(driverTotal, ['1 112,83 kr']), isFalse);
    expect(
      PayVerdict.shareShown(const Money(minorUnits: 1283, currency: 'SEK'), [
        driverTotal.formatted,
      ]),
      isFalse,
    );
    expect(
      PayVerdict.shareShown(driverTotal, [' ${driverTotal.formatted} ']),
      isTrue,
    );
  });
}
