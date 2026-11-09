// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/home/components/driver_sheet_nav.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  for (final size in phoneSizes) {
    testWidgets(
      'Driver Home sheet is layout-safe at ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpHome(tester, size);

        await openPanel(tester);
        expect(
          find.byKey(const ValueKey<String>('home-sheet-today')).hitTestable(),
          findsOneWidget,
        );
        expectNoException(tester);

        await closePanel(tester);
        expectNoException(tester);
      },
    );
  }

  for (final size in phoneSizes) {
    testWidgets(
      'Scheduled Rides is layout-safe at ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: ScheduledRidesScreen()),
        );
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Scheduled rides'), findsOneWidget);
        expect(find.text('Requests'), findsOneWidget);
        expectNoException(tester);

        await tester.tap(find.text('Accepted'));
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Upcoming'), findsOneWidget);
        expectNoException(tester);
      },
    );
  }

  testWidgets(
    'Home sheet survives rapid open-close-open without stale map blocking',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(tester, const Size(320, 700));

      final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      panel.controller!.open();
      await tester.pump(const Duration(milliseconds: 140));
      panel.controller!.close();
      await tester.pump(const Duration(milliseconds: 140));
      panel.controller!.open();
      await advanceAnimation(tester, const Duration(milliseconds: 520));

      var latestPanel = tester.widget<SlidingUpPanel>(
        find.byType(SlidingUpPanel),
      );
      expect(
        homeMapAbsorber(latestPanel).absorbing,
        isFalse,
        reason: 'Map remains zoomable after interrupted sheet open/close/open',
      );
      expect(
        find.byKey(const ValueKey<String>('home-sheet-today')).hitTestable(),
        findsOneWidget,
      );
      expectNoException(tester);

      latestPanel.controller!.close();
      await advanceAnimation(tester, const Duration(milliseconds: 520));

      latestPanel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      expect(homeMapAbsorber(latestPanel).absorbing, isFalse);
      expectNoException(tester);
    },
  );

  testWidgets(
    'Driver menu is full-height, closes on scrim, and Back returns to menu',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(tester, const Size(320, 700));

      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      scaffoldState.openDrawer();
      await advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(scaffoldState.isDrawerOpen, isTrue);
      final drawer = find.byKey(const ValueKey<String>('driver-side-menu'));
      expect(drawer, findsOneWidget);
      expect(
        tester.getSize(drawer).height,
        tester.getSize(find.byType(DriverHome)).height,
      );
      expect(find.byTooltip('Close menu'), findsNothing);
      expectNoException(tester);

      // The uncovered map/scrim area closes the menu; no X button is required.
      await tester.tapAt(const Offset(316, 350));
      await advanceAnimation(tester, const Duration(milliseconds: 420));
      expect(scaffoldState.isDrawerOpen, isFalse);
      expectNoException(tester);

      // Top-level menu destinations keep the drawer open underneath. Back from
      // the destination therefore returns to the menu, not directly to the map.
      scaffoldState.openDrawer();
      await advanceAnimation(tester, const Duration(milliseconds: 420));
      await tester.tap(find.text('Ride history'));
      await advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(find.byType(DriverRideHistory), findsOneWidget);
      expectNoException(tester);

      Navigator.of(tester.element(find.byType(DriverRideHistory))).pop();
      await advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(find.byType(DriverRideHistory), findsNothing);
      expect(scaffoldState.isDrawerOpen, isTrue);
      expect(find.text('Ride history'), findsOneWidget);
      expectNoException(tester);
    },
  );

  testWidgets('Collapsed dock actions are wired safely in isolation', (
    WidgetTester tester,
  ) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final pulseController = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 2600),
    );
    addTearDown(pulseController.dispose);

    var scheduledTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          drawer: const Drawer(child: Text('Menu drawer')),
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 108,
                child: DriverSheetNav.collapsedDock(
                  context: context,
                  scaffoldKey: scaffoldKey,
                  isOnline: false,
                  hasRideOffers: false,
                  hasScheduledRideOffers: true,
                  goOnlinePulseController: pulseController,
                  onOpenScheduledRides: () {
                    scheduledTapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final wallet = find.byTooltip('Wallet');
    expect(wallet, findsOneWidget);
    await tester.tap(wallet);
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);
    expectNoException(tester);
    Navigator.of(tester.element(find.byType(WalletScreen))).pop();
    await tester.pumpAndSettle();

    final inbox = find.byTooltip('Inbox');
    expect(inbox, findsOneWidget);
    await tester.tap(inbox);
    await tester.pumpAndSettle();
    expect(find.byType(SupportInboxScreen), findsOneWidget);
    expectNoException(tester);
    Navigator.of(tester.element(find.byType(SupportInboxScreen))).pop();
    await tester.pumpAndSettle();

    final scheduled = find.byTooltip('Scheduled');
    expect(scheduled, findsOneWidget);
    await tester.tap(scheduled);
    await tester.pump();
    expect(scheduledTapped, isTrue);
    expectNoException(tester);

    final preferences = find.byTooltip('Ride preferences');
    expect(preferences, findsOneWidget);
    await tester.tap(preferences);
    await tester.pumpAndSettle();
    expect(find.byType(Preferences), findsOneWidget);
    expect(scaffoldKey.currentState?.isDrawerOpen, isFalse);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(Preferences), findsNothing);
    expect(find.byTooltip('Ride preferences'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Home map remains zoomable above a settled sheet', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    SlidingUpPanel panel = tester.widget<SlidingUpPanel>(
      find.byType(SlidingUpPanel),
    );
    expect(panel.body, isA<Stack>());
    expect(homeMapAbsorber(panel).absorbing, isFalse);

    await openPanel(tester);
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(
      homeMapAbsorber(panel).absorbing,
      isFalse,
      reason: 'A settled sheet must not block zoom on exposed map',
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('home-sheet-today'))),
    );
    await tester.pump();
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(
      homeMapAbsorber(panel).absorbing,
      isTrue,
      reason: 'An active sheet pointer cannot simultaneously pan the map',
    );
    await drag.up();
    await tester.pump();
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(
      homeMapAbsorber(panel).absorbing,
      isFalse,
      reason: 'Releasing a sheet touch restores map zoom even while open',
    );
    expectNoException(tester);

    await closePanel(tester);
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(homeMapAbsorber(panel).absorbing, isFalse);
    expectNoException(tester);
  });
}
