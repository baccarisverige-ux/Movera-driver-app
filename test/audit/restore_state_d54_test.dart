// Wave 5 D5.4: what a crash or reload restore of a trip keeps.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// A car standing still about 1 km from the drop-off, one fix a second.
class _StillGps implements DriverLocationRepository {
  _StillGps(this.clock);
  final DateTime Function() clock;
  final updates = StreamController<DriverLocation>.broadcast();
  DriverLocation fix() => DriverLocation(
    point: const GeoPoint(59.3416, 18.0649),
    measuredAt: DateTime.now(), // fresh to the trip screen
    accuracyMeters: 5,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

PersistedActiveRide _saved(Map<String, Object> extra) =>
    PersistedActiveRide.fromJson({
      'schemaVersion': 2,
      'tripId': 'restored-trip',
      'stage': 'onTrip',
      'category': 'Comfort',
      'pickupLat': 59.33, 'pickupLng': 18.06,
      'dropoffLat': 59.3326, 'dropoffLng': 18.0649,
      ...extra,
    })!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(
      autoOffline: false,
      exclusiveWhileDriving: false,
    );
  });
  tearDown(() {
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  testWidgets('driver-u44: a Ride check answered before a reload does not '
      'open again', (tester) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = DateTime.now();
    final alerts = DemoSafetyAlertRepository();
    addTearDown(alerts.dispose);
    final services = RideCheckServices(
      alerts: alerts,
      log: MemoryRideCheckLog(),
      now: () => now,
      launch: (_) async => true,
    );
    final gps = _StillGps(() => now);
    final repo = MemoryActiveRideRepository();
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RideCheckScope(
          services: services,
          child: AcceptRide.fromPersisted(
            _saved({'rideCheckFired': ['longStop']}),
            locationRepository: gps,
            activeRideRepository: repo,
          ),
        ),
      ),
    ));
    await _frames(tester);
    // Still stuck: 5 minutes without moving.
    for (var i = 0; i < 15; i++) {
      now = now.add(const Duration(seconds: 20));
      gps.updates.add(gps.fix());
      await tester.pump(const Duration(seconds: 20));
    }
    await _frames(tester);
    expect(find.byKey(const ValueKey('ride-check-card')), findsNothing,
        reason: 'the long-stop check was answered before the reload');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
    await gps.updates.close();
  });

  test('driver-u44: the saved trip keeps the used checks; older saves have none', () {
    final ride = _saved({'rideCheckFired': ['longStop', 'offRoute']});
    expect(PersistedActiveRide.fromJson(ride.stamped().toJson())!.rideCheckFired,
        ['longStop', 'offRoute']);
    expect(_saved({}).rideCheckFired, isEmpty);
  });
}
