import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_content.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/content/content_card.dart';
import 'package:movera/presentation/driver/content/driver_content_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.10.0 §19 (owner Content answers 2026-10-28): the admin's
/// Content page publishes texts, terms and app versions to the driver app.

final _now = DateTime.utc(2026, 10, 28, 12);

Map<String, Object?> _item(
  String slot, {
  int version = 1,
  String title = 'Titel',
  Map<String, String>? text,
  String? image,
  String? expiresAt,
  bool reaccept = false,
  Map<String, Object?>? versions,
}) => {
  'slot': slot,
  'zoneId': 'Z001',
  'version': version,
  'publishedAt': '2026-10-28T08:00:00Z',
  'publishedBy': 'adm_1',
  'title': title,
  'text': text ?? {'sv': 'Hej', 'fr': 'Bonjour', 'en': 'Hello'},
  'image': ?image,
  'expiresAt': ?expiresAt,
  if (reaccept) 'reaccept': true,
  'versions': ?versions,
};

Map<String, Object?> _versions(String min, String recommended) => {
  'rider': {'min': '1.0.0', 'recommended': '1.0.0'},
  'driver': {'min': min, 'recommended': recommended},
};

DriverContent _content(List<Map<String, Object?>> items) =>
    DriverContent.fromJson({'items': items});

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      const DriverLocation(point: GeoPoint(59.33, 18.06), accuracyMeters: 8);
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

ApiClient _api(
  List<http.Request> seen,
  http.Response Function(http.Request) answer,
) {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  return ApiClient(
    client: MockClient((request) async {
      seen.add(request);
      return answer(request);
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  tearDown(() {
    DriverContentStore.instance = DriverContentStore();
    DriverAppVersion.current = const AppVersion(1, 0, 0);
    DriverAppTexts.reset();
  });

  group('items', () {
    test('title and text in the driver language, https image only', () {
      final content = _content([
        _item('driver-home', image: 'https://cdn.movera.se/a.png'),
        _item('driver-event', image: 'http://cdn.movera.se/b.png'),
      ]);
      final home = content.homeAt(_now);
      expect(home.map((i) => i.slot), ['driver-home', 'driver-event']);
      expect(home.first.textIn('sv'), 'Hej');
      expect(home.first.textIn('fr'), 'Bonjour');
      expect(home.first.textIn('ar'), 'Hello');
      expect(home.first.image, 'https://cdn.movera.se/a.png');
      expect(home.last.image, isNull);
    });

    test('hidden after expiresAt; the newest version of a slot wins', () {
      final content = _content([
        _item('driver-home', expiresAt: '2026-10-28T11:00:00Z'),
        _item('driver-event', version: 1, title: 'old'),
        _item('driver-event', version: 2, title: 'new'),
        _item('help', expiresAt: '2026-10-29T00:00:00Z'),
      ]);
      expect(content.homeAt(_now).single.title, 'new');
      expect(content.helpAt(_now), isNotNull);
      expect(content.helpAt(DateTime.utc(2026, 10, 30)), isNull);
    });

    test('broken and other apps\' items are left out', () {
      final content = _content([
        _item('rider-banner-1'),
        {'slot': 'driver-home'},
        _item('driver-home', text: {'sv': '', 'en': ''}),
      ]);
      expect(content.items.single.textIn('sv'), '');
      expect(DriverContent.fromJson('nope').items, isEmpty);
      expect(DriverContentItem.tryParse(7), isNull);
    });
  });

  group('app versions (driver pair)', () {
    test('semantic compare', () {
      expect(
        AppVersion.tryParse('1.10.0')! < AppVersion.tryParse('1.9.9')!,
        isFalse,
      );
      expect(
        AppVersion.tryParse('1.0.0')! < AppVersion.tryParse('1.0.1')!,
        isTrue,
      );
      expect(AppVersion.tryParse('x'), isNull);
      expect(AppVersion.tryParse(3), isNull);
      expect(const AppVersion(2, 1, 0).toString(), '2.1.0');
    });

    test('below min blocks, below recommended asks, else nothing', () {
      const app = AppVersion(1, 2, 0);
      UpdateNeed need(String min, String rec) => _content([
        _item('app-versions', versions: _versions(min, rec)),
      ]).updateNeed(app, _now);
      expect(need('1.3.0', '1.4.0'), UpdateNeed.required);
      expect(need('1.0.0', '1.4.0'), UpdateNeed.recommended);
      expect(need('1.0.0', '1.2.0'), UpdateNeed.none);
      expect(DriverContent.empty.updateNeed(app, _now), UpdateNeed.none);
    });

    test('during a trip only a small message; the block after the trip', () {
      expect(
        DriverContent.viewFor(UpdateNeed.required, onTrip: true),
        UpdateView.tripMessage,
      );
      expect(
        DriverContent.viewFor(UpdateNeed.required, onTrip: false),
        UpdateView.blocked,
      );
      expect(
        DriverContent.viewFor(UpdateNeed.recommended, onTrip: false),
        UpdateView.recommendedMessage,
      );
      expect(
        DriverContent.viewFor(UpdateNeed.recommended, onTrip: true),
        UpdateView.tripMessage,
      );
      expect(
        DriverContent.viewFor(
          UpdateNeed.recommended,
          onTrip: false,
          dismissed: true,
        ),
        UpdateView.none,
      );
      expect(
        DriverContent.viewFor(UpdateNeed.none, onTrip: false),
        UpdateView.none,
      );
    });
  });

  group('legal reaccept', () {
    test('due until the version is accepted; no reaccept, nothing due', () {
      final legal = _content([_item('legal', version: 3, reaccept: true)]);
      expect(legal.termsDue(_now, null), 3);
      expect(legal.termsDue(_now, 2), 3);
      expect(legal.termsDue(_now, 3), isNull);
      expect(_content([_item('legal')]).termsDue(_now, null), isNull);
    });

    test(
      'the store asks at start, keeps the answer and the acceptance',
      () async {
        final cache = MemoryDriverContentCache();
        final store = DriverContentStore(cache: cache, now: () => _now);
        await store.restore();
        expect(store.termsScreenWanted, isFalse);
        await store.use(
          _content([
            _item('legal', version: 4, reaccept: true),
            _item('driver-home'),
          ]),
          atStart: true,
        );
        expect(store.termsScreenWanted, isTrue);
        expect(store.blocksOnline, isTrue);
        await store.accepted(4);
        expect(store.blocksOnline, isFalse);
        expect(store.termsScreenWanted, isFalse);

        // Offline next start: the kept answer, already accepted.
        final next = DriverContentStore(cache: cache, now: () => _now);
        await next.restore();
        expect(next.home.single.slot, 'driver-home');
        expect(next.acceptedTerms, 4);
        expect(next.blocksOnline, isFalse);
      },
    );

    test(
      'terms published later wait for the next start or a refusal',
      () async {
        final store = DriverContentStore(
          cache: MemoryDriverContentCache(),
          now: () => _now,
        );
        await store.use(DriverContent.empty, atStart: true);
        await store.use(_content([_item('legal', reaccept: true)]));
        expect(store.blocksOnline, isTrue);
        expect(store.termsScreenWanted, isFalse);
        store.askTerms();
        expect(store.termsScreenWanted, isTrue);
        store.reset();
        store.askTerms();
        expect(store.termsScreenWanted, isFalse);
      },
    );

    test('prefs cache round trip', () async {
      SharedPreferences.setMockInitialValues({});
      const cache = PrefsDriverContentCache();
      expect(await cache.read(), isNull);
      await cache.write({'items': <Object>[], 'acceptedTerms': 2});
      expect((await cache.read())!['acceptedTerms'], 2);
    });
  });

  group('live', () {
    test('GET /driver/content?zoneId on start; the answer is kept', () async {
      final seen = <http.Request>[];
      final store = DriverContentStore(
        cache: MemoryDriverContentCache(),
        now: () => _now,
      );
      final live = LiveDriverContent(
        api: _api(
          seen,
          (_) => _json({
            'items': [_item('driver-home'), _item('help')],
          }),
        ),
        zoneId: () => 'Z001',
        store: store,
      );
      await live.start();
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/api/v1/driver/content');
      expect(seen.single.url.queryParameters['zoneId'], 'Z001');
      expect(store.home.single.slot, 'driver-home');
      expect(store.help, isNotNull);
    });

    test('a failure keeps the last answer', () async {
      final store = DriverContentStore(
        cache: MemoryDriverContentCache(),
        now: () => _now,
      );
      await store.use(_content([_item('driver-home')]));
      var status = 503;
      final live = LiveDriverContent(
        api: _api([], (_) => _json({'code': 'down'}, status)),
        zoneId: () => null,
        store: store,
      );
      await live.refresh();
      expect(store.home, hasLength(1));
      status = 200;
      final odd = LiveDriverContent(
        api: _api([], (_) => _json({'nope': true})),
        zoneId: () => '',
        store: store,
      );
      await odd.refresh();
      expect(store.home, hasLength(1));
      expect(live.store, same(store));
    });

    test('accept: POST /account/terms/accept { contentVersion }', () async {
      final seen = <http.Request>[];
      final store = DriverContentStore(
        cache: MemoryDriverContentCache(),
        now: () => _now,
      );
      await store.use(_content([_item('legal', version: 7, reaccept: true)]));
      final live = LiveDriverContent(
        api: _api(seen, (_) => http.Response('', 204)),
        zoneId: () => null,
        store: store,
      );
      expect(await live.acceptTerms(7), isTrue);
      expect(seen.single.url.path, '/api/v1/account/terms/accept');
      expect(jsonDecode(seen.single.body), {'contentVersion': 7});
      expect(store.blocksOnline, isFalse);

      final refused = LiveDriverContent(
        api: _api([], (_) => _json({'code': 'bad'}, 400)),
        zoneId: () => null,
        store: store,
      );
      expect(await refused.acceptTerms(8), isFalse);
    });

    test('config_published with doc content refetches the content', () async {
      final events = StreamController<List<int>>();
      var published = 0;
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            return http.StreamedResponse(events.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 't',
        cache: MemoryDriverConfigCache(),
        onContentPublished: () => published++,
      );
      await config.watch();
      events.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"content","version":3}\n\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(published, 1);
      expect(config.current, isNull);
      config.dispose();
      await events.close();
    });

    test('until accepted the driver cannot go online', () async {
      final seen = <http.Request>[];
      final api = _api(seen, (_) => _json({}));
      final store = DriverContentStore(
        cache: MemoryDriverContentCache(),
        now: DateTime.now,
      );
      DriverContentStore.instance = store;
      await store.use(_content([_item('legal', reaccept: true)]));
      final presence = LivePresence(
        api: api,
        dispatch: ApiDispatchRepository(
          client: MockClient((_) async => http.Response('{}', 200)),
          baseUri: Uri.parse('https://api.test.movera.se/api/v1'),
          accessToken: () async => null,
        ),
        reporter: LiveLocationReporter(api: api, location: _Gps()),
      );
      final message = await presence.goOnline();
      expect(message, isNotNull);
      expect(seen, isEmpty);
      expect(store.termsScreenWanted, isTrue);
    });
  });

  group('screens', () {
    Future<DriverSessionController> pumpGate(
      WidgetTester tester,
      DriverContentStore store, {
      Future<bool> Function(int)? accept,
      List<Uri>? opened,
      bool onTrip = false,
    }) async {
      DriverAppTexts.language = 'sv';
      final session = DriverSessionController(initialOnline: true);
      if (onTrip) session.beginTrip('trip_1');
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => DriverContentGate(
            session: session,
            navigatorKey: key,
            store: store,
            acceptTerms: accept,
            openStore: (uri) async {
              opened?.add(uri);
              return opened != null;
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.pump();
      return session;
    }

    Future<DriverContentStore> storeWith(
      List<Map<String, Object?>> items,
    ) async {
      final store = DriverContentStore(
        cache: MemoryDriverContentCache(),
        now: () => _now,
      );
      await store.use(_content(items), atStart: true);
      return store;
    }

    testWidgets('below min: "Uppdatera appen" with the store and SOS', (
      tester,
    ) async {
      final store = await storeWith([
        _item('app-versions', versions: _versions('1.1.0', '1.1.0')),
      ]);
      final opened = <Uri>[];
      await pumpGate(tester, store, opened: opened);
      expect(find.text('Uppdatera appen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('content-update-store')));
      await tester.pump();
      expect(opened.single.host, 'play.google.com');
      expect(driverStoreUri(TargetPlatform.iOS).host, 'apps.apple.com');
      // SOS stays reachable; with no trip it is "Call 112" (v0.18.5
      // `safety.onlyDuringTrip`).
      await tester.tap(find.byKey(const ValueKey('content-update-sos')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('safety-call-112')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('content-update-required')),
        findsNothing,
      );
      Navigator.of(
        tester.element(find.byKey(const ValueKey('safety-call-112'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('content-update-required')),
        findsOneWidget,
      );
    });

    testWidgets('the store cannot open: the screen says so', (tester) async {
      final store = await storeWith([
        _item('app-versions', versions: _versions('1.1.0', '1.1.0')),
      ]);
      await pumpGate(tester, store);
      await tester.tap(find.byKey(const ValueKey('content-update-store')));
      await tester.pump();
      expect(find.text('Butiken kunde inte öppnas.'), findsOneWidget);
    });

    testWidgets('during a trip a small message; the block after it', (
      tester,
    ) async {
      final store = await storeWith([
        _item('app-versions', versions: _versions('1.1.0', '1.1.0')),
      ]);
      final session = await pumpGate(tester, store, onTrip: true);
      expect(find.byKey(const ValueKey('content-update-trip')), findsOneWidget);
      expect(find.text('Uppdatera appen efter resan.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('content-update-required')),
        findsNothing,
      );
      session.endTrip();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('content-update-required')),
        findsOneWidget,
      );
    });

    testWidgets('below recommended: a message the driver can close', (
      tester,
    ) async {
      final store = await storeWith([
        _item('app-versions', versions: _versions('1.0.0', '1.1.0')),
      ]);
      await pumpGate(tester, store, opened: []);
      expect(
        find.byKey(const ValueKey('content-update-recommended')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('content-update-close')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('content-update-recommended')),
        findsNothing,
      );
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('new terms at start with "Jag godkänner"', (tester) async {
      final store = await storeWith([
        _item(
          'legal',
          version: 5,
          title: 'Villkor',
          reaccept: true,
          text: {'sv': 'Nya villkor', 'fr': 'f', 'en': 'e'},
        ),
      ]);
      var answer = false;
      final accepted = <int>[];
      await pumpGate(
        tester,
        store,
        accept: (v) async {
          accepted.add(v);
          if (answer) await store.accepted(v);
          return answer;
        },
      );
      expect(find.text('Nya villkor'), findsOneWidget);
      await tester.tap(find.text('Jag godkänner'));
      await tester.pump();
      expect(
        find.text('Inte sparat. Kontrollera anslutningen och försök igen.'),
        findsOneWidget,
      );
      answer = true;
      await tester.tap(find.text('Jag godkänner'));
      await tester.pump();
      expect(accepted, [5, 5]);
      expect(find.byKey(const ValueKey('content-terms')), findsNothing);
    });

    testWidgets('never during a trip', (tester) async {
      final store = await storeWith([_item('legal', reaccept: true)]);
      final session = await pumpGate(tester, store, onTrip: true);
      expect(find.byKey(const ValueKey('content-terms')), findsNothing);
      session.endTrip();
      await tester.pump();
      expect(find.byKey(const ValueKey('content-terms')), findsOneWidget);
      // Without a live build the acceptance is kept on the phone.
      await tester.tap(find.byKey(const ValueKey('content-terms-accept')));
      await tester.pump();
      expect(store.acceptedTerms, 1);
    });

    testWidgets('the admin card: title, text in the driver language', (
      tester,
    ) async {
      DriverAppTexts.language = 'fr';
      final item = DriverContentItem.tryParse(
        _item('driver-home', title: 'Fête', image: 'https://x.invalid/a.png'),
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriverContentCard(item: item)),
        ),
      );
      expect(find.text('Fête'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('content-image-driver-home')),
        findsOneWidget,
      );
    });
  });
}
