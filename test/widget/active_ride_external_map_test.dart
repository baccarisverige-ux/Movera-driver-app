import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Location implements DriverLocationRepository {
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

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'active ride catches Maps launch failure, locks repeated taps and permits retry',
    (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      final config = DriverRuntimeConfig.current;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: false,
        externalRouting: false,
        skipAccountActivation: false,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
      );
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        GoogleMapsFlutterPlatform.instance = original;
        DriverRuntimeConfig.current = config;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var calls = 0;
      final pending = Completer<bool>();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(
              locationRepository: _Location(),
              launchExternalMap: (uri) {
                expect(uri.host, 'www.google.com');
                calls++;
                return calls == 1 ? pending.future : Future.value(true);
              },
            ),
          ),
        ),
      );
      await _frames(tester);
      final launch = tester
          .widget<MapControlButton>(
            find.byKey(const ValueKey<String>('active-ride-navigation-button')),
          )
          .onTap;
      launch();
      launch();
      expect(calls, 1);
      pending.completeError(StateError('Maps unavailable'));
      await _frames(tester);
      expect(find.text('Google Maps is unavailable.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      launch();
      await _frames(tester);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      await _frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
