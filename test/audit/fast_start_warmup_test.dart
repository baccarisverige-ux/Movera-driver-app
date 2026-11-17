import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/location/driver_start_warmup.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner REMINDERS 144/145 (fast start behind the intro): the position
/// read starts when the app starts, before Home, and Home reuses it.

class _CountingGps implements DriverLocationRepository {
  int reads = 0;
  final _updates = StreamController<DriverLocation>.broadcast();

  @override
  Future<DriverLocation> getCurrentPosition() {
    reads++;
    return Completer<DriverLocation>().future;
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _updates.stream;
}

const _fix = DriverLocation(point: GeoPoint(59.6519, 17.9186));

void main() {
  setUp(() {
    DriverStartWarmup.resetForTesting();
    DriverStartPosition.clearMemory();
    SharedPreferences.setMockInitialValues({});
  });

  test('signed in and allowed: one position read starts at app start', () async {
    var reads = 0;
    await DriverStartWarmup.start(
      signedIn: () async => true,
      allowedWithoutAsking: () async => true,
      read: () async {
        reads++;
        return _fix;
      },
    );
    expect(reads, 1);
    final warm = DriverStartWarmup.take();
    expect(warm, isNotNull);
    expect((await warm!).point, _fix.point);
    // Taken once: a later Home read asks the GPS itself.
    expect(DriverStartWarmup.take(), isNull);
  });

  test('not signed in: no permission check and no location read', () async {
    var checks = 0, reads = 0;
    await DriverStartWarmup.start(
      signedIn: () async => false,
      allowedWithoutAsking: () async {
        checks++;
        return true;
      },
      read: () async {
        reads++;
        return _fix;
      },
    );
    expect(checks, 0);
    expect(reads, 0);
    expect(DriverStartWarmup.take(), isNull);
  });

  test('permission not given yet: nothing read, Home keeps the Allow flow',
      () async {
    var reads = 0;
    await DriverStartWarmup.start(
      signedIn: () async => true,
      allowedWithoutAsking: () async => false,
      read: () async {
        reads++;
        return _fix;
      },
    );
    expect(reads, 0);
    expect(DriverStartWarmup.take(), isNull);
  });

  test('a failed warm read never throws at start', () async {
    await DriverStartWarmup.start(
      signedIn: () async => true,
      allowedWithoutAsking: () async => true,
      read: () async => throw TimeoutException('gps'),
    );
    final warm = DriverStartWarmup.take();
    expect(warm, isNotNull);
    await expectLater(warm!, throwsA(isA<TimeoutException>()));
  });

  testWidgets('Home reuses the warm read: the GPS is asked once in total', (
    tester,
  ) async {
    var warmReads = 0;
    await DriverStartWarmup.start(
      signedIn: () async => true,
      allowedWithoutAsking: () async => true,
      read: () {
        warmReads++;
        return Completer<DriverLocation>().future;
      },
    );
    final gps = _CountingGps();
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
            MaterialApp(home: DriverHome(locationRepository: gps)),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(warmReads, 1);
    expect(gps.reads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
