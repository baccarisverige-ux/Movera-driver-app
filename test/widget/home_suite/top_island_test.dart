// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Top island opens small, then grows and turns its screen on', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final island = find.ancestor(
      of: find.byKey(const ValueKey<String>('last-trip-launcher')),
      matching: find.byType(DigitalIslandShell),
    );
    // Launch: only the arrow and the menu, no money display yet.
    expect(tester.getSize(island).width, lessThan(130));
    expect(find.text('•••• kr'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-mode-open')),
      findsOneWidget,
    );
    expect(find.byTooltip('Menu'), findsOneWidget);

    await wakeIsland(tester);
    expect(tester.getSize(island).width, closeTo(244, 1));
    expect(find.text('•••• kr'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Last trip shows updating dots until its money settles', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      WaybillStore.reset();
      tester.binding.setSurfaceSize(null);
    });
    WaybillStore.reset();
    // A trip that has just finished.
    WaybillStore.last = WaybillRecord(
      tripId: 'just-finished',
      statusLabel: 'Completed',
      issuedAt: DateTime.now(),
      fare: '156,80 kr',
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
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);

    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('last-trip-launcher')),
        )
        .onTap!
        .call();
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    final island = find.byKey(const ValueKey<String>('last-trip-launcher'));
    expect(find.text('UPDATING'), findsOneWidget);
    expect(
      find.descendant(of: island, matching: find.text('156,80 kr')),
      findsNothing,
    );

    // Once settled, the real fare of that trip appears.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('UPDATING'), findsNothing);
    expect(find.text('LAST TRIP'), findsOneWidget);
    expect(
      find.descendant(of: island, matching: find.text('156,80 kr')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('Going online: Radar online, then Finding trips after 2 s', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);

    await tester.tap(find.text('OFF'));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Radar online'), findsOneWidget);

    // R13-1: "Radar online" for 2 s, then "Finding trips" with its dots.
    await tester.pump(const Duration(milliseconds: 1600));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Radar online'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('island-finding')),
      findsOneWidget,
    );
    expect(find.text('Finding trips'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('island-finding-dots')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('Touching the island puts it back to normal at once', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 2200));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Finding trips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('last-trip-launcher')));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Finding trips'), findsNothing);
    // The tap only closed it: the money display is on its hidden total.
    expect(find.text('•••• kr'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('An offer clears the waiting messages from the island', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 2200));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Finding trips'), findsOneWidget);

    // The demo's Exclusive offer arrives: the island is itself again.
    await tester.pump(const Duration(milliseconds: 1500));
    await advanceAnimation(tester, const Duration(milliseconds: 900));
    expect(find.text('79,60 kr'), findsOneWidget);
    expect(find.text('Finding trips'), findsNothing);
    expect(find.byKey(const ValueKey<String>('island-finding')), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Island stretches sideways to fit a message, never taller', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(390, 844));
    await wakeIsland(tester);

    final island = find.ancestor(
      of: find.byKey(const ValueKey<String>('last-trip-launcher')),
      matching: find.byType(DigitalIslandShell),
    );
    final normal = tester.getSize(island);
    expect(normal.width, closeTo(244, 1));
    // Drawn at 80 %, content included.
    expect(tester.getRect(island).width, closeTo(244 * 0.8, 1));
    expect(tester.getRect(island).height, closeTo(50.4 * 0.8, 1));

    IslandMessages.show(const IslandMessage(title: 'Matched'));
    await advanceAnimation(tester, const Duration(milliseconds: 900));
    final short = tester.getSize(island);
    // Short words keep the normal size.
    expect(short.width, closeTo(244, 1));

    IslandMessages.reset();
    await tester.pump(const Duration(seconds: 4));
    IslandMessages.show(
      const IslandMessage(title: 'Weekly earnings statement ready'),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 900));
    final long = tester.getSize(island);

    expect(long.width, greaterThan(short.width));
    expect(long.width, lessThanOrEqualTo(normal.width * 1.15 + 0.001));
    expect(tester.getRect(island).width, lessThanOrEqualTo(390 - 32 + 1));
    // Only the length changes; the height is always the same.
    expect(short.height, normal.height);
    expect(long.height, normal.height);

    // And it goes back to the normal island afterwards.
    await tester.pump(const Duration(seconds: 3));
    await advanceAnimation(tester, const Duration(milliseconds: 900));
    expect(tester.getSize(island).width, closeTo(244, 1));
    expect(find.text('•••• kr'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Top island returns to the hidden total after 5 s untouched', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);

    final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
    Future<void> tap() async {
      tester.widget<InkWell>(launcher).onTap!.call();
      await advanceAnimation(tester, const Duration(milliseconds: 520));
    }

    await tap();
    expect(find.text('—'), findsOneWidget);
    // A tap restarts the 5 s: 4 s, tap, 4 s later it still shows today.
    await tester.pump(const Duration(seconds: 4));
    await tap();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('0,00 kr'), findsOneWidget);
    // Then 5 s without a touch brings back the hidden total.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('•••• kr'), findsOneWidget);
    expect(find.text('0,00 kr'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Top island arrow opens Destination and menu opens the drawer', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final arrow = find.byKey(const ValueKey<String>('destination-mode-open'));
    final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
    final menu = find.byTooltip('Menu');
    // Menu on the left, money in the middle, search arrow on the right.
    expect(tester.getCenter(menu).dx, lessThan(tester.getCenter(launcher).dx));
    expect(
      tester.getCenter(arrow).dx,
      greaterThan(tester.getCenter(launcher).dx),
    );

    await tester.tap(menu);
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.isDrawerOpen, isTrue);
    expectNoException(tester);
  });

  testWidgets('Holding the island opens Ride history straight away', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);

    await tester.longPress(
      find.byKey(const ValueKey<String>('last-trip-launcher')),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverRideHistory), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('First launch hint shows once and leads to the earnings', (
    WidgetTester tester,
  ) async {
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = DriverRuntimeConfig(
      simulatedArrival: previous.simulatedArrival,
      externalRouting: previous.externalRouting,
      skipAccountActivation: previous.skipAccountActivation,
      liveMapTicker: previous.liveMapTicker,
      reservationPopup: previous.reservationPopup,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});

    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tap to see earnings'), findsOneWidget);

    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('last-trip-launcher')),
        )
        .onTap!
        .call();
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('LAST TRIP'), findsOneWidget);

    // Seen: the next launch starts on the hidden total.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('home_island_hint_seen'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tap to see earnings'), findsNothing);
    expect(find.text('•••• kr'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Sliding the island on Ride history opens Movera history', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);

    final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
    for (var i = 0; i < 3; i++) {
      tester.widget<InkWell>(launcher).onTap!.call();
      await advanceAnimation(tester, const Duration(milliseconds: 520));
    }
    expect(find.text('Ride history'), findsOneWidget);

    await tester.fling(launcher, const Offset(120, 0), 800);
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    // LT-4: Ride history now loads on open (one more frame here).
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DriverRideHistory), findsOneWidget);
    expect(find.text('Earnings & history'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('history-overview')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('Exclusive sheet rises over the dock, its grey orb on top', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('Kungsgatan 42'), findsOneWidget);
    // The grey orb on the Exclusive sheet is its Accept.
    expect(
      find.byKey(const ValueKey<String>('home-radar-exclusive')),
      findsOneWidget,
    );

    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.minHeight, 108);
    expect(panel.isDraggable, isFalse);
    expect(panel.panelSnapping, isFalse);
    expectNoException(tester);
  });
}
