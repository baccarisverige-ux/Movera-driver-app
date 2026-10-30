import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Driver group 3, deep second audit (Rules decisions/driver-g3.md,
/// owner 2026-10-30): G3-D1 one real notification list, G3-D2 real
/// performance numbers, G3-D3 address search + recent destinations,
/// G3-D6 "NEW" only for an unopened campaign, G3-D7 black/green dialogs.
void main() {
  late List<http.Request> seen;
  late Map<String, http.Response Function(http.Request)> routes;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ApiClient api() {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    return ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        final route = routes['${request.method} ${request.url.path}'];
        return route == null
            ? json(503, {
                'code': 'unavailable',
                'message': 'down',
                'requestId': 'x',
                'retryable': true,
              })
            : route(request);
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
  }

  Map<String, Object?> profile({Object? performance}) => {
    'driverId': 'd1',
    'accountStatus': 'active',
    'firstName': 'Amira',
    'version': 3,
    'country': 'FR',
    'performance': ?performance,
  };

  setUp(() {
    seen = [];
    routes = {};
    DriverAppTexts.language = 'en';
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    DriverPerformanceConfig.live.value = null;
    DriverPerformanceConfig.featureOn = true;
    DriverPerformanceConfig.liveBuild = false;
    DriverNotificationFeed.instance.reset();
    Promotions.resetOpened();
  });

  Future<void> pumpMenu(
    WidgetTester tester, {
    DriverAccountSession? account,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = DriverSessionController();
    addTearDown(controller.dispose);
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

  group('G3-D1 one real notification list', () {
    test('a live build never has the demo list or demo arrivals', () {
      final feed = DriverNotificationFeed();
      expect(feed.items, isNotEmpty, reason: 'the demo keeps its list');
      feed.useLive();
      expect(feed.items, isEmpty);
      expect(feed.takeArrivals(), isEmpty);
      feed.reset();
      expect(feed.items, isEmpty);
      expect(feed.takeArrivals(), isEmpty);
    });

    testWidgets('live: the menu shows the bell\'s unread count and opens '
        'the server list', (tester) async {
      routes['GET /api/v1/notifications'] = (_) => json(200, {'items': []});
      final account = DriverAccountSession(
        repository: DriverAccountRepository(api()),
      )..unreadNotifications.value = 3;
      await pumpMenu(tester, account: account);
      final row = find.ancestor(
        of: find.text('Notifications'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: row.first, matching: find.text('3')),
        findsOneWidget,
      );
      // G3-D6: a live build has no campaign source: never "NEW".
      expect(find.text('NEW'), findsNothing);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerNotificationsScreen), findsOneWidget);
      expect(find.byType(DriverNotificationsScreen), findsNothing);
      expect(
        seen.where((r) => r.url.path == '/api/v1/notifications'),
        isNotEmpty,
      );
    });
  });

  group('G3-D2 real performance numbers', () {
    testWidgets('Analytics shows the server numbers and "—" for null', (
      tester,
    ) async {
      final account = DriverAccountSession(
        repository: DriverAccountRepository(api()),
      );
      account.replace(
        DriverAccount.fromJson(
          profile(
            performance: {
              'windowDays': 30,
              'offersAnswerable': 21,
              'offersAccepted': 17,
              'tripsCancelled': 0,
              'ratingCount': 6,
              'acceptancePct': 81,
              'cancellationPct': null,
              'rating': 4.62,
            },
          ),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Analytics()));
      await tester.pumpAndSettle();
      expect(find.text('4.62'), findsOneWidget);
      expect(find.text('81%'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('94%'), findsNothing);
      expect(find.text('4.88'), findsNothing);
      expect(find.text('Sample performance'), findsNothing);
      expect(find.text('81% of offers accepted'), findsOneWidget);
      expect(find.text('Not enough data yet'), findsOneWidget);
    });

    testWidgets('live without numbers yet: "—", never the sample', (
      tester,
    ) async {
      DriverPerformanceConfig.liveBuild = true;
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Analytics()));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('94%'), findsNothing);
      expect(find.text('4.88'), findsNothing);
    });

    testWidgets('the side menu shows the real rating', (tester) async {
      DriverPerformanceConfig.live.value = DriverPerformanceConfig.fromServer({
        'rating': 4.71,
        'acceptancePct': null,
        'cancellationPct': null,
      });
      await pumpMenu(tester);
      expect(find.text('4.71'), findsOneWidget);
      expect(find.text('4.88'), findsNothing);
    });

    testWidgets('features.performance off hides the numbers', (tester) async {
      DriverAppConfig.fromJson({
        'features': {'performance': false},
      }).apply();
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Analytics()));
      await tester.pumpAndSettle();
      expect(find.text('94%'), findsNothing);
      expect(find.text('Acceptance rate'), findsNothing);
    });

    test('profile performance parses; command answers keep the numbers', () {
      final parsed = DriverAccount.fromJson(
        profile(performance: {'acceptancePct': 90, 'rating': null}),
      );
      expect(parsed.performance?.acceptanceLabel, '90%');
      expect(parsed.performance?.ratingLabel, '—');
      expect(parsed.performance?.cancellationLabel, '—');
      expect(DriverAccount.fromJson(profile()).performance, isNull);
    });
  });

  group('G3-D3 destination search + recent', () {
    testWidgets('no fixed places: the server search and the last 5', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        RecentDestinations.key: jsonEncode([
          {
            'name': 'Gare de Lyon',
            'address': 'Gare de Lyon, Paris',
            'lat': 48.8443,
            'lng': 2.3744,
          },
        ]),
      });
      routes['POST /api/v1/locations/autocomplete'] = (request) {
        final body = jsonDecode(request.body) as Map;
        expect(body['query'], 'Opéra');
        return json(200, {
          'suggestions': [
            {
              'title': 'Opéra Garnier',
              'subtitle': 'Place de l’Opéra, Paris',
              'latitude': 48.8720,
              'longitude': 2.3316,
            },
          ],
        });
      };
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DriverDestinationResult? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DriverDestinationPicker(
                      search: ApiDestinationSearch(api: api()),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Stockholm Central'), findsNothing);
      expect(find.text('Solna centrum'), findsNothing);
      expect(find.text('Gare de Lyon'), findsOneWidget);
      expect(find.text('Your recent destinations'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('destination-search')),
        'Opéra',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Opéra Garnier'), findsOneWidget);
      await tester.tap(find.text('Opéra Garnier'));
      await tester.pumpAndSettle();
      expect(picked?.name, 'Opéra Garnier');
      expect(picked?.position.latitude, closeTo(48.872, 1e-6));

      final recent = await RecentDestinations.load();
      expect(recent.map((p) => p.name), ['Opéra Garnier', 'Gare de Lyon']);
    });

    test('recent keeps the last 5, newest first, no duplicates', () async {
      for (var i = 0; i < 7; i++) {
        await RecentDestinations.remember(
          DestinationPlace(
            id: '$i',
            name: 'P$i',
            address: 'Addr $i',
            position: GeoPoint(48.8 + i / 100, 2.3),
          ),
        );
      }
      await RecentDestinations.remember(
        const DestinationPlace(
          id: 'x',
          name: 'P4',
          address: 'Addr 4',
          position: GeoPoint(48.84, 2.3),
        ),
      );
      final recent = await RecentDestinations.load();
      expect(recent.map((p) => p.name), ['P4', 'P6', 'P5', 'P3', 'P2']);
    });

    testWidgets('a search that fails says so in the driver\'s language', (
      tester,
    ) async {
      for (final (language, text) in [
        ('sv', 'Adressökningen fungerar inte just nu'),
        ('fr', 'La recherche d’adresse n’est pas disponible'),
        ('en', 'Address search is not available'),
      ]) {
        DriverAppTexts.language = language;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(language),
            home: DriverDestinationPicker(
              search: ApiDestinationSearch(api: api()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey<String>('destination-search')),
          'x',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
      }
    });
  });

  group('G3-D6 campaigns NEW', () {
    testWidgets('NEW only until the campaigns are opened', (tester) async {
      await pumpMenu(tester);
      expect(find.text('NEW'), findsOneWidget);
      await tester.tap(find.text('Promotions'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpMenu(tester);
      expect(find.text('NEW'), findsNothing);
    });
  });

  group('G3-D7 dialogs in Movera black/green', () {
    testWidgets('"Go offline?" has a white box and a black main button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGoOfflineConfirm(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      Color? fill(Finder button) => tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)).first,
          )
          .color;
      expect(
        fill(find.byKey(const ValueKey<String>('go-offline-yes'))),
        const Color(0xFF111614),
      );
      final dialog = find.byKey(const ValueKey<String>('go-offline-confirm'));
      final box = tester.widget<Material>(
        find.descendant(of: dialog, matching: find.byType(Material)).first,
      );
      expect(box.color, Colors.white);
      final stay = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('go-offline-stay')),
          matching: find.byType(Text),
        ),
      );
      final stayColor = DefaultTextStyle.of(
        tester.element(find.byWidget(stay)),
      ).style.color;
      expect(stayColor, const Color(0xFF19865C));
    });
  });
}
