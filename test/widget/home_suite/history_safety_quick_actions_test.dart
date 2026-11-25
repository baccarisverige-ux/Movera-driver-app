// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('History exposes overview and full rides list on narrow phone', (
    WidgetTester tester,
  ) async {
    await seedCompletedRideForHistory();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(const MaterialApp(home: DriverRideHistory()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Earnings & history'), findsOneWidget);
    expect(find.text('126.75 kr'), findsWidgets);
    expectNoException(tester);

    await tester.drag(
      find.byKey(const ValueKey<String>('history-overview')),
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(
      find.byKey(const ValueKey<String>('history-view-all-rides')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('history-view-all-rides')),
    );
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('All rides'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('history-all-rides')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('ride-001')), findsWidgets);

    await tester.drag(
      find.byKey(const ValueKey<String>('history-all-rides')),
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(
      find.byKey(const ValueKey<String>('history-all-rides')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('History Today period aligns with Home daily summary', (
    WidgetTester tester,
  ) async {
    await seedCompletedRideForHistory();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: DriverRideHistory()));
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('126.75 kr'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expectNoException(tester);
  });

  testWidgets('Safety button stays fixed when direct offer appears', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    AnimatedPositioned safetyPosition() {
      return tester.widget<AnimatedPositioned>(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('home-safety-button')),
          matching: find.byType(AnimatedPositioned),
        ),
      );
    }

    expect(safetyPosition().bottom, 138);

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('Kungsgatan 42'), findsOneWidget);
    expect(safetyPosition().bottom, 138);
    expectNoException(tester);
  });

  testWidgets('Safety tools open from Home and basic actions remain usable', (
    WidgetTester tester,
  ) async {
    SafetyAudioOption.debugEnabled = true; // owner decision 10: offered again
    addTearDown(() => SafetyAudioOption.debugEnabled = null);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(320, 700));

    final homeSafetyIcon = find.byKey(
      const ValueKey<String>('home-safety-button'),
    );
    expect(homeSafetyIcon, findsOneWidget);
    final safetyInk = find.descendant(
      of: homeSafetyIcon,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(safetyInk).onTap!.call();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(SafetyToolKits), findsOneWidget);
    expect(find.text('Safety tools'), findsOneWidget);
    expectNoException(tester);

    // v0.18.5 `safety.onlyDuringTrip` (owner 2026-10-30): Home has no
    // trip, so only "Call 112" and Safety preferences; no SOS, no audio,
    // no Share trip.
    expect(find.text('Call 112'), findsWidgets);
    expect(find.text('Safety preferences'), findsOneWidget);
    expect(find.text('Record audio'), findsNothing);
    expect(find.text('Share trip'), findsNothing);
    expect(find.byKey(const ValueKey('safety-sos')), findsNothing);
    expectNoException(tester);

    await tester.tap(find.byTooltip('Close'));
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(SafetyToolKits), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Expanded Home quick actions navigate and return safely', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await openPanel(tester);

    invokeTooltipAction(tester, 'Wallet');
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(WalletScreen), findsOneWidget);
    expectNoException(tester);
    Navigator.of(tester.element(find.byType(WalletScreen))).pop();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    invokeTooltipAction(tester, 'Inbox');
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(SupportInboxScreen), findsOneWidget);
    expectNoException(tester);
    Navigator.of(tester.element(find.byType(SupportInboxScreen))).pop();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    invokeTooltipAction(tester, 'Scheduled');
    await advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    expectNoException(tester);
    Navigator.of(tester.element(find.byType(ScheduledRidesScreen))).pop();
    await advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets(
    'Direct Home offer Route and Accept path reaches active ride safely',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(tester, const Size(375, 812));

      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 3800));

      expect(find.text('79,60 kr'), findsOneWidget);
      expect(find.text('Kungsgatan 42'), findsOneWidget);

      // The sheet settles, then the route is on the map.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('79,60 kr'), findsOneWidget);
      expectNoException(tester);

      // The grey orb is the Accept.
      await tester.tap(
        find.byKey(const ValueKey<String>('home-radar-exclusive')),
      );
      await advanceAnimation(tester, const Duration(milliseconds: 520));

      expect(find.byType(AcceptRide), findsOneWidget);
      expectNoException(tester);
    },
  );
}
