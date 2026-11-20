import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept ride/cash_collect_sheet.dart';

/// Owner 2026-11-19 "Yes, build M2 + M3 (Rec.)" (Rules
/// decisions/session-2026-11-06.md; contract v0.18.140
/// `completePreview.cashDueSplit`): the collect sheet keeps the big
/// "Ta emot 250,00 kr kontant" and shows "Resa 215,00 kr" and "Tidigare
/// avgift (till Movera) 35,00 kr" under it, only from the server's
/// `cashDueRide` / `cashDueOutstandingFee` (never a sum on the phone).
Map<String, Object?> _m(int minor, [String currency = 'SEK']) => {
  'amountMinor': minor,
  'currency': currency,
};

Map<String, dynamic> _preview([Map<String, Object?> extra = const {}]) => {
  'previewId': 'cpv_1',
  'total': _m(25000),
  'cashDue': _m(25000),
  'earlyEnd': false,
  'driverEarnings': _m(17200),
  'fareLines': const [],
  ...extra,
};

const _sek = Money(minorUnits: 21500, currency: 'SEK');
const _fee = Money(minorUnits: 3500, currency: 'SEK');

Future<void> _pump(WidgetTester tester, Widget sheet) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));
  await tester.pump();
}

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  group('CompletePreview cash split (v0.18.140)', () {
    test('reads the server\'s ride and earlier-fee parts', () {
      final p = CompletePreview.tryParse(
        _preview({'cashDueRide': _m(21500), 'cashDueOutstandingFee': _m(3500)}),
      )!;
      expect(p.cashDueRide, _sek);
      expect(p.cashDueOutstandingFee, _fee);
    });

    test('absent, only one, or another currency: no split', () {
      for (final extra in <Map<String, Object?>>[
        {},
        {'cashDueRide': _m(21500)},
        {'cashDueOutstandingFee': _m(3500)},
        {'cashDueRide': _m(21500), 'cashDueOutstandingFee': _m(3500, 'EUR')},
      ]) {
        final p = CompletePreview.tryParse(_preview(extra))!;
        expect(p.cashDueRide, isNull, reason: '$extra');
        expect(p.cashDueOutstandingFee, isNull, reason: '$extra');
      }
    });
  });

  group('Collect sheet rows (M3)', () {
    testWidgets('sv: big 250,00 kr, then Resa 215,00 kr and the fee', (
      tester,
    ) async {
      DriverAppTexts.language = 'sv';
      await _pump(
        tester,
        CashCollectSheet(
          fare: '172,00 kr',
          cash: '250,00 kr',
          riderName: 'Sara',
          live: false,
          rideCash: _sek,
          earlierFee: _fee,
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cash-collect-amount')))
            .data,
        '250,00 kr',
      );
      final ride = find.byKey(const ValueKey('cash-collect-ride'));
      final fee = find.byKey(const ValueKey('cash-collect-earlier-fee'));
      expect(
        find.descendant(of: ride, matching: find.text('Resa')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ride, matching: find.text('215,00 kr')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: fee,
          matching: find.text('Tidigare avgift (till Movera)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fee, matching: find.text('35,00 kr')),
        findsOneWidget,
      );
      // Under the big amount, inside the case.
      final caseBox = find.byKey(const ValueKey('cash-collect-case'));
      expect(find.descendant(of: caseBox, matching: ride), findsOneWidget);
      expect(
        tester.getTopLeft(ride).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('cash-collect-amount')))
              .dy,
        ),
      );
    });

    testWidgets('no split from the server: no rows (as before)', (
      tester,
    ) async {
      await _pump(
        tester,
        const CashCollectSheet(
          fare: '172,00 kr',
          cash: '250,00 kr',
          riderName: 'Sara',
          live: false,
        ),
      );
      expect(find.byKey(const ValueKey('cash-collect-ride')), findsNothing);
      expect(
        find.byKey(const ValueKey('cash-collect-earlier-fee')),
        findsNothing,
      );
    });

    testWidgets('only one part: no rows, never worked out on the phone', (
      tester,
    ) async {
      await _pump(
        tester,
        const CashCollectSheet(
          fare: '172,00 kr',
          cash: '250,00 kr',
          riderName: 'Sara',
          live: false,
          earlierFee: _fee,
        ),
      );
      expect(find.byKey(const ValueKey('cash-collect-ride')), findsNothing);
      expect(
        find.byKey(const ValueKey('cash-collect-earlier-fee')),
        findsNothing,
      );
    });
  });
}
