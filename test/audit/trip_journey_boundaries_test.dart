import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class _Location implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

class _DelayedSave extends MemoryActiveRideRepository {
  final requests = <Completer<void>>[];
  @override
  Future<void> save(PersistedActiveRide ride) async {
    final gate = Completer<void>();
    requests.add(gate);
    await gate.future;
    await super.save(ride);
  }
}

class _FailedClear extends MemoryActiveRideRepository {
  int attempts = 0;
  @override
  Future<void> clear() async {
    if (++attempts == 1) {
      throw StateError('Storage unavailable');
    }
    await super.clear();
  }
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _mount(WidgetTester tester, AcceptRide ride) async {
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
  await _frames(tester);
}

Future<void> _middle(WidgetTester tester) async {
  tester
      .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .controller!
      .animatePanelToSnapPoint();
  await _frames(tester, 16);
}

int? _wait(WidgetTester tester) => tester
    .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
    .waitingSeconds;

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: true,
      skipAccountActivation: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  test('delayed onboard save prevents a duplicate transition', () async {
    final store = _DelayedSave();
    final ride = ActiveRideController(
      tripId: 'A',
      repository: store,
      initialStage: ActiveRideStage.waitingForRider,
    );
    final first = ride.transitionTo(ActiveRideStage.onTrip);
    expect(await ride.transitionTo(ActiveRideStage.onTrip), isFalse);
    expect(store.requests, hasLength(1));
    expect(ride.stage, ActiveRideStage.waitingForRider);
    store.requests.single.complete();
    expect(await first, isTrue);
    expect(ride.stage, ActiveRideStage.onTrip);
    ride.dispose();
  });

  test(
    'failed completion cleanup can retry without duplicate completion',
    () async {
      final store = _FailedClear();
      final ride = ActiveRideController(
        tripId: 'A',
        repository: store,
        initialStage: ActiveRideStage.onTrip,
      );
      expect(await ride.complete(), isFalse);
      expect(ride.terminal, isFalse);
      expect(ride.persistenceError, isA<StateError>());
      expect(await ride.complete(), isTrue);
      expect(ride.persistenceError, isNull);
      expect(await ride.complete(), isFalse);
      expect(store.attempts, 2);
      ride.dispose();
    },
  );

  testWidgets('authoritative arrival starts waiting from the current stage', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 8, 12);
    final realtime = MemoryDriverRealtime();
    await _mount(
      tester,
      AcceptRide(
        tripId: 'projection-trip',
        realtime: realtime,
        locationRepository: _Location(),
        waitNow: () => now,
      ),
    );
    realtime.emit(
      tripId: 'projection-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.arrived,
    );
    await _frames(tester);
    expect(_wait(tester), 0);
    now = now.add(const Duration(seconds: 150));
    await tester.pump(const Duration(seconds: 1));
    expect(_wait(tester), 150);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    realtime.dispose();
  });

  testWidgets('two stops advance once and each paid wait starts from zero', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 8, 12);
    final store = MemoryActiveRideRepository();
    await _mount(
      tester,
      AcceptRide(
        tripId: 'stop-trip',
        initialStage: ActiveRideStage.onTrip,
        initialWaitSeconds: 30,
        waitNow: () => now,
        locationRepository: _Location(),
        activeRideRepository: store,
        stopAddresses: const ['First stop', 'Second stop'],
        stopPositions: const [
          LatLng(59.3279, 18.0615),
          LatLng(59.3279, 18.0615),
        ],
        restoredSnapshot: const PersistedActiveRide(
          tripId: 'stop-trip',
          stage: ActiveRideStage.onTrip,
          stopIndex: 0,
          paidStopWait: true,
        ),
      ),
    );
    expect(_wait(tester), 30);
    await _middle(tester);
    final action = find.byKey(
      const ValueKey<String>('active-ride-primary-action'),
    );
    await tester.ensureVisible(action);
    await tester.drag(action, const Offset(320, 0));
    await _frames(tester);
    expect((await store.read())?.stopIndex, 1);
    expect((await store.read())?.paidStopWait, isFalse);
    expect(_wait(tester), isNull);
    now = now.add(const Duration(seconds: 100));
    final arrive = find.byKey(
      const ValueKey<String>('active-ride-arrived-button'),
    );
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await _frames(tester);
    expect(_wait(tester), 0);
    now = now.add(const Duration(seconds: 95));
    await tester.pump(const Duration(seconds: 1));
    expect(_wait(tester), 95);
    // The simulated next-trip offer owns the sheet until explicitly denied.
    final deny = find.byKey(const ValueKey<String>('on-trip-radar-deny'));
    expect(deny, findsOneWidget);
    await tester.tap(deny);
    await _frames(tester);
    expect(_wait(tester), 95);
    await _middle(tester);
    await tester.ensureVisible(action);
    await tester.drag(action, const Offset(320, 0));
    await _frames(tester);
    expect((await store.read())?.stopIndex, 2);
    expect((await store.read())?.paidStopWait, isFalse);
    expect(_wait(tester), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
