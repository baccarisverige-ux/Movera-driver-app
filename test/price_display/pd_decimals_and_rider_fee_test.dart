import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept ride/rider_cancelled_sheet.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';

/// Price audit 2026-11-14 gap 10 (owner 2026-11-14: whole amounts keep
/// their decimals, TND with 3) and gap 19 (the driver sees only his own
/// money, never the rider's fee).
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(home: Scaffold(body: screen)),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool _anyText(WidgetTester tester, bool Function(String) test) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => test(t.data ?? t.textSpan?.toPlainText() ?? ''));

void main() {
  group('gap 10: whole amounts keep their decimals', () {
    test('formattedShort is the exact form in every currency', () {
      expect(
        const Money(minorUnits: 4000, currency: 'SEK').formattedShort,
        '40,00 kr',
      );
      expect(
        const Money(minorUnits: 800, currency: 'EUR').formattedShort,
        '8,00 €',
      );
      expect(
        const Money(minorUnits: 5000, currency: 'TND').formattedShort,
        '5.000 DT',
      );
    });

    test('island fee and tip texts keep the decimals', () {
      expect(
        HomeIslandNotices.feeSuffix(
          const Money(minorUnits: 4500, currency: 'SEK'),
        ),
        contains('45,00 kr'),
      );
      expect(
        const TripTipInfo(
          amount: Money(minorUnits: 2000, currency: 'SEK'),
          method: 'card',
        ).text,
        contains('20,00 kr'),
      );
    });

    testWidgets('the cash collect sheet shows 250,00 kr / 5.000 DT', (
      tester,
    ) async {
      await _pump(
        tester,
        const CashCollectSheet(
          fare: '150,00 kr',
          cash: '250,00 kr',
          riderName: 'Anna',
          category: 'Movera',
        ),
      );
      expect(_anyText(tester, (t) => t.contains('250,00 kr')), isTrue);
      expect(_anyText(tester, (t) => RegExp(r'\b250 kr').hasMatch(t)), isFalse);

      await _pump(
        tester,
        const CashCollectSheet(
          fare: '4.000 DT',
          cash: '5.000 DT',
          riderName: 'Anna',
          category: 'Movera',
        ),
      );
      expect(_anyText(tester, (t) => t.contains('5.000 DT')), isTrue);
      expect(
        _anyText(tester, (t) => RegExp(r'(^|\s)5 DT').hasMatch(t)),
        isFalse,
      );
    });
  });

  group('gap 19: rider-cancelled sheet', () {
    testWidgets("shows the driver's share, never the rider's fee", (
      tester,
    ) async {
      await _pump(
        tester,
        RiderCancelledSheet(
          riderName: 'Nils',
          wasOnTrip: false,
          fee: const Money(minorUnits: 4500, currency: 'SEK'),
          feeKind: 'no_show',
          riderFee: const Money(minorUnits: 9000, currency: 'SEK'),
          onAcknowledge: () {},
        ),
      );
      expect(_anyText(tester, (t) => t.contains('45,00 kr')), isTrue);
      expect(_anyText(tester, (t) => t.contains('90')), isFalse);
    });
  });
}
