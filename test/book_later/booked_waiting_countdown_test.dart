import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/live/live_driver_services.dart';
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

/// Contract v0.18.51 §73 (`bookedRide0_18_51.waitFrom` / `beforePickup`,
/// owner 2026-11-07 "if driver arrive to pickup and still 12 min to pickup
/// time must show -12 min on timer until become 0 min then start timing
/// free then the charge time ... like usual trip"): the driver's waiting
/// timer on a booked ride reached early counts DOWN to the pickup time
/// (−12:00 … −0:01, texts.beforePickup), then 0:00 and the free minutes,
/// then the paid waiting, exactly as a live ride.

const _trip = 'booked-wait';

/// The phone's clock for the waiting count (fake time does not move
/// DateTime.now()).
DateTime _now = DateTime.utc(2026, 11, 8, 7, 48);

Map<String, dynamic> _projection({
  String kind = 'scheduled',
  String? scheduledAt = '2026-11-08T08:00:00Z',
  required Map<String, dynamic> waiting,
}) => {
  'tripId': _trip,
  'version': 4,
  'status': 'arrived',
  'kind': kind,
  'scheduledAt': ?scheduledAt,
  'acceptedAt': '2026-11-08T07:20:00Z',
  'pickup': {'lat': 59.3279, 'lng': 18.0615, 'address': 'Odlarvägen 22'},
  'dropoff': {'lat': 59.3326, 'lng': 18.0649, 'address': 'T-Centralen'},
  'rider': {'firstName': 'Camille'},
  'terms': {
    'currency': 'SEK',
    'freeWaitMin': 15,
    'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    'noShowAfterMin': 15,
    'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
    'noShowDriverSharePct': 80,
    'cancelDriverSharePct': 80,
    'maxPickupMoveMeters': 200,
  },
  'waiting': waiting,
};

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MemoryDriverRealtime> _pumpWaiting(WidgetTester tester) async {
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
          initialStage: ActiveRideStage.waitingForRider,
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
    status: TripStatus.arrived,
    projection: projection,
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland)).onWait();
  await _frames(tester, 8);
}

Finder _inSheet(String text) => find.descendant(
  of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
  matching: find.text(text),
);

void main() {
  setUp(() {
    _now = DateTime.utc(2026, 11, 8, 7, 48);
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

  contractTexts();

  group('waiting.waitFrom (model)', () {
    test('read from the server when it sends it', () {
      final w = TripLiveDetails.fromProjection(
        _projection(
          waiting: {
            'arrivedAt': '2026-11-08T07:48:00Z',
            'waitFrom': '2026-11-08T08:00:00Z',
            'freeUntil': '2026-11-08T08:15:00Z',
            'noShowAt': '2026-11-08T08:15:00Z',
          },
        ),
      ).waiting!;
      expect(w.waitFrom, DateTime.utc(2026, 11, 8, 8));
      expect(w.secondsAfterArrival(w.waitFrom), 12 * 60);
    });

    test('older server, booked ride: the later of arrival and pickup', () {
      final early = TripLiveDetails.fromProjection(
        _projection(waiting: {'arrivedAt': '2026-11-08T07:48:00Z'}),
      ).waiting!;
      expect(early.waitFrom, DateTime.utc(2026, 11, 8, 8));
      final late = TripLiveDetails.fromProjection(
        _projection(waiting: {'arrivedAt': '2026-11-08T08:07:00Z'}),
      ).waiting!;
      expect(late.waitFrom, DateTime.utc(2026, 11, 8, 8, 7));
    });

    test('older server, live ride: the arrival', () {
      final live = TripLiveDetails.fromProjection(
        _projection(
          kind: 'live',
          scheduledAt: '2026-11-08T08:00:00Z',
          waiting: {'arrivedAt': '2026-11-08T07:48:00Z'},
        ),
      ).waiting!;
      expect(live.waitFrom, DateTime.utc(2026, 11, 8, 7, 48));
    });
  });

  group('island face', () {
    TripIslandInput input(int seconds, {bool paid = false}) => TripIslandInput(
      status: 'Waiting',
      address: 'Odlarvägen 22',
      waitingMessage: '',
      arrived: true,
      waitingSeconds: seconds,
      paidWait: paid,
      paidSeconds: paid ? seconds - 27 * 60 : null,
    );

    test(
      '−12:00 · Before the pickup time, then 0:00 at the pickup (contract m:ss)',
      () {
        WaitingTerms.active = WaitingRules.current.base.anchored(
          freeSeconds: 27 * 60,
          noShowSeconds: 27 * 60,
          beforeSeconds: 12 * 60,
        );
        final island = TripIslandController(input(0));
        expect(island.face.title, '−12:00');
        expect(island.face.subtitle, 'Before the pickup time');
        island.update(input(11 * 60 + 59));
        expect(island.face.title, '\u22120:01');
        island.update(input(12 * 60));
        expect(island.face.title, '0:00');
        expect(island.face.subtitle, 'Waiting time');
        island.update(input(20 * 60));
        expect(island.face.title, '8:00');
        island.dispose();
      },
    );

    test('a live ride has no countdown (unchanged)', () {
      final island = TripIslandController(input(65));
      expect(island.face.title, '1:05');
      expect(island.face.subtitle, 'Waiting time');
      island.dispose();
    });
  });

  testWidgets('booked 08:00, arrived 07:48: −12:00, 0:00 at 08:00, free to '
      '08:15, then paid', (tester) async {
    final realtime = await _pumpWaiting(tester);
    _emit(
      realtime,
      _projection(
        waiting: {
          'arrivedAt': '2026-11-08T07:48:00Z',
          'waitFrom': '2026-11-08T08:00:00Z',
          'freeUntil': '2026-11-08T08:15:00Z',
          'noShowAt': '2026-11-08T08:15:00Z',
          'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
          'noShowDriverShare': {'amountMinor': 5200, 'currency': 'SEK'},
        },
      ),
    );
    await _frames(tester);
    await _openSheet(tester);
    expect(_inSheet('−12:00'), findsOneWidget);
    expect(_inSheet('Before the pickup time'), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-no-show-cancel')), findsNothing);

    // 08:00: the countdown is over, the free minutes start at 0:00.
    _now = _now.add(const Duration(minutes: 12));
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);
    expect(_inSheet('0:00'), findsOneWidget);
    expect(_inSheet('Before the pickup time'), findsNothing);
    expect(_inSheet('Included minutes'), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-fee-counter')), findsNothing);

    // 08:16: one paid minute, the no-show is possible (as a live ride).
    _now = _now.add(const Duration(minutes: 16));
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);
    expect(_inSheet('16:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-fee-counter')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('waiting-no-show-cancel')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('older server without waitFrom: the countdown from the '
      'pickup time', (tester) async {
    final realtime = await _pumpWaiting(tester);
    _emit(
      realtime,
      _projection(
        waiting: {
          'arrivedAt': '2026-11-08T07:48:00Z',
          'freeUntil': '2026-11-08T08:15:00Z',
          'noShowAt': '2026-11-08T08:15:00Z',
        },
      ),
    );
    await _frames(tester);
    await _openSheet(tester);
    expect(_inSheet('−12:00'), findsOneWidget);
    expect(_inSheet('Before the pickup time'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late driver (arrived 08:07): 0:00 at once, no countdown', (
    tester,
  ) async {
    final realtime = await _pumpWaiting(tester);
    _emit(
      realtime,
      _projection(
        waiting: {
          'arrivedAt': '2026-11-08T08:07:00Z',
          'waitFrom': '2026-11-08T08:07:00Z',
          'freeUntil': '2026-11-08T08:22:00Z',
          'noShowAt': '2026-11-08T08:22:00Z',
        },
      ),
    );
    await _frames(tester);
    await _openSheet(tester);
    expect(_inSheet('0:00'), findsOneWidget);
    expect(_inSheet('Before the pickup time'), findsNothing);
    expect(_inSheet('Included minutes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// The label is the contract's own text in sv / fr / en.
void contractTexts() {
  test('texts.beforePickup is the contract text in sv, fr and en', () {
    final contract =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final texts =
        (contract['bookedRide0_18_51'] as Map)['texts']['beforePickup'] as Map;
    for (final lang in ['sv', 'fr', 'en']) {
      expect(
        lookupAppLocalizations(Locale(lang)).waitingBeforePickup,
        texts[lang],
        reason: lang,
      );
    }
  });
}
