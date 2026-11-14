import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Job A5 / BQ-M13 (contract v0.18.94 payouts.schedule.nextPayout; owner
/// G10-2 "Admin sets day and time (Recommended)" … "driver app shows next
/// payout", Rules decisions/driver-g10.md:6): the Wallet shows
/// "Next payout: Mon 08:00" from the server's `nextPayoutLocal` (the payout
/// zone's wall clock, never the phone's), in the driver's language. Without
/// the field (older server, paused payouts) the old line stays.
void main() {
  LiveDriverServices? live;
  late List<Uri> asked;

  void serve(Map<String, Object?> page) {
    asked = [];
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      asked.add(request.url);
      if (request.url.path.endsWith('/driver/earnings')) {
        return http.Response(
          jsonEncode({
            'currency': 'SEK',
            'currencies': ['SEK'],
            'periods': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(page),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    final services = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    live = services;
    LiveDriverServices.instance = services;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    DriverAppTexts.language = 'en';
    LiveDriverServices.instance = null;
    Money.forgetZone();
    await live?.dispose();
    live = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const page = {
    'items': <Object>[],
    'nextCursor': null,
    'nextPayoutAt': '2026-11-16T07:00:00Z',
    'nextPayoutLocal': '2026-11-16T08:00',
    'nextPayoutTimeZone': 'Europe/Stockholm',
  };

  test('DriverPayoutPage reads nextPayoutLocal as the zone wall clock', () {
    final p = DriverPayoutPage.of(page);
    expect(p.items, isEmpty);
    expect(p.nextPayoutLocal, DateTime.utc(2026, 11, 16, 8, 0));
    // Supervisor S1: a UTC wall clock, so the phone's own summer-time gap
    // never moves it (Sunday 02:30 on a spring-forward night stays 02:30).
    expect(p.nextPayoutLocal!.isUtc, isTrue);
    final gap = DriverPayoutPage.of({
      'items': <Object>[],
      'nextPayoutLocal': '2026-03-29T02:30',
    }).nextPayoutLocal!;
    expect(
      [gap.year, gap.month, gap.day, gap.hour, gap.minute],
      [2026, 3, 29, 2, 30],
    );
    expect(DriverPayoutPage.of({'items': <Object>[]}).nextPayoutLocal, isNull);
    expect(
      DriverPayoutPage.of({
        'items': <Object>[],
        'nextPayoutLocal': 'soon',
      }).nextPayoutLocal,
      isNull,
    );
  });

  testWidgets('en: "Next payout: Mon 08:00" with the date, one payouts read', (
    tester,
  ) async {
    serve(page);
    await open(tester);
    expect(find.text('Next payout: Mon 08:00'), findsOneWidget);
    expect(find.text('16 Nov 2026'), findsOneWidget);
    expect(find.text('No automatic payout'), findsNothing);
    expect(find.text('Payout date is not available'), findsNothing);
    expect(find.text('No payouts yet.'), findsOneWidget);
    expect(asked.where((u) => u.path.endsWith('/driver/payouts')).length, 1);
  });

  testWidgets('sv: "Nästa utbetalning: mån 08:00"', (tester) async {
    DriverAppTexts.language = 'sv';
    serve(page);
    await open(tester);
    expect(find.text('Nästa utbetalning: mån 08:00'), findsOneWidget);
    expect(find.text('16 nov. 2026'), findsOneWidget);
  });

  testWidgets('fr: "Prochain versement : lun. 08:00"', (tester) async {
    DriverAppTexts.language = 'fr';
    serve(page);
    await open(tester);
    expect(find.text('Prochain versement : lun. 08:00'), findsOneWidget);
  });

  testWidgets('no nextPayoutLocal (paused / older server): the old line', (
    tester,
  ) async {
    serve({'items': <Object>[], 'nextCursor': null});
    await open(tester);
    expect(find.textContaining('Next payout'), findsNothing);
    expect(find.text('Payout date is not available'), findsOneWidget);
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
