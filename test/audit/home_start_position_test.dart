import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_zones.dart';
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

/// Records every camera command Home sends to the map.
class _RecordingMaps extends HeadlessMapPlatform {
  final moves = <String>[];

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => moves.add(jsonEncode(cameraUpdate.toJson()));

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => moves.add(jsonEncode(cameraUpdate.toJson()));
}

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
  setUp(() {
    DriverStartPosition.clearMemory();
    StartCountryHints.reset();
  });
  tearDown(StartCountryHints.reset);

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

  testWidgets('nothing known: the map shows at once (no hidden wait), no car', (
    tester,
  ) async {
    // Owner REMINDERS 145: never wait longer than the intro; open at the
    // zone centre and move when the position arrives.
    SharedPreferences.setMockInitialValues({});
    await _pumpHome(tester);

    expect(find.byKey(const ValueKey('home-map-locating')), findsNothing);
    expect(find.byType(GoogleMap), findsWidgets);
    expect(
      tester
          .widgetList<GoogleMap>(find.byType(GoogleMap))
          .any(
            (map) =>
                map.markers.any((m) => m.markerId.value == 'driver_location'),
          ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'French driver, no saved position: opens at the FR zone centre, not '
    'Stockholm',
    (tester) async {
      // Rule: Sweden AND France (and Tunisia). Fallback order: saved
      // position, working zone centre, country centre, Stockholm last.
      SharedPreferences.setMockInitialValues({
        PrefsDriverZonesCache.key: jsonEncode({
          'zones': [
            {
              'zoneId': 'paris',
              'country': 'FR',
              'polygon': [
                [48.80, 2.20],
                [48.80, 2.50],
                [48.92, 2.50],
                [48.92, 2.20],
              ],
            },
          ],
        }),
        PrefsDriverConfigCache.key: jsonEncode({'zoneId': 'paris'}),
      });
      await StartCountryHints.load();
      await _pumpHome(tester);

      final maps = tester.widgetList<GoogleMap>(find.byType(GoogleMap));
      expect(maps, isNotEmpty);
      for (final map in maps) {
        final target = map.initialCameraPosition.target;
        expect(target.latitude, closeTo(48.86, 0.001));
        expect(target.longitude, closeTo(2.35, 0.001));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('map shown first, GPS later: the camera moves to the driver', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final maps = GoogleMapsFlutterPlatform.instance;
    final recording = _RecordingMaps();
    GoogleMapsFlutterPlatform.instance = recording;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gps = _WaitingGps();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) =>
            MaterialApp(home: DriverHome(locationRepository: gps)),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(GoogleMap), findsWidgets);
    gps._fix.complete(
      DriverLocation(
        point: const GeoPoint(59.6519, 17.9186),
        measuredAt: DateTime.now(),
        accuracyMeters: 10,
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      recording.moves.any((m) => m.contains('59.65')),
      isTrue,
      reason: recording.moves.join('\n'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'map shown first, rough Wi-Fi fix later (laptop): the camera still moves',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final maps = GoogleMapsFlutterPlatform.instance;
      final recording = _RecordingMaps();
      GoogleMapsFlutterPlatform.instance = recording;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gps = _WaitingGps();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) =>
              MaterialApp(home: DriverHome(locationRepository: gps)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(GoogleMap), findsWidgets);
      gps._fix.complete(
        DriverLocation(
          point: const GeoPoint(59.6519, 17.9186),
          measuredAt: DateTime.now(),
          accuracyMeters: 800,
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        recording.moves.any((m) => m.contains('59.65')),
        isTrue,
        reason: recording.moves.join('\n'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
