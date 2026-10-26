import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingLocation implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

Future<int?> _restoredWait(
  WidgetTester tester,
  Duration age, {
  String? destination,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final snapshot = PersistedActiveRide(
    tripId: 'stale-wait-trip',
    stage: ActiveRideStage.waitingForRider,
    waitSeconds: 30,
    savedAt: DateTime.now().subtract(age),
    destinationModeActive: destination != null,
    destinationAddress: destination,
    pickupLat: 59.33,
    pickupLng: 18.06,
    dropoffLat: 59.35,
    dropoffLng: 18.07,
  );
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide.fromPersisted(
          snapshot,
          locationRepository: _PendingLocation(),
          activeRideRepository: MemoryActiveRideRepository(),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final seconds = tester
      .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
      .waitingSeconds;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  return seconds;
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  // driver-u58: a snapshot older than the freshness window was dead, not
  // waiting; resuming it must not bill the hours in between.
  testWidgets('a stale waiting snapshot resumes without the gap', (
    tester,
  ) async {
    final seconds = await _restoredWait(tester, const Duration(hours: 7));
    expect(seconds, inInclusiveRange(30, 35));
  });

  testWidgets('a fresh waiting snapshot still counts the time away', (
    tester,
  ) async {
    final seconds = await _restoredWait(tester, const Duration(minutes: 4));
    expect(seconds, inInclusiveRange(270, 275));
  });

  // driver-r4-11: after a restart the session is empty; the restored
  // destination still counts for today and its time limit runs.
  testWidgets('a restored destination counts for today and its time runs', (
    tester,
  ) async {
    final session = DestinationModeSession.instance = DestinationModeSession();
    await _restoredWait(
      tester,
      const Duration(minutes: 4),
      destination: 'Solna',
    );
    expect(session.activeAddress, 'Solna');
    expect(session.usedToday(), 1);
    final since = session.activeSince!;
    expect(DateTime.now().difference(since).inMinutes, inInclusiveRange(4, 5));
  });
}
