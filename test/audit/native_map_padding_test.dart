import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// driver-77: on native the 75 % driving anchor is the GoogleMap padding.
/// The SDK keeps the camera target at the centre of the padded region, so
/// a padding change with no camera move shifts the map. Panning in guidance
/// (and the Recenter flight back) must not flip the padding.
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

EdgeInsets _padding(WidgetTester tester) =>
    tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap)).padding;

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

  testWidgets('a pan in guidance keeps the native map padding', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'padding-trip',
            locationRepository: _Loc(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final following = _padding(tester);
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    expect(
      map.cameraAnchor,
      .75,
      reason: 'the trip is in guidance, following the car',
    );

    map.onUserGesture!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      _padding(tester),
      following,
      reason: 'the pan must not shift the map under the finger',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
