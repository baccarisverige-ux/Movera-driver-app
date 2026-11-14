// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Home sheet shows Today: driving time, Performance, waybill', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await openPanel(tester);

    expect(
      find.byKey(const ValueKey<String>('home-sheet-today')),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Right now'), findsOneWidget);
    expect(find.textContaining('left to drive'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Latest waybill'), findsOneWidget);
    // Only these three rows; details open on tap.
    expect(find.text('Rating'), findsNothing);
    expect(find.text('Reservations'), findsNothing);
    expect(find.text('Events'), findsNothing);
    expectNoException(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('home-sheet-performance')),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('4.88'), findsWidgets);
    expect(find.text('Acceptance'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Cancellation'), findsOneWidget);
    expect(find.text('2.4%'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Driving time row opens the driving time and the rest rule', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await openPanel(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('home-sheet-driving-time')),
    );
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.text('Driving time'), findsOneWidget);
    expect(find.text('Worked'), findsOneWidget);
    expect(find.text('Left before rest'), findsOneWidget);
    // SV: the limit and the offline reset as the clock has them (the
    // server's once read), and the admin's break (default 30 min).
    expect(find.text('12 h 00 min'), findsWidgets);
    expect(find.text('6 h 00 min'), findsOneWidget);
    expect(find.text('Break'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    // SV supervisor round 3: the note says the owner's rule (driving only)
    // with the clock's limit and reset, never "while Radar is on".
    expect(
      find.text(
        'Counts only while you drive to the pickup and on the trip. After '
        '12 h you can go online again once you have been offline 6 h in a row.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Radar is on'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Home sheet has one shape: the dock stays and the map dims', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.footer, isNotNull, reason: 'The dock is the sheet bottom');
    expect(panel.collapsed, isNull, reason: 'No second face to cross-fade');
    expect(find.byKey(const ValueKey<String>('home-map-dim')), findsNothing);
    final wallet = tester.getCenter(find.byTooltip('Wallet'));

    await openPanel(tester);
    expect(find.byKey(const ValueKey<String>('home-map-dim')), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Wallet')),
      wallet,
      reason: 'Dock icons do not move with the sheet',
    );
    expectNoException(tester);
  });

  testWidgets(
    'Opening the Home sheet pushes the island away; closing brings it back',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(tester, const Size(375, 812));
      double islandOpacity() => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(const ValueKey<String>('home-island-push')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(islandOpacity(), 1);
      await openPanel(tester);
      expect(islandOpacity(), 0);
      await closePanel(tester);
      expect(islandOpacity(), 1);
      expectNoException(tester);
    },
  );

  testWidgets('Home sheet exposes the last completed waybill', (
    WidgetTester tester,
  ) async {
    WaybillStore.reset();
    WaybillStore.last = WaybillRecord(
      tripId: 'last-waybill-test',
      statusLabel: 'Completed',
      issuedAt: DateTime(2026, 9, 20, 20, 2),
      fare: '259,00 kr',
      service: 'Movera',
      riderName: 'Nicole',
      pickup: 'Hägersten, Stockholm',
      dropoff: 'Södertälje, Stockholm',
      source: 'Movera Radar',
      driverName: 'Movera Driver',
      vehicle: 'Movera partner vehicle',
      licensePlate: 'MVR 418',
      passengerCapacity: 4,
    );
    addTearDown(() {
      WaybillStore.reset();
      tester.binding.setSurfaceSize(null);
    });

    await pumpHome(tester, const Size(375, 812));
    await openPanel(tester);

    final lastWaybill = find.byKey(
      const ValueKey<String>('home-sheet-last-waybill'),
    );
    await tester.ensureVisible(lastWaybill);
    expect(lastWaybill, findsOneWidget);
    expect(find.text('Latest waybill'), findsOneWidget);

    await tester.tap(lastWaybill);
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      find.byKey(const ValueKey<String>('waybill-last-waybill-test')),
      findsOneWidget,
    );
    expect(find.text('259,00 kr'), findsWidgets);
    expectNoException(tester);
  });

  testWidgets('Home exposes a dedicated driver location recenter control', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    expect(
      find.byKey(const ValueKey<String>('driver-location-zoom')),
      findsOneWidget,
    );
    final location = tester.getRect(
      find.byKey(const ValueKey<String>('driver-location-zoom')),
    );
    final safety = tester.getRect(
      find.byKey(const ValueKey<String>('home-safety-button')),
    );
    expect(location.center.dy, closeTo(safety.center.dy, 16));
    // Safety sits on the left, recenter on the right.
    expect(location.left, greaterThan(safety.left));
    expectNoException(tester);
  });
}
