import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_income_statement.dart';
import 'package:movera/presentation/driver/my wallet/year_statement.dart';

/// v0.18.153 P29 (contract.json#driverIncomeYear; owner 2026-11-21 "Execute!
/// ... everywhere", DAC7): Earnings › Year statement reads
/// `GET /driver/income-statement` and shows year → months → days → trips
/// with the server's totals. Fake values only.
Map<String, dynamic> _m(int minor) => {'amountMinor': minor, 'currency': 'SEK'};
Map<String, dynamic> _t(int rides, int net, {int gross = 0, int cash = 0}) => {
  'rides': rides,
  'grossFares': _m(gross),
  'tips': _m(0),
  'bonuses': _m(0),
  'adjustments': _m(0),
  'pickupPay': _m(0),
  'feeShare': _m(0),
  'moveraCommission': _m(gross - net),
  'moveraFees': _m(0),
  'netEarnings': _m(net),
  'cashCollectedByDriver': _m(cash),
  'paidOutByMovera': _m(0),
};
Map<String, dynamic> _row({
  bool own = false,
  List<Map<String, dynamic>>? trips,
}) => {
  'kind': own ? 'company' : 'driver',
  'payeeId': own ? 'flt_1' : 'drv_1',
  'name': own ? 'Test Taxi AB' : 'Inc Test',
  'orgNumber': own ? '000000-0000' : null,
  'address': null,
  'country': 'SE',
  'currency': 'SEK',
  'bank': null,
  'driverIds': ['drv_1'],
  if (own) 'ownPartOnly': true,
  ..._t(2, 24000, gross: 30000, cash: 15000),
  'quarters': [
    {'quarter': 1, ..._t(2, 24000, gross: 30000, cash: 15000)},
  ],
  'months': [
    {
      'month': '2025-01',
      ..._t(2, 24000, gross: 30000, cash: 15000),
      'days': [
        {
          'day': '2025-01-01',
          ..._t(2, 24000, gross: 30000, cash: 15000),
          if (trips != null) 'trips': trips,
        },
      ],
    },
  ],
};

ApiClient _api(List<Uri> asked, {bool own = false, bool empty = false}) =>
    ApiClient(
      client: MockClient((request) async {
        asked.add(request.url);
        final trips = request.url.queryParameters['detail'] == 'trips';
        return http.Response(
          jsonEncode({
            'year': 2025,
            'detail': request.url.queryParameters['detail'],
            'items': empty
                ? []
                : [
                    _row(
                      own: own,
                      trips: trips
                          ? [
                              {
                                'localTime': '2025-01-01T00:30',
                                'tripId': 'trp_inc_1',
                                'zoneId': 'Z001',
                                'paymentMethod': 'cash',
                                ..._t(1, 12000, gross: 15000, cash: 15000),
                              },
                              {
                                'localTime': '2025-01-01T09:00',
                                'tripId': 'trp_inc_2',
                                'zoneId': 'Z001',
                                'paymentMethod': 'card',
                                ..._t(1, 12000, gross: 15000),
                              },
                            ]
                          : null,
                    ),
                  ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );

void main() {
  test('reads the driver\'s own statement with the server\'s totals', () async {
    final asked = <Uri>[];
    final s = await LiveIncomeStatement(
      api: _api(asked),
    ).load(year: 2025, detail: 'day');
    expect(asked.single.path, '/api/v1/driver/income-statement');
    expect(asked.single.queryParameters, {'year': '2025', 'detail': 'day'});
    final row = s.rows.single;
    expect(row.totals.rides, 2);
    expect(row.totals.netEarnings.minorUnits, 24000);
    expect(row.totals.cash.minorUnits, 15000);
    expect(row.months.single.days!.single.day, '2025-01-01');
    final trips = await LiveIncomeStatement(
      api: _api(asked),
    ).load(year: 2025, detail: 'trips', month: '2025-01');
    expect(asked.last.queryParameters['month'], '2025-01');
    expect(
      trips.rows.single.months.single.days!.single.trips!.map((t) => t.tripId),
      ['trp_inc_1', 'trp_inc_2'],
    );
  });

  testWidgets('Year statement: last year first, year → month → day → trips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: YearStatementScreen(
          source: LiveIncomeStatement(api: _api(asked)),
          now: DateTime(2026, 11, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(asked.single.queryParameters['year'], '2025');
    expect(
      find.text('What Movera reports to the tax office for 2025'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('year-total-SEK')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('year-month-2025-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('year-day-2025-01-01')));
    await tester.pumpAndSettle();
    expect(asked.last.queryParameters['detail'], 'trips');
    expect(find.textContaining('trp_inc_1'), findsOneWidget);
    expect(find.textContaining('trp_inc_2'), findsOneWidget);
  });

  testWidgets('a fleet driver who does not own it sees "Your own part of"', (
    tester,
  ) async {
    final asked = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: YearStatementScreen(
          source: LiveIncomeStatement(api: _api(asked, own: true)),
          now: DateTime(2026, 11, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your own part of Test Taxi AB'), findsOneWidget);
  });

  testWidgets('no earnings: the empty line, share off', (tester) async {
    final asked = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: YearStatementScreen(
          source: LiveIncomeStatement(api: _api(asked, empty: true)),
          now: DateTime(2026, 11, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('year-statement-empty')),
      findsOneWidget,
    );
    final share = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('year-statement-share')),
    );
    expect(share.onPressed, isNull);
  });
}
