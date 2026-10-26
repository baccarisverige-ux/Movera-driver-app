import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// GPS that has not answered yet: Home must not invent a position.
class _WaitingGps implements DriverLocationRepository {
  final _fix = Completer<DriverLocation>();
  final _updates = StreamController<DriverLocation>.broadcast();

  @override
  Future<DriverLocation> getCurrentPosition() => _fix.future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _updates.stream;
}

const _stockholm = LatLng(59.3293, 18.0686);

Future<void> _pumpHome(WidgetTester tester) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) =>
          MaterialApp(home: DriverHome(locationRepository: _WaitingGps())),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(DriverStartPosition.clearMemory);

  testWidgets('saved last position is the first camera target and car', (
    tester,
  ) async {
    const saved = LatLng(59.6519, 17.9186);
    SharedPreferences.setMockInitialValues({
      DriverStartPosition.key: jsonEncode({
        'lat': saved.latitude,
        'lng': saved.longitude,
      }),
    });
    await _pumpHome(tester);

    final maps = tester.widgetList<GoogleMap>(find.byType(GoogleMap));
    expect(maps, isNotEmpty);
    for (final map in maps) {
      expect(map.initialCameraPosition.target, saved);
      expect(map.initialCameraPosition.target, isNot(_stockholm));
      expect(
        map.markers
            .singleWhere((m) => m.markerId.value == 'driver_location')
            .position,
        saved,
      );
    }
    expect(find.byKey(const ValueKey('home-map-locating')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('nothing known: no Stockholm map or car, a neutral placeholder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpHome(tester);

    expect(find.byKey(const ValueKey('home-map-locating')), findsWidgets);
    expect(find.byType(GoogleMap), findsNothing);
    expect(
      tester
          .widgetList<GoogleMap>(find.byType(GoogleMap))
          .any((map) => map.markers.any((m) => m.position == _stockholm)),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
