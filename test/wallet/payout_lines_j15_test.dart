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
import 'package:shared_preferences/shared_preferences.dart';

/// S5 J15 (contract v0.18.133 payoutLines.driver; owner 2026-11-19 "driver
/// payout 3 lines", "carry line only when needed"): a payout with parts shows
/// Earned · Owed to Movera · Paid out, and "Moves to next week: X" only when
/// carriedOut > 0. Server amounts as sent; nothing worked out on the phone.
/// Rule 36: fails on main (no parts read, no lines).
void main() {
  Map<String, dynamic> money(int minor, String c) => {
    'amountMinor': minor,
    'currency': c,
  };
  Map<String, dynamic> payout(
    String c, {
    required int earned,
    required int owed,
    required int paid,
    required int carriedOut,
  }) => {
    'payoutId': 'PY1',
    'driverId': 'D1',
    'amount': money(paid, c),
    'status': 'pending',
    'periodStart': '2026-11-02T00:00:00Z',
    'periodEnd': '2026-11-09T00:00:00Z',
    'createdAt': '2026-11-09T01:00:00Z',
    'source': 'weekly',
    'tripCount': 1,
    'summary': {'driverGets': money(7027, c), 'moveraGets': money(2473, c)},
    'earned': money(earned, c),
    'owedToMovera': money(owed, c),
    'paidOut': money(paid, c),
    'carriedIn': money(0, c),
    'carriedOut': money(carriedOut, c),
  };

  group('DriverPayout.parts parse', () {
    test(
      'all four amounts → parts; one missing → null (the 2 summary lines stay)',
      () {
        final p = DriverPayout.tryParse(
          payout('SEK', earned: 0, owed: 2473, paid: 0, carriedOut: 2473),
        )!;
        expect(p.parts, isNotNull);
        expect(p.parts!.owedToMovera.formatted, '24,73 kr');
        expect(p.parts!.movesToNextWeek, isTrue);
        final old = payout('SEK', earned: 0, owed: 0, paid: 0, carriedOut: 0)
          ..remove('carriedOut');
        expect(DriverPayout.tryParse(old)!.parts, isNull);
        expect(DriverPayout.tryParse(old)!.summary, isNotNull);
      },
    );
    test('TND keeps 3 decimals', () {
      final p = DriverPayout.tryParse(
        payout('TND', earned: 6000, owed: 8001, paid: 0, carriedOut: 2001),
      )!;
      expect(p.parts!.carriedOut.amountMinor, 2001);
      expect(p.parts!.carriedOut.formatted, '2.001 DT');
    });
  });

  group('wallet payout card with parts', () {
    late LiveDriverServices live;

    void serve(List<Map<String, dynamic>> items) {
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/driver/payouts')) {
          return http.Response(
            jsonEncode({'items': items, 'nextCursor': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/driver/earnings')) {
          return http.Response(
            jsonEncode({
              'currency': 'SEK',
              'currencies': ['SEK'],
              'periods': [],
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

    testWidgets(
      'week with owed > earned: 3 lines + Moves to next week; no summary lines',
      (tester) async {
        serve([
          payout('SEK', earned: 0, owed: 2473, paid: 0, carriedOut: 2473),
        ]);
        await open(tester);
        expect(textOf(tester, 'wallet-payout-earned'), 'Earned 0,00 kr');
        expect(
          textOf(tester, 'wallet-payout-owed-to-movera'),
          'Owed to Movera 24,73 kr',
        );
        expect(textOf(tester, 'wallet-payout-paid-out'), 'Paid out 0,00 kr');
        expect(
          textOf(tester, 'wallet-payout-moves-next-week'),
          'Moves to next week: 24,73 kr',
        );
        expect(
          find.byKey(const ValueKey<String>('wallet-payout-driver-gets')),
          findsNothing,
        );
      },
    );

    testWidgets('normal week: 3 lines only, no 4th line', (tester) async {
      serve([
        payout('SEK', earned: 10000, owed: 2473, paid: 7527, carriedOut: 0),
      ]);
      await open(tester);
      expect(textOf(tester, 'wallet-payout-paid-out'), 'Paid out 75,27 kr');
      expect(
        find.byKey(const ValueKey<String>('wallet-payout-moves-next-week')),
        findsNothing,
      );
    });

    for (final (lang, line) in const [
      ('sv', 'Flyttas till nästa vecka: 24,73 kr'),
      ('fr', 'Reporté à la semaine prochaine : 24,73 kr'),
    ]) {
      testWidgets('$lang texts', (tester) async {
        await tester.runAsync(() => DriverLanguage.choose(lang));
        addTearDown(DriverLanguage.resetForTest);
        serve([
          payout('SEK', earned: 0, owed: 2473, paid: 0, carriedOut: 2473),
        ]);
        await open(tester);
        expect(textOf(tester, 'wallet-payout-moves-next-week'), line);
      });
    }
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
