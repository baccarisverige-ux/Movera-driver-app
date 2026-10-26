// D-02: destination mode on Home must not ask for a road route on every
// GPS fix while the driver follows that route.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loc implements DriverLocationRepository {
  _Loc(this.first);
  final DriverLocation first;
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => first;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// A straight road from where the car asked to the destination.
class _Routes implements RouteRepository {
  int calls = 0;
  GeoPoint? from, to;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    from ??= origin;
    to = destination;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return RoadRoute(
      points: [origin, destination],
      distanceMeters: origin.distanceMetersTo(destination),
      durationSeconds: 600,
    );
  }
}

void main() {
  testWidgets('following the destination route sends no route per fix', (
    tester,
  ) async {
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
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    const start = GeoPoint(59.3326, 18.0649);
    final location = _Loc(
      DriverLocation(
        point: start,
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ),
    );
    final routes = _Routes();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            locationRepository: location,
            routeRepository: routes,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('destination-mode-open')),
        )
        .onTap!
        .call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.tap(
      find.byKey(const ValueKey<String>('destination-result-solna')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await tester.tap(find.byKey(const ValueKey<String>('destination-confirm')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(routes.calls, greaterThanOrEqualTo(1));
    final from = routes.from!, to = routes.to!;
    final length = from.distanceMetersTo(to);
    GeoPoint along(double m) => GeoPoint(
      from.latitude + (to.latitude - from.latitude) * m / length,
      from.longitude + (to.longitude - from.longitude) * m / length,
    );
    final before = routes.calls;
    var mapBuilds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget is CustomGoogleMap) mapBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    const fixes = 60;
    for (var i = 1; i <= fixes; i++) {
      location.updates.add(
        DriverLocation(
          point: along(i * 10.0),
          headingDegrees: 0,
          speedMetersPerSecond: 10,
          measuredAt: DateTime.now(),
          accuracyMeters: 5,
        ),
      );
      for (var f = 0; f < 10; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    debugOnRebuildDirtyWidget = null;
    // Before: one road-route request per fix (60) and 136 map builds.
    expect(routes.calls - before, 0);
    expect(mapBuilds, lessThan(fixes * 2));
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await location.updates.close();
  });
}
