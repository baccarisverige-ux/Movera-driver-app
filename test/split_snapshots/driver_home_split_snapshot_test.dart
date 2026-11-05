import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';
import 'tree_snapshot.dart';

// Base job 2 (2026-11-04): Home's map/sheet part (home_map_sheet.dart) split
// with no behaviour change. The snapshot was written before the split.

class _Location implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.34, 18.07),
    measuredAt: DateTime.now(),
    accuracyMeters: 4,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
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

  testWidgets('driver home: map, island and sheet', (tester) async {
    final originalMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = originalMaps);
    final location = _Location();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) =>
            MaterialApp(home: DriverHome(locationRepository: location)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expectTreeSnapshot(tester, 'driver_home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await location.updates.close();
  });
}
