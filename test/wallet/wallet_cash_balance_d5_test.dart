import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/pay_movera/pay_movera.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bug D5 (Rules audits/impact/driver-wallet-cash.md; owner button 2026-11-20
/// "Yes, server + app (Rec.)"; contract v0.18.139 `driverWalletBalance`): the
/// wallet shows the cash collected this week and what the driver owes Movera
/// (or Movera owes him), then how it settles. Example Ali: 349,00 kr cash in
/// the car, own pay 325,16 kr → he owes Movera 23,84 kr. Every amount is the
/// server's (`EarningsPeriod.cashCollected`, `EarningsReport.moveraBalance`):
/// nothing is added or subtracted on the phone.
/// Rule 36: fails on main (the wallet shows only "325,16 kr intjänat").
void main() {
  Map<String, dynamic> money(int minor, String c) => {
    'amountMinor': minor,
    'currency': c,
  };
  final now = DateTime.now().toUtc();
  Map<String, dynamic> report(
    String c, {
    int net = 32516,
    int? cash = 34900,
    int? owed,
    int? owesYou,
    bool period = true,
  }) => {
    'driverId': 'D1',
    'period': 'week',
    'currency': c,
    'currencies': [c],
    'periods': [
      if (period)
        {
          'periodStart': now
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'periodEnd': now.add(const Duration(days: 5)).toIso8601String(),
          'tripCount': 3,
          'gross': money(40000, c),
          'commission': money(7484, c),
          'tips': money(0, c),
          'adjustments': money(0, c),
          'cashCollected': ?(cash == null ? null : money(cash, c)),
          'net': money(net, c),
        },
    ],
    'moveraBalance': ?(owed == null && owesYou == null
        ? null
        : {
            'owedToMovera': money(owed ?? 0, c),
            'moveraOwesYou': money(owesYou ?? 0, c),
          }),
  };

  group('EarningsWeek reads the server numbers', () {
    test('cash collected of the week and the balance, as sent', () {
      final week = EarningsWeek.of(report('SEK', owed: 2384), DateTime.now());
      expect(week.net!.formatted, '325,16 kr');
      expect(week.cashCollected!.formatted, '349,00 kr');
      expect(week.moveraBalance!.owedToMovera.formatted, '23,84 kr');
      expect(week.moveraBalance!.moveraOwesYou.amountMinor, 0);
    });

    test('an older server (no moveraBalance): null, never worked out', () {
      final week = EarningsWeek.of(report('SEK'), DateTime.now());
      expect(week.cashCollected!.formatted, '349,00 kr');
      expect(week.moveraBalance, isNull);
    });

    test('half a balance or a broken amount → no balance at all', () {
      final half = report('SEK', owed: 2384);
      (half['moveraBalance'] as Map).remove('moveraOwesYou');
      expect(EarningsWeek.of(half, DateTime.now()).moveraBalance, isNull);
      final broken = report('SEK', owed: 2384);
      (broken['moveraBalance'] as Map)['owedToMovera'] = {'amountMinor': 'x'};
      expect(EarningsWeek.of(broken, DateTime.now()).moveraBalance, isNull);
      expect(MoveraBalance.tryParse('nope'), isNull);
    });

    test('a week with no entry: cash 0 in the report currency; the balance '
        'still comes (it is the balance now)', () {
      final week = EarningsWeek.of(
        report('SEK', period: false, owed: 5000),
        DateTime.now(),
      );
      expect(week.net, isNull);
      expect(week.cashCollected!.formatted, '0,00 kr');
      expect(week.moveraBalance!.owedToMovera.formatted, '50,00 kr');
    });

    test('a period without cashCollected (optional field): no cash line', () {
      final week = EarningsWeek.of(report('SEK', cash: null), DateTime.now());
      expect(week.cashCollected, isNull);
    });
  });

  group('wallet lines', () {
    late LiveDriverServices live;
    final asked = <String>[];

    void serve(Map<String, dynamic> Function(String? currency) earnings) {
      asked.clear();
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final client = MockClient((request) async {
        asked.add(request.url.path);
        if (request.url.path.endsWith('/driver/earnings')) {
          return http.Response(
            jsonEncode(earnings(request.url.queryParameters['currency'])),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('/driver/pay-movera')) {
          return http.Response(
            jsonEncode({
              'enabled': false,
              'owedToMovera': money(2384, 'SEK'),
              'reference': 'drv_1-202611',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'items': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      live = LiveDriverServices(
        client: client,
        origin: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
        api: api,
        location: _NoGps(),
      );
      LiveDriverServices.instance = live;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Money.zoneCurrency = 'SEK';
    });
    tearDown(() async {
      LiveDriverServices.instance = null;
      Money.forgetZone();
      await live.dispose();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    String textOf(WidgetTester tester, String key) {
      final f = find.byKey(ValueKey<String>(key));
      expect(f, findsOneWidget, reason: key);
      final self = tester.widget(f);
      if (self is Text) return self.data ?? self.textSpan!.toPlainText();
      return tester
          .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
          .map((t) => t.data ?? t.textSpan!.toPlainText())
          .join(' ');
    }

    Finder key(String k) => find.byKey(ValueKey<String>(k));

    testWidgets('Ali: cash collected 349,00 kr, You owe Movera 23,84 kr, '
        'settled in the next payout', (tester) async {
      serve((_) => report('SEK', owed: 2384));
      await open(tester);
      expect(textOf(tester, 'wallet-live-week'), '325,16 kr');
      expect(
        textOf(tester, 'wallet-cash-collected'),
        'Cash collected 349,00 kr',
      );
      expect(
        textOf(tester, 'wallet-movera-balance'),
        'You owe Movera 23,84 kr',
      );
      expect(
        textOf(tester, 'wallet-balance-settles'),
        'Settled in your next payout.',
      );
    });

    testWidgets('the server number is shown as it is: never net − cash, '
        'never a phone sum', (tester) async {
      // net 325,16 and cash 349,00 would give 23,84 on the phone; the server
      // says 99,99 (an older week carried in): 99,99 is shown.
      serve((_) => report('SEK', owed: 9999));
      await open(tester);
      expect(
        textOf(tester, 'wallet-movera-balance'),
        'You owe Movera 99,99 kr',
      );
      expect(find.textContaining('23,84'), findsNothing);
    });

    testWidgets('Movera owes him: that line, with the amount', (tester) async {
      serve((_) => report('SEK', net: 50000, cash: 0, owesYou: 50000));
      await open(tester);
      expect(textOf(tester, 'wallet-cash-collected'), 'Cash collected 0,00 kr');
      expect(
        textOf(tester, 'wallet-movera-balance'),
        'Movera owes you 500,00 kr',
      );
      expect(key('wallet-balance-settles'), findsOneWidget);
    });

    testWidgets('nothing owed either way: Settled, no amount to pay', (
      tester,
    ) async {
      serve((_) => report('SEK', owed: 0, owesYou: 0));
      await open(tester);
      expect(textOf(tester, 'wallet-movera-balance'), 'Settled');
      expect(key('wallet-pay-movera'), findsNothing);
    });

    testWidgets('an older server: the cash line only, no owed line and no '
        'made-up number', (tester) async {
      serve((_) => report('SEK'));
      await open(tester);
      expect(
        textOf(tester, 'wallet-cash-collected'),
        'Cash collected 349,00 kr',
      );
      expect(key('wallet-movera-balance'), findsNothing);
      expect(key('wallet-balance-settles'), findsNothing);
      expect(find.textContaining('23,84'), findsNothing);
    });

    testWidgets('the report could not be read: no line at all', (tester) async {
      serve((_) => {'broken': true, 'periods': 'x'});
      await open(tester);
      expect(key('wallet-movera-balance'), findsNothing);
    });

    testWidgets('Tunis: dinars keep 3 decimals', (tester) async {
      Money.zoneCurrency = 'TND';
      serve((_) => report('TND', net: 16000, cash: 22000, owed: 6000));
      await open(tester);
      expect(
        textOf(tester, 'wallet-cash-collected'),
        'Cash collected 22.000 DT',
      );
      expect(
        textOf(tester, 'wallet-movera-balance'),
        'You owe Movera 6.000 DT',
      );
    });

    for (final (lang, cash, owes, settles) in const [
      (
        'sv',
        'Kontant mottaget 349,00 kr',
        'Du är skyldig Movera 23,84 kr',
        'Regleras i din nästa utbetalning.',
      ),
      (
        'fr',
        'Espèces encaissées 349,00 kr',
        'Vous devez à Movera 23,84 kr',
        'Réglé lors de votre prochain versement.',
      ),
    ]) {
      testWidgets('$lang texts (the app\'s existing words)', (tester) async {
        await tester.runAsync(() => DriverLanguage.choose(lang));
        addTearDown(DriverLanguage.resetForTest);
        serve((_) => report('SEK', owed: 2384));
        await open(tester);
        expect(textOf(tester, 'wallet-cash-collected'), cash);
        expect(textOf(tester, 'wallet-movera-balance'), owes);
        expect(textOf(tester, 'wallet-balance-settles'), settles);
      });
    }

    testWidgets('a tap on "You owe Movera" opens Pay Movera', (tester) async {
      serve((_) => report('SEK', owed: 2384));
      await open(tester);
      await tester.tap(key('wallet-pay-movera'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PayMoveraScreen), findsOneWidget);
      expect(asked, contains('/api/v1/driver/pay-movera'));
    });

    testWidgets('large text and a narrow phone: no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => DriverLanguage.choose('fr'));
      addTearDown(DriverLanguage.resetForTest);
      serve(
        (_) => report('SEK', net: 123456789, cash: 123456789, owed: 123456789),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: WalletScreen(),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      expect(key('wallet-movera-balance'), findsOneWidget);
    });
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
