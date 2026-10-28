import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Location implements DriverLocationRepository {
  DriverLocation get fix => DriverLocation(
    point: const GeoPoint(59.3293, 18.0686),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream.value(fix);
}

Set<Polygon> _surgePolygons(WidgetTester tester) => {
  for (final map in tester.widgetList<GoogleMap>(find.byType(GoogleMap)))
    ...map.polygons.where((p) => p.polygonId.value.startsWith('surge_')),
};

/// Contract v0.7.2 §17 on the demo Home: online, the map colours three
/// surge zones (one per level) and nothing else says surge; offline, none.
void main() {
  testWidgets('demo Home: coloured zones online, none offline', (tester) async {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController(initialOnline: true);
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverHome(
              sessionController: session,
              initialOnline: true,
              locationRepository: _Location(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GoogleMap), findsWidgets);
    final polygons = _surgePolygons(tester);
    expect(polygons, hasLength(3));
    expect(polygons.map((p) => p.strokeColor.toARGB32()).toSet(), {
      0xFFFFC79E,
      0xFFFF8A3D,
      0xFFE5482B,
    });
    // No multiplier and no money anywhere on Home.
    expect(find.textContaining('×'), findsNothing);
    expect(find.textContaining('surge', findRichText: true), findsNothing);

    session.setOnline(false);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_surgePolygons(tester), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
