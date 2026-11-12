import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G28 step 1: "Earnings & history" read only this phone's trip archive,
/// wiped at sign-out and reinstall, so a driver with earnings on the
/// server saw 0. A live build reads the totals from GET /driver/earnings.
void main() {
  tearDown(() => LiveDriverServices.instance = null);

  Map<String, Object?> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };

  Map<String, Object?> day(String start, String end, int net, int trips) => {
    'periodStart': start,
    'periodEnd': end,
    'tripCount': trips,
    'gross': money(net),
    'commission': money(0),
    'pickupPay': money(0),
    'tips': money(0),
    'adjustments': money(0),
    'cashCollected': money(0),
    'fees': money(0),
    'net': money(net),
  };

  final threeDays = {
    'driverId': 'd1',
    'period': 'day',
    'timeZone': 'Europe/Stockholm',
    'currency': 'SEK',
    'currencies': ['SEK'],
    'periods': [
      day('2026-11-09T23:00:00Z', '2026-11-10T23:00:00Z', 100, 1),
      day('2026-11-10T23:00:00Z', '2026-11-11T23:00:00Z', 200, 2),
      day('2026-11-11T23:00:00Z', '2026-11-12T23:00:00Z', 300, 3),
    ],
  };

  Future<List<Uri>> open(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) answer,
  ) async {
    // Signed out and in again: the phone's archive is empty.
    SharedPreferences.setMockInitialValues({});
    Money.zoneCurrency = 'SEK';
    final seen = <Uri>[];
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      seen.add(request.url);
      return answer(request);
    });
    final origin = Uri.parse('https://api.test.movera.se');
    LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _NoGps(),
    );
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DriverRideHistory()));
    await tester.pumpAndSettle();
    return seen;
  }

  String metric(WidgetTester tester, String label) {
    final card = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_MetricCard',
      ),
    );
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .where((d) => d != label);
    return texts.single!;
  }

  testWidgets(
    "G28: a live build shows the server's week total and trip count, not the phone archive",
    (tester) async {
      final seen = await open(
        tester,
        (_) async => http.Response(
          jsonEncode(threeDays),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final earnings = seen
          .where((u) => u.path == '/api/v1/driver/earnings')
          .toList();
      expect(earnings, isNotEmpty, reason: 'the server was never asked');
      final query = earnings.last.queryParameters;
      expect(query['period'], 'day');
      expect(query['currency'], 'SEK');
      final from = DateTime.parse(query['from']!);
      final to = DateTime.parse(query['to']!);
      expect(query['from'], endsWith('Z'));
      expect(query['to'], endsWith('Z'));
      // "Last 7 days": [now − 7 d, now].
      expect(to.difference(from).inHours, inInclusiveRange(167, 169));
      expect(find.text('6,00 kr'), findsWidgets);
      expect(metric(tester, 'Rides'), '6');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('G28: each period asks the server for its own range', (
    tester,
  ) async {
    final seen = await open(
      tester,
      (_) async => http.Response(
        jsonEncode(threeDays),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    final today = seen.last.queryParameters;
    final from = DateTime.parse(today['from']!).toLocal();
    final now = DateTime.now();
    expect(
      [from.year, from.month, from.day, from.hour, from.minute],
      [now.year, now.month, now.day, 0, 0],
      reason: "today starts at the phone's local midnight",
    );
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    final month = DateTime.parse(seen.last.queryParameters['from']!).toLocal();
    expect([month.day, month.hour, month.month], [1, 0, now.month]);
  });

  testWidgets('G28: server down → total unavailable, never the local sum', (
    tester,
  ) async {
    await open(tester, (_) async => http.Response('{}', 503));
    expect(find.text('Unavailable'), findsWidgets);
    // The cash-balance row stays this phone's in step 1 (its formula is
    // fare − cash per trip, not the server's net − cash); every other
    // total is the server's, so no local 0 kr outside it.
    final cashRow = find.byKey(const ValueKey('history-other-earnings'));
    final zero = find.text('0,00 kr');
    final outside = zero.evaluate().where(
      (e) => find
          .descendant(of: cashRow, matching: find.byWidget(e.widget))
          .evaluate()
          .isEmpty,
    );
    expect(outside, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.33, 18.06),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
