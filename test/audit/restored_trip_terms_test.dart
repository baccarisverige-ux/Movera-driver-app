import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/waiting_rules.dart';
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

Future<void> _mount(WidgetTester tester, Widget trip) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(home: trip),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
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
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    WaitingTerms.active = WaitingRules.current.base;
  });

  // driver-u56: a far pickup (Q20) gives other waiting terms; a restored
  // trip must keep them, and the bags the rider brings.
  testWidgets('the trip snapshot saves the pickup distance and bags', (
    tester,
  ) async {
    final repo = MemoryActiveRideRepository();
    await _mount(
      tester,
      AcceptRide(
        tripId: 'far-pickup-trip',
        initialStage: ActiveRideStage.waitingForRider,
        pickupKm: 7,
        bags: 2,
        locationRepository: _PendingLocation(),
        activeRideRepository: repo,
      ),
    );
    final json = (await repo.read())!.toJson();
    expect(json['pickupKm'], 7);
    expect(json['bags'], 2);
    await _unmount(tester);
  });

  testWidgets('a restored far-pickup trip keeps its waiting terms and bags', (
    tester,
  ) async {
    // Contract v0.18.8 (G6): a far pickup's terms are the server's; the
    // zone's served terms are all the app has before them.
    final far = WaitingRules.current.termsFor(category: 'Movera');
    final snapshot = PersistedActiveRide.fromJson({
      'schemaVersion': 2,
      'tripId': 'far-pickup-trip',
      'stage': 'waitingForRider',
      'category': 'Movera',
      'pickupLat': 59.33,
      'pickupLng': 18.06,
      'dropoffLat': 59.35,
      'dropoffLng': 18.07,
      'pickupKm': 7.0,
      'bags': 2,
    })!;
    await _mount(
      tester,
      AcceptRide.fromPersisted(
        snapshot,
        locationRepository: _PendingLocation(),
        activeRideRepository: MemoryActiveRideRepository(),
      ),
    );
    expect(WaitingTerms.active.freeSeconds, far.freeSeconds);
    expect(WaitingTerms.active.noShowFee, far.noShowFee);
    expect(
      tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland)).bags,
      2,
    );
    await _unmount(tester);
  });

  test('a bad pickup distance or bag count is ignored, not trusted', () {
    final ride = PersistedActiveRide.fromJson({
      'schemaVersion': 2,
      'tripId': 't',
      'stage': 'onTrip',
      'pickupKm': -3,
      'bags': 'two',
    })!;
    expect(ride.toJson().containsKey('pickupKm'), isFalse);
    expect(ride.toJson().containsKey('bags'), isFalse);
  });
}
