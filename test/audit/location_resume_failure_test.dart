import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class _DelayedLocation implements DriverLocationRepository {
  final requests = <Completer<DriverLocation>>[];
  final updates = StreamController<DriverLocation>.broadcast();

  @override
  Future<DriverLocation> getCurrentPosition() {
    final request = Completer<DriverLocation>();
    requests.add(request);
    return request.future;
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

class _DelayedRoutes implements RouteRepository {
  final requests = <Completer<RoadRoute>>[];
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final response = Completer<RoadRoute>();
    requests.add(response);
    return response.future;
  }
}

DriverLocation _pickup() => DriverLocation(
  point: const GeoPoint(59.3279, 18.0615),
  measuredAt: DateTime.now(),
  accuracyMeters: 5,
);

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _mount(
  WidgetTester tester,
  _DelayedLocation location, {
  RouteRepository? routes,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(locationRepository: location, routeRepository: routes),
      ),
    ),
  );
  await _frames(tester);
  expect(location.requests, hasLength(1));
}

Future<void> _arrive(WidgetTester tester) async {
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
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
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

  for (final staleFailure in [true, false]) {
    testWidgets(
      'resumed pickup ignores old GPS ${staleFailure ? 'failure' : 'success'}',
      (tester) async {
        final location = _DelayedLocation();
        await _mount(tester, location);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await _frames(tester, 2);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _frames(tester, 2);
        expect(location.requests, hasLength(2));
        location.requests[1].complete(_pickup());
        await _frames(tester);
        if (staleFailure) {
          location.requests[0].completeError(
            StateError('Old GPS request failed'),
          );
        } else {
          location.requests[0].complete(
            DriverLocation(
              point: const GeoPoint(48.8566, 2.3522),
              measuredAt: DateTime.now(),
              accuracyMeters: 5,
            ),
          );
        }
        await _frames(tester);
        await _arrive(tester);
        expect(
          find.byKey(
            const ValueKey<String>('active-ride-panel-waitingForRider'),
          ),
          findsOneWidget,
          reason: 'The newer valid pickup fix must remain usable.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester, 2);
        await location.updates.close();
      },
    );
  }

  // driver-r4-32: the shade, a permission prompt or a call banner makes the
  // app inactive while the trip stays on screen.
  testWidgets('inactive keeps the trip GPS and arrival', (tester) async {
    final location = _DelayedLocation();
    await _mount(tester, location);
    location.requests.single.complete(_pickup());
    await _frames(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _frames(tester, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester, 2);
    expect(location.requests, hasLength(1), reason: 'no new one-shot fix');
    await _arrive(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
    await location.updates.close();
  });

  testWidgets('current GPS failure still blocks arrival', (tester) async {
    final location = _DelayedLocation();
    await _mount(tester, location);
    location.requests.single.completeError(StateError('Current GPS failed'));
    await _frames(tester);
    await _arrive(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsNothing,
    );
    expect(
      find.text('Location unavailable. Enable location to confirm arrival.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
    await location.updates.close();
  });
  testWidgets('a pending road route does not block fresh GPS arrival', (
    tester,
  ) async {
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: true,
      skipAccountActivation: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
    final location = _DelayedLocation();
    final routes = _DelayedRoutes();
    await _mount(tester, location, routes: routes);
    location.requests.single.complete(
      DriverLocation(
        point: const GeoPoint(59.32, 18.05),
        // Measured a while ago, so driving on to the pickup is plausible.
        measuredAt: DateTime.now().subtract(const Duration(seconds: 25)),
        accuracyMeters: 5,
      ),
    );
    await _frames(tester);
    expect(routes.requests, isNotEmpty);
    location.updates.add(_pickup());
    await _frames(tester);
    await _arrive(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsOneWidget,
      reason: 'GPS updates must not wait for road routing.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    for (final request in routes.requests) {
      if (!request.isCompleted) {
        request.completeError(StateError('Route disposed'));
      }
    }
    await _frames(tester, 2);
    expect(tester.takeException(), isNull);
    await location.updates.close();
  });
}
