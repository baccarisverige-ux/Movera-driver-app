// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Full radar orb responds near its outer edge', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

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
    expectNoException(tester);
  });

  testWidgets(
    'Exclusive Radar stays separate and Radar offers survive list open-close',
    (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sound = FakeRadarSound();
      RadarOfferSound.debugPlayer = sound;
      addTearDown(() => RadarOfferSound.debugPlayer = null);
      final vibrations = <List<int>>[];
      OfferVibration.debugVibrate = vibrations.add;
      OfferAlertSettings.reset();
      addTearDown(() => OfferVibration.debugVibrate = null);
      await pumpHome(tester, const Size(375, 812));

      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 1550));
      expect(find.text('LIVE'), findsOneWidget);
      // R15-4: scanning, the soft sweep turns once every 3.3 s.
      expect(await wedgeTurnsPerSecond(tester), closeTo(0.3, 0.01));

      // Exclusive Radar offer uses its own exclusive surface.
      await tester.pump(const Duration(milliseconds: 2300));
      // One total: the driver's 78,60 kr share of the 104,80 kr fare
      // (owner decision 2026-10-26) plus 1,00 kr pickup pay (Comfort,
      // 0.9 km / 3 min: 1 km and 2 min free, 1 kr/min).
      expect(find.text('79,60 kr'), findsOneWidget);
      expect(find.text('Kungsgatan 42'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('radar-home-deck')),
        findsNothing,
      );
      // G4-E6 (owner "Sound + vibration"): the Exclusive offer rings; a
      // tap anywhere stops it.
      expect(sound.calls, ['start']);
      // Vibration is on by default (owner 2026-10-31): one for the offer.
      expect(vibrations, [OfferAlertRule.vibratePattern]);
      // Exclusive keeps its own radar: no soft sweep.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('home-radar-exclusive')),
          matching: find.byKey(const ValueKey<String>('radar-sweep-wedge')),
        ),
        findsNothing,
      );
      expectNoException(tester);

      // Let the outside offer expire, then allow the first Radar offer to arrive.
      // The Exclusive offer's time to accept (Dispatch, 15 s).
      await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
      await tester.pump(const Duration(milliseconds: 900));

      final card = find.byKey(
        const ValueKey<String>('radar-offer-card-nearby-1'),
      );
      expect(card, findsOneWidget);
      expect(find.text('Kungsgatan 42'), findsNothing);
      // While Radar offers show, the radar reads Accept for the front card.
      expect(
        find.byKey(const ValueKey<String>('home-radar-accept')),
        findsOneWidget,
      );
      expect(find.text('MATCH'), findsOneWidget);
      // R15-3/4: a black MATCH, and the sweep turns once every 2 s.
      final accept = find.byKey(const ValueKey<String>('home-radar-accept'));
      final match = tester.widget<Text>(
        find.descendant(
          of: accept,
          matching: find.byKey(const ValueKey<String>('radar-status-found')),
        ),
      );
      expect(match.style!.color!.withValues(alpha: 1), MoveraRadarOrb.offerInk);
      expect(await wedgeTurnsPerSecond(tester, accept), closeTo(0.5, 0.01));
      // G4-E6: Radar offers stay quiet (until v0.18.6 they rang, R15-5).
      // The Exclusive offer's sound stopped when it left.
      expect(sound.calls, ['start', 'stop']);
      await tester.tapAt(const Offset(187, 300));
      await tester.pump();
      expect(sound.calls, ['start', 'stop']);
      expectNoException(tester);

      // Owner N1: no "ALL OFFERS" pill above the deck; the island's
      // middle says "1 offer · radar" and opens the full Radar list.
      expect(
        find.byKey(const ValueKey<String>('radar-home-all-offers')),
        findsNothing,
      );
      final allOffers = find.byKey(
        const ValueKey<String>('island-radar-offers'),
      );
      expect(
        tester.widget<Text>(allOffers).textSpan!.toPlainText(),
        '11 offers · radar',
      );
      await tester.tap(allOffers);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byType(RideRequests), findsOneWidget);
      expectNoException(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 160));

      // Returning to Home keeps the Home Radar opportunity alive.
      expect(find.byType(RideRequests), findsNothing);
      expect(card, findsOneWidget);
      expectNoException(tester);
    },
  );

  testWidgets('Home Radar deck takes new trips and drops a taken one', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(320, 700));
    IslandMessages.reset();
    Finder card(String id) =>
        find.byKey(ValueKey<String>('radar-offer-card-$id'));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));

    // Outside offer first, still isolated from Radar.
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('79,60 kr'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('radar-home-deck')), findsNothing);
    expectNoException(tester);

    // Expire outside offer and receive the first Radar offer.
    // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    expect(card('nearby-1'), findsOneWidget);
    expectNoException(tester);

    // New Radar matches join the deck behind it; no refresh on Home.
    await tester.pump(const Duration(milliseconds: 3100));
    expect(card('nearby-2'), findsOneWidget);
    expect(refreshIcon, findsNothing);
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(card('nearby-4'), findsOneWidget);
    // The first trip stays in front: it sits lowest, the others peek above.
    expect(
      tester.getTopLeft(card('nearby-1')).dy,
      greaterThan(tester.getTopLeft(card('nearby-4')).dy),
    );
    expectNoException(tester);

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
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 3000));
    expect(card('nearby-4'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('Swiping the front Radar card sends it to the back', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

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
      (a, b) => tester.getTopLeft(card(a)).dy >= tester.getTopLeft(card(b)).dy
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
    expectNoException(tester);
  });

  testWidgets('Exclusive Radar hides Home dash and normal Radar restores it', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));

    // The Exclusive sheet covers the dock and its dash, like a
    // reservation request.
    expect(
      find.byKey(const ValueKey<String>('home-exclusive-sheet')),
      findsOneWidget,
    );

    // The Exclusive offer's time to accept (Dispatch, 15 s).
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));

    final radarDashes = tester.widgetList<RadarEdgeDash>(
      find.byType(RadarEdgeDash),
    );
    expect(
      radarDashes.any((dash) => dash.color == MoveraRadarOrb.offerAccent),
      isTrue,
    );
    expectNoException(tester);
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
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(card, findsNothing);
    expectNoException(tester);
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
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    // A short banner says why; the card fades out of the list.
    expect(find.text('Taken by another driver'), findsOneWidget);
    expect(tester.widget<FilledButton>(match).onPressed, isNull);
    expect(find.byType(AcceptRide), findsNothing);
    expectNoException(tester);
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
    expect(
      find.byKey(const ValueKey<String>('radar-live-dot')),
      findsOneWidget,
    );
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
      expect(find.byKey(ValueKey<String>('radar-match-$id')), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('radar-offer-dismiss-$id')),
        findsOneWidget,
      );
    }
    expectNoException(tester);

    // × removes a card from the list.
    final dismiss = find.byKey(
      ValueKey<String>('radar-offer-dismiss-${ids.first}'),
    );
    await tester.tap(dismiss);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(ValueKey<String>('radar-offer-card-${ids.first}')),
      findsNothing,
    );
    expectNoException(tester);
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
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Trip matched'), findsOneWidget);
    final notice = tester.getRect(
      find.byKey(const ValueKey<String>('radar-match-notice')),
    );
    expect(notice.top, closeTo(0, 0.5));
    expect(notice.left, closeTo(0, 0.5));
    expect(notice.width, closeTo(375, 1));
    expectNoException(tester);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.byType(AcceptRide), findsOneWidget);
    expectNoException(tester);
  });
}
