import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/history/trip_path.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// B16 (2026-11-04): the driver maps never ask Google for the traffic
/// layer. Replaces the source-reading `trafficEnabled` guard (archived in
/// Rules/archive/old-tests/Movera-driver-app/) by building the maps.
void main() {
  setUp(() {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
  });

  void expectNoTraffic(WidgetTester tester) {
    final maps = tester.widgetList<GoogleMap>(
      find.byType(GoogleMap, skipOffstage: false),
    );
    expect(maps, isNotEmpty);
    for (final map in maps) {
      expect(map.trafficEnabled, isFalse);
    }
  }

  final variants = <String, CustomGoogleMap Function()>{
    'defaults': () => const CustomGoogleMap(myLocationEnabled: false),
    'every option on': () => const CustomGoogleMap(
      myLocationEnabled: false,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      compassEnabled: true,
      buildingsEnabled: true,
      indoorViewEnabled: true,
      mapType: MapType.hybrid,
    ),
    'gestures off': () => const CustomGoogleMap(
      myLocationEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    ),
  };

  variants.forEach((name, build) {
    testWidgets('CustomGoogleMap ($name) keeps the traffic layer off', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: build())));
      await tester.pump();
      expectNoTraffic(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the past-ride map keeps the traffic layer off', (tester) async {
    const pickup = GeoPoint(59.1955, 17.6253);
    const dropoff = GeoPoint(59.1960, 17.6268);
    final record = TripHistoryRecord(
      tripId: 'trp_b16',
      riderName: 'Stored rider',
      whenLabel: '29/10/2026, 12:50',
      pickup: 'Klockarvägen 37',
      dropoff: 'Södertälje centrum',
      fare: '68,64 kr',
      paymentMethod: 'Cash',
      category: 'Premium',
      status: TripStatus.completed,
      completedAt: DateTime(2026, 10, 29, 12, 50),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: record,
            loadPath: (_) async => const TripPath(
              source: TripPathSource.driven,
              points: [pickup, dropoff],
              pickup: pickup,
              dropoff: dropoff,
            ),
            loadRideChecks: (_) async => const [],
            loadTip: (_) async => null,
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CustomGoogleMap), findsWidgets);
    expectNoTraffic(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  for (final (name, screen) in [
    ('Settings', const Settings()),
    ('Preferences', const Preferences()),
  ]) {
    testWidgets('$name offers no traffic-layer switch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(home: screen),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.textContaining(RegExp('traffic', caseSensitive: false)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
