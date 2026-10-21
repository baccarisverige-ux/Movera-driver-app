// driver-u86: GPS that goes quiet (a tunnel, a garage) is not a long stop,
// and a safety alert does not send the old position as the current one.
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

/// One fix at the start, then silence: no fixes and no error.
class _QuietGps implements DriverLocationRepository {
  _QuietGps(this.clock);
  final DateTime Function() clock;
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    // About 1 km from the drop-off: not a planned stop.
    point: const GeoPoint(59.3416, 18.0649),
    measuredAt: clock(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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

  testWidgets('three quiet minutes open no Long stop check, and an alert '
      'sends no stale position', (tester) async {
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
    final gps = _QuietGps(() => now);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: AcceptRide(
          tripId: 'tunnel-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: gps,
          rideCheck: services,
        ),
      ),
    ));
    await _frames(tester);
    // The tunnel: 3 minutes with no fix (the native stream sends one a
    // second, even when the car stands still).
    for (var i = 0; i < 9; i++) {
      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
    }
    await _frames(tester);
    expect(find.byKey(const ValueKey('ride-check-card')), findsNothing,
        reason: 'lost GPS is not a long stop');

    // The driver asks for help: Movera gets no minutes-old position as
    // the car's current one.
    await tester.longPress(find.byKey(const ValueKey('island-morph-shell')));
    await _frames(tester);
    final demo = find.byKey(const ValueKey('ride-check-demo-longStop'));
    await tester.ensureVisible(demo);
    await tester.tap(demo);
    await _frames(tester, 30);
    await tester.tap(find.byKey(const ValueKey('ride-check-call-112')));
    await _frames(tester, 10);
    expect(alerts.alerts, isNotEmpty);
    expect(alerts.alerts.last.trip.position, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
    await gps.updates.close();
  });
}
