import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BQ-V44 driver part (contract v0.18.103 `bonusCampaigns`, Rules
/// audits/impact/v44-driver-bonuses.md §8): the Campaigns screen on live
/// reads GET /driver/bonuses and shows the server's numbers only (R8
/// "apps never work money out"): progress as trips or as "4 h 20 min",
/// the amount in the currency's decimals, "Earned", a NEW badge from
/// isNew, and POST /driver/bonuses/opened once. EarningsPeriod.bonus is
/// a part of net, never added to it again.
void main() {
  late List<http.Request> seen;
  late Map<String, http.Response Function(http.Request)> routes;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  void installLive() {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      seen.add(request);
      final route = routes['${request.method} ${request.url.path}'];
      return route == null
          ? json(404, {
              'code': 'not_found',
              'message': 'no',
              'requestId': 'x',
              'retryable': false,
            })
          : route(request);
    });
    final origin = Uri.parse('https://api.test.movera.se');
    LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _NoGps(),
    );
  }

  Map<String, Object?> money(int minor, String currency) => {
    'amountMinor': minor,
    'currency': currency,
  };

  Map<String, Object?> bonus({
    required String id,
    required String en,
    String measure = 'trips',
    String state = 'active',
    required int done,
    required int target,
    required Map<String, Object?> amount,
    bool earned = false,
    bool isNew = false,
    String startDate = '2026-11-10',
    String endDate = '2026-11-30',
  }) => {
    'bonusId': id,
    'names': {'sv': 'SV $en', 'fr': 'FR $en', 'en': en},
    'measure': measure,
    'state': state,
    'startDate': startDate,
    'endDate': endDate,
    'timeZone': 'Europe/Stockholm',
    'polygon': [
      [59.30, 18.00],
      [59.40, 18.00],
      [59.40, 18.10],
    ],
    'bounds': {'south': 59.30, 'west': 18.00, 'north': 59.40, 'east': 18.10},
    'amount': amount,
    'progress': {'done': done, 'target': target},
    'earned': earned,
    if (earned) 'earnedAt': '2026-11-14T10:00:00Z',
    'isNew': isNew,
  };

  List<Map<String, Object?>> sekItems() => [
    bonus(
      id: 'b1',
      en: 'City rush',
      done: 3,
      target: 10,
      amount: money(15000, 'SEK'),
      isNew: true,
    ),
    bonus(
      id: 'b2',
      en: 'Long shift',
      measure: 'online_hours',
      done: 260,
      target: 600,
      amount: money(50000, 'SEK'),
    ),
    bonus(
      id: 'b3',
      en: 'Airport week',
      done: 10,
      target: 10,
      amount: money(8000, 'SEK'),
      earned: true,
    ),
  ];

  List<http.Request> opened() => seen
      .where(
        (r) =>
            r.method == 'POST' && r.url.path == '/api/v1/driver/bonuses/opened',
      )
      .toList();

  Future<void> openScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Promotions()));
    await tester.pumpAndSettle();
  }

  setUp(() {
    seen = [];
    routes = {
      'POST /api/v1/driver/bonuses/opened': (_) => http.Response('', 204),
    };
    DriverAppTexts.language = 'en';
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    LiveDriverServices.instance = null;
    DriverAppTexts.language = 'en';
    Promotions.resetOpened();
    Money.zoneCurrency = 'SEK';
  });

  group('Campaigns screen on live (SEK)', () {
    testWidgets('shows the server progress, amounts, Earned and NEW; '
        'no demo campaign', (tester) async {
      routes['GET /api/v1/driver/bonuses'] = (_) =>
          json(200, {'items': sekItems()});
      installLive();
      await openScreen(tester);

      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('City rush'), findsOneWidget);
      expect(find.text('150,00 kr'), findsOneWidget);
      expect(find.text('500,00 kr'), findsOneWidget);
      expect(find.text('80,00 kr'), findsOneWidget);
      expect(find.text('3 of 10 trips'), findsOneWidget);
      expect(find.text('4 h 20 min of 10 h online'), findsOneWidget);
      expect(find.text('Earned – added to your next payout'), findsOneWidget);
      expect(find.text('Ends 30 Nov'), findsWidgets);
      // NEW on the one card the server marks isNew.
      expect(find.text('NEW'), findsOneWidget);
      // R5 / G3-D6: the invented demo campaigns never show on live.
      expect(find.text('PEAK80'), findsNothing);
      expect(find.textContaining('+80 kr'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('POST /driver/bonuses/opened once, with the new ids only', (
      tester,
    ) async {
      routes['GET /api/v1/driver/bonuses'] = (_) =>
          json(200, {'items': sekItems()});
      installLive();
      await openScreen(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final posts = opened();
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body), {
        'bonusIds': ['b1'],
      });
      expect(posts.single.headers['Idempotency-Key'], isNotEmpty);
    });

    testWidgets('nothing new → no opened call', (tester) async {
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {
        'items': [
          bonus(
            id: 'b9',
            en: 'Quiet',
            done: 0,
            target: 5,
            amount: money(100, 'SEK'),
          ),
        ],
      });
      installLive();
      await openScreen(tester);
      expect(find.text('0 of 5 trips'), findsOneWidget);
      expect(find.text('NEW'), findsNothing);
      expect(opened(), isEmpty);
    });

    testWidgets('Swedish texts from the contract', (tester) async {
      DriverAppTexts.language = 'sv';
      routes['GET /api/v1/driver/bonuses'] = (_) =>
          json(200, {'items': sekItems()});
      installLive();
      await openScreen(tester);
      expect(find.text('Kampanjer'), findsOneWidget);
      expect(find.text('SV City rush'), findsOneWidget);
      expect(find.text('3 av 10 resor'), findsOneWidget);
      expect(find.text('4 h 20 min av 10 h online'), findsOneWidget);
      expect(
        find.text('Intjänad – läggs till nästa utbetalning'),
        findsOneWidget,
      );
      expect(find.text('NY'), findsOneWidget);
    });

    testWidgets('scheduled, paused and ended states', (tester) async {
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {
        'items': [
          bonus(
            id: 's',
            en: 'Soon',
            state: 'scheduled',
            startDate: '2026-12-01',
            endDate: '2026-12-07',
            done: 0,
            target: 60,
            measure: 'online_hours',
            amount: money(2000, 'SEK'),
          ),
          bonus(
            id: 'p',
            en: 'Held',
            state: 'paused',
            done: 1,
            target: 4,
            amount: money(2000, 'SEK'),
          ),
          bonus(
            id: 'e',
            en: 'Over',
            state: 'ended',
            done: 2,
            target: 4,
            amount: money(2000, 'SEK'),
          ),
        ],
      });
      installLive();
      await openScreen(tester);
      expect(find.text('Starts 1 Dec'), findsOneWidget);
      // Whole hours: "1 h", and 0 minutes "0 h" (texts.durationWholeHours).
      expect(find.text('0 h of 1 h online'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {'items': []});
      installLive();
      await openScreen(tester);
      expect(find.text('No campaigns right now'), findsOneWidget);
      expect(find.text('PEAK80'), findsNothing);
    });

    testWidgets('a server error shows Retry, never the demo', (tester) async {
      var calls = 0;
      routes['GET /api/v1/driver/bonuses'] = (_) {
        calls++;
        return calls == 1
            ? json(503, {
                'code': 'unavailable',
                'message': 'down',
                'requestId': 'x',
                'retryable': true,
              })
            : json(200, {'items': sekItems()});
      };
      installLive();
      await openScreen(tester);
      expect(find.text('PEAK80'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('3 of 10 trips'), findsOneWidget);
    });
  });

  group('Campaigns screen on live (TND)', () {
    testWidgets('dinar with a dot and 3 decimals; hours from minutes', (
      tester,
    ) async {
      DriverAppTexts.language = 'fr';
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {
        'items': [
          bonus(
            id: 't1',
            en: 'Tunis',
            measure: 'online_hours',
            done: 125,
            target: 1200,
            amount: money(20000, 'TND'),
            isNew: true,
          ),
          bonus(
            id: 't2',
            en: 'Sfax',
            done: 7,
            target: 7,
            amount: money(1250500, 'TND'),
            earned: true,
          ),
        ],
      });
      installLive();
      await openScreen(tester);
      expect(find.text('Campagnes'), findsOneWidget);
      expect(find.text('FR Tunis'), findsOneWidget);
      expect(find.text('20.000 DT'), findsOneWidget);
      expect(find.text('1 250.500 DT'), findsOneWidget);
      expect(find.text('2 h 5 min sur 20 h en ligne'), findsOneWidget);
      expect(find.text('7 sur 7 courses'), findsOneWidget);
      expect(
        find.text('Gagnée – ajoutée au prochain versement'),
        findsOneWidget,
      );
      expect(find.text('NOUVEAU'), findsOneWidget);
      expect(jsonDecode(opened().single.body), {
        'bonusIds': ['t1'],
      });
    });
  });

  group('demo', () {
    testWidgets('the demo catalog (PEAK80) stays demo-only', (tester) async {
      await openScreen(tester);
      expect(find.text('PEAK80'), findsOneWidget);
      expect(seen, isEmpty);
    });
  });

  group('side menu NEW badge from isNew (live)', () {
    Future<void> pumpMenu(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = DriverSessionController();
      addTearDown(controller.dispose);
      final account = DriverAccountSession(
        repository: DriverAccountRepository(LiveDriverServices.instance!.api),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DriverRuntimeScope(
            session: controller,
            homeBuilder: () => const SizedBox(),
            account: account,
            child: const Scaffold(body: DriverSideMenu()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('NEW while the server has an unopened campaign, gone after '
        'the screen is opened', (tester) async {
      var newOnServer = true;
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {
        'items': [
          bonus(
            id: 'b1',
            en: 'City rush',
            done: 3,
            target: 10,
            amount: money(15000, 'SEK'),
            isNew: newOnServer,
          ),
        ],
      });
      routes['POST /api/v1/driver/bonuses/opened'] = (_) {
        newOnServer = false;
        return http.Response('', 204);
      };
      installLive();
      await pumpMenu(tester);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      await tester.tap(find.text('Campaigns'));
      await tester.pumpAndSettle();
      expect(opened(), hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpMenu(tester);
      expect(find.text('NEW'), findsNothing);
    });

    testWidgets('no unopened campaign → no NEW', (tester) async {
      routes['GET /api/v1/driver/bonuses'] = (_) => json(200, {
        'items': [
          bonus(
            id: 'b1',
            en: 'City rush',
            done: 3,
            target: 10,
            amount: money(15000, 'SEK'),
          ),
        ],
      });
      installLive();
      await pumpMenu(tester);
      expect(find.text('NEW'), findsNothing);
    });
  });

  group('EarningsPeriod.bonus is part of net, never added again', () {
    Map<String, Object?> period(
      String start,
      String end,
      String currency, {
      required int net,
      required int bonus,
    }) => {
      'periodStart': start,
      'periodEnd': end,
      'tripCount': 2,
      'gross': money(net, currency),
      'commission': money(0, currency),
      'pickupPay': money(0, currency),
      'tips': money(0, currency),
      'adjustments': money(0, currency),
      'cashCollected': money(0, currency),
      'fees': money(0, currency),
      'net': money(net, currency),
      'bonus': money(bonus, currency),
    };

    Future<void> openHistory(WidgetTester tester, String currency) async {
      Money.zoneCurrency = currency;
      installLive();
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DriverRideHistory()));
      await tester.pumpAndSettle();
    }

    testWidgets('SEK: net 1 050,00 kr holds the 150,00 kr bonus', (
      tester,
    ) async {
      routes['GET /api/v1/driver/earnings'] = (_) => json(200, {
        'driverId': 'd1',
        'period': 'day',
        'currency': 'SEK',
        'currencies': ['SEK'],
        'periods': [
          period(
            '2026-11-09T23:00:00Z',
            '2026-11-10T23:00:00Z',
            'SEK',
            net: 50000,
            bonus: 0,
          ),
          period(
            '2026-11-10T23:00:00Z',
            '2026-11-11T23:00:00Z',
            'SEK',
            net: 55000,
            bonus: 15000,
          ),
        ],
      });
      await openHistory(tester, 'SEK');
      expect(find.text('1 050,00 kr'), findsWidgets);
      expect(find.text('1 200,00 kr'), findsNothing);
      expect(find.text('Bonuses (included)'), findsOneWidget);
      expect(find.text('150,00 kr'), findsOneWidget);
    });

    testWidgets('TND: net 84.000 DT holds the 20.000 DT bonus', (tester) async {
      routes['GET /api/v1/driver/earnings'] = (_) => json(200, {
        'driverId': 'd1',
        'period': 'day',
        'currency': 'TND',
        'currencies': ['TND'],
        'periods': [
          period(
            '2026-11-10T23:00:00Z',
            '2026-11-11T23:00:00Z',
            'TND',
            net: 84000,
            bonus: 20000,
          ),
        ],
      });
      await openHistory(tester, 'TND');
      expect(find.text('84.000 DT'), findsWidgets);
      expect(find.text('104.000 DT'), findsNothing);
      expect(find.text('Bonuses (included)'), findsOneWidget);
      expect(find.text('20.000 DT'), findsOneWidget);
    });
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
