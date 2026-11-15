// G19 (s06:1078, BrowserStack 2026-11-12 run 1 + run 2): the driver's
// navigation banner stood at "Partez maintenant · 0%" for the whole trip
// while the GPS moved. This feeds real fixes along the road route to the
// trip screen and reads the banner's percent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

const _start = GeoPoint(59.3416, 18.0649);

class _Gps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: _start,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// A straight road from the asked origin to the destination.
class _Routes implements RouteRepository {
  GeoPoint? destination;
  final origins = <GeoPoint>[];
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    origins.add(origin);
    this.destination = destination;
    final points = [
      for (var i = 0; i <= 20; i++)
        GeoPoint(
          origin.latitude + (destination.latitude - origin.latitude) * i / 20,
          origin.longitude +
              (destination.longitude - origin.longitude) * i / 20,
        ),
    ];
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += points[i - 1].distanceMetersTo(points[i]);
    }
    return RoadRoute(
      points: points,
      distanceMeters: length,
      durationSeconds: length / 10,
    );
  }
}

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

int? _percent(WidgetTester tester) {
  final strip = find.byKey(const ValueKey('strip-eta'));
  if (strip.evaluate().isEmpty) return null;
  for (final w in tester.widgetList<Text>(
    find.descendant(of: strip, matching: find.byType(Text)),
  )) {
    final m = RegExp(r'^(\d+)%$').firstMatch(w.data ?? '');
    if (m != null) return int.parse(m.group(1)!);
  }
  return null;
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: true,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  for (final (stage, streamError) in [
    (ActiveRideStage.headingToPickup, false),
    (ActiveRideStage.onTrip, false),
    // G-S9: the phone's GPS stream reported an error at the start
    // (the WAKE_LOCK SecurityException); later fixes must still count.
    (ActiveRideStage.onTrip, true),
  ]) {
    testWidgets('G19: banner percent follows GPS progress '
        '(${stage.name}${streamError ? ', after a stream error' : ''})', (
      tester,
    ) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gps = _Gps();
      final routes = _Routes();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: AcceptRide(
              tripId: 'g19-trip-${stage.name}',
              initialStage: stage,
              locationRepository: gps,
              routeRepository: routes,
            ),
          ),
        ),
      );
      await _frames(tester, 40);
      final dest = routes.destination!;
      final first = routes.origins.first;
      final seen = <int?>[_percent(tester)];
      expect(seen.first, 0, reason: 'at the start nothing is driven yet');
      if (streamError) {
        gps.updates.addError(StateError('location service failed'));
        await _frames(tester, 4);
      }
      // Drive along the road at ~15 m/s, one fix a second, to 60 %.
      for (var step = 1; step <= 12; step++) {
        final f = step / 20;
        gps.updates.add(
          DriverLocation(
            point: GeoPoint(
              first.latitude + (dest.latitude - first.latitude) * f,
              first.longitude + (dest.longitude - first.longitude) * f,
            ),
            measuredAt: DateTime.now(),
            accuracyMeters: 5,
            speedMetersPerSecond: 15,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await _frames(tester, 4);
        seen.add(_percent(tester));
      }
      // ignore: avoid_print
      print('G19 ${stage.name} error=$streamError percents: $seen');
      expect(seen.last, isNotNull, reason: 'the banner shows a percent');
      expect(
        seen.last!,
        greaterThanOrEqualTo(40),
        reason:
            'driven 60 % of the road; the banner must follow, not stay at 0 %',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
      await gps.updates.close();
    });
  }
}
