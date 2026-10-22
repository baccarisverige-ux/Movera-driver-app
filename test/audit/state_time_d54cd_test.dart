// Wave 5 D5.4 (parts c + d): state and time. Time cases also run under
// TZ=Europe/Stockholm and TZ=America/New_York.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// GPS the test feeds by hand, standing near the default drop-off.
class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
  DriverLocation fix() => DriverLocation(
    point: const GeoPoint(59.3279, 18.0615),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [total] in 250 ms steps, so timers fire on time.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMilliseconds ~/ 250; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// A trip screen with the rider on board.
Future<_Loc> _pumpTrip(
  WidgetTester tester, {
  ActiveRideStage stage = ActiveRideStage.onTrip,
  bool paidByCash = false,
  DriverRealtime? realtime,
  bool destination = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final location = _Loc();
  addTearDown(location.updates.close);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(
      home: AcceptRide(
        tripId: 'cd-trip',
        fare: '250,00 kr',
        paidByCash: paidByCash,
        initialStage: stage,
        locationRepository: location,
        realtime: realtime,
        waitNow: () => tester.binding.clock.now(),
        activeRideRepository: MemoryActiveRideRepository(),
        waybillRepository: InMemoryWaybillRepository.instance,
        sessionController: DriverSessionController()..setOnline(true),
        destinationModeActive: destination,
        destinationAddress: destination ? 'Arlanda, Sigtuna' : null,
        destinationPosition: destination ? const LatLng(59.6519, 17.9186) : null,
      ),
    ),
  ));
  await _settle(tester, 10);
  return location;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 10);
}

/// Drags the trip's slide action (start, then complete).
Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester
        .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .last
        .controller!
        .animatePanelToSnapPoint();
    await _settle(tester, 18);
  }
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _settle(tester, 6);
}

/// Waits (in test time) until [finder] shows, up to [limit].
Future<void> _until(WidgetTester tester, Finder finder,
    [Duration limit = const Duration(seconds: 10)]) async {
  for (var t = Duration.zero; t < limit && finder.evaluate().isEmpty;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _offerCard = ValueKey<String>('on-trip-radar-offer-button');
const _matchNext = ValueKey<String>('on-trip-radar-match-next');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    InMemoryWaybillRepository.instance.reset();
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() {
    WaybillStore.reset();
    RideCheckGate.set(false);
    DriverOfferRules.current = const DriverOfferRules();
  });

  testWidgets('driver-u76: no next-trip offer after the trip ended, even '
      'after a resume and a GPS fix', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final location = await _pumpTrip(tester, realtime: realtime);
    realtime.emit(
      tripId: 'cd-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.cancelledByAdmin,
    );
    await _until(tester,
        find.byKey(const ValueKey<String>('trip-outcome-acknowledge')));
    // The driver leaves the app and comes back; the sheet is still up.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    location.updates.add(location.fix());
    await _pumpFor(tester, const Duration(seconds: 20));
    expect(find.byKey(_offerCard), findsNothing);
    expect(ExclusiveAnswers.instance.missedInRow, 0);
    await _unmount(tester);
  });

  testWidgets('driver-u77: a card trip is archived as paid by Card',
      (tester) async {
    await _pumpTrip(tester, stage: ActiveRideStage.waitingForRider);
    await _slide(tester); // Start the trip.
    await _slide(tester); // Complete.
    final confirm = find.byKey(const ValueKey('finish-soon-finish'));
    if (confirm.evaluate().isNotEmpty) await tester.tap(confirm);
    await _until(tester, find.byType(DriverRideCompleted));
    await _settle(tester, 24);
    final row = (await PrefsTripHistoryRepository().list()).single;
    expect(row.paymentMethod, 'Card');
    await _unmount(tester);
  });

  testWidgets('driver-45: a next-trip offer hidden for a Ride check comes '
      'back with only the time it had left', (tester) async {
    await _pumpTrip(tester);
    await _until(tester, find.byKey(_offerCard));
    // 15 s offer: 6 s on screen, then a 4 s Ride check.
    await _pumpFor(tester, const Duration(seconds: 6));
    RideCheckGate.set(true);
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(find.byKey(_offerCard), findsNothing);
    RideCheckGate.set(false);
    await tester.pump();
    expect(find.byKey(_offerCard), findsOneWidget);
    // About 9 s were left; it runs out then, not 15 s later.
    await _pumpFor(tester, const Duration(seconds: 10));
    expect(find.byKey(_offerCard), findsNothing);
    expect(ExclusiveAnswers.instance.missedInRow, 1);
    await _unmount(tester);
  });

  testWidgets('driver-46: ending the trip early starts the secured next trip '
      'with destination mode on', (tester) async {
    await _pumpTrip(tester, destination: true);
    await _until(tester, find.byKey(_matchNext));
    await tester.ensureVisible(find.byKey(_matchNext));
    await tester.tap(find.byKey(_matchNext));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(WaybillStore.next, isNotNull);
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await _settle(tester, 6);
    await tester
        .tap(find.byKey(const ValueKey<String>('active-ride-cancel-option')));
    await _settle(tester, 6);
    await tester.tap(find.byKey(
      const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
    ));
    await _settle(tester, 6);
    await tester
        .tap(find.byKey(const ValueKey<String>('confirm-trip-cancellation')));
    await _settle(tester, 24);
    final next = tester.widget<AcceptRide>(find.byType(AcceptRide));
    expect(next.tripId, isNot('cd-trip'));
    expect(next.destinationModeActive, isTrue);
    expect(next.destinationAddress, 'Arlanda, Sigtuna');
    await _unmount(tester);
  });

  testWidgets('driver-u171: a saved ticket keeps its category; older '
      'tickets still load', (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalSupportRepository.key: jsonEncode({
        'schemaVersion': 1,
        'tickets': [{'subject': 'Old ticket', 'preview': 'Saved before'}],
        'draft': {
          'subject': 'Payout',
          'message': 'Missing',
          'category': 'Wallet & payments',
        },
      }),
    });
    Future<void> open() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
        home: SupportInboxScreen(repository: LocalSupportRepository()),
      ));
      await tester.pumpAndSettle();
    }
    await open();
    await tester.tap(find.text('Draft local ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft in demo'));
    await tester.pumpAndSettle();
    await open(); // read back from storage
    expect(find.text('Payout'), findsOneWidget);
    expect(find.text('Wallet & payments'), findsOneWidget);
    expect(find.text('Old ticket'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('driver-u159: a trip hidden with × stays hidden when the Live '
      'list is opened again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hidden = RadarHiddenTrips(); // Home's
    const card = ValueKey<String>('radar-offer-card-nearby-1');
    Future<void> open() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: RideRequests(hiddenTrips: hidden)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    await open();
    expect(find.byKey(card), findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey<String>('radar-offer-dismiss-nearby-1')));
    await tester.pump(const Duration(milliseconds: 120));
    await open(); // closed and opened again
    expect(find.byKey(card), findsNothing);
    expect(find.byKey(const ValueKey<String>('radar-offer-card-nearby-2')),
        findsOneWidget);
    await _unmount(tester);
  });

  test('driver-u148: "Yesterday" only for the day before, by the calendar', () {
    final now = DateTime(2026, 10, 21, 1);
    expect(noticeTimeLabel(DateTime(2026, 10, 19, 23), now), '2 days ago');
    expect(noticeTimeLabel(DateTime(2026, 10, 19, 23, 30),
        DateTime(2026, 10, 20, 23, 45)), 'Yesterday');
  });

  test('driver-97: a time tomorrow says "tomorrow" on the spring DST day', () {
    // 28 Mar 2027 in Europe, 14 Mar 2027 in the US: a 23 h local day.
    for (final now in [DateTime(2027, 3, 28, 12), DateTime(2027, 3, 14, 12)]) {
      final until = DateTime(now.year, now.month, now.day + 1, 7);
      expect(scheduledTimeFrom(until, now), 'tomorrow 07:00');
    }
  });
}
