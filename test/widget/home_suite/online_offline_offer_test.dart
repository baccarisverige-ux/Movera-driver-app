// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Online state survives Scheduled Rides navigation and return', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);

    await openPanel(tester);
    final scheduledTooltips = find.byTooltip('Scheduled');
    expect(scheduledTooltips, findsWidgets);
    final scheduledTaps = find.descendant(
      of: scheduledTooltips,
      matching: find.byType(InkWell),
    );
    final scheduledAction = tester
        .widgetList<InkWell>(scheduledTaps)
        .firstWhere((widget) => widget.onTap != null);
    scheduledAction.onTap!.call();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    expectNoException(tester);

    Navigator.of(tester.element(find.byType(ScheduledRidesScreen))).pop();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    // Still online: with the sheet open the radar reads "Hold · OFF".
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Go offline'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Q19: a long press on the radar asks "Go offline?" first', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);

    // The sheet is closed: the radar button at the bottom.
    final radar = find.byKey(const ValueKey<String>('home-radar-long-press'));
    await tester.longPress(radar);
    await advanceAnimation(tester, const Duration(milliseconds: 320));
    expect(find.text('Go offline?'), findsOneWidget);
    // Stay online: nothing changes.
    await tester.tap(find.byKey(const ValueKey<String>('go-offline-stay')));
    await advanceAnimation(tester, const Duration(milliseconds: 320));
    expect(find.text('Go offline?'), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);

    await tester.longPress(radar);
    await advanceAnimation(tester, const Duration(milliseconds: 320));
    await tester.tap(find.byKey(const ValueKey<String>('go-offline-yes')));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Tap to scan'), findsOneWidget);
    // Offline, a long press on the radar asks nothing.
    await tester.longPress(find.text('OFF'));
    await advanceAnimation(tester, const Duration(milliseconds: 320));
    expect(find.text('Go offline?'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Q19: holding the island while online asks "Go offline?"', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    // Let "Radar online" pass: the island says "Finding trips", the top
    // of the radar.
    for (
      var i = 0;
      i < 20 && find.text('Finding trips').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Finding trips'), findsOneWidget);
    final island = find.byKey(const ValueKey<String>('last-trip-launcher'));
    await tester.longPress(island);
    await advanceAnimation(tester, const Duration(milliseconds: 320));
    expect(find.text('Go offline?'), findsOneWidget);
    expect(find.byType(DriverRideHistory), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('go-offline-yes')));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Tap to scan'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Going offline cancels pending direct-offer state', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);

    await openPanel(tester);
    await holdRadarOff(tester);

    expect(find.text('OFF'), findsOneWidget);

    // Advance beyond the first direct-offer timer. Nothing may appear offline.
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('79,60 kr'), findsNothing);
    expect(find.text('Kungsgatan 42'), findsNothing);
    expect(find.text('OFF'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Direct offer timeout returns Home to scanning state', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('79,60 kr'), findsOneWidget);
    // The grey Exclusive orb is up on its sheet.
    expect(
      find.byKey(const ValueKey<String>('home-radar-exclusive')),
      findsOneWidget,
    );

    // Advance in small frames so the async route-preview continuation can
    // install and then fire the 15 s timeout timer.
    for (var i = 0; i < 40; i++) {
      if (find.text('79,60 kr').evaluate().isEmpty) break;
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('79,60 kr'), findsNothing);
    expect(find.text('Kungsgatan 42'), findsNothing);
    // The radar is itself again (the demo's Radar trips may follow at
    // once, their sheet having gone down first).
    expect(
      find.byKey(const ValueKey<String>('home-radar-exclusive')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('radar-online')), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets(
    'Top island screen cycles money faces and resets when radar starts',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(tester, const Size(375, 812));
      await wakeIsland(tester);

      final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
      expect(launcher, findsOneWidget);
      Future<void> tap() async {
        tester.widget<InkWell>(launcher).onTap!.call();
        await advanceAnimation(tester, const Duration(milliseconds: 520));
      }

      // Hidden → last trip → today → Ride history → hidden. No trip yet:
      // no last fare and 0,00 kr today (driver-u125: sample figures before).
      expect(find.text('•••• kr'), findsOneWidget);
      await tap();
      expect(find.text('LAST TRIP'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      await tap();
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('0,00 kr'), findsOneWidget);
      await tap();
      expect(find.text('Ride history'), findsOneWidget);
      expect(find.text('SLIDE TO OPEN'), findsOneWidget);
      await tap();
      expect(find.text('•••• kr'), findsOneWidget);
      expect(find.text('0,00 kr'), findsNothing);
      expectNoException(tester);

      // Going online hides the money again.
      await tap();
      await tap();
      expect(find.text('0,00 kr'), findsOneWidget);
      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 1550));
      expect(find.text('LIVE'), findsOneWidget);
      // Let the screen finish its switch back to the hidden total.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('0,00 kr'), findsNothing);
      expectNoException(tester);
    },
  );
}
