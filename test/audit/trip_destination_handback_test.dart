// driver-u65: a destination set on the trip screen comes back to Home.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

class _Routes implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async => RoadRoute(
    points: [origin, destination],
    distanceMeters: origin.distanceMetersTo(destination),
    durationSeconds: 600,
  );
}

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

bool _homeHasDestination(WidgetTester tester) => tester
    .widget<CustomGoogleMap>(find.byType(CustomGoogleMap).first)
    .markers!
    .any((marker) => marker.markerId.value == 'destination_mode_target');

void main() {
  testWidgets('Home shows the destination the driver set during the trip',
      (tester) async {
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: true,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    DriverOfferRules.current = const DriverOfferRules(
      autoOffline: false,
      exclusiveWhileDriving: false,
    );
    addTearDown(() => DriverOfferRules.current = const DriverOfferRules());
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    WaybillStore.reset();
    DestinationModeSession.instance = DestinationModeSession();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final homeLocation = _Loc(), tripLocation = _Loc();
    final routes = _Routes();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [driverRouteObserver],
        home: DriverHome(
          locationRepository: homeLocation,
          routeRepository: routes,
        ),
      ),
    ));
    await _frames(tester, 20);
    expect(_homeHasDestination(tester), isFalse);

    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => AcceptRide(
        initialStage: ActiveRideStage.onTrip,
        locationRepository: tripLocation,
        routeRepository: routes,
      ),
    )));
    await _frames(tester, 20);
    tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland)).onSearch();
    await _frames(tester, 12);
    await tester.tap(
        find.byKey(const ValueKey<String>('destination-result-solna')));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const ValueKey<String>('destination-confirm')));
    await _frames(tester, 10);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(DestinationModeSession.instance.usedToday(), 1);

    // The trip ends and Home is visible again.
    navigator.currentState!.pop();
    await _frames(tester, 20, 100);
    expect(find.byType(AcceptRide), findsNothing);
    expect(_homeHasDestination(tester), isTrue,
        reason: 'the destination counted today is the one Home follows');
    expect(DestinationModeSession.instance.usedToday(), 1,
        reason: 'taking it over is not a second use');

    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
    await homeLocation.updates.close();
    await tripLocation.updates.close();
  });
}
