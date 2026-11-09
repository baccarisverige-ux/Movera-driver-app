// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('On-trip options allow safe early cancellation with reasons', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    // driver-u3: over a stand-in Home, as in the app. With AcceptRide as the
    // only route a real cancel left it mounted with the onTrip marker, so
    // the Keep trip checks could not fail.
    final active = MemoryActiveRideRepository();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Home stand-in')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => AcceptRide(activeRideRepository: active),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    await tapArrived(tester);

    await slideActiveRideAction(tester);

    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
      findsOneWidget,
    );

    // The relocated island action remains available while the radar offer is visible.
    await advanceAnimation(tester, const Duration(milliseconds: 700));
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
    // Nothing of a cancel happened.
    expect(
      ModalRoute.of(tester.element(find.byType(AcceptRide)))!.isCurrent,
      isTrue,
    );
    expect(find.text('Home stand-in'), findsNothing);
    expect(find.textContaining('Trip ended early'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsTripHistoryRepository.key), isNull);
    expect(await active.read(), isNotNull);
    expectNoException(tester);
  });

  testWidgets('Direct offer shows a visible expiry countdown', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('Kungsgatan 42'), findsOneWidget);
    // The time left runs on the radar's hairline blue ring; the orb
    // itself reads MATCH (R11-8).
    final radar = find.byKey(const ValueKey<String>('home-radar-exclusive'));
    expect(
      find.descendant(of: radar, matching: find.text('MATCH')),
      findsOneWidget,
    );
    final ring = find.descendant(
      of: radar,
      matching: find.byKey(const ValueKey<String>('radar-exclusive-ring')),
    );
    expect(ring, findsOneWidget);
    double left() =>
        (tester.widget<CustomPaint>(ring).painter! as ExclusiveTimeRingPainter)
            .timeLeft;
    final before = left();
    await tester.pump(const Duration(seconds: 2));
    expect(left(), lessThan(before));
    expectNoException(tester);
  });

  testWidgets('Direct Home offer can appear without sheet/layout errors', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('79,60 kr'), findsOneWidget);
    expect(find.text('Kungsgatan 42'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Exclusive offer on Home: the request sheet and an island note', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 3800));
    await tester.pump(const Duration(milliseconds: 300));

    // The sheet: Comfort chip, the grey countdown pill, the down arrow;
    // card payment, so no Cash chip, and not a reservation.
    final card = find.byKey(
      const ValueKey<String>('exclusive-offer-card-home-direct-close'),
    );
    expect(card, findsOneWidget);
    Finder inCard(Finder finder) => find.descendant(of: card, matching: finder);
    expect(inCard(find.textContaining('Exclusive for you · ')), findsOneWidget);
    expect(inCard(find.text('Comfort')), findsOneWidget);
    expect(inCard(find.text('Cash')), findsNothing);
    expect(inCard(find.textContaining('Reservation')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('direct-offer-dismiss')),
      findsOneWidget,
    );

    // The island says it too: info blue, with a bolt instead of the "i".
    expect(
      IslandMessages.posted.map((m) => m.title),
      contains('Exclusive ride'),
    );
    final face = find.byType(DigitalMessageFace);
    expect(
      find.descendant(of: face, matching: find.text('Exclusive ride')),
      findsOneWidget,
    );
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
    expectNoException(tester);

    // The down arrow skips it: the sheet slides down, then Home is
    // normal again.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const ValueKey<String>('direct-offer-dismiss')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Kungsgatan 42'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Kungsgatan 42'), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Home sheet has two positions: closed and open', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.minHeight, 108);
    expect(
      panel.maxHeight,
      closeTo(812, 0.5),
      reason: "Open, the sheet reaches the status bar",
    );
    expect(
      panel.parallaxEnabled,
      isTrue,
      reason: "The map rises with the sheet",
    );
    expect(panel.snapPoint, isNull, reason: 'No middle stop');
    // The sheet's own spring settles it (immediately, in the finger's
    // direction), not the panel's built-in snap.
    expect(panel.panelSnapping, isFalse);
    expectNoException(tester);
  });

  testWidgets('Home sheet release settles on a valid snap position', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));

    await tester.drag(find.byType(SlidingUpPanel), const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump(const Duration(milliseconds: 520));

    final position = panel.controller!.panelPosition;
    expect(position, anyOf(closeTo(0, 0.04), closeTo(1, 0.04)));
    expectNoException(tester);
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
      await expandActiveRideSheet(tester);

      expect(
        find.byKey(const ValueKey<String>('active-ride-current-trip-card')),
        findsOneWidget,
      );
      // Every point, in order, as plain addresses.
      expect(find.text('Kungsgatan 44, Stockholm'), findsWidgets);
      expect(find.text('Vasagatan 10, Stockholm'), findsOneWidget);
      expect(find.text('Liljeholmen, Stockholm'), findsOneWidget);

      await collapseActiveRideSheet(tester);
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
      expectNoException(tester);
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
      expect(find.byTooltip('Trip settings'), findsOneWidget);
      expect(
        activeRidePanel(tester).controller!.panelPosition,
        closeTo(0, .01),
      );
      // Tapping the bar lifts it to the middle sheet with the action.
      await tester.tap(find.byKey(const ValueKey('trip-bar-details')));
      await advanceAnimation(tester, const Duration(milliseconds: 520));
      expect(
        find.byKey(const ValueKey('active-ride-arrived-button')),
        findsOneWidget,
      );
      await expandActiveRideSheet(tester);
      expect(
        find.byKey(const ValueKey('active-ride-current-trip-card')),
        findsOneWidget,
      );
      expectNoException(tester);
    },
  );
}
