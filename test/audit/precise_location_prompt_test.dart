import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

// driver-u24: with only approximate location allowed every fix fails the
// 50 m gate. The driver is told to turn on precise location, on Home and
// when Arrived is refused, instead of "Enable location".

const _precise =
    'Precise location is off. Turn it on in Settings to show '
    'your position and confirm arrival.';

class _ApproximateOnly implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();

  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw const PreciseLocationRequiredException();

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  testWidgets('driver-u24: Arrived refused for approximate location asks '
      'for precise location', (tester) async {
    final location = _ApproximateOnly();
    _phone(tester);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) =>
            MaterialApp(home: AcceptRide(locationRepository: location)),
      ),
    );
    await _frames(tester);
    ScaffoldMessenger.of(
      tester.element(find.byType(AcceptRide)),
    ).clearSnackBars();
    await _frames(tester, 4);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await _frames(tester, 16);
    final arrive = find.byKey(
      const ValueKey<String>('active-ride-arrived-button'),
    );
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await _frames(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsNothing,
    );
    expect(find.text(_precise), findsOneWidget);
    expect(
      find.text('Location unavailable. Enable location to confirm arrival.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
    await location.updates.close();
  });

  testWidgets('driver-u24: Home says precise location is off', (tester) async {
    final originalMaps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = originalMaps);
    final location = _ApproximateOnly();
    _phone(tester);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) =>
            MaterialApp(home: DriverHome(locationRepository: location)),
      ),
    );
    await _frames(tester);
    expect(find.text(_precise), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
    await location.updates.close();
  });
}
