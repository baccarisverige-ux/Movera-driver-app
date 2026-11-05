import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tree_snapshot.dart';

// Base job B8 (2026-11-04): scheduled_rides.dart, accept_ride_trip.dart and
// home_offer_radar.dart split with no behaviour change. These snapshots were
// written before the split (home is covered by driver_home.txt).

class _Loc implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3279, 18.0615),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('scheduled rides: requests, details and accepted', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: ScheduledRidesScreen()),
      ),
    );
    await _settle(tester);
    expectTreeSnapshot(tester, 'driver_scheduled_requests');
    final cards = find.byType(InkWell);
    if (cards.evaluate().length > 3) {
      await tester.tap(cards.at(3), warnIfMissed: false);
      await _settle(tester);
      expectTreeSnapshot(tester, 'driver_scheduled_details');
      final nav = Navigator.of(tester.element(find.byType(Scaffold).last));
      if (nav.canPop()) nav.pop();
      await _settle(tester);
    }
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(home: ScheduledRidesScreen()),
      ),
    );
    await _settle(tester);
    final accepted = find.textContaining('Accepted');
    if (accepted.evaluate().isNotEmpty) {
      await tester.tap(accepted.first, warnIfMissed: false);
      await _settle(tester);
    }
    expectTreeSnapshot(tester, 'driver_scheduled_accepted');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('accept ride: trip screen', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: AcceptRide(
            tripId: 'snapshot-trip',
            locationRepository: _Loc(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    await _settle(tester);
    expectTreeSnapshot(tester, 'driver_accept_ride');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
