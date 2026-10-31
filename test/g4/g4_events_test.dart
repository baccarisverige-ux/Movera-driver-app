import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/home_map_layers.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner G4-F6 (Rules decisions/driver-g4.md): "Mark small premium icon in
/// the map in the exact location of event and when clic see all details"
/// — contract v0.18.6 §32 `dispatchTools.events`, `GET /driver/events`.

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _wire({
  String id = 'evt_1',
  DateTime? startsAt,
  DateTime? endsAt,
  bool running = false,
  String? pickupNote = 'Use the north gate, lane 3.',
}) {
  final start = startsAt ?? DateTime.utc(2026, 11, 7, 17);
  return {
    'eventId': id,
    'name': 'Friends Arena',
    'location': {'lat': 59.3727, 'lng': 18.0003},
    'startsAt': start.toUtc().toIso8601String(),
    'endsAt': (endsAt ?? start.add(const Duration(hours: 4)))
        .toUtc()
        .toIso8601String(),
    'running': running,
    'title': 'Concert at Friends Arena',
    'description': 'About 50 000 visitors; many leave at the same time.',
    'pickupNote': ?pickupNote,
    'language': 'en',
  };
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('location denied');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient _api(FutureOr<http.Response> Function(http.Request) answer) =>
    ApiClient(
      client: MockClient((request) async => answer(request)),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );

Future<void> _pumpSheet(
  WidgetTester tester,
  DriverEvent event, {
  required DateTime now,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: EventDetailsSheet(event: event, now: now),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every event label is the contract\'s, in sv, fr, en', () {
    final texts =
        _contract['dispatchTools']['events']['texts'] as Map<String, dynamic>;
    for (final lang in ['sv', 'fr', 'en']) {
      final arb = _arb(lang);
      expect(arb['eventRunning'], texts['running'][lang], reason: lang);
      expect(arb['eventStarts'], texts['upcoming'][lang], reason: lang);
      expect(arb['eventPickupNote'], texts['pickupNote'][lang], reason: lang);
    }
  });

  group('GET /driver/events', () {
    test('an answer is read; a broken item is left out', () {
      final events = LiveDriverEvents.parse({
        'items': [
          _wire(),
          {'eventId': 'bad'},
          _wire(id: 'evt_2', pickupNote: null),
        ],
        'at': '2026-11-01T10:00:00Z',
      })!;
      expect(events.map((e) => e.eventId), ['evt_1', 'evt_2']);
      final first = events.first;
      expect(first.location.latitude, 59.3727);
      expect(first.location.longitude, 18.0003);
      expect(first.title, 'Concert at Friends Arena');
      expect(first.name, 'Friends Arena');
      expect(first.pickupNote, 'Use the north gate, lane 3.');
      expect(events.last.pickupNote, isNull);
      expect(LiveDriverEvents.parse({'nope': 1}), isNull);
      // endsAt must be after startsAt.
      expect(
        DriverEvent.tryParse(
          _wire(
            startsAt: DateTime.utc(2026, 11, 7, 17),
            endsAt: DateTime.utc(2026, 11, 7, 16),
          ),
        ),
        isNull,
      );
    });

    test(
      'refresh fills the Home list; a failed read keeps the last one',
      () async {
        final requests = <String>[];
        var fail = false;
        final events = DriverEvents(now: () => DateTime.utc(2026, 11, 1));
        final live = LiveDriverEvents(
          api: _api((request) {
            requests.add('${request.method} ${request.url.path}');
            return fail
                ? _json(503, {'code': 'unavailable'})
                : _json(200, {
                    'items': [_wire()],
                    'at': '2026-11-01T00:00:00Z',
                  });
          }),
          events: events,
        );
        expect(await live.refresh(), isTrue);
        expect(requests, ['GET /api/v1/driver/events']);
        expect(events.visible().single.eventId, 'evt_1');
        fail = true;
        expect(await live.refresh(), isFalse);
        expect(events.visible().single.eventId, 'evt_1');
        events.dispose();
      },
    );

    test('config_published with doc events reads the events again', () async {
      final stream = StreamController<List<int>>();
      var published = 0;
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            return http.StreamedResponse(stream.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 't',
        cache: MemoryDriverConfigCache(),
        onEventsPublished: () => published++,
      );
      await config.watch();
      stream.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"'
          '${_contract['dispatchTools']['events']['signalDoc']}",'
          '"zoneId":"Z001","version":3}\n\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(published, 1);
      expect(config.current, isNull, reason: 'not a config document');
      config.dispose();
      await stream.close();
    });

    test('a live session reads them at sign-in and when the app comes '
        'back to the front; sign-out empties the list', () async {
      final seen = <String>[];
      final client = MockClient((request) async {
        seen.add(request.url.path);
        if (request.url.path == '/api/v1/driver/events') {
          return _json(200, {
            'items': [
              _wire(startsAt: DateTime.now().add(const Duration(days: 1))),
            ],
            'at': DateTime.now().toUtc().toIso8601String(),
          });
        }
        return http.Response('', 503);
      });
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final live = LiveDriverServices(
        client: client,
        origin: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        location: _NoGps(),
        locationEvery: const Duration(hours: 1),
      );
      int reads() => seen.where((p) => p == '/api/v1/driver/events').length;
      live.resumed();
      await pumpEventQueue();
      expect(reads(), 0, reason: 'no session yet');
      live.signedIn();
      await pumpEventQueue();
      expect(reads(), 1);
      expect(DriverEvents.instance.visible(), hasLength(1));
      live.resumed();
      await pumpEventQueue();
      expect(reads(), 2);
      live.signedOut();
      expect(DriverEvents.instance.all, isEmpty);
      await live.dispose();
    });

    testWidgets('an event leaves by itself at its endsAt', (tester) async {
      final start = DateTime.utc(2026, 11, 7, 17);
      var now = start.subtract(const Duration(hours: 1));
      final events = DriverEvents(now: () => now);
      var changes = 0;
      events.addListener(() => changes++);
      events.use([
        DriverEvent.tryParse(
          _wire(startsAt: start, endsAt: start.add(const Duration(hours: 2))),
        )!,
      ]);
      expect(events.visible(), hasLength(1));
      now = start.add(const Duration(hours: 2, seconds: 2));
      await tester.pump(const Duration(hours: 3, seconds: 2));
      expect(events.visible(), isEmpty);
      expect(changes, 2, reason: 'once on the answer, once at the end');
      events.dispose();
    });
  });

  group('the premium mark on the Home map', () {
    testWidgets('one mark per event, at its exact point, centred, the same '
        'screen size at every zoom, not Google\'s pin; a tap gives the event', (
      tester,
    ) async {
      MoveraEventMarker.reset();
      await tester.runAsync(MoveraEventMarker.paintIcon);
      final icon = MoveraEventMarker.icon.value;
      expect(icon, isA<BytesMapBitmap>());
      // A map bitmap is drawn in screen pixels: 30 × 30 at every zoom.
      expect((icon! as BytesMapBitmap).width, MoveraEventMarker.size.width);
      expect((icon as BytesMapBitmap).height, MoveraEventMarker.size.height);
      final events = DriverEvents(now: () => DateTime.utc(2026, 11, 7, 12));
      events.use([DriverEvent.tryParse(_wire())!]);
      DriverEvent? tapped;
      final marks = withEventMarkers(
        {const Marker(markerId: MarkerId('car'))},
        events,
        onTap: (event) => tapped = event,
      );
      final mark = marks.firstWhere(
        (m) => m.markerId.value == 'driver_event_evt_1',
      );
      expect(mark.position, const LatLng(59.3727, 18.0003));
      expect(mark.anchor, const Offset(0.5, 0.5));
      expect(mark.icon, same(icon));
      expect(marks.map((m) => m.markerId.value), contains('car'));
      mark.onTap!();
      expect(tapped?.eventId, 'evt_1');
      events.dispose();
    });

    testWidgets('Home shows the event mark; a tap opens all the details', (
      tester,
    ) async {
      MoveraEventMarker.reset();
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(MoveraEventMarker.paintIcon);
      final start = DateTime.now().add(const Duration(days: 2));
      DriverEvents.instance.use([
        DriverEvent.tryParse(_wire(startsAt: start))!,
      ]);
      await tester.pumpWidget(
        LayoutViewport(
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              home: DriverHome(
                sessionController: DriverSessionController(),
                dispatchRepository: DemoDispatchRepository(),
                locationRepository: _NoGps(),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
      final mark = map.markers!.firstWhere(
        (m) => m.markerId.value == 'driver_event_evt_1',
      );
      expect(mark.position, const LatLng(59.3727, 18.0003));
      mark.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey<String>('event-details-evt_1')),
        findsOneWidget,
      );
      expect(find.text('Concert at Friends Arena'), findsOneWidget);
      expect(find.textContaining('Starts '), findsOneWidget);
      expect(find.text('Use the north gate, lane 3.'), findsOneWidget);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      // Its end timer goes with the list.
      DriverEvents.instance.clear();
    });
  });

  group('the details sheet', () {
    testWidgets('upcoming: title, "Starts" with the phone time, the place, '
        'the description and the pickup note', (tester) async {
      final start = DateTime(2026, 11, 7, 18);
      final event = DriverEvent.tryParse(_wire(startsAt: start.toUtc()))!;
      await _pumpSheet(tester, event, now: DateTime(2026, 11, 7, 12));
      expect(find.text('Concert at Friends Arena'), findsOneWidget);
      expect(find.text('Starts 18:00'), findsOneWidget);
      expect(find.text('Sat 7 Nov · 18:00–22:00'), findsOneWidget);
      expect(find.text('Friends Arena'), findsOneWidget);
      expect(
        find.text('About 50 000 visitors; many leave at the same time.'),
        findsOneWidget,
      );
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Use the north gate, lane 3.'), findsOneWidget);
    });

    testWidgets('another day: the day and the time', (tester) async {
      final start = DateTime(2026, 11, 7, 18);
      final event = DriverEvent.tryParse(_wire(startsAt: start.toUtc()))!;
      await _pumpSheet(tester, event, now: DateTime(2026, 11, 5, 9));
      expect(find.text('Starts Sat 7 Nov 18:00'), findsOneWidget);
    });

    testWidgets('running: "Happening now"; no pickup note, no box', (
      tester,
    ) async {
      final start = DateTime(2026, 11, 7, 18);
      final event = DriverEvent.tryParse(
        _wire(startsAt: start.toUtc(), running: true, pickupNote: null),
      )!;
      await _pumpSheet(tester, event, now: DateTime(2026, 11, 7, 19));
      expect(find.text('Happening now'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('event-details-pickup')),
        findsNothing,
      );
    });

    for (final (lang, running, starts, pickup) in const [
      ('sv', 'Pågår nu', 'Börjar 18:00', 'Upphämtning'),
      ('fr', 'En cours', 'Commence à 18:00', 'Prise en charge'),
    ]) {
      testWidgets('$lang labels', (tester) async {
        DriverAppTexts.language = lang;
        final start = DateTime(2026, 11, 7, 18);
        final event = DriverEvent.tryParse(_wire(startsAt: start.toUtc()))!;
        await _pumpSheet(tester, event, now: DateTime(2026, 11, 7, 12));
        expect(find.text(starts), findsOneWidget);
        expect(find.text(pickup), findsOneWidget);
        await _pumpSheet(tester, event, now: DateTime(2026, 11, 7, 19));
        expect(find.text(running), findsOneWidget);
      });
    }
  });

  group('no demo events on live; the island uses the real start', () {
    test('a live build has no built-in events; the demo keeps its own', () {
      final previous = DriverRuntimeConfig.current;
      addTearDown(() => DriverRuntimeConfig.current = previous);
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: true,
        externalRouting: false,
        skipAccountActivation: true,
        authRequired: true,
      );
      expect(const DriverHomeAdminContentService().load().events, isEmpty);
      DriverRuntimeConfig.current = previous;
      expect(const DriverHomeAdminContentService().load().events, isNotEmpty);
    });

    test('"Peak hours start at" says the real start of today\'s event', () {
      final now = DateTime(2026, 11, 7, 12);
      final config = const DriverHomeAdminContentService().load();
      final live = DriverEvent.tryParse(
        _wire(startsAt: DateTime(2026, 11, 7, 18, 30).toUtc()),
      )!;
      final tips = IslandWaitingSignals.fromHome(
        DriverHomeAdminConfig(
          performance: config.performance,
          scheduledRides: config.scheduledRides,
          update: config.update,
          eventsSectionTitle: '',
          eventsSectionSubtitle: '',
          events: const [],
          stockholmWork: config.stockholmWork,
        ),
        now: now,
        liveEvents: [live],
      ).tips();
      expect(tips.map((t) => t.title), contains('Peak hours start at 18:30'));
      // Tomorrow's event or one already started: no peak tip.
      final none = IslandWaitingSignals.fromHome(
        DriverHomeAdminConfig(
          performance: config.performance,
          scheduledRides: config.scheduledRides,
          update: config.update,
          eventsSectionTitle: '',
          eventsSectionSubtitle: '',
          events: const [],
          stockholmWork: config.stockholmWork,
        ),
        now: now,
        liveEvents: [
          DriverEvent.tryParse(
            _wire(startsAt: DateTime(2026, 11, 8, 18).toUtc()),
          )!,
          DriverEvent.tryParse(
            _wire(id: 'e2', startsAt: DateTime(2026, 11, 7, 10).toUtc()),
          )!,
        ],
      ).tips();
      expect(none.map((t) => t.id), isNot(contains('peak')));
    });
  });
}
