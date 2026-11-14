import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_error_message.dart';
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

/// Job C9 (contract v0.18.93 §91, `contract.json#autoArrive`; owner
/// 2026-11-02 review Q3 "Both: auto + button", Rules
/// decisions/driver-g7.md:83-84): the server marks the driver arrived and
/// stops the waiting clock while he is more than `terms.leaveMeters` from
/// the pickup. The driver app shows the server's state: the trip moves to
/// waiting on a projection with status arrived (no tap), the waiting clock
/// stands still while `waiting.away` is set with the paused note, and goes
/// on from the server's moved moments. No distance is measured here.

const _trip = 'c9-auto';
DateTime _now = DateTime.utc(2026, 11, 14, 10, 1);

Map<String, dynamic> _projection(
  Map<String, dynamic> waiting, {
  String status = 'arrived',
}) => {
  'tripId': _trip,
  'version': 5,
  'status': status,
  'kind': 'live',
  'acceptedAt': '2026-11-14T09:50:00Z',
  'pickup': {'lat': 59.3326, 'lng': 18.0649, 'address': 'Sergels torg'},
  'dropoff': {'lat': 59.3143, 'lng': 18.0735, 'address': 'Medborgarplatsen'},
  'rider': {'firstName': 'Camille'},
  'terms': {
    'currency': 'SEK',
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 1226, 'currency': 'SEK'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
    'noShowDriverSharePct': 80,
    'cancelDriverSharePct': 100,
    'maxPickupMoveMeters': 200,
    'autoArriveMeters': 100,
    'leaveMeters': 200,
  },
  'waiting': waiting,
};

const _arrived = {
  'arrivedAt': '2026-11-14T10:00:00Z',
  'waitFrom': '2026-11-14T10:00:00Z',
  'chargedSeconds': 0,
  'arrivedBy': 'auto',
};

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MemoryDriverRealtime> _pump(
  WidgetTester tester,
  ActiveRideStage stage,
) async {
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
          initialStage: stage,
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
    status: projection['status'] == 'arrived'
        ? TripStatus.arrived
        : TripStatus.driverToPickup,
    projection: projection,
  );
}

Finder _inSheet(String text) => find.descendant(
  of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
  matching: find.text(text),
);

/// The collapsed trip bar (the face the waiting driver sees first).
Finder _inDock(String text) => find.descendant(
  of: find.byKey(const ValueKey<String>('active-ride-compact-dock')),
  matching: find.textContaining(text),
);

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
  setUp(() {
    _now = DateTime.utc(2026, 11, 14, 10, 1);
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

  test('texts: autoArrive.texts.driverPaused / noShowAway are the '
      'contract text in sv, fr and en', () {
    final contract =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final texts = (contract['autoArrive'] as Map)['texts'] as Map;
    for (final lang in ['sv', 'fr', 'en']) {
      final l = lookupAppLocalizations(Locale(lang));
      expect(
        l.waitingPausedAway(200, 100),
        (texts['driverPaused'][lang] as String)
            .replaceAll('{leave}', '200')
            .replaceAll('{arrive}', '100'),
        reason: lang,
      );
      expect(l.noShowAwayFromPickup, texts['noShowAway'][lang], reason: lang);
    }
  });

  group('model (TripWaitingNow / TripTerms)', () {
    test('away, stopped seconds and the clock as the server counts it', () {
      final live = TripLiveDetails.fromProjection(
        _projection({
          ..._arrived,
          'freeUntil': '2026-11-14T10:11:00Z',
          'noShowAt': '2026-11-14T10:11:00Z',
          'pausedSeconds': 360,
          'pauseCount': 1,
          'away': {'since': '2026-11-14T10:09:00Z'},
        }),
      );
      final w = live.waiting!;
      expect(w.arrivedBy, 'auto');
      expect(w.paused, isTrue);
      expect(w.pausedSeconds, 360);
      // 10:09 − 10:00 − 6 min stopped = 3 min, still 3 min at 10:20.
      expect(w.waitingClockAt(DateTime.utc(2026, 11, 14, 10, 20)), 180);
      // freeUntil 10:11 − 6 min stopped = 5 min on the clock (the free wait).
      expect(w.clockSecondsOf(w.freeUntil), 300);
      expect(live.terms!.autoArriveMeters, 100);
      expect(live.terms!.leaveMeters, 200);
    });

    test('an older server: nothing stopped, nothing changes', () {
      final w = TripLiveDetails.fromProjection(
        _projection({
          'arrivedAt': '2026-11-14T10:00:00Z',
          'freeUntil': '2026-11-14T10:05:00Z',
          'noShowAt': '2026-11-14T10:05:00Z',
        }),
      ).waiting!;
      expect(w.paused, isFalse);
      expect(w.arrivedBy, isNull);
      expect(w.waitingClockAt(DateTime.utc(2026, 11, 14, 10, 2)), 120);
      expect(w.clockSecondsOf(w.freeUntil), 300);
    });

    test('a restored trip keeps the server clock (stopped time out)', () {
      final ride = LiveActiveTrip.snapshotOf(
        _projection({
          ..._arrived,
          'freeUntil': '2026-11-14T10:05:00Z',
          'noShowAt': '2026-11-14T10:05:00Z',
          'away': {'since': '2000-01-01T00:00:00Z'},
        }),
      )!;
      expect(ride.waitSeconds, 0, reason: 'stands still at away.since');
    });

    test('the no-show refused while away says why', () {
      expect(
        liveTripErrorMessage(
          const ApiError(
            statusCode: 409,
            code: 'invalid_transition',
            message: 'x',
            reason: 'driver_away_from_pickup',
          ),
        ),
        lookupAppLocalizations(const Locale('en')).noShowAwayFromPickup,
      );
    });
  });

  testWidgets('the server marks him arrived: the trip moves to waiting with '
      'no tap', (tester) async {
    final realtime = await _pump(tester, ActiveRideStage.headingToPickup);
    await _openSheet(tester);
    expect(
      find.byKey(const ValueKey<String>('waiting-time-sheet')),
      findsNothing,
      reason: 'no waiting before the arrival',
    );
    _now = DateTime.utc(2026, 11, 14, 10, 0, 30);
    _emit(
      realtime,
      _projection({
        ..._arrived,
        'freeUntil': '2026-11-14T10:05:00Z',
        'noShowAt': '2026-11-14T10:05:00Z',
      }),
    );
    await _frames(tester);
    await _openSheet(tester);
    expect(
      find.byKey(const ValueKey<String>('waiting-time-sheet')),
      findsOneWidget,
    );
    expect(_inSheet('Included minutes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('away: the clock stands still with the paused note; back: it '
      'goes on from the moved moments', (tester) async {
    final realtime = await _pump(tester, ActiveRideStage.waitingForRider);
    // 10:03: away since 10:02 (2 min waited).
    _now = DateTime.utc(2026, 11, 14, 10, 3);
    _emit(
      realtime,
      _projection({
        ..._arrived,
        'freeUntil': '2026-11-14T10:05:00Z',
        'noShowAt': '2026-11-14T10:05:00Z',
        'away': {'since': '2026-11-14T10:02:00Z'},
      }),
    );
    await _frames(tester);
    final paused = lookupAppLocalizations(
      const Locale('en'),
    ).waitingPausedAway(200, 100);
    expect(_inDock(paused), findsOneWidget);
    await _openSheet(tester);
    expect(_inSheet('2:00'), findsOneWidget);
    // 10:07: still 2:00 (nothing counts while he is away).
    _now = DateTime.utc(2026, 11, 14, 10, 7);
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);
    expect(_inSheet('2:00'), findsOneWidget);
    await _closeSheet(tester);
    // 10:08: back since 10:08 → 6 min stopped; freeUntil / noShowAt 10:11.
    _now = DateTime.utc(2026, 11, 14, 10, 8);
    _emit(
      realtime,
      _projection({
        ..._arrived,
        'freeUntil': '2026-11-14T10:11:00Z',
        'noShowAt': '2026-11-14T10:11:00Z',
        'pausedSeconds': 360,
        'pauseCount': 1,
      }),
    );
    await _frames(tester);
    expect(
      _inDock(paused),
      findsNothing,
      reason: 'the note goes with the stop',
    );
    expect(_inDock('Waiting for'), findsOneWidget);
    _now = DateTime.utc(2026, 11, 14, 10, 9);
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);
    await _openSheet(tester);
    // 10:09 − 10:00 − 6 min = 3:00, still inside the 5 free minutes.
    expect(_inSheet('3:00'), findsOneWidget);
    expect(_inSheet('Included minutes'), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-fee-counter')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
