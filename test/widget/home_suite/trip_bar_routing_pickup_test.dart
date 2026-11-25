// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'dart:async';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Rider row messages the rider in one tap', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => const MaterialApp(home: AcceptRide()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    await middleActiveRideSheet(tester);
    // Middle sheet: call on the left, message on the right.
    expect(find.byTooltip('Call rider'), findsOneWidget);
    await tester.tap(find.byTooltip('Message rider'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(Chat), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Collapsed trip bar opens Ride preferences and trip details', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await collapseActiveRideSheet(tester);
    final dock = find.byKey(const ValueKey<String>('active-ride-compact-dock'));
    expect(dock, findsOneWidget);

    // Demo arrival is always in range, so the arrived pill takes the
    // details slot; the middle of the bar opens the details too.
    expect(
      find.descendant(
        of: dock,
        matching: find.byKey(
          const ValueKey<String>('active-ride-arrived-button'),
        ),
      ),
      findsNothing,
    );
    // Tapping the bar lifts it to the middle sheet with the action.
    await tester.tap(
      find.byKey(const ValueKey<String>('trip-bar-next-address')),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(dock, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('active-ride-arrived-button')),
      findsOneWidget,
    );
    // No details button: tapping the middle sheet's header opens the full
    // trip details.
    expect(find.byTooltip('Trip details'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('trip-bar-details')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.byKey(const ValueKey<String>('active-ride-current-trip-card')),
      findsOneWidget,
    );

    // The trip settings live on the lifted sheet (G5: the trip settings,
    // not the car types).
    await middleActiveRideSheet(tester);
    await tester.tap(find.byTooltip('Trip settings'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(TripSettings), findsOneWidget);
    expectNoException(tester);
  });

  for (final seconds in [30, 150, 330]) {
    testWidgets('Trip sheet excludes the waiting clock at ${seconds}s', (
      WidgetTester tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        MaterialApp(
          home: AcceptRide(
            initialStage: ActiveRideStage.waitingForRider,
            initialWaitSeconds: seconds,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await collapseActiveRideSheet(tester);
      final dock = find.byKey(
        const ValueKey<String>('active-ride-compact-dock'),
      );
      expect(
        find.descendant(
          of: dock,
          matching: find.byKey(const ValueKey('trip-sheet-next-point-eta')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: dock, matching: find.textContaining('Waiting for')),
        findsOneWidget,
      );
      await expandActiveRideSheet(tester);
      expect(
        find.byKey(const ValueKey<String>('active-ride-wait-phase')),
        findsOneWidget,
      );
      expectNoException(tester);
    });
  }

  testWidgets('Map gestures keep the collapsed trip sheet visible', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));
    await collapseActiveRideSheet(tester);
    final dock = find.byKey(const ValueKey<String>('active-ride-compact-dock'));
    double dockTop() => tester.getTopLeft(dock).dy;
    final shown = dockTop();
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    const camera = CameraPosition(target: LatLng(59.33, 18.06), zoom: 15);

    // A camera move nobody touched (the app's own follow) changes nothing.
    map.onCameraMove!(camera);
    await advanceAnimation(tester, const Duration(milliseconds: 600));
    expect(dockTop(), closeTo(shown, 1));

    // One finger only moves the map: the sheet stays.
    final drag = await tester.startGesture(const Offset(120, 400));
    map.onCameraMove!(camera);
    await drag.moveBy(const Offset(0, 40));
    await drag.up();
    await advanceAnimation(tester, const Duration(milliseconds: 600));
    expect(dockTop(), closeTo(shown, 1));

    // Two fingers zoom: the sheet slides away, recenter pulses.
    final a = await tester.startGesture(const Offset(120, 400), pointer: 7);
    final b = await tester.startGesture(const Offset(220, 400), pointer: 8);
    await a.moveBy(const Offset(-30, 0));
    await b.moveBy(const Offset(30, 0));
    map.onCameraMove!(camera);
    await a.up();
    await b.up();
    await advanceAnimation(tester, const Duration(milliseconds: 600));
    expect(dockTop(), closeTo(shown, 1));

    // It stays away until recenter, however long the driver looks.
    await tester.pump(const Duration(seconds: 15));
    expect(dockTop(), closeTo(shown, 1));
    expect(
      find.byKey(const ValueKey<String>('active-ride-recenter-pulse')),
      findsOneWidget,
    );

    // Recenter: following again and the sheet comes back, even when the
    // map reports its own camera move afterwards.
    await tester.tap(
      find.byKey(const ValueKey<String>('active-ride-recenter-button')),
    );
    map.onCameraMove!(camera);
    await advanceAnimation(tester, const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dockTop(), closeTo(shown, 1));
    expect(
      find.byKey(const ValueKey<String>('active-ride-recenter-pulse')),
      findsNothing,
    );
    expectNoException(tester);
  });

  testWidgets('Routing failure keeps the driver on the active trip', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    // Routing is on here, so the trip asks the failing repository.
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = DriverRuntimeConfig(
      simulatedArrival: previous.simulatedArrival,
      externalRouting: true,
      skipAccountActivation: previous.skipAccountActivation,
      liveMapTicker: previous.liveMapTicker,
      reservationPopup: previous.reservationPopup,
      islandHint: previous.islandHint,
      radarSound: previous.radarSound,
      adminDemoOffers: previous.adminDemoOffers,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    final routes = _FailingRouteRepository();
    final location = _FixedLocation();
    addTearDown(location.updates.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AcceptRide(routeRepository: routes, locationRepository: location),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));
    location.updates.add(location.fix());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(routes.calls, greaterThan(0));
    expect(find.textContaining('Route unavailable'), findsWidgets);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
      findsWidgets,
    );
    // No route to guide along: the island says so on its status face.
    expect(
      find.byKey(const ValueKey<String>('trip-status-island')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('On-trip ride appears on screen with accept and deny', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await tapArrived(tester);
    await slideActiveRideAction(tester);
    await tester.pump(const Duration(milliseconds: 2400));

    final ride = find.byKey(
      const ValueKey<String>('on-trip-radar-offer-button'),
    );
    expect(ride, findsOneWidget);
    expect(tester.getSize(ride).width, greaterThan(200));
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets(
    'Live navigation banner shows turn-by-turn copy at the extreme top',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NavigationInstructionBanner(
              banner: NavigationBanner(
                primary: 'Turn left in 300 m',
                distanceLabel: '300 m',
                roadName: 'Sveavägen',
                symbol: NavigationBannerSymbol.left,
              ),
              etaLabel: '4 min',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Turn left in 300 m'), findsOneWidget);
      expect(find.text('Sveavägen'), findsOneWidget);
      final banner = tester.getRect(
        find.byKey(const ValueKey<String>('active-ride-navigation-card')),
      );
      expect(banner.top, closeTo(0, 0.5));
      expect(banner.left, closeTo(0, 0.5));
      expect(banner.width, closeTo(375, 1));
      expectNoException(tester);
    },
  );
  testWidgets('Pickup slide names an arrival action', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text("I've arrived"), findsNothing);
    await middleActiveRideSheet(tester);
    expect(find.text("I've arrived"), findsOneWidget);
    // Arriving is a button, not a slide.
    expect(
      find.byKey(const ValueKey<String>('active-ride-arrived-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-ride-primary-action')),
      findsNothing,
    );
    expectNoException(tester);
  });

  testWidgets('A stop without coordinates cannot be marked arrived', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      const MaterialApp(
        home: AcceptRide(
          initialStage: ActiveRideStage.onTrip,
          stopAddresses: <String>['Unlocated stop'],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));
    await middleActiveRideSheet(tester);
    // v0.7.1: on the way to a middle stop the button is the stop's own.
    expect(find.text('Arrive at the stop'), findsOneWidget);
    await tapArrived(tester);
    expect(
      find.text('This stop needs a verified map location before arrival.'),
      findsOneWidget,
    );
    await middleActiveRideSheet(tester);
    // v0.7.1: on the way to a middle stop the button is the stop's own.
    expect(find.text('Arrive at the stop'), findsOneWidget);
    expectNoException(tester);
  });
}

class _FailingRouteRepository implements RouteRepository {
  var calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    calls++;
    throw Exception('offline');
  }
}

class _FixedLocation implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  DriverLocation fix() => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}
