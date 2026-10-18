import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/finish_soon_sheet.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

SlidingUpPanel _panel(WidgetTester tester) =>
    tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _middle(WidgetTester tester) async {
  if (find.byKey(const ValueKey('active-ride-arrived-button')).evaluate().isNotEmpty ||
      find.byKey(const ValueKey('active-ride-primary-action')).evaluate().isNotEmpty) {
    return;
  }
  _panel(tester).controller!.animatePanelToSnapPoint();
  await _settle(tester, 17);
}

Future<void> _full(WidgetTester tester) async {
  await _settle(tester, 20);
  _panel(tester).controller!.open();
  await _settle(tester, 17);
}

Future<void> _startTrip(WidgetTester tester) async {
  await _middle(tester);
  await tester.tap(find.byKey(const ValueKey('active-ride-arrived-button')));
  await _settle(tester, 6);
  await _middle(tester);
  final slide = find.byKey(const ValueKey('active-ride-primary-action'));
  await tester.drag(slide, const Offset(320, 0));
  await _settle(tester, 6);
}

Future<void> _pumpRide(WidgetTester tester) async {
  WaybillStore.reset();
  addTearDown(() {
    WaybillStore.reset();
    tester.binding.setSurfaceSize(null);
  });
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(
    const MaterialApp(home: AcceptRide(fare: '111,02 kr', category: 'Comfort')),
  );
  await tester.pump(const Duration(milliseconds: 160));
}

void main() {
  setUp(() {
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  testWidgets('Trip sheet follows the finger and a flick settles without a jump', (
    tester,
  ) async {
    await _pumpRide(tester);
    // Tap the bar: the middle sheet.
    await tester.tap(find.byKey(const ValueKey('active-ride-compact-dock')));
    await _settle(tester, 20);
    double top() =>
        tester.getTopLeft(find.byKey(const ValueKey('active-ride-panel'))).dy;
    final controller = _panel(tester).controller!;
    final middle = controller.panelPosition;
    expect(middle, closeTo(_panel(tester).snapPoint!, 0.01));

    // A quick flick up: 20 px a frame, then let go while still moving.
    final gesture = await tester.createGesture();
    var time = Duration.zero;
    await gesture.down(Offset(300, top() + 40), timeStamp: time);
    var last = top();
    var biggest = 0.0;
    for (var i = 0; i < 4; i++) {
      time += const Duration(milliseconds: 16);
      await gesture.moveBy(const Offset(0, -20), timeStamp: time);
      await tester.pump(const Duration(milliseconds: 16));
      // 1:1 with the finger from the first frame (no dead zone, no jump
      // when the full sheet's content is measured).
      expect(top() - last, closeTo(-20, 0.5));
      last = top();
    }
    await gesture.up(timeStamp: time);
    var settledAt = -1;
    for (var frame = 1; frame <= 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      biggest = math.max(biggest, (top() - last).abs());
      // The release keeps going up: it never stops dead or turns back.
      expect(top(), lessThanOrEqualTo(last + 0.01));
      last = top();
      if (settledAt < 0 && controller.panelPosition > 0.995) { settledAt = frame * 16; }
    }
    expect(controller.panelPosition, closeTo(1, 0.005));
    expect(biggest, lessThan(20), reason: 'no step bigger than the finger moved');
    expect(settledAt, inInclusiveRange(16, 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pickup sheet shows the trip card; old rows are gone', (tester) async {
    await _pumpRide(tester);
    await _full(tester);

    final card = find.byKey(const ValueKey('active-ride-current-trip-card'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Your trip')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('111,02 kr')), findsOneWidget);
    expect(find.byKey(const ValueKey('current-trip-more')), findsOneWidget);
    expect(find.text('Safety'), findsNothing);
    expect(find.text('Trip options'), findsNothing);
    expect(find.byKey(const ValueKey('active-ride-safety-tile')), findsNothing);
    expect(find.byKey(const ValueKey('active-ride-trip-options')), findsNothing);
    // No radar before pickup.
    expect(find.byKey(const ValueKey('trip-radar-dock')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel next trip uses the reasons sheet and keeps the current trip', (
    tester,
  ) async {
    await _pumpRide(tester);
    await _startTrip(tester);
    await tester.pump(const Duration(milliseconds: 2400));
    final match = find.byKey(const ValueKey('on-trip-radar-match-next'));
    await tester.ensureVisible(match);
    await tester.tap(match);
    await tester.pump(const Duration(milliseconds: 1600));
    await _full(tester);

    expect(find.byKey(const ValueKey('secured-next-trip-details')), findsOneWidget);
    expect(WaybillStore.next, isNotNull);

    await tester.tap(find.byKey(const ValueKey('next-trip-more')));
    await _settle(tester, 4);
    expect(find.text('Open waybill'), findsOneWidget);
    expect(find.text('Contact rider'), findsOneWidget);
    expect(find.text('Safety toolkit'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-trip-cancel-option')));
    await _settle(tester, 4);

    expect(
      find.byKey(const ValueKey('next-trip-cancellation-reasons-sheet')),
      findsOneWidget,
    );
    expect(find.text('Current trip is taking longer'), findsOneWidget);
    // Same reason flags: the car problem doesn't count, the others do.
    expect(find.text('Your car can’t make the next trip · Doesn’t count'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('trip-cancel-reason-next_trip_current_running_late')),
    );
    await _settle(tester, 4);
    expect(find.text('Cancel the next trip?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-trip-cancellation')));
    await _settle(tester, 4);

    expect(find.byKey(const ValueKey('secured-next-trip-details')), findsNothing);
    expect(WaybillStore.next, isNull);
    expect(find.byKey(const ValueKey('active-ride-panel-onTrip')), findsOneWidget);
    expect(find.byKey(const ValueKey('active-ride-current-trip-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Holding the trip radar stops and starts next-trip offers', (
    tester,
  ) async {
    await _pumpRide(tester);
    await _startTrip(tester);
    // Let the first demo offer go by so none pops up during the holds.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.tap(find.byKey(const ValueKey('on-trip-radar-deny')));
    await _settle(tester, 4);
    await _full(tester);

    expect(find.byKey(const ValueKey('trip-radar-dock')), findsOneWidget);
    expect(find.text('Stop radar'), findsOneWidget);

    final hold = find.byKey(const ValueKey('trip-radar-hold'));
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await _settle(tester, 10);
    expect(find.text('Stop radar'), findsOneWidget);
    await _settle(tester, 16);
    await gesture.up();
    await tester.pump();
    expect(find.text('Start radar'), findsOneWidget);

    final again = await tester.startGesture(tester.getCenter(hold));
    await _settle(tester, 26);
    await again.up();
    await tester.pump();
    expect(find.text('Stop radar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Finish so soon sheet: Back to ride and Finish trip', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await showFinishSoonSheet(context, minutesSincePickup: 1);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('Finish so soon?'), findsOneWidget);
    expect(
      find.text('You picked up the rider 1 min ago. Finish only if the trip really ended.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to ride'));
    await tester.pump();
    expect(answer, isFalse);
    expect(find.text('Finish so soon?'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(find.text('Finish trip'));
    await tester.pump();
    expect(answer, isTrue);
  });
}
