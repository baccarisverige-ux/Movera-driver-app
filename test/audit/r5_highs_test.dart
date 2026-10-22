// Audit round 5, the high bugs (Wave 6b): routes over Home and the trip,
// the trip's GPS start, and a won Radar Match under a sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// GPS the test feeds by hand; [listening] says whether a screen
/// follows the stream.
class _Gps implements DriverLocationRepository {
  _Gps({this.firstFixFails = false});
  final bool firstFixFails;
  final updates = StreamController<DriverLocation>.broadcast();
  bool get listening => updates.hasListener;
  @override
  Future<DriverLocation> getCurrentPosition() async {
    if (firstFixFails) throw TimeoutException('no first fix');
    return at(0);
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// [meters] north of Stockholm Central, driving north.
DriverLocation at(double meters) => DriverLocation(
      point: GeoPoint(59.3300 + meters / 111000, 18.0600),
      speedMetersPerSecond: 10,
      measuredAt: DateTime.now(),
      accuracyMeters: 5,
    );

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void _setUp(WidgetTester tester, {GoogleMapsFlutterPlatform? map}) {
  SharedPreferences.setMockInitialValues({});
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = map ?? HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  final config = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = const DriverRuntimeConfig(
    externalRouting: false,
    liveMapTicker: false,
    reservationPopup: false,
    islandHint: false,
    radarSound: false,
    simulatedArrival: true,
    skipAccountActivation: true,
  );
  addTearDown(() => DriverRuntimeConfig.current = config);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<GlobalKey<NavigatorState>> _pumpApp(
    WidgetTester tester, Widget home) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [driverRouteObserver],
      home: home,
    ),
  ));
  await _frames(tester, 20);
  return navigator;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester, 10, 100);
}

void main() {
  testWidgets('driver-r5-28: the trip and the side menu pause Home; a sheet '
      'does not', (tester) async {
    _setUp(tester);
    final homeGps = _Gps(), tripGps = _Gps();
    addTearDown(homeGps.updates.close);
    addTearDown(tripGps.updates.close);
    final navigator = await _pumpApp(
        tester, DriverHome(locationRepository: homeGps));
    expect(homeGps.listening, isTrue);

    // A sheet leaves Home visible and following GPS (driver-r4-31).
    final home = tester.element(find.byType(DriverHome));
    unawaited(showModalBottomSheet<void>(
        context: home, builder: (_) => const Text('sheet')));
    await _frames(tester, 10);
    expect(homeGps.listening, isTrue);
    navigator.currentState!.pop();
    await _frames(tester, 10);

    // The trip opens with the route the app uses: Home pauses under it.
    unawaited(navigator.currentState!.push(ActiveRideTransition(AcceptRide(
      initialStage: ActiveRideStage.onTrip,
      locationRepository: tripGps,
    ))));
    await _frames(tester, 20);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(homeGps.listening, isFalse,
        reason: 'one GPS stream during the trip, the trip\'s');
    navigator.currentState!.pop();
    await _frames(tester, 20);
    expect(homeGps.listening, isTrue, reason: 'Home resumes after the trip');

    // A side-menu page covers Home the same way.
    tester.state<ScaffoldState>(find.byWidgetPredicate(
        (w) => w is Scaffold && w.drawer != null)).openDrawer();
    await _frames(tester, 10);
    await tester.tap(find.text('Promotions'));
    await _frames(tester, 10);
    expect(find.byType(Promotions), findsOneWidget);
    expect(homeGps.listening, isFalse);
    navigator.currentState!.pop();
    await _frames(tester, 10);
    expect(homeGps.listening, isTrue);
    await _unmount(tester);
  });

  testWidgets('driver-r5-15: a failed first GPS fix still follows the GPS '
      'stream on the trip', (tester) async {
    _setUp(tester);
    final gps = _Gps(firstFixFails: true);
    addTearDown(gps.updates.close);
    await _pumpApp(tester, AcceptRide(
      initialStage: ActiveRideStage.onTrip,
      locationRepository: gps,
    ));
    expect(gps.listening, isTrue,
        reason: 'before: no subscription until the app went to the background');
    await _unmount(tester);
  });
}
