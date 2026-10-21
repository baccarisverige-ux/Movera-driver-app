import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// D3 (driver-74/75): "Leave now" while a screen or sheet covers Home keeps
// the accepted ride and opens it once Home is back on top.
// D4 (driver-37/38/39): an authoritative `completed` keeps the cash and
// waiting-fee record and updates Home's last trip; a same-stage projection
// leaves the next-trip offer alone.

/// Dispatch with no offers of its own.
class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(const <RideOffer>[]);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      ClaimResult.success(RideOffer.reservation(demoReservationRequest));
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  DriverSessionController? session,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          // As in the app: Home hears routes covering it and leaving.
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController:
                session ?? DriverSessionController(initialOnline: true),
            initialOnline: true,
            dispatchRepository: _Dispatch(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpTrip(
  WidgetTester tester,
  MemoryDriverRealtime realtime, {
  bool paidByCash = false,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey<String>('open-ride'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AcceptRide(
                  tripId: 'trip-c',
                  fare: '250,00 kr',
                  paidByCash: paidByCash,
                  initialStage: ActiveRideStage.onTrip,
                  activeRideRepository: MemoryActiveRideRepository(),
                  sessionController: DriverSessionController()..setOnline(true),
                  realtime: realtime,
                  waybillRepository: InMemoryWaybillRepository.instance,
                ),
              )),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const ValueKey<String>('open-ride')));
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    InMemoryWaybillRepository.instance.reset();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  for (final cover in ['screen', 'sheet']) {
    testWidgets(
      'driver-74/75: "Leave now" under a $cover keeps the ride in Accepted '
      'and opens the trip once Home is back on top',
      (tester) async {
        ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
        await _pumpHome(tester);
        await _frames(tester, const Duration(seconds: 40));
        expect(find.byType(AcceptRide), findsNothing);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        if (cover == 'screen') {
          navigator.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('covering')),
          ));
        } else {
          showModalBottomSheet<void>(
            context: navigator.context,
            builder: (_) => const SizedBox(height: 200, child: Text('covering')),
          );
        }
        // "Leave now" (about 46 s into the demo day) passes while covered.
        await _frames(tester, const Duration(seconds: 9));
        expect(find.byType(AcceptRide), findsNothing);
        expect(ScheduledRideStore.upcoming, contains(demoReservationRequest));
        expect(_saidTitles, isNot(contains('Leave now for 07:40 pickup')));

        navigator.pop();
        await _frames(tester, const Duration(seconds: 2));
        expect(find.byType(AcceptRide), findsOneWidget);
        expect(
          tester.widget<AcceptRide>(find.byType(AcceptRide)).pickupAddress,
          'Gamla vägen, Stockholm',
        );
        expect(_saidTitles, contains('Leave now for 07:40 pickup'));
        expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
        expect(ScheduledRideStore.backupNote.value, isNull);
        tester.takeException();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  // Owner rule: a scheduled ride belongs to the driver who accepted it.
  // Only an offline driver loses it to a backup driver.
  testWidgets(
    'scheduled rule: an online driver kept off Home past the backup '
    'minutes keeps the ride',
    (tester) async {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      await _pumpHome(tester);
      await _frames(tester, const Duration(seconds: 40));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering')),
      ));
      // "Leave now" passes, then the 5 admin minutes (10 s of demo day).
      await _frames(tester, const Duration(seconds: 25));
      expect(_saidTitles, isNot(contains('Given to backup driver')));
      expect(ScheduledRideStore.upcoming, contains(demoReservationRequest));
      expect(ScheduledRideStore.backupNote.value, isNull);

      navigator.pop();
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide), findsOneWidget);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'scheduled rule: a late driver who goes offline loses the ride to a '
    'backup driver',
    (tester) async {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      final session = DriverSessionController(initialOnline: true);
      await _pumpHome(tester, session: session);
      await _frames(tester, const Duration(seconds: 40));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering')),
      ));
      await _frames(tester, const Duration(seconds: 25));
      expect(_saidTitles, isNot(contains('Given to backup driver')));

      session.setOnline(false);
      await _frames(tester, const Duration(seconds: 1));
      expect(_saidTitles, contains('Given to backup driver'));
      expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'driver-37: an authoritative completed keeps the cash trip\'s payment '
    'method and cash collected in history',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(tester, realtime, paidByCash: true);

      realtime.emit(
        tripId: 'trip-c',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.completed,
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('trip-outcome-acknowledge')));
      await _settle(tester, 30);

      final row = (await PrefsTripHistoryRepository().list()).single;
      expect(row.tripId, 'trip-c');
      expect(row.status, TripStatus.completed);
      expect(row.paidByCash, isTrue);
      expect(row.cashCollected, '250,00 kr');
      expect(row.cashBalance, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'driver-39: an authoritative completed becomes Home\'s last trip',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(tester, realtime);

      realtime.emit(
        tripId: 'trip-c',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.completed,
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('trip-outcome-acknowledge')));
      await _settle(tester, 30);

      final waybills = InMemoryWaybillRepository.instance;
      expect(waybills.current, isNull);
      expect(waybills.last?.tripId, 'trip-c');
      expect(waybills.last?.fare, '250,00 kr');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'driver-38: a same-stage projection keeps the next trip the driver '
    'just accepted',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(tester, realtime);
      await tester.pump(const Duration(milliseconds: 3500));

      final match = find.byKey(const ValueKey('on-trip-radar-match-next'));
      expect(match, findsOneWidget);
      await tester.ensureVisible(match);
      await tester.tap(match);
      await tester.pump(const Duration(milliseconds: 200));
      realtime.emit(
        tripId: 'trip-c',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.approachingDropoff,
      );
      await _settle(tester, 32);

      expect(InMemoryWaybillRepository.instance.next, isNotNull);
      expect(find.byKey(const ValueKey('on-trip-radar-match-next')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'driver-r4-29: a completed during "Matching" keeps the accepted next trip',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(tester, realtime);
      await tester.pump(const Duration(milliseconds: 3500));
      final match = find.byKey(const ValueKey('on-trip-radar-match-next'));
      await tester.ensureVisible(match);
      await tester.tap(match);
      await tester.pump(const Duration(milliseconds: 100));
      realtime.emit(
        tripId: 'trip-c',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.completed,
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('trip-outcome-acknowledge')));
      await _settle(tester, 30);

      final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
      expect(trip.tripId, isNot('trip-c'), reason: 'the next trip opens');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

Iterable<String> get _saidTitles => IslandMessages.posted.map((m) => m.title);
