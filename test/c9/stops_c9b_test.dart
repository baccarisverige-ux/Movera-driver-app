import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Job C9b (contract v0.18.108 §93, `contract.json#autoArrive.stops`; owner
/// 2026-11-02 "At the pickup AND at stops", Rules decisions/driver-g7.md:84):
/// at a middle stop the server marks the driver arrived and stops the stop
/// wait while he is more than `terms.leaveMeters` from the stop
/// (`stops[i].away`). The driver app shows the server's state: the stop
/// clock = (min(now, away.since) − arrivedAt) − pausedSeconds from server
/// stamps only, the paused note, "I'm back at the stop" (the arrive command
/// again, with the latest fix), and the stop tap sends the latest fix.
/// No distance and no money are worked out on the phone.

/// `contract.json#autoArrive.stops.texts` at v0.18.108 (movera-contracts
/// 0acefe8). The app's contract copy is synced from the tag after 0.18.108
/// merges; once it carries `autoArrive.stops`, the copy is checked too.
const _contractTexts = {
  'driverStopPaused': {
    'en':
        'Waiting paused: you are more than {leave} m from the stop. Drive '
        'back within {arrive} m to continue.',
    'fr':
        'Attente en pause : vous êtes à plus de {leave} m de l’arrêt. '
        'Revenez à moins de {arrive} m pour continuer.',
    'sv':
        'Väntetiden är pausad: du är mer än {leave} m från stoppet. Kör '
        'tillbaka inom {arrive} m för att fortsätta.',
  },
  'driverStopBack': {
    'en': "I'm back at the stop",
    'fr': 'Je suis de retour à l’arrêt',
    'sv': 'Jag är tillbaka vid stoppet',
  },
  'notAtStop': {
    'en': 'You are not at the stop yet.',
    'fr': 'Vous n’êtes pas encore à l’arrêt.',
    'sv': 'Du är inte vid stoppet än.',
  },
};

const _trip = 'c9b-stop';
DateTime _now = DateTime.utc(2026, 11, 14, 10, 3);

const _stop0 = {'lat': 59.3429, 'lng': 18.0498, 'address': 'Odenplan'};

Map<String, dynamic> _projection(
  Map<String, Object?> visit, {
  int version = 9,
}) => {
  'tripId': _trip,
  'version': version,
  'status': 'in_trip',
  'kind': 'live',
  'acceptedAt': '2026-11-14T09:40:00Z',
  'startedAt': '2026-11-14T09:50:00Z',
  'pickup': {'lat': 59.3326, 'lng': 18.0649, 'address': 'Sergels torg'},
  'dropoff': {'lat': 59.3143, 'lng': 18.0735, 'address': 'Medborgarplatsen'},
  'stops': [
    {..._stop0, ...visit},
  ],
  'stopVisits': [
    {'stopIndex': 0, ...visit},
  ],
  'rider': {'firstName': 'Camille'},
  'terms': {
    'currency': 'SEK',
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 5000, 'currency': 'SEK'},
    'stopFreeWaitMin': 0,
    'stopWaitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    'autoArriveMeters': 100,
    'leaveMeters': 200,
  },
};

const _arrived = {'arrivedAt': '2026-11-14T10:00:00Z', 'arrivedBy': 'auto'};

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MemoryDriverRealtime> _pump(WidgetTester tester) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final realtime = MemoryDriverRealtime();
  addTearDown(realtime.dispose);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: AcceptRide(
          tripId: _trip,
          riderName: 'Camille',
          initialStage: ActiveRideStage.onTrip,
          stopAddresses: const ['Odenplan'],
          stopPositions: const [LatLng(59.3429, 18.0498)],
          activeRideRepository: MemoryActiveRideRepository(),
          realtime: realtime,
          waitNow: () => _now,
        ),
      ),
    ),
  );
  await _frames(tester);
  return realtime;
}

void _emit(MemoryDriverRealtime realtime, Map<String, dynamic> projection) {
  realtime.emit(
    tripId: _trip,
    kind: DriverRealtimeKind.tripProjection,
    status: TripStatus.inTrip,
    projection: projection,
  );
}

Finder _inSheet(String text) => find.descendant(
  of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
  matching: find.text(text),
);

Finder _inDock(String text) => find.descendant(
  of: find.byKey(const ValueKey<String>('active-ride-compact-dock')),
  matching: find.textContaining(text),
);

/// The demo build offers a next trip on the way (2.2 s after the trip
/// screen opens); it covers the trip bar until declined.
Future<void> _declineDemoNextTrip(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await _frames(tester);
  final deny = find.text('Deny');
  if (deny.evaluate().isEmpty) return;
  await tester.tap(deny.first);
  await _frames(tester);
}

Future<void> _openSheet(WidgetTester tester) async {
  tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland)).onWait();
  await _frames(tester, 8);
}

Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(
    tester.element(find.byKey(const ValueKey<String>('waiting-time-sheet'))),
  ).pop();
  await _frames(tester, 8);
}

void main() {
  test('texts: autoArrive.stops.texts (driverStopPaused, driverStopBack, '
      'notAtStop) are the contract text in sv, fr and en', () {
    final copy =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final copied = ((copy['autoArrive'] as Map?)?['stops'] as Map?)?['texts'];
    final texts = copied is Map ? copied : _contractTexts;
    for (final lang in ['sv', 'fr', 'en']) {
      final l = lookupAppLocalizations(Locale(lang));
      expect(
        l.waitingPausedAtStop(200, 100),
        (texts['driverStopPaused'][lang] as String)
            .replaceAll('{leave}', '200')
            .replaceAll('{arrive}', '100'),
        reason: lang,
      );
      expect(l.waitingBackAtStop, texts['driverStopBack'][lang], reason: lang);
      expect(l.liveTripNotAtStop, texts['notAtStop'][lang], reason: lang);
    }
  });

  group('model (TripStopVisit, stops[i] v0.18.108)', () {
    test('arrivedBy, away, pausedSeconds, pauseCount and the clock as the '
        'server counts it', () {
      final live = TripLiveDetails.fromProjection(
        _projection({
          ..._arrived,
          'away': {'since': '2026-11-14T10:09:00Z'},
          'pausedSeconds': 120,
          'pauseCount': 1,
        }),
      );
      final visit = live.stopVisits!.single;
      expect(visit.arrivedBy, 'auto');
      expect(visit.paused, isTrue);
      expect(visit.pausedSeconds, 120);
      expect(visit.pauseCount, 1);
      // (10:09 − 10:00) − 2 min = 7 min, still 7 min at 10:20.
      expect(visit.clockAt(DateTime.utc(2026, 11, 14, 10, 20)), 420);
      expect(live.openStopVisit(0), same(visit));
    });

    test('read from the stopVisits mirror when stops[i] has none', () {
      final projection = _projection(const {});
      projection['stopVisits'] = [
        {
          'stopIndex': 0,
          ..._arrived,
          'away': {'since': '2026-11-14T10:02:00Z'},
        },
      ];
      final visit = TripLiveDetails.fromProjection(
        projection,
      ).stopVisits!.single;
      expect(visit.paused, isTrue);
      expect(visit.clockAt(DateTime.utc(2026, 11, 14, 10, 30)), 120);
    });

    test('an older server (no new fields): the clock counts from arrivedAt '
        'as before', () {
      final visit = TripLiveDetails.fromProjection(
        _projection({'arrivedAt': '2026-11-14T10:00:00Z'}),
      ).stopVisits!.single;
      expect(visit.paused, isFalse);
      expect(visit.arrivedBy, isNull);
      expect(visit.pausedSeconds, 0);
      expect(visit.clockAt(DateTime.utc(2026, 11, 14, 10, 2)), 120);
    });

    test('409 not_at_stop says "not at the stop yet"; position_stale the '
        'existing stale-position text', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        liveTripErrorMessage(
          const ApiError(
            statusCode: 409,
            code: 'invalid_transition',
            message: 'x',
            reason: 'not_at_stop',
          ),
        ),
        en.liveTripNotAtStop,
      );
      expect(
        liveTripErrorMessage(
          const ApiError(
            statusCode: 409,
            code: 'invalid_transition',
            message: 'x',
            reason: 'position_stale',
          ),
        ),
        en.liveTripPositionStale,
      );
    });
  });

  group('LiveTripCommands at a stop', () {
    final origin = Uri.parse('https://api.test.movera.se');
    late List<http.Request> requests;
    late List<FutureOr<http.Response> Function(http.Request)> answers;
    http.Response json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    ApiClient api() => ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return answers.removeAt(0)(request);
      }),
      baseUri: origin,
      tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
    );
    const LiveFix fix = {
      'lat': 59.3429,
      'lng': 18.0498,
      'accuracy': 5,
      'measuredAt': '2026-11-14T10:08:00Z',
    };
    const LiveFix fresh = {
      'lat': 59.3429,
      'lng': 18.0498,
      'accuracy': 4,
      'measuredAt': '2026-11-14T10:08:30Z',
    };
    const path = '/api/v1/driver/trips/c9b-stop/stops/0/arrive';
    setUp(() {
      requests = [];
      answers = [];
    });

    test('the stop tap sends the latest fix and the version', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(_projection(const {}));
      answers.add((_) => json(200, _projection(_arrived, version: 10)));
      final outcome = await trips.arriveAtStop(_trip, 0);
      expect(outcome.ok, isTrue);
      expect(requests.single.url.path, path);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['expectedVersion'], 9);
      expect((body['location'] as Map)['measuredAt'], fix['measuredAt']);
      expect(trips.versionOf(_trip), 10);
    });

    test(
      'position_stale: one fresh fix, asked now, and arrive again',
      () async {
        final trips = LiveTripCommands(
          api: api(),
          lastFix: () => fix,
          freshFix: () async => fresh,
        )..observe(_projection(const {}));
        answers
          ..add(
            (_) => json(409, {
              'code': 'invalid_transition',
              'reason': 'position_stale',
              'message': 'old',
            }),
          )
          ..add((_) => json(200, _projection(_arrived, version: 10)));
        final outcome = await trips.arriveAtStop(_trip, 0);
        expect(outcome.ok, isTrue);
        expect(requests, hasLength(2));
        final second = jsonDecode(requests.last.body) as Map<String, dynamic>;
        expect((second['location'] as Map)['measuredAt'], fresh['measuredAt']);
      },
    );

    test('too far: 409 not_at_stop says "not at the stop yet"', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(_projection(const {}));
      answers.add(
        (_) => json(409, {
          'code': 'invalid_transition',
          'reason': 'not_at_stop',
          'message': 'You are not at the stop yet.',
        }),
      );
      final outcome = await trips.arriveAtStop(_trip, 0);
      expect(outcome.ok, isFalse);
      expect(
        outcome.message,
        lookupAppLocalizations(const Locale('en')).liveTripNotAtStop,
      );
    });

    test('back tap while away: POST arrive with the latest fix although the '
        'stop has arrivedAt', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(
          _projection({
            ..._arrived,
            'away': {'since': '2026-11-14T10:02:00Z'},
          }),
        );
      answers.add(
        (_) => json(
          200,
          _projection({
            ..._arrived,
            'pausedSeconds': 360,
            'pauseCount': 1,
          }, version: 10),
        ),
      );
      final outcome = await trips.resumeStopWaiting(_trip, 0);
      expect(outcome.ok, isTrue);
      expect(requests.single.url.path, path);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['expectedVersion'], 9);
      expect((body['location'] as Map)['lat'], 59.3429);
      expect(trips.versionOf(_trip), 10);
    });

    test(
      'back tap when a fix already brought him back: nothing is sent',
      () async {
        final trips = LiveTripCommands(api: api(), lastFix: () => fix)
          ..observe(_projection({..._arrived, 'pausedSeconds': 360}));
        final outcome = await trips.resumeStopWaiting(_trip, 0);
        expect(outcome.ok, isTrue);
        expect(requests, isEmpty);
      },
    );

    test(
      'back tap answered stop_already_arrived (resumed meanwhile): done',
      () async {
        final trips = LiveTripCommands(api: api(), lastFix: () => fix)
          ..observe(
            _projection({
              ..._arrived,
              'away': {'since': '2026-11-14T10:02:00Z'},
            }),
          );
        answers.add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'reason': 'stop_already_arrived',
            'message': 'x',
          }),
        );
        expect((await trips.resumeStopWaiting(_trip, 0)).ok, isTrue);
      },
    );

    test('back tap too far (beyond leaveMeters): 409 not_at_stop', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(
          _projection({
            ..._arrived,
            'away': {'since': '2026-11-14T10:02:00Z'},
          }),
        );
      answers.add(
        (_) => json(409, {
          'code': 'invalid_transition',
          'reason': 'not_at_stop',
          'message': 'You are not at the stop yet.',
        }),
      );
      final outcome = await trips.resumeStopWaiting(_trip, 0);
      expect(outcome.ok, isFalse);
      expect(
        outcome.message,
        lookupAppLocalizations(const Locale('en')).liveTripNotAtStop,
      );
    });
  });

  group('trip screen', () {
    setUp(() {
      _now = DateTime.utc(2026, 11, 14, 10, 3);
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
      IslandMessages.reset();
      NavigationAppSetting.reset();
      DriverOfferRules.current = const DriverOfferRules();
      WaitingTerms.active = WaitingRules.current.base;
    });
    tearDown(() {
      NavigationAppSetting.reset();
      DriverOfferRules.current = const DriverOfferRules();
      WaitingTerms.active = WaitingRules.current.base;
      LiveDriverServices.instance = null;
    });

    testWidgets('away at the stop: the stop clock stands still with the '
        'paused note and "I\'m back at the stop"; back: it goes on from '
        'pausedSeconds and the note goes', (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final realtime = await _pump(tester);
      // 10:03: arrived 10:00 by the server, away since 10:02.
      _emit(
        realtime,
        _projection({
          ..._arrived,
          'away': {'since': '2026-11-14T10:02:00Z'},
        }),
      );
      await _frames(tester);
      final paused = en.waitingPausedAtStop(200, 100);
      expect(_inDock(paused), findsOneWidget);
      await _declineDemoNextTrip(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('active-ride-compact-dock')),
      );
      await _frames(tester);
      final back = find.byKey(
        const ValueKey<String>('active-ride-back-at-stop'),
      );
      expect(back, findsOneWidget);
      expect(
        find.descendant(of: back, matching: find.text(en.waitingBackAtStop)),
        findsOneWidget,
      );
      await _openSheet(tester);
      expect(_inSheet('2:00'), findsOneWidget);
      // 10:07: still 2:00.
      _now = DateTime.utc(2026, 11, 14, 10, 7);
      await tester.pump(const Duration(seconds: 1));
      await _frames(tester, 4);
      expect(_inSheet('2:00'), findsOneWidget);
      await _closeSheet(tester);
      // 10:08: back (6 min stopped).
      _now = DateTime.utc(2026, 11, 14, 10, 8);
      _emit(
        realtime,
        _projection({
          ..._arrived,
          'pausedSeconds': 360,
          'pauseCount': 1,
        }, version: 10),
      );
      await _frames(tester);
      expect(back, findsNothing, reason: 'the button goes with the stop');
      expect(find.textContaining(paused), findsNothing);
      _now = DateTime.utc(2026, 11, 14, 10, 9);
      await tester.pump(const Duration(seconds: 1));
      await _frames(tester, 4);
      await _openSheet(tester);
      // 10:09 − 10:00 − 6 min = 3:00.
      expect(_inSheet('3:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an older server (no away field): the stop clock counts '
        'from arrivedAt as before, no note, no button', (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final realtime = await _pump(tester);
      _emit(realtime, _projection({'arrivedAt': '2026-11-14T10:00:00Z'}));
      await _frames(tester);
      expect(_inDock(en.waitingPausedAtStop(200, 100)), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('active-ride-back-at-stop')),
        findsNothing,
      );
      await _openSheet(tester);
      expect(_inSheet('3:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
