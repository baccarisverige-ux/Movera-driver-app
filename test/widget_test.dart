import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/main.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/home/components/driver_sheet_nav.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

Future<void> _pumpHome(WidgetTester tester, Size size) async {
  IslandMessages.reset();
  ScheduledRideStore.reset();
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(const MoveraApp());

  // Allow responsive layout and map placeholders to settle.
  await tester.pump(const Duration(milliseconds: 120));
  expect(find.byType(DriverHome), findsOneWidget);

  final startupException = tester.takeException();
  expect(startupException, isNull, reason: startupException?.toString());
}

/// Lets the top island finish its launch animation (small → full → on).
Future<void> _wakeIsland(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 450));
  }
}

void _expectNoException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: exception?.toString());
}

Future<void> _advanceAnimation(WidgetTester tester, Duration duration) async {
  await tester.pump();
  await tester.pump(duration);
}

Future<void> _confirmShortTripIfAsked(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 220));
  final confirm = find.text('Confirm finish');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
  }
  // Each asynchronous journal write must be flushed before asserting navigation.
  for (
    var i = 0;
    i < 60 && find.byType(DriverRideCompleted).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pump(const Duration(milliseconds: 1100));
}

Future<void> _tapArrived(WidgetTester tester) async {
  await _middleActiveRideSheet(tester);
  final button = find.byKey(
    const ValueKey<String>('active-ride-arrived-button'),
  );
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 240));
  // Flush awaited durability and the frame that unlocks the next action.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _slideActiveRideAction(WidgetTester tester) async {
  await _middleActiveRideSheet(tester);
  final action = find.byKey(
    const ValueKey<String>('active-ride-primary-action'),
  );
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await tester.pump(const Duration(milliseconds: 240));
  // Flush awaited durability and the frame that unlocks the next action.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _openPanel(WidgetTester tester) async {
  final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
  panel.controller!.open();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
}

Future<void> _closePanel(WidgetTester tester) async {
  final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
  panel.controller!.close();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
}

/// With the Home sheet open and Radar on, the radar reads "Hold · OFF";
/// holding it one second goes offline and closes the sheet.
Future<void> _holdRadarOff(WidgetTester tester) async {
  final radar = find.byKey(const ValueKey<String>('home-radar-hold-off'));
  expect(radar, findsOneWidget);
  final gesture = await tester.startGesture(tester.getCenter(radar));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await gesture.up();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
}

/// Home's sheet body is the map (behind an AbsorbPointer) plus the dim.
AbsorbPointer _homeMapAbsorber(SlidingUpPanel panel) =>
    (panel.body! as Stack).children.first as AbsorbPointer;

SlidingUpPanel _activeRidePanel(WidgetTester tester) {
  return tester.widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel)).last;
}

Future<void> _collapseActiveRideSheet(WidgetTester tester) async {
  _activeRidePanel(tester).controller!.close();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _expandActiveRideSheet(WidgetTester tester) async {
  // Flush a still-running middle-sheet spring before asking for full details.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  _activeRidePanel(tester).controller!.open();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

/// Middle sheet: rider and the slide action; the full sheet has neither.
Future<void> _middleActiveRideSheet(WidgetTester tester) async {
  if (find
          .byKey(const ValueKey('active-ride-arrived-button'))
          .evaluate()
          .isNotEmpty ||
      find
          .byKey(const ValueKey('active-ride-primary-action'))
          .evaluate()
          .isNotEmpty) {
    return;
  }
  _activeRidePanel(tester).controller!.animatePanelToSnapPoint();
  await _advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

void _invokeTooltipAction(WidgetTester tester, String tooltip) {
  final tooltips = find.byTooltip(tooltip);
  expect(tooltips, findsWidgets);
  final taps = find.descendant(of: tooltips, matching: find.byType(InkWell));
  final action = tester
      .widgetList<InkWell>(taps)
      .firstWhere((widget) => widget.onTap != null);
  action.onTap!.call();
}

Future<void> seedCompletedRideForHistory() async {
  SharedPreferences.setMockInitialValues({});
  await PrefsTripHistoryRepository().archive(
    WaybillRecord(
      tripId: 'ride-001',
      statusLabel: 'Completed',
      issuedAt: DateTime.now(),
      fare: '126.75 kr',
      service: 'Comfort',
      riderName: 'Rider',
      pickup: 'Central Station',
      dropoff: 'Södermalm',
      source: 'Radar',
      driverName: 'Driver',
      vehicle: 'Vehicle',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    ),
  );
}

void main() {
  setUp(() {
    CompletionJournal.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  const phoneSizes = <Size>[
    Size(320, 700),
    Size(375, 812),
    Size(390, 844),
    Size(430, 932),
  ];

  for (final size in phoneSizes) {
    testWidgets(
      'Driver Home sheet is layout-safe at ${size.width.toInt()}x${size.height.toInt()}',
      (WidgetTester tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpHome(tester, size);

        await _openPanel(tester);
        expect(
          find.byKey(const ValueKey<String>('home-sheet-today')).hitTestable(),
          findsOneWidget,
        );
        _expectNoException(tester);

        await _closePanel(tester);
        _expectNoException(tester);
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
        _expectNoException(tester);

        await tester.tap(find.text('Accepted'));
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.text('Upcoming'), findsOneWidget);
        _expectNoException(tester);
      },
    );
  }

  testWidgets(
    'Home sheet survives rapid open-close-open without stale map blocking',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(320, 700));

      final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      panel.controller!.open();
      await tester.pump(const Duration(milliseconds: 140));
      panel.controller!.close();
      await tester.pump(const Duration(milliseconds: 140));
      panel.controller!.open();
      await _advanceAnimation(tester, const Duration(milliseconds: 520));

      var latestPanel = tester.widget<SlidingUpPanel>(
        find.byType(SlidingUpPanel),
      );
      expect(_homeMapAbsorber(latestPanel).absorbing, isFalse,
          reason: 'Map remains zoomable after interrupted sheet open/close/open');
      expect(
        find.byKey(const ValueKey<String>('home-sheet-today')).hitTestable(),
        findsOneWidget,
      );
      _expectNoException(tester);

      latestPanel.controller!.close();
      await _advanceAnimation(tester, const Duration(milliseconds: 520));

      latestPanel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      expect(_homeMapAbsorber(latestPanel).absorbing, isFalse);
      _expectNoException(tester);
    },
  );

  testWidgets(
    'Driver menu is full-height, closes on scrim, and Back returns to menu',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(320, 700));

      final scaffoldState = tester.state<ScaffoldState>(
        find.byType(Scaffold).first,
      );
      scaffoldState.openDrawer();
      await _advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(scaffoldState.isDrawerOpen, isTrue);
      final drawer = find.byKey(const ValueKey<String>('driver-side-menu'));
      expect(drawer, findsOneWidget);
      expect(
        tester.getSize(drawer).height,
        tester.getSize(find.byType(DriverHome)).height,
      );
      expect(find.byTooltip('Close menu'), findsNothing);
      _expectNoException(tester);

      // The uncovered map/scrim area closes the menu; no X button is required.
      await tester.tapAt(const Offset(316, 350));
      await _advanceAnimation(tester, const Duration(milliseconds: 420));
      expect(scaffoldState.isDrawerOpen, isFalse);
      _expectNoException(tester);

      // Top-level menu destinations keep the drawer open underneath. Back from
      // the destination therefore returns to the menu, not directly to the map.
      scaffoldState.openDrawer();
      await _advanceAnimation(tester, const Duration(milliseconds: 420));
      await tester.tap(find.text('Ride history'));
      await _advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(find.byType(DriverRideHistory), findsOneWidget);
      _expectNoException(tester);

      Navigator.of(tester.element(find.byType(DriverRideHistory))).pop();
      await _advanceAnimation(tester, const Duration(milliseconds: 420));

      expect(find.byType(DriverRideHistory), findsNothing);
      expect(scaffoldState.isDrawerOpen, isTrue);
      expect(find.text('Ride history'), findsOneWidget);
      _expectNoException(tester);
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
    _expectNoException(tester);
    Navigator.of(tester.element(find.byType(WalletScreen))).pop();
    await tester.pumpAndSettle();

    final inbox = find.byTooltip('Inbox');
    expect(inbox, findsOneWidget);
    await tester.tap(inbox);
    await tester.pumpAndSettle();
    expect(find.byType(SupportInboxScreen), findsOneWidget);
    _expectNoException(tester);
    Navigator.of(tester.element(find.byType(SupportInboxScreen))).pop();
    await tester.pumpAndSettle();

    final scheduled = find.byTooltip('Scheduled');
    expect(scheduled, findsOneWidget);
    await tester.tap(scheduled);
    await tester.pump();
    expect(scheduledTapped, isTrue);
    _expectNoException(tester);

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
    _expectNoException(tester);
  });

  testWidgets('Home map remains zoomable above a settled sheet', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    SlidingUpPanel panel = tester.widget<SlidingUpPanel>(
      find.byType(SlidingUpPanel),
    );
    expect(panel.body, isA<Stack>());
    expect(_homeMapAbsorber(panel).absorbing, isFalse);

    await _openPanel(tester);
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(_homeMapAbsorber(panel).absorbing, isFalse,
        reason: 'A settled sheet must not block zoom on exposed map');
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('home-sheet-today'))),
    );
    await tester.pump();
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(_homeMapAbsorber(panel).absorbing, isTrue,
        reason: 'An active sheet pointer cannot simultaneously pan the map');
    await drag.up();
    await tester.pump();
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(_homeMapAbsorber(panel).absorbing, isFalse,
        reason: 'Releasing a sheet touch restores map zoom even while open');
    _expectNoException(tester);

    await _closePanel(tester);
    panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(_homeMapAbsorber(panel).absorbing, isFalse);
    _expectNoException(tester);
  });

  testWidgets('Full radar orb responds near its outer edge', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    final target = find.byKey(
      const ValueKey<String>('trip-radar-touch-target'),
    );
    expect(target, findsOneWidget);
    expect(tester.getSize(target), const Size(104, 104));

    final rect = tester.getRect(target);
    await tester.tapAt(Offset(rect.right - 4, rect.center.dy));
    await tester.pump();

    expect(find.text('STARTING'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets(
    'Exclusive Radar stays separate and Radar offers survive list open-close',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(375, 812));

      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 1550));
      expect(find.text('LIVE'), findsOneWidget);

      // Exclusive Radar offer uses its own exclusive surface.
      await tester.pump(const Duration(milliseconds: 2300));
      // One total: the 104,80 kr fare plus 1,00 kr pickup pay (Comfort,
      // 0.9 km / 3 min: 1 km and 2 min free, 1 kr/min).
      expect(find.text('105,80 kr'), findsOneWidget);
      expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('radar-home-deck')),
        findsNothing,
      );
      _expectNoException(tester);

      // Let the outside offer expire, then allow the first Radar offer to arrive.
      // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
      await tester.pump(const Duration(milliseconds: 900));

      final card = find.byKey(
        const ValueKey<String>('radar-offer-card-nearby-1'),
      );
      expect(card, findsOneWidget);
      expect(find.text('Only for you · pickup 3 min away'), findsNothing);
      // While Radar offers show, the radar reads Accept for the front card.
      expect(
        find.byKey(const ValueKey<String>('home-radar-accept')),
        findsOneWidget,
      );
      expect(find.text('MATCH'), findsOneWidget);
      _expectNoException(tester);

      // The ALL OFFERS badge opens the full Radar list.
      final allOffers = find.byKey(
        const ValueKey<String>('radar-home-all-offers'),
      );
      expect(
        find.descendant(of: allOffers, matching: find.text('ALL OFFERS')),
        findsOneWidget,
      );
      await tester.tap(allOffers);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byType(RideRequests), findsOneWidget);
      _expectNoException(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 160));

      // Returning to Home keeps the Home Radar opportunity alive.
      expect(find.byType(RideRequests), findsNothing);
      expect(card, findsOneWidget);
      _expectNoException(tester);
    },
  );

  testWidgets('Home Radar deck takes new trips and drops a taken one', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(320, 700));
    IslandMessages.reset();
    Finder card(String id) =>
        find.byKey(ValueKey<String>('radar-offer-card-$id'));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));

    // Outside offer first, still isolated from Radar.
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('105,80 kr'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('radar-home-deck')), findsNothing);
    _expectNoException(tester);

    // Expire outside offer and receive the first Radar offer.
    // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    expect(card('nearby-1'), findsOneWidget);
    _expectNoException(tester);

    // New Radar matches join the deck behind it; no refresh on Home.
    await tester.pump(const Duration(milliseconds: 3100));
    expect(card('nearby-2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('radar-home-refresh')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(card('nearby-4'), findsOneWidget);
    // The first trip stays in front: it sits lowest, the others peek above.
    expect(
      tester.getTopLeft(card('nearby-1')).dy,
      greaterThan(tester.getTopLeft(card('nearby-4')).dy),
    );
    _expectNoException(tester);

    // Another driver takes nearby-4 while it is behind: it leaves at once,
    // with no island message.
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(card('nearby-4'), findsNothing);
    expect(card('nearby-1'), findsOneWidget);
    expect(
      IslandMessages.posted.map((m) => m.title),
      isNot(contains('Taken by another driver')),
    );
    _expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 3000));
    expect(card('nearby-4'), findsNothing);
    _expectNoException(tester);
  });

  testWidgets('Swiping the front Radar card sends it to the back', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));
    // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 6200));
    await tester.pump(const Duration(milliseconds: 1000));

    Finder card(String id) =>
        find.byKey(ValueKey<String>('radar-offer-card-$id'));
    final ids = [
      'nearby-1',
      'nearby-2',
      'nearby-4',
    ].where((id) => card(id).evaluate().isNotEmpty).toList();
    expect(ids.length, 3);
    String front() => ids.reduce(
      (a, b) =>
          tester.getTopLeft(card(a)).dy >= tester.getTopLeft(card(b)).dy
          ? a
          : b,
    );
    final first = front();
    expect(first, 'nearby-1');

    await tester.drag(card(first), const Offset(-260, 0));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    // The next one is in front; the swiped one went to the back.
    final next = front();
    expect(next, isNot(first));
    expect(
      tester.getTopLeft(card(first)).dy,
      lessThan(tester.getTopLeft(card(next)).dy),
    );
    _expectNoException(tester);
  });

  testWidgets('Exclusive Radar hides Home dash and normal Radar restores it', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));

    expect(find.byType(RadarEdgeDash), findsNothing);

    // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));

    final radarDashes = tester.widgetList<RadarEdgeDash>(
      find.byType(RadarEdgeDash),
    );
    expect(
      radarDashes.any((dash) => dash.color == const Color(0xFFFFA94D)),
      isTrue,
    );
    _expectNoException(tester);
  });

  testWidgets('Full Radar disables a trip when another driver matches it', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: RideRequests()));
    await tester.pump(const Duration(milliseconds: 120));

    // Demo: nearby-3 is claimed remotely 4.5 s after the Exclusive offer's
    // time to accept (15 s), so soon after Home shows Radar trips.
    await tester.pump(
      DriverOfferRules.current.exclusiveAcceptTime +
          const Duration(milliseconds: 4500),
    );
    // Its card fades out: Match and × are off.
    final card = find.byKey(const ValueKey<String>('nearby-3'));
    expect(card, findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('radar-match-nearby-3')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey<String>('radar-offer-dismiss-nearby-3')),
      findsNothing,
    );
    _expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(card, findsNothing);
    _expectNoException(tester);
  });

  testWidgets('Full Radar resolves a simultaneous claim as request taken', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: RideRequests()));
    await tester.pump(const Duration(milliseconds: 120));

    // Demo: nearby-2 represents two drivers tapping Match at nearly
    // the same time, with the other driver winning the atomic claim.
    final card = find.byKey(const ValueKey<String>('nearby-2'));
    final match = find.byKey(const ValueKey<String>('radar-match-nearby-2'));
    await tester.tap(match);
    await tester.pump();

    expect(find.text('Matching trip'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Matching…')),
      findsOneWidget,
    );
    _expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    // A short banner says why; the card fades out of the list.
    expect(find.text('Taken by another driver'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(match).onPressed,
      isNull,
    );
    expect(find.byType(AcceptRide), findsNothing);
    _expectNoException(tester);
  });

  testWidgets('Full Radar lists every trip with its details', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 2000));
    await tester.pumpWidget(const MaterialApp(home: RideRequests()));
    await tester.pump(const Duration(milliseconds: 120));

    // Header: back, small live dot, "Live" and the OFFERS count.
    expect(find.text('Live'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('radar-live-dot')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('radar-live-count')),
        matching: find.text('OFFERS'),
      ),
      findsOneWidget,
    );
    final ids = ['nearby-1', 'nearby-2', 'nearby-3']
        .where(
          (id) => find
              .byKey(ValueKey<String>('radar-offer-card-$id'))
              .evaluate()
              .isNotEmpty,
        )
        .toList();
    expect(ids, isNotEmpty);
    // Same card as Home: pickup distance, trip length, Match and ×.
    for (final id in ids) {
      final card = find.byKey(ValueKey<String>('radar-offer-card-$id'));
      expect(
        find.descendant(of: card, matching: find.textContaining('km away')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('min trip')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('radar-match-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('radar-offer-dismiss-$id')),
        findsOneWidget,
      );
    }
    _expectNoException(tester);

    // × removes a card from the list.
    final dismiss = find.byKey(ValueKey<String>('radar-offer-dismiss-${ids.first}'));
    await tester.tap(dismiss);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(ValueKey<String>('radar-offer-card-${ids.first}')),
      findsNothing,
    );
    _expectNoException(tester);
  });

  testWidgets('Full Radar winning Match opens the assigned ride', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: RideRequests()));
    await tester.pump(const Duration(milliseconds: 120));

    final card = find.byKey(const ValueKey<String>('nearby-1'));
    await tester.tap(find.descendant(of: card, matching: find.text('Match')));
    await tester.pump();

    expect(find.text('Matching trip'), findsOneWidget);
    _expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Trip matched'), findsOneWidget);
    final notice = tester.getRect(
      find.byKey(const ValueKey<String>('radar-match-notice')),
    );
    expect(notice.top, closeTo(0, 0.5));
    expect(notice.left, closeTo(0, 0.5));
    expect(notice.width, closeTo(375, 1));
    _expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.byType(AcceptRide), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Destination Mode sets one route and auto-starts online', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    final openDestination = find.byKey(
      const ValueKey<String>('destination-mode-open'),
    );
    expect(openDestination, findsOneWidget);
    final destinationControl = tester.widget<InkWell>(openDestination);
    expect(destinationControl.onTap, isNotNull);
    destinationControl.onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));

    expect(find.byType(DriverDestinationPicker), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('destination-search')),
      findsOneWidget,
    );
    expect(find.byType(CustomGoogleMap), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-result-solna')),
      findsOneWidget,
    );
    _expectNoException(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('destination-result-solna')),
    );
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('destination-mode-home-tab')),
      findsOneWidget,
    );
    expect(find.text('STARTING'), findsOneWidget);

    final map = tester.widget<CustomGoogleMap>(
      find.byType(CustomGoogleMap).first,
    );
    // Routing is real-road only. In widget tests there is no live GPS/provider,
    // so Destination Mode must not invent a straight two-point route.
    expect(
      map.polylines!.any(
        (polyline) => polyline.polylineId.value == 'destination_mode_route',
      ),
      isFalse,
    );
    expect(
      map.markers!.any(
        (marker) => marker.markerId.value == 'destination_mode_target',
      ),
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);

    final endDestination = find.byKey(
      const ValueKey<String>('destination-mode-end'),
    );
    expect(endDestination, findsOneWidget);
    tester.widget<InkWell>(endDestination).onTap!.call();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('destination-mode-home-tab')),
      findsNothing,
    );
    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Home destination control does not block the map area', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    final destinationControl = find.byKey(
      const ValueKey<String>('destination-mode-open'),
    );
    expect(destinationControl, findsOneWidget);

    final interceptor = find.ancestor(
      of: destinationControl,
      matching: find.byType(PointerInterceptor),
    );
    expect(interceptor, findsOneWidget);

    // One black island, centred, leaving both map corners free.
    final islandRect = tester.getRect(interceptor);
    expect(islandRect.width, lessThanOrEqualTo(250));
    expect(islandRect.height, lessThan(70));
    expect(islandRect.center.dx, closeTo(375 / 2, 2));
    _expectNoException(tester);
  });

  testWidgets('Destination picker remains layout-safe on narrow phone', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(const MaterialApp(home: DriverDestinationPicker()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Choose one address'), findsOneWidget);
    expect(find.text('Suggested addresses'), findsOneWidget);
    expect(find.byType(CustomGoogleMap), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-search')),
      findsOneWidget,
    );
    _expectNoException(tester);
  });

  testWidgets('Destination radar only shows same-way frontend offers', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(
      const MaterialApp(
        home: RideRequests(
          destinationModeActive: true,
          destinationAddress: 'Solna Torg, Solna',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey<String>('radar-destination-filter')),
      findsOneWidget,
    );
    expect(find.textContaining('Trips toward Solna Torg'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('nearby-1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('nearby-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('nearby-3')), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Trip radar online and Go offline sheet flow is safe', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    expect(find.text('OFF'), findsOneWidget);
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));

    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);

    await _openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // Same radar, now "Hold · OFF · Go offline".
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Go offline'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    // A short tap does nothing.
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-hold-off')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hold'), findsOneWidget);

    await _holdRadarOff(tester);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.controller!.panelPosition, closeTo(0, 0.02),
        reason: 'Going offline brings the sheet down by itself');
    _expectNoException(tester);
  });

  testWidgets('Home sheet shows Today: driving time, Performance, waybill', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _openPanel(tester);

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
    _expectNoException(tester);

    await tester.tap(find.byKey(const ValueKey<String>('home-sheet-performance')));
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('4.88'), findsWidgets);
    expect(find.text('Acceptance'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Cancellation'), findsOneWidget);
    expect(find.text('2.4%'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Driving time row opens the driving time and the rest rule', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _openPanel(tester);

    await tester.tap(find.byKey(const ValueKey<String>('home-sheet-driving-time')));
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.text('Driving time'), findsOneWidget);
    expect(find.text('Worked'), findsOneWidget);
    expect(find.text('Left before rest'), findsOneWidget);
    expect(find.text('12 h'), findsOneWidget);
    expect(find.text('6 h'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Home sheet has one shape: the dock stays and the map dims', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.footer, isNotNull, reason: 'The dock is the sheet bottom');
    expect(panel.collapsed, isNull, reason: 'No second face to cross-fade');
    expect(find.byKey(const ValueKey<String>('home-map-dim')), findsNothing);
    final wallet = tester.getCenter(find.byTooltip('Wallet'));

    await _openPanel(tester);
    expect(find.byKey(const ValueKey<String>('home-map-dim')), findsOneWidget);
    expect(tester.getCenter(find.byTooltip('Wallet')), wallet,
        reason: 'Dock icons do not move with the sheet');
    _expectNoException(tester);
  });

  testWidgets(
    'Opening the Home sheet pushes the island away; closing brings it back',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(375, 812));
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
      await _openPanel(tester);
      expect(islandOpacity(), 0);
      await _closePanel(tester);
      expect(islandOpacity(), 1);
      _expectNoException(tester);
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

    await _pumpHome(tester, const Size(375, 812));
    await _openPanel(tester);

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
    _expectNoException(tester);
  });

  testWidgets('Home exposes a dedicated driver location recenter control', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

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
    _expectNoException(tester);
  });

  testWidgets('Online state survives Scheduled Rides navigation and return', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);

    await _openPanel(tester);
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
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    _expectNoException(tester);

    Navigator.of(tester.element(find.byType(ScheduledRidesScreen))).pop();
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    // Still online: with the sheet open the radar reads "Hold · OFF".
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Go offline'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Going offline cancels pending direct-offer state', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);

    await _openPanel(tester);
    await _holdRadarOff(tester);

    expect(find.text('OFF'), findsOneWidget);

    // Advance beyond the first direct-offer timer. Nothing may appear offline.
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('105,80 kr'), findsNothing);
    expect(find.text('Only for you · pickup 3 min away'), findsNothing);
    expect(find.text('OFF'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Direct offer timeout returns Home to scanning state', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('105,80 kr'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    // Advance in small frames so the async route-preview continuation can
    // install and then fire the 15 s timeout timer.
    for (var i = 0; i < 40; i++) {
      if (find.text('105,80 kr').evaluate().isEmpty) break;
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('105,80 kr'), findsNothing);
    expect(find.text('Only for you · pickup 3 min away'), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets(
    'Top island screen cycles money faces and resets when radar starts',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(375, 812));
      await _wakeIsland(tester);

      final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
      expect(launcher, findsOneWidget);
      Future<void> tap() async {
        tester.widget<InkWell>(launcher).onTap!.call();
        await _advanceAnimation(tester, const Duration(milliseconds: 520));
      }

      // Hidden → last trip → today → Ride history → hidden.
      expect(find.text('•••• kr'), findsOneWidget);
      await tap();
      expect(find.text('LAST TRIP'), findsOneWidget);
      expect(find.text('126 kr'), findsOneWidget);
      await tap();
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('183.25 kr'), findsOneWidget);
      await tap();
      expect(find.text('Ride history'), findsOneWidget);
      expect(find.text('SLIDE TO OPEN'), findsOneWidget);
      await tap();
      expect(find.text('•••• kr'), findsOneWidget);
      expect(find.text('183.25 kr'), findsNothing);
      _expectNoException(tester);

      // Going online hides the money again.
      await tap();
      await tap();
      expect(find.text('183.25 kr'), findsOneWidget);
      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 1550));
      expect(find.text('LIVE'), findsOneWidget);
      // Let the screen finish its switch back to the hidden total.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('183.25 kr'), findsNothing);
      _expectNoException(tester);
    },
  );

  testWidgets('Top island opens small, then grows and turns its screen on', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

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

    await _wakeIsland(tester);
    expect(tester.getSize(island).width, closeTo(244, 1));
    expect(find.text('•••• kr'), findsOneWidget);
    _expectNoException(tester);
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
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);

    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('last-trip-launcher')),
        )
        .onTap!
        .call();
    await _advanceAnimation(tester, const Duration(milliseconds: 520));
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
    _expectNoException(tester);
  });

  testWidgets('Going online shows on the island, then it returns', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);

    await tester.tap(find.text('OFF'));
    await _advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Radar online'), findsOneWidget);

    // A quick message: about 2 s, then the money display comes back.
    await tester.pump(const Duration(milliseconds: 1600));
    await _advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Radar online'), findsNothing);
    expect(find.text('•••• kr'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Island stretches sideways to fit a message, never taller', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(390, 844));
    await _wakeIsland(tester);

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
    await _advanceAnimation(tester, const Duration(milliseconds: 900));
    final short = tester.getSize(island);
    // Short words keep the normal size.
    expect(short.width, closeTo(244, 1));

    IslandMessages.reset();
    await tester.pump(const Duration(seconds: 4));
    IslandMessages.show(
      const IslandMessage(title: 'Weekly earnings statement ready'),
    );
    await _advanceAnimation(tester, const Duration(milliseconds: 900));
    final long = tester.getSize(island);

    expect(long.width, greaterThan(short.width));
    expect(long.width, lessThanOrEqualTo(normal.width * 1.15 + 0.001));
    expect(tester.getRect(island).width, lessThanOrEqualTo(390 - 32 + 1));
    // Only the length changes; the height is always the same.
    expect(short.height, normal.height);
    expect(long.height, normal.height);

    // And it goes back to the normal island afterwards.
    await tester.pump(const Duration(seconds: 3));
    await _advanceAnimation(tester, const Duration(milliseconds: 900));
    expect(tester.getSize(island).width, closeTo(244, 1));
    expect(find.text('•••• kr'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Top island returns to the hidden total after 5 s untouched', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);

    final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
    Future<void> tap() async {
      tester.widget<InkWell>(launcher).onTap!.call();
      await _advanceAnimation(tester, const Duration(milliseconds: 520));
    }

    await tap();
    expect(find.text('126 kr'), findsOneWidget);
    // A tap restarts the 5 s: 4 s, tap, 4 s later it still shows today.
    await tester.pump(const Duration(seconds: 4));
    await tap();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('183.25 kr'), findsOneWidget);
    // Then 5 s without a touch brings back the hidden total.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('•••• kr'), findsOneWidget);
    expect(find.text('183.25 kr'), findsNothing);
    _expectNoException(tester);
  });

  testWidgets('Top island arrow opens Destination and menu opens the drawer', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

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
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.isDrawerOpen, isTrue);
    _expectNoException(tester);
  });

  testWidgets('Holding the island opens Ride history straight away', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);

    await tester.longPress(
      find.byKey(const ValueKey<String>('last-trip-launcher')),
    );
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverRideHistory), findsOneWidget);
    _expectNoException(tester);
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

    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tap to see earnings'), findsOneWidget);

    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('last-trip-launcher')),
        )
        .onTap!
        .call();
    await _advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('LAST TRIP'), findsOneWidget);

    // Seen: the next launch starts on the hidden total.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('home_island_hint_seen'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tap to see earnings'), findsNothing);
    expect(find.text('•••• kr'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Sliding the island on Ride history opens Movera history', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _wakeIsland(tester);

    final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
    for (var i = 0; i < 3; i++) {
      tester.widget<InkWell>(launcher).onTap!.call();
      await _advanceAnimation(tester, const Duration(milliseconds: 520));
    }
    expect(find.text('Ride history'), findsOneWidget);

    await tester.fling(launcher, const Offset(120, 0), 800);
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverRideHistory), findsOneWidget);
    expect(find.text('Earnings & history'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('history-overview')),
      findsOneWidget,
    );
    _expectNoException(tester);
  });

  testWidgets(
    'Exclusive card sits on the Home sheet; the dock and radar stay',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(375, 812));

      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 3800));

      expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
      // The radar stays in the dock as the offer's blue Accept.
      expect(
        find.byKey(const ValueKey<String>('home-radar-exclusive')),
        findsOneWidget,
      );

      final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
      expect(panel.minHeight, 108);
      expect(panel.isDraggable, isFalse);
      expect(panel.panelSnapping, isFalse);
      expect(find.byType(RadarEdgeDash), findsNothing);
      _expectNoException(tester);
    },
  );

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
    _expectNoException(tester);

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
    _expectNoException(tester);
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
    _expectNoException(tester);
  });

  testWidgets('Safety button stays fixed when direct offer appears', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

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

    expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
    expect(safetyPosition().bottom, 138);
    _expectNoException(tester);
  });

  testWidgets('Safety tools open from Home and basic actions remain usable', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(320, 700));

    final homeSafetyIcon = find.byKey(
      const ValueKey<String>('home-safety-button'),
    );
    expect(homeSafetyIcon, findsOneWidget);
    final safetyInk = find.descendant(
      of: homeSafetyIcon,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(safetyInk).onTap!.call();
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(SafetyToolKits), findsOneWidget);
    expect(find.text('Safety tools'), findsOneWidget);
    _expectNoException(tester);

    await tester.tap(find.text('Record audio'));
    await tester.pump();
    expect(find.text('Stop audio'), findsNothing);
    expect(
      find.text('Audio recording is unavailable in this demo.'),
      findsOneWidget,
    );
    _expectNoException(tester);

    await tester.tap(find.text('Share trip'));
    await tester.pump();
    expect(
      find.text('Trip sharing is unavailable in this demo.'),
      findsOneWidget,
    );
    _expectNoException(tester);

    await tester.tap(find.byTooltip('Close'));
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(SafetyToolKits), findsNothing);
    _expectNoException(tester);
  });

  testWidgets('Expanded Home quick actions navigate and return safely', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));
    await _openPanel(tester);

    _invokeTooltipAction(tester, 'Wallet');
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(WalletScreen), findsOneWidget);
    _expectNoException(tester);
    Navigator.of(tester.element(find.byType(WalletScreen))).pop();
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    _invokeTooltipAction(tester, 'Inbox');
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(SupportInboxScreen), findsOneWidget);
    _expectNoException(tester);
    Navigator.of(tester.element(find.byType(SupportInboxScreen))).pop();
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    _invokeTooltipAction(tester, 'Scheduled');
    await _advanceAnimation(tester, const Duration(milliseconds: 420));
    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    _expectNoException(tester);
    Navigator.of(tester.element(find.byType(ScheduledRidesScreen))).pop();
    await _advanceAnimation(tester, const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets(
    'Direct Home offer Route and Accept path reaches active ride safely',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHome(tester, const Size(375, 812));

      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 3800));

      expect(find.text('105,80 kr'), findsOneWidget);
      expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);

      final route = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('direct-offer-route')),
      );
      expect(route.onPressed, isNotNull);
      route.onPressed!.call();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('105,80 kr'), findsOneWidget);
      _expectNoException(tester);

      // The blue radar is the Accept.
      await tester.tap(
        find.byKey(const ValueKey<String>('home-radar-exclusive')),
      );
      await _advanceAnimation(tester, const Duration(milliseconds: 520));

      expect(find.byType(AcceptRide), findsOneWidget);
      _expectNoException(tester);
    },
  );

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
      await _middleActiveRideSheet(tester);
      expect(find.text("I've arrived"), findsOneWidget);
      expect(find.text('Slide to confirm pickup'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
        findsOneWidget,
      );
      _expectNoException(tester);

      await _tapArrived(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
        findsWidgets,
      );
      expect(find.text('Start trip'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
        findsOneWidget,
      );
      _expectNoException(tester);

      await _slideActiveRideAction(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
        findsOneWidget,
      );
      expect(find.text('Complete trip'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
        findsOneWidget,
      );
      _expectNoException(tester);

      await _slideActiveRideAction(tester);
      await _confirmShortTripIfAsked(tester);

      expect(find.byType(DriverRideCompleted), findsOneWidget);
      _expectNoException(tester);
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

      await _tapArrived(tester);

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
      _expectNoException(tester);

      await _slideActiveRideAction(tester);

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
      _expectNoException(tester);
    },
  );

  testWidgets('Completing a trip returns home with radar offline', (
    WidgetTester tester,
  ) async {
    WaybillStore.reset();
    addTearDown(() {
      WaybillStore.reset();
      tester.binding.setSurfaceSize(null);
    });

    await _pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    // The blue radar is the Exclusive offer's Accept.
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
    await _advanceAnimation(tester, const Duration(milliseconds: 520));

    expect(find.byType(AcceptRide), findsOneWidget);

    await _tapArrived(tester);
    await _slideActiveRideAction(tester);
    await _slideActiveRideAction(tester);
    await _confirmShortTripIfAsked(tester);

    expect(find.byType(DriverRideCompleted), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 420));
    // The radar's last face change (from the blue Exclusive Accept)
    // finishes its fade on the next frame.
    await tester.pump();

    expect(find.byType(DriverHome), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Go offline'), findsNothing);
    await _openPanel(tester);
    final lastWaybill = find.byKey(
      const ValueKey<String>('home-sheet-last-waybill'),
    );
    await tester.ensureVisible(lastWaybill);
    expect(lastWaybill, findsOneWidget);
    expect(find.text('None yet'), findsNothing);
    _expectNoException(tester);
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
    _expectNoException(tester);
  });

  testWidgets('On-trip Radar stays hidden until a near-dropoff offer exists', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await _tapArrived(tester);
    await _slideActiveRideAction(tester);

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
    _expectNoException(tester);

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
    _expectNoException(tester);
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

    await _middleActiveRideSheet(tester);
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
    _expectNoException(tester);
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

    await _tapArrived(tester);
    await _slideActiveRideAction(tester);
    await tester.pump(const Duration(milliseconds: 2400));

    expect(
      find.byKey(const ValueKey<String>('on-trip-radar-offer-button')),
      findsOneWidget,
    );
    _expectNoException(tester);
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

      await _tapArrived(tester);

      await _slideActiveRideAction(tester);

      await tester.pump(const Duration(milliseconds: 2400));

      final matchNext = find.byKey(
        const ValueKey<String>('on-trip-radar-match-next'),
      );
      await tester.ensureVisible(matchNext);
      await tester.tap(matchNext);
      await tester.pump(const Duration(milliseconds: 1600));
      await _expandActiveRideSheet(tester);

      expect(
        find.byKey(const ValueKey<String>('secured-next-trip-details')),
        findsOneWidget,
      );
      expect(find.text('Next trip secured'), findsWidgets);
      expect(find.text('Vasagatan 10, Stockholm'), findsOneWidget);
      expect(find.text('Södermalm, Stockholm'), findsOneWidget);
      expect(WaybillStore.next, isNotNull);
      _expectNoException(tester);

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
      _expectNoException(tester);
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

      await _tapArrived(tester);
      await _slideActiveRideAction(tester);
      await tester.pump(const Duration(milliseconds: 2400));

      final matchNext = find.byKey(
        const ValueKey<String>('on-trip-radar-match-next'),
      );
      await tester.ensureVisible(matchNext);
      await tester.tap(matchNext);
      await tester.pump(const Duration(milliseconds: 1600));
      await _expandActiveRideSheet(tester);

      expect(find.text('Next trip secured'), findsWidgets);

      await _middleActiveRideSheet(tester);
      await _slideActiveRideAction(tester);
      await _confirmShortTripIfAsked(tester);
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
      expect(tester.widget<AcceptRide>(find.byType(AcceptRide)).riderName, 'Maya');
      await _middleActiveRideSheet(tester);
      expect(find.textContaining('Maya'), findsWidgets);
      await _expandActiveRideSheet(tester);
      expect(find.textContaining('Vasagatan 10'), findsWidgets);
      _expectNoException(tester);
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
      _expectNoException(tester);
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
            offerId: 'waybill-current-test',
            fare: '111,02 kr',
            category: 'Comfort',
            matchedVia: 'Movera Radar',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await _expandActiveRideSheet(tester);

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
      // Fare marked for rounding, then what the passenger paid and what the
      // driver keeps after Movera's fee.
      expect(find.text('111,02 kr*'), findsOneWidget);
      expect(find.text('111,02 kr'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('83,26 kr'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('waybill-waybill-current-test')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('−27,76 kr'), findsOneWidget);
      expect(find.text('83,26 kr'), findsOneWidget);
      _expectNoException(tester);
    },
  );

  testWidgets('On-trip options allow safe early cancellation with reasons', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await _tapArrived(tester);

    await _slideActiveRideAction(tester);

    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsOneWidget,
    );

    // The relocated island action remains available while the radar offer is visible.
    await _advanceAnimation(tester, const Duration(milliseconds: 700));
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('End trip early'), findsOneWidget);
    expect(find.text('Stop safely first · reason required'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('active-ride-cancel-option')),
    );
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-reasons-sheet')),
      findsOneWidget,
    );
    expect(find.text('Rider asked to end the trip'), findsOneWidget);
    expect(find.text('Safety concern'), findsOneWidget);
    expect(find.text('Vehicle problem'), findsOneWidget);
    expect(find.text('Accident or road emergency'), findsOneWidget);
    expect(find.text('Rider behavior'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-confirmation')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Only end the trip after you have stopped in a safe place and the rider can exit safely.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep trip'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsOneWidget,
    );
    _expectNoException(tester);
  });

  testWidgets('Direct offer shows a visible expiry countdown', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
    // The seconds left are on the radar, inside its blue ring.
    final radar = find.byKey(const ValueKey<String>('home-radar-exclusive'));
    expect(
      find.descendant(of: radar, matching: find.textContaining(RegExp(r'^\d+s$'))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: radar,
        matching: find.byKey(const ValueKey<String>('radar-exclusive-ring')),
      ),
      findsOneWidget,
    );
    _expectNoException(tester);
  });

  testWidgets('Direct Home offer can appear without sheet/layout errors', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('105,80 kr'), findsOneWidget);
    expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Exclusive offer on Home: Radar-style card and an island note', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));
    await tester.pump(const Duration(milliseconds: 300));

    // The card: Comfort badge, black Exclusive mark, × to hide; card
    // payment, so no Cash badge, and not a reservation.
    final card = find.byKey(
      const ValueKey<String>('exclusive-offer-card-home-direct-close'),
    );
    expect(card, findsOneWidget);
    Finder inCard(Finder finder) =>
        find.descendant(of: card, matching: finder);
    expect(inCard(find.text('Exclusive')), findsOneWidget);
    expect(inCard(find.text('Comfort')), findsOneWidget);
    expect(inCard(find.text('Cash')), findsNothing);
    expect(inCard(find.textContaining('Reservation')), findsNothing);
    expect(inCard(find.byTooltip('Hide offer')), findsOneWidget);

    // The island says it too: info blue, with a bolt instead of the "i".
    expect(
      IslandMessages.posted.map((m) => m.title),
      contains('Exclusive ride'),
    );
    final face = find.byType(DigitalMessageFace);
    expect(find.descendant(of: face, matching: find.text('Exclusive ride')),
        findsOneWidget);
    expect(
      find.descendant(of: face, matching: find.byIcon(Icons.bolt_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: face,
        matching: find.byIcon(Icons.info_outline_rounded),
      ),
      findsNothing,
    );
    _expectNoException(tester);

    // × hides it: the card slides back into the sheet, then the radar
    // comes back.
    await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Only for you · pickup 3 min away'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Only for you · pickup 3 min away'), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Home sheet has two positions: closed and open', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.minHeight, 108);
    expect(panel.maxHeight, closeTo(812, 0.5),
        reason: "Open, the sheet reaches the status bar");
    expect(panel.parallaxEnabled, isTrue,
        reason: "The map rises with the sheet");
    expect(panel.snapPoint, isNull, reason: 'No middle stop');
    // The sheet's own spring settles it (immediately, in the finger's
    // direction), not the panel's built-in snap.
    expect(panel.panelSnapping, isFalse);
    _expectNoException(tester);
  });

  testWidgets('Home sheet release settles on a valid snap position', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHome(tester, const Size(375, 812));

    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));

    await tester.drag(find.byType(SlidingUpPanel), const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump(const Duration(milliseconds: 520));

    final position = panel.controller!.panelPosition;
    expect(position, anyOf(closeTo(0, 0.04), closeTo(1, 0.04)));
    _expectNoException(tester);
  });

  testWidgets(
    'Active ride route summary shows real optional stops expanded and collapsed',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        const MaterialApp(
          home: AcceptRide(
            pickupAddress: 'Kungsgatan 44, Stockholm',
            dropoffAddress: 'Fittjavägen, Botkyrka',
            stopAddresses: <String>[
              'Vasagatan 10, Stockholm',
              'Liljeholmen, Stockholm',
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await _expandActiveRideSheet(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-journey-card')),
        findsOneWidget,
      );
      // Every point, in order, as plain addresses.
      expect(find.text('Kungsgatan 44, Stockholm'), findsWidgets);
      expect(find.text('Vasagatan 10, Stockholm'), findsOneWidget);
      expect(find.text('Liljeholmen, Stockholm'), findsOneWidget);

      await _collapseActiveRideSheet(tester);
      expect(
        find.byKey(const ValueKey<String>('active-ride-compact-dock')),
        findsOneWidget,
      );
      // The flat bar names the next step and where it is.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('active-ride-compact-dock')),
          matching: find.text('Kungsgatan 44, Stockholm'),
        ),
        findsOneWidget,
      );
      // The flat bar keeps only the arrived pill; the slide action is on
      // the middle sheet.
      expect(
        find.byKey(const ValueKey<String>('active-ride-primary-action')),
        findsNothing,
      );
      _expectNoException(tester);
    },
  );

  testWidgets(
    'Active ride opens collapsed with one island and expands on demand',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        find.byKey(const ValueKey('trip-guidance-island')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('active-ride-navigation-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('active-ride-destination-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('active-ride-compact-dock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('active-ride-arrived-button')),
        findsNothing,
      );
      expect(find.byTooltip('Ride preferences'), findsOneWidget);
      expect(
        _activeRidePanel(tester).controller!.panelPosition,
        closeTo(0, .01),
      );
      // Tapping the bar lifts it to the middle sheet with the action.
      await tester.tap(find.byKey(const ValueKey('trip-bar-details')));
      await _advanceAnimation(tester, const Duration(milliseconds: 520));
      expect(
        find.byKey(const ValueKey('active-ride-arrived-button')),
        findsOneWidget,
      );
      await _expandActiveRideSheet(tester);
      expect(
        find.byKey(const ValueKey('active-ride-journey-card')),
        findsOneWidget,
      );
      _expectNoException(tester);
    },
  );

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

    await _middleActiveRideSheet(tester);
    // Middle sheet: call on the left, message on the right.
    expect(find.byTooltip('Call rider'), findsOneWidget);
    await tester.tap(find.byTooltip('Message rider'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(Chat), findsOneWidget);
    _expectNoException(tester);
  });

  testWidgets('Collapsed trip bar opens Ride preferences and trip details', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await _collapseActiveRideSheet(tester);
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
    await _advanceAnimation(tester, const Duration(milliseconds: 520));
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
      find.byKey(const ValueKey<String>('active-ride-journey-card')),
      findsOneWidget,
    );

    // Preferences live on the lifted sheet.
    await _middleActiveRideSheet(tester);
    await tester.tap(find.byTooltip('Ride preferences'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(Preferences), findsOneWidget);
    _expectNoException(tester);
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
      await _collapseActiveRideSheet(tester);
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
      await _expandActiveRideSheet(tester);
      expect(
        find.byKey(const ValueKey<String>('active-ride-wait-phase')),
        findsOneWidget,
      );
      _expectNoException(tester);
    });
  }

  testWidgets('Map gestures keep the collapsed trip sheet visible', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));
    await _collapseActiveRideSheet(tester);
    final dock = find.byKey(const ValueKey<String>('active-ride-compact-dock'));
    double dockTop() => tester.getTopLeft(dock).dy;
    final shown = dockTop();
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    const camera = CameraPosition(target: LatLng(59.33, 18.06), zoom: 15);

    // A camera move nobody touched (the app's own follow) changes nothing.
    map.onCameraMove!(camera);
    await _advanceAnimation(tester, const Duration(milliseconds: 600));
    expect(dockTop(), closeTo(shown, 1));

    // One finger only moves the map: the sheet stays.
    final drag = await tester.startGesture(const Offset(120, 400));
    map.onCameraMove!(camera);
    await drag.moveBy(const Offset(0, 40));
    await drag.up();
    await _advanceAnimation(tester, const Duration(milliseconds: 600));
    expect(dockTop(), closeTo(shown, 1));

    // Two fingers zoom: the sheet slides away, recenter pulses.
    final a = await tester.startGesture(const Offset(120, 400), pointer: 7);
    final b = await tester.startGesture(const Offset(220, 400), pointer: 8);
    await a.moveBy(const Offset(-30, 0));
    await b.moveBy(const Offset(30, 0));
    map.onCameraMove!(camera);
    await a.up();
    await b.up();
    await _advanceAnimation(tester, const Duration(milliseconds: 600));
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
    await _advanceAnimation(tester, const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dockTop(), closeTo(shown, 1));
    expect(
      find.byKey(const ValueKey<String>('active-ride-recenter-pulse')),
      findsNothing,
    );
    _expectNoException(tester);
  });

  testWidgets('Routing failure keeps the driver on the active trip', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(
      MaterialApp(home: AcceptRide(routeRepository: _FailingRouteRepository())),
    );
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey<String>('trip-guidance-island')),
      findsOneWidget,
    );
    _expectNoException(tester);
  });

  testWidgets('On-trip ride appears on screen with accept and deny', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));

    await _tapArrived(tester);
    await _slideActiveRideAction(tester);
    await tester.pump(const Duration(milliseconds: 2400));

    final ride = find.byKey(
      const ValueKey<String>('on-trip-radar-offer-button'),
    );
    expect(ride, findsOneWidget);
    expect(tester.getSize(ride).width, greaterThan(200));
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    _expectNoException(tester);
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
      _expectNoException(tester);
    },
  );
  testWidgets('Pickup slide names an arrival action', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text("I've arrived"), findsNothing);
    await _middleActiveRideSheet(tester);
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
    _expectNoException(tester);
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
    await _middleActiveRideSheet(tester);
    expect(find.text("I've arrived"), findsOneWidget);
    await _tapArrived(tester);
    expect(
      find.text('This stop needs a verified map location before arrival.'),
      findsOneWidget,
    );
    await _middleActiveRideSheet(tester);
    expect(find.text("I've arrived"), findsOneWidget);
    _expectNoException(tester);
  });
}

class _FailingRouteRepository implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    throw Exception('offline');
  }
}
