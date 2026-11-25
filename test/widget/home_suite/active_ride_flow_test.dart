// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets(
    'Matched ride flow moves safely through pickup, waiting and trip',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
      await tester.pump(const Duration(milliseconds: 160));

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
        findsWidgets,
      );
      await middleActiveRideSheet(tester);
      expect(find.text("I've arrived"), findsOneWidget);
      expect(find.text('Slide to confirm pickup'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
        findsOneWidget,
      );
      expectNoException(tester);

      await tapArrived(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
        findsWidgets,
      );
      expect(find.text('Start trip'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
        findsOneWidget,
      );
      expectNoException(tester);

      await slideActiveRideAction(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
        findsOneWidget,
      );
      expect(find.text('Complete trip'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
        findsOneWidget,
      );
      expectNoException(tester);

      await slideActiveRideAction(tester);
      await confirmShortTripIfAsked(tester);

      expect(find.byType(DriverRideCompleted), findsOneWidget);
      expectNoException(tester);
    },
  );

  testWidgets(
    'Active ride stages keep the same map, panel and ride State mounted',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
      await tester.pump(const Duration(milliseconds: 160));

      final rideState = tester.state(find.byType(AcceptRide));
      final mapElement = tester.element(
        find.byKey(const ValueKey<String>('active-ride-map')),
      );
      final panelElement = tester.element(
        find.byKey(const ValueKey<String>('active-ride-panel')),
      );
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(find.byType(CustomGoogleMap), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
        findsWidgets,
      );

      await tapArrived(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
        findsWidgets,
      );
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(find.byType(CustomGoogleMap), findsOneWidget);
      expect(
        identical(rideState, tester.state(find.byType(AcceptRide))),
        isTrue,
      );
      expect(
        identical(
          mapElement,
          tester.element(find.byKey(const ValueKey<String>('active-ride-map'))),
        ),
        isTrue,
      );
      expect(
        identical(
          panelElement,
          tester.element(
            find.byKey(const ValueKey<String>('active-ride-panel')),
          ),
        ),
        isTrue,
      );
      // Arriving is a button; the slide action starts with the trip.
      final slideElement = tester.element(
        find.byKey(const ValueKey<String>('active-ride-slide-action')),
      );
      expectNoException(tester);

      await slideActiveRideAction(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
        findsOneWidget,
      );
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(find.byType(DriverRideCompleted), findsNothing);
      expect(
        identical(rideState, tester.state(find.byType(AcceptRide))),
        isTrue,
      );
      expect(
        identical(
          mapElement,
          tester.element(find.byKey(const ValueKey<String>('active-ride-map'))),
        ),
        isTrue,
      );
      expect(
        identical(
          panelElement,
          tester.element(
            find.byKey(const ValueKey<String>('active-ride-panel')),
          ),
        ),
        isTrue,
      );
      expect(
        identical(
          slideElement,
          tester.element(
            find.byKey(const ValueKey<String>('active-ride-slide-action')),
          ),
        ),
        isTrue,
      );
      expectNoException(tester);
    },
  );

  testWidgets('Completing a trip returns home with radar online', (
    WidgetTester tester,
  ) async {
    WaybillStore.reset();
    addTearDown(() {
      WaybillStore.reset();
      tester.binding.setSurfaceSize(null);
    });

    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    // The grey orb on the Exclusive sheet is its Accept, once it is up.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const ValueKey<String>('home-radar-exclusive')),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 520));

    expect(find.byType(AcceptRide), findsOneWidget);

    await tapArrived(tester);
    await slideActiveRideAction(tester);
    await slideActiveRideAction(tester);
    await confirmShortTripIfAsked(tester);

    expect(find.byType(DriverRideCompleted), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 420));
    // The radar's last face change finishes its fade on the next frame.
    await tester.pump();

    // R13-5: Done goes back to Home online, the radar scanning.
    expect(find.byType(DriverHome), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('OFF'), findsNothing);
    expect(find.text('Go offline'), findsNothing);
    await openPanel(tester);
    final lastWaybill = find.byKey(
      const ValueKey<String>('home-sheet-last-waybill'),
    );
    await tester.ensureVisible(lastWaybill);
    expect(lastWaybill, findsOneWidget);
    expect(find.text('None yet'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Active ride blocks system back so the trip does not snap Home', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    final popScope = tester.allWidgets.firstWhere(
      (widget) => widget.runtimeType.toString().startsWith('PopScope'),
    );
    expect((popScope as dynamic).canPop, isFalse);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
      findsWidgets,
    );
    expectNoException(tester);
  });

  testWidgets('On-trip Radar stays hidden until a near-dropoff offer exists', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await tapArrived(tester);
    await slideActiveRideAction(tester);

    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-sheet')),
      findsNothing,
    );
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 2400));

    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-button')),
      findsOneWidget,
    );
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-sheet')),
      findsNothing,
    );
    expect(find.text('Available after your current drop-off'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('on-trip-radar-deny')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('Active ride slide blocks map pan while the finger is down', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      const MaterialApp(
        home: AcceptRide(initialStage: ActiveRideStage.waitingForRider),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    await middleActiveRideSheet(tester);
    expect(find.byType(PointerInterceptor), findsWidgets);
    CustomGoogleMap map = tester.widget<CustomGoogleMap>(
      find.byType(CustomGoogleMap),
    );
    expect(map.scrollGesturesEnabled, isTrue);

    final action = find.byKey(
      const ValueKey<String>('active-ride-primary-action'),
    );
    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump();

    map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    expect(map.scrollGesturesEnabled, isFalse);

    await gesture.up();
    await tester.pump();
    expectNoException(tester);
  });

  testWidgets('On-trip Radar demo appears toward a city drop-off', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      const MaterialApp(
        home: AcceptRide(
          pickupPosition: LatLng(59.3295, 18.0475),
          dropoffPosition: LatLng(59.2705, 18.0515),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    await tapArrived(tester);
    await slideActiveRideAction(tester);
    await tester.pump(const Duration(milliseconds: 2400));

    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-button')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets(
    'Secured next trip stays inside current ride panel and exposes waybill',
    (WidgetTester tester) async {
      WaybillStore.reset();
      addTearDown(() {
        WaybillStore.reset();
        tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        const MaterialApp(
          home: AcceptRide(fare: '156,80 kr', category: 'Comfort'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));

      await tapArrived(tester);

      await slideActiveRideAction(tester);

      await tester.pump(const Duration(milliseconds: 2400));

      final matchNext = find.byKey(
        const ValueKey<String>('on-trip-radar-match-next'),
      );
      await tester.ensureVisible(matchNext);
      await tester.tap(matchNext);
      await tester.pump(const Duration(milliseconds: 1600));
      await expandActiveRideSheet(tester);

      expect(
        find.byKey(const ValueKey<String>('secured-next-trip-details')),
        findsOneWidget,
      );
      expect(find.text('Next trip secured'), findsWidgets);
      expect(find.text('Vasagatan 10, Stockholm'), findsOneWidget);
      expect(find.text('Södermalm, Stockholm'), findsOneWidget);
      expect(WaybillStore.next, isNotNull);
      expectNoException(tester);

      final waybillButton = find.byKey(
        const ValueKey<String>('next-trip-waybill'),
      );
      await tester.ensureVisible(waybillButton);
      await tester.tap(waybillButton);
      await tester.pump(const Duration(milliseconds: 320));

      expect(
        find.byKey(ValueKey<String>('waybill-${WaybillStore.next!.tripId}')),
        findsOneWidget,
      );
      expect(find.text('Next trip waybill'), findsOneWidget);
      // While driving a rider only Exclusive offers come (Q18).
      expect(find.text('Exclusive offer'), findsOneWidget);
      expectNoException(tester);
    },
  );

  testWidgets(
    'Secured next trip starts after the current drop-off is completed',
    (WidgetTester tester) async {
      WaybillStore.reset();
      addTearDown(() {
        WaybillStore.reset();
        tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        const MaterialApp(
          home: AcceptRide(fare: '156,80 kr', category: 'Comfort'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));

      await tapArrived(tester);
      await slideActiveRideAction(tester);
      await tester.pump(const Duration(milliseconds: 2400));

      final matchNext = find.byKey(
        const ValueKey<String>('on-trip-radar-match-next'),
      );
      await tester.ensureVisible(matchNext);
      await tester.tap(matchNext);
      await tester.pump(const Duration(milliseconds: 1600));
      await expandActiveRideSheet(tester);

      expect(find.text('Next trip secured'), findsWidgets);

      await middleActiveRideSheet(tester);
      await slideActiveRideAction(tester);
      await confirmShortTripIfAsked(tester);
      expect(find.byType(DriverRideCompleted), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 520));
      // One more frame: the new trip lifts its sheet to the middle.
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(AcceptRide), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
        findsWidgets,
      );
      // The compact header now names the journey stage, not the passenger.
      // Verify the actual handoff identity before opening its rider details.
      expect(
        tester.widget<AcceptRide>(find.byType(AcceptRide)).riderName,
        'Maya',
      );
      await middleActiveRideSheet(tester);
      expect(find.textContaining('Maya'), findsWidgets);
      await expandActiveRideSheet(tester);
      expect(find.textContaining('Vasagatan 10'), findsWidgets);
      expectNoException(tester);
    },
  );

  testWidgets(
    'Completed screen clears a stale queued waybill without a nextRide widget',
    (WidgetTester tester) async {
      WaybillStore.reset();
      addTearDown(() {
        WaybillStore.reset();
        tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(375, 812));

      WaybillStore.last = WaybillRecord(
        tripId: 'finished-1',
        statusLabel: 'Completed',
        issuedAt: DateTime(2026, 9, 21, 12),
        fare: '104,80 kr',
        service: 'Comfort',
        riderName: 'Angelica',
        pickup: 'Odlarvägen 22',
        dropoff: 'T-Centralen, Stockholm',
        source: 'Movera Radar',
        driverName: 'Movera Driver',
        vehicle: 'Movera partner vehicle',
        licensePlate: 'MVR 418',
        passengerCapacity: 4,
      );
      WaybillStore.secureNext(
        WaybillRecord(
          tripId: 'queued-1',
          statusLabel: 'Next trip secured',
          issuedAt: DateTime(2026, 9, 21, 12, 20),
          fare: '128,40 kr',
          service: 'Comfort',
          riderName: 'Maya',
          pickup: 'Vasagatan 10, Stockholm',
          dropoff: 'Södermalm, Stockholm',
          source: 'Movera Radar',
          driverName: 'Movera Driver',
          vehicle: 'Movera partner vehicle',
          licensePlate: 'MVR 418',
          passengerCapacity: 4,
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: DriverRideCompleted()));
      await tester.pump(const Duration(milliseconds: 160));

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 520));

      expect(find.byType(AcceptRide), findsNothing);
      expect(find.byType(DriverHome), findsOneWidget);
      expect(WaybillStore.next, isNull);
      expect(WaybillStore.current, isNull);
      expectNoException(tester);
    },
  );

  testWidgets(
    'Current trip waybill is directly visible in the active ride sheet',
    (WidgetTester tester) async {
      WaybillStore.reset();
      addTearDown(() {
        WaybillStore.reset();
        tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        const MaterialApp(
          home: AcceptRide(
            tripId: 'waybill-current-test',
            fare: '111,02 kr',
            category: 'Comfort',
            matchedVia: 'Movera Radar',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await expandActiveRideSheet(tester);

      final shortcut = find.byKey(
        const ValueKey<String>('current-waybill-shortcut'),
      );
      await tester.ensureVisible(shortcut);
      expect(shortcut, findsOneWidget);

      await tester.tap(shortcut);
      await tester.pump(const Duration(milliseconds: 320));

      expect(
        find.byKey(const ValueKey<String>('waybill-waybill-current-test')),
        findsOneWidget,
      );
      expect(find.text('Waybill'), findsWidgets);
      // The trip's fare is the driver's own money (owner decision
      // 2026-10-26): shown as the earnings, with no rider fare marked for
      // the taximeter and no Movera fee taken off it again.
      expect(find.text('111,02 kr*'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Your earnings'),
        200,
        scrollable: find.descendant(
          of: find.byKey(
            const ValueKey<String>('waybill-waybill-current-test'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('111,02 kr'), findsWidgets);
      expect(find.text('Movera fee'), findsNothing);
      expect(find.text('−27,76 kr'), findsNothing);
      expect(find.text('83,26 kr'), findsNothing);
      expectNoException(tester);
    },
  );
}
