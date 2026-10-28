// Batch D2 regressions: offers and the trip lifecycle (D-04, D-05, D-09,
// X5, X9, UI-04, UI-07, UI-08).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentSound implements RadarSoundPlayer {
  @override
  Future<void> startLoop() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> prime() async {}
  @override
  Future<void> dispose() async {}
}

class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3279, 18.0615),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// A save that waits until the test lets it finish.
class _SlowSaveRepo extends MemoryActiveRideRepository {
  Completer<void>? gate;
  @override
  Future<void> save(PersistedActiveRide ride) async {
    final pending = gate;
    if (pending != null) await pending.future;
    await super.save(ride);
  }
}

class _RecordingRealtime extends MemoryDriverRealtime {
  final subscribed = <String>[];
  @override
  Stream<DriverRealtimeEvent> subscribe(String tripId) {
    subscribed.add(tripId);
    return super.subscribe(tripId);
  }
}

void _hide(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _show(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final steps = total.inMilliseconds ~/ 250;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _toRadarOffer(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  IslandMessages.reset();
  ScheduledRideStore.reset();
  DriverStartPosition.clearMemory();
  await (await SharedPreferences.getInstance()).setString(
    DriverStartPosition.key,
    '{"lat":59.3326,"lng":18.0649}',
  );
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(const MoveraApp());
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(find.text('OFF'));
  await tester.pump(const Duration(milliseconds: 1550));
  await tester.pump(const Duration(milliseconds: 2300));
  await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
  await tester.pump(const Duration(milliseconds: 900));
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-nearby-1')),
    findsOneWidget,
  );
}

Future<void> _pumpTrip(WidgetTester tester, Widget ride) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(home: ride),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _unmount(WidgetTester tester, [_Loc? location]) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await location?.updates.close();
}

const _offerCard = ValueKey<String>('on-trip-radar-offer-button');

void main() {
  tearDown(() => RadarOfferSound.debugPlayer = null);

  group('D-04: Radar pick window across pause/resume', () {
    testWidgets('an expired Radar offer stays expired after a resume', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      RadarOfferSound.debugPlayer = _SilentSound();
      await _toRadarOffer(tester);
      final match = find.byKey(const ValueKey<String>('radar-match-nearby-1'));
      bool enabled() => tester.widget<FilledButton>(match).onPressed != null;
      expect(enabled(), isTrue);
      await tester.pump(DriverOfferRules.current.radarTime);
      await tester.pump(const Duration(seconds: 1));
      expect(enabled(), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(match, findsOneWidget);
      expect(enabled(), isFalse, reason: 'resume must not revive it');
    });

    testWidgets('a pause before the end keeps the window, then it ends', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final realNow = ScheduledClock.realNow;
      ScheduledClock.realNow = () => tester.binding.clock.now();
      addTearDown(() => ScheduledClock.realNow = realNow);
      RadarOfferSound.debugPlayer = _SilentSound();
      await _toRadarOffer(tester);
      final match = find.byKey(const ValueKey<String>('radar-match-nearby-1'));
      bool enabled() => tester.widget<FilledButton>(match).onPressed != null;
      // The pause eats most of the window. Only the time left counts after
      // resume: a fresh window would keep Match lit well past that.
      final window = DriverOfferRules.current.radarTime;
      final pause = window * 0.6;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(pause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(enabled(), isTrue);
      await tester.pump(window - pause);
      expect(
        enabled(),
        isFalse,
        reason: 'the window ends on its first deadline, not resume + window',
      );
    });
  });

  group('D-05: on-trip Exclusive offer while the app is hidden', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExclusiveAnswers.instance.reset();
    });

    testWidgets('no offer arrives or counts as missed while hidden', (
      tester,
    ) async {
      final location = _Loc();
      await _pumpTrip(
        tester,
        AcceptRide(
          locationRepository: location,
          initialStage: ActiveRideStage.onTrip,
          waitNow: () => tester.binding.clock.now(),
        ),
      );
      _hide(tester);
      await _pumpFor(tester, const Duration(seconds: 25));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      _show(tester);
      await tester.pump(const Duration(milliseconds: 2600));
      expect(
        find.byKey(_offerCard),
        findsOneWidget,
        reason: 'Radar looks again once the trip is visible',
      );
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _unmount(tester, location);
    });

    testWidgets('an offer that ran out while hidden leaves without a miss', (
      tester,
    ) async {
      final location = _Loc();
      await _pumpTrip(
        tester,
        AcceptRide(
          locationRepository: location,
          initialStage: ActiveRideStage.onTrip,
          waitNow: () => tester.binding.clock.now(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byKey(_offerCard), findsOneWidget);
      _hide(tester);
      await _pumpFor(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(seconds: 2),
      );
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      _show(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_offerCard), findsNothing);
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _unmount(tester, location);
    });

    testWidgets('an offer with time left counts down the rest after resume', (
      tester,
    ) async {
      final location = _Loc();
      await _pumpTrip(
        tester,
        AcceptRide(
          locationRepository: location,
          initialStage: ActiveRideStage.onTrip,
          waitNow: () => tester.binding.clock.now(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byKey(_offerCard), findsOneWidget);
      _hide(tester);
      await tester.pump(const Duration(seconds: 2));
      _show(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_offerCard), findsOneWidget);
      // Seen and left unanswered on screen: that is a miss. Only the time
      // left runs after resume; a fresh lifetime would still show it here.
      await _pumpFor(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime -
            const Duration(milliseconds: 1750),
      );
      expect(find.byKey(_offerCard), findsNothing);
      // Owner 2026-10-27 (contract v0.8.0 §6.7): an Exclusive offer missed
      // while on a trip never counts toward going offline.
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _unmount(tester, location);
    });
  });

  group('D-09: driver commands during a background save', () {
    test('Arrive waits for the GPS snapshot save, then runs', () async {
      final repo = _SlowSaveRepo();
      final ride = ActiveRideController(tripId: 't1', repository: repo);
      repo.gate = Completer<void>();
      final save = ride.persistNow();
      final arrive = ride.transitionTo(ActiveRideStage.waitingForRider);
      await Future<void>.delayed(Duration.zero);
      expect(ride.stage, ActiveRideStage.headingToPickup);
      repo.gate!.complete();
      repo.gate = null;
      expect(await save, isTrue);
      expect(await arrive, isTrue);
      expect(ride.stage, ActiveRideStage.waitingForRider);
      expect((await repo.read())?.stage, ActiveRideStage.waitingForRider);
    });

    test('Finish waits for a lifecycle save, then completes', () async {
      final repo = _SlowSaveRepo();
      final ride = ActiveRideController(
        tripId: 't1',
        repository: repo,
        initialStage: ActiveRideStage.onTrip,
      );
      repo.gate = Completer<void>();
      final save = ride.persistNow();
      final finish = ride.complete();
      repo.gate!.complete();
      await save;
      expect(await finish, isTrue);
      expect(ride.completed, isTrue);
    });

    test(
      'a second command while the first is saving is still refused',
      () async {
        final repo = _SlowSaveRepo()..gate = Completer<void>();
        final ride = ActiveRideController(tripId: 't1', repository: repo);
        final first = ride.transitionTo(ActiveRideStage.waitingForRider);
        final second = ride.cancel();
        expect(await second, isFalse);
        repo.gate!.complete();
        expect(await first, isTrue);
        expect(ride.terminal, isFalse);
      },
    );
  });

  group('X5: searching / requested projections', () {
    for (final stage in ActiveRideStage.values) {
      for (final status in [TripStatus.searching, TripStatus.requested]) {
        test(
          '${status.wireName} at ${stage.name} ends the trip here',
          () async {
            final repo = MemoryActiveRideRepository();
            final ride = ActiveRideController(
              tripId: 'T1',
              repository: repo,
              initialStage: stage,
            );
            await ride.persistNow();
            expect(await ride.applyProjection(status), isTrue);
            expect(ride.terminal, isTrue);
            expect(ride.releasedToDispatch, isTrue);
            expect(await repo.read(), isNull);
            expect(await ride.transitionTo(ActiveRideStage.onTrip), isFalse);
          },
        );
      }
    }

    test('the echo of the driver\'s own cancel is not applied twice', () async {
      final ride = ActiveRideController(tripId: 'T1');
      expect(await ride.cancel(), isTrue);
      expect(ride.terminalStatus, TripStatus.searching);
      expect(await ride.applyProjection(TripStatus.searching), isFalse);
    });

    testWidgets('admin reassign: the trip leaves with an island notice', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      IslandMessages.reset();
      final realtime = _RecordingRealtime();
      addTearDown(realtime.dispose);
      final session = DriverSessionController(initialOnline: true);
      addTearDown(session.dispose);
      final location = _Loc();
      final navigator = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('home-under-trip')),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => AcceptRide(
              offerId: 'offer-7',
              tripId: 'trip-7',
              realtime: realtime,
              sessionController: session,
              locationRepository: location,
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AcceptRide), findsOneWidget);
      // X9: the trip, not the offer, is what realtime follows.
      expect(realtime.subscribed, ['trip-7']);
      expect(session.activeTripId, 'trip-7');

      realtime.emit(
        tripId: 'trip-7',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.searching,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AcceptRide), findsNothing);
      expect(find.text('home-under-trip'), findsOneWidget);
      expect(
        IslandMessages.posted.map((m) => m.title),
        contains('Trip removed by Movera'),
      );
      expect(session.activeTripId, isNull);
      expect(session.availableForOffers, isTrue);
      await _unmount(tester, location);
    });
  });

  group('X9: offer id and trip id stay apart', () {
    testWidgets('trip events are matched by trip id, not offer id', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final realtime = _RecordingRealtime();
      addTearDown(realtime.dispose);
      final repo = MemoryActiveRideRepository();
      final location = _Loc();
      await _pumpTrip(
        tester,
        AcceptRide(
          offerId: 'offer-9',
          tripId: 'trip-9',
          realtime: realtime,
          activeRideRepository: repo,
          locationRepository: location,
        ),
      );
      expect(realtime.subscribed, ['trip-9']);
      realtime.emit(
        tripId: 'trip-9',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.arrived,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final saved = await repo.read();
      expect(saved?.tripId, 'trip-9');
      expect(saved?.stage, ActiveRideStage.waitingForRider);
      await _unmount(tester, location);
    });
  });

  group('UI-04/07/08: trip screen entries', () {
    testWidgets('the in-trip menu gets the dispatch and the real status', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dispatch = DemoDispatchRepository();
      addTearDown(dispatch.dispose);
      final session = DriverSessionController(initialOnline: true);
      addTearDown(session.dispose);
      final location = _Loc();
      await _pumpTrip(
        tester,
        AcceptRide(
          dispatchRepository: dispatch,
          sessionController: session,
          locationRepository: location,
        ),
      );
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pump(const Duration(milliseconds: 400));
      var menu = tester.widget<DriverSideMenu>(find.byType(DriverSideMenu));
      expect(menu.dispatchRepository, same(dispatch));
      expect(menu.isOnline, isTrue);
      scaffold.closeDrawer();
      await tester.pump(const Duration(milliseconds: 400));
      // Five missed offers in a row: offline once this trip ends.
      session.setOnline(false);
      scaffold.openDrawer();
      await tester.pump(const Duration(milliseconds: 400));
      menu = tester.widget<DriverSideMenu>(find.byType(DriverSideMenu));
      expect(menu.isOnline, isFalse);
      await _unmount(tester, location);
    });

    testWidgets('two quick taps on the trip search open one picker, '
        'which starts from the car', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final location = _Loc();
      await _pumpTrip(tester, AcceptRide(locationRepository: location));
      final island = tester.widget<AdaptiveTripIsland>(
        find.byType(AdaptiveTripIsland),
      );
      island.onSearch();
      island.onSearch();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byType(DriverDestinationPicker, skipOffstage: false),
        findsOneWidget,
      );
      final picker = tester.widget<DriverDestinationPicker>(
        find.byType(DriverDestinationPicker),
      );
      expect(
        picker.origin,
        isNotNull,
        reason: 'with the car, a place needs "Confirm destination"',
      );
      expect(picker.routeRepository, isNotNull);
      await _unmount(tester, location);
    });

    testWidgets('two quick taps on Home search open one picker', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      DriverStartPosition.clearMemory();
      IslandMessages.reset();
      ScheduledRideStore.reset();
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => const MaterialApp(home: DriverHome()),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final open = find.byKey(const ValueKey<String>('destination-mode-open'));
      final onTap = tester.widget<InkWell>(open).onTap!;
      onTap();
      onTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byType(DriverDestinationPicker, skipOffstage: false),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });
}
