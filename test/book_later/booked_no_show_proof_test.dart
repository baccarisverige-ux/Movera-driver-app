import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Proof for contract v0.18.51 §73 items 3 and 4 (`bookedRide0_18_51.noShow`
/// and `.fees`, owner 2026-11-07 "Late arrival" and "Booked fees"):
/// (3) on a booked ride the driver's no-show button is offered only from
/// `waiting.noShowAt` (noShowAfterMin after the LATER of Arrived and the
/// pickup time), never from the phone's own count of the zone minutes;
/// (4) the no-show confirm says the booking fee the server put on the trip
/// at arrive (`waiting.noShowFee` / `noShowDriverShare`), not the zone's
/// normal no-show fee.

const _trip = 'booked-no-show';

DateTime _now = DateTime.utc(2026, 11, 8, 8, 7);

Map<String, dynamic> _projection(Map<String, dynamic> waiting) => {
  'tripId': _trip,
  'version': 4,
  'status': 'arrived',
  'kind': 'scheduled',
  'scheduledAt': '2026-11-08T08:00:00Z',
  'acceptedAt': '2026-11-08T07:20:00Z',
  'pickup': {'lat': 59.3279, 'lng': 18.0615, 'address': 'Odlarvägen 22'},
  'dropoff': {'lat': 59.3326, 'lng': 18.0649, 'address': 'T-Centralen'},
  'rider': {'firstName': 'Camille'},
  'terms': {
    'currency': 'SEK',
    // The zone's normal rule: 5 free minutes, no-show after 5, 65 kr.
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
    'noShowDriverSharePct': 80,
    'cancelDriverSharePct': 80,
    'maxPickupMoveMeters': 200,
  },
  'waiting': waiting,
};

/// Booked 08:00, the driver arrived late at 08:07: waitFrom 08:07, free
/// until 08:12, no-show from 08:12. The booking fee is 150 kr; the driver
/// gets 80 % = 120 kr (owner Q1 2026-11-07: the no-show share).
const _lateWaiting = {
  'arrivedAt': '2026-11-08T08:07:00Z',
  'waitFrom': '2026-11-08T08:07:00Z',
  'freeUntil': '2026-11-08T08:12:00Z',
  'noShowAt': '2026-11-08T08:12:00Z',
  'noShowFee': {'amountMinor': 15000, 'currency': 'SEK'},
  'noShowDriverShare': {'amountMinor': 12000, 'currency': 'SEK'},
};

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MemoryDriverRealtime> _pumpWaiting(
  WidgetTester tester, {
  int waitSeconds = 0,
}) async {
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
          initialWaitSeconds: waitSeconds,
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

void _emit(MemoryDriverRealtime realtime, Map<String, dynamic> waiting) {
  realtime.emit(
    tripId: _trip,
    kind: DriverRealtimeKind.tripProjection,
    status: TripStatus.arrived,
    projection: _projection(waiting),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland)).onWait();
  await _frames(tester, 8);
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
      matching: find.text('Close'),
    ),
  );
  await _frames(tester, 12);
}

final _noShowButton = find.byKey(const ValueKey('waiting-no-show-cancel'));

void main() {
  setUp(() {
    _now = DateTime.utc(2026, 11, 8, 8, 7);
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

  testWidgets('item 3: late booked driver — no-show only from noShowAt '
      '(08:12), not at once', (tester) async {
    final realtime = await _pumpWaiting(tester);
    _emit(realtime, _lateWaiting);
    await _frames(tester);
    // Right after Arrived (08:07): the old rule "from the pickup time"
    // would already allow it (7 min > 5); waitFrom says no.
    await _openSheet(tester);
    expect(_noShowButton, findsNothing);
    await _closeSheet(tester);

    // 08:11:59 — one second before noShowAt: still no button.
    _now = DateTime.utc(2026, 11, 8, 8, 11, 59);
    await tester.pump(const Duration(seconds: 1));
    await _openSheet(tester);
    expect(_noShowButton, findsNothing);
    await _closeSheet(tester);

    // 08:12 — noShowAt: the button is offered.
    _now = DateTime.utc(2026, 11, 8, 8, 12);
    await tester.pump(const Duration(seconds: 1));
    await _openSheet(tester);
    expect(_noShowButton, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('item 3: early booked driver (07:48, noShowAt 08:05) — no '
      'button at 10 min on the phone count', (tester) async {
    _now = DateTime.utc(2026, 11, 8, 7, 58);
    // The phone counted 10 min (5 + 5 of the zone rule would allow it).
    final realtime = await _pumpWaiting(tester, waitSeconds: 10 * 60);
    _emit(realtime, {
      ..._lateWaiting,
      'arrivedAt': '2026-11-08T07:48:00Z',
      'waitFrom': '2026-11-08T08:00:00Z',
      'freeUntil': '2026-11-08T08:05:00Z',
      'noShowAt': '2026-11-08T08:05:00Z',
    });
    await _frames(tester);
    expect(WaitingTerms.active.noShowSeconds, 17 * 60);
    await _openSheet(tester);
    expect(_noShowButton, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('item 4: the confirm says the booking fee share '
      '(waiting.noShowDriverShare 120 kr), not 80 % of 65 kr', (tester) async {
    _now = DateTime.utc(2026, 11, 8, 8, 12);
    final realtime = await _pumpWaiting(tester, waitSeconds: 5 * 60);
    _emit(realtime, _lateWaiting);
    await _frames(tester);
    await _openSheet(tester);
    // The sheet's no-show line is the driver's share of the booking fee.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
        matching: find.textContaining('120'),
      ),
      findsWidgets,
    );
    expect(find.textContaining('52'), findsNothing);
    final list = find.descendant(
      of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(_noShowButton, 120, scrollable: list.first);
    await tester.tap(_noShowButton);
    await _frames(tester, 8);
    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-confirmation')),
      findsOneWidget,
    );
    expect(find.text('Mark as no-show? You get 120 kr'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('item 4: a booked fee of 0 → "Mark as no-show? No fee"', (
    tester,
  ) async {
    _now = DateTime.utc(2026, 11, 8, 8, 12);
    final realtime = await _pumpWaiting(tester, waitSeconds: 5 * 60);
    _emit(realtime, {
      ..._lateWaiting,
      'noShowFee': {'amountMinor': 0, 'currency': 'SEK'},
      'noShowDriverShare': {'amountMinor': 0, 'currency': 'SEK'},
    });
    await _frames(tester);
    await _openSheet(tester);
    final list = find.descendant(
      of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(_noShowButton, 120, scrollable: list.first);
    await tester.tap(_noShowButton);
    await _frames(tester, 8);
    expect(find.text('Mark as no-show? No fee'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
