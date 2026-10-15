import 'dart:io';

import 'package:movera/presentation/driver/accept%20ride/island_waiting_motion.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/island_icons.dart';
import 'package:movera/presentation/driver/accept%20ride/island_morph.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';

Widget surface({
  int? seconds,
  bool waitingAtStop = false,
  VoidCallback? route,
  String waitingMessage = 'Waiting for Angelica',
  double width = 320,
  double textScale = 1,
  String? fontFamily,
  String? arrival,
  bool arrived = false,
  NavigationBanner? banner,
  double progress = .4,
  bool radarVisible = false,
  VoidCallback? radar,
}) => MaterialApp(
  theme: ThemeData(fontFamily: fontFamily),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('island-visual-proof'),
      child: SizedBox(
        width: width,
        height: 220,
        child: AdaptiveTripIsland(
          banner:
              banner ??
              const NavigationBanner(
                primary: 'Roundabout, exit 3',
                distanceLabel: '150 m',
                symbol: NavigationBannerSymbol.roundabout,
                roadName: 'Sveavägen',
              ),
          status: 'To pickup',
          address: 'Sveavägen 20',
          detail: 'Picking up Angelica',
          eta: '2 min',
          arrival: arrival,
          arrived: arrived,
          progress: progress,
          waitingSeconds: seconds,
          waitingAtStop: waitingAtStop,
          waitingMessage: waitingMessage,
          lastTripLabel: '120 kr',
          radarVisible: radarVisible,
          onRadar: radar ?? () {},
          onMenu: () {},
          onSearch: () {},
          onHistory: () {},
          onRoute: route ?? () {},
          onSafety: () {},
          onWait: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Record rendered guidance and alternating waiting views', (
    tester,
  ) async {
    String? font;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (file.existsSync()) {
        final loader = FontLoader('IslandProof')
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
        font = 'IslandProof';
      }
    }
    Future<void> capture(String name) async {
      await tester.pump();
      final size = tester.getSize(
        find.byKey(const ValueKey('island-morph-shell')),
      );
      // Frames include mid-morph sizes: always between Home and the route
      // island, never smaller than Home.
      expect(
        size.height,
        greaterThanOrEqualTo(TripIslandGeometry.height - .01),
      );
      expect(
        size.height,
        lessThanOrEqualTo(AdaptiveTripIsland.routeHeight + .01),
      );
      expect(size.width, greaterThanOrEqualTo(TripIslandGeometry.width - .01));
      expect(size.width, lessThanOrEqualTo(640 - 24));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('island-visual-proof')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/test-evidence/island-$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final stages = <String, NavigationBanner>{
      '01-pickup': const NavigationBanner(
        primary: 'Toward pickup · 450 m',
        distanceLabel: '',
        symbol: NavigationBannerSymbol.arrive,
      ),
      '02-straight': const NavigationBanner(
        primary: 'Continue ahead · 800 m',
        distanceLabel: '',
        symbol: NavigationBannerSymbol.straight,
      ),
      '03-right': const NavigationBanner(
        primary: 'Turn right · 180 m',
        distanceLabel: '',
        roadName: 'Sveavägen',
        symbol: NavigationBannerSymbol.right,
      ),
      '04-roundabout': const NavigationBanner(
        primary: 'Take 2nd exit',
        distanceLabel: 'Roundabout · 50 m',
        exitNumber: '2',
        exitAngleDegrees: 90,
        symbol: NavigationBannerSymbol.roundabout,
      ),
      '08-trip-started': const NavigationBanner(
        primary: 'Taking Angelica to destination',
        distanceLabel: '',
        symbol: NavigationBannerSymbol.arrive,
      ),
      '09-dropoff': const NavigationBanner(
        primary: 'Keep left · 300 m',
        distanceLabel: '',
        roadName: 'E4 toward Stockholm',
        symbol: NavigationBannerSymbol.slightLeft,
      ),
      '10-stop': const NavigationBanner(
        primary: 'Arriving at stop · 100 m',
        distanceLabel: '',
        symbol: NavigationBannerSymbol.arrive,
      ),
    };
    for (final entry in stages.entries) {
      await tester.pumpWidget(surface(fontFamily: font, banner: entry.value));
      await tester.pump(const Duration(seconds: 1));
      await capture(entry.key);
    }
    await tester.pumpWidget(
      surface(
        fontFamily: font,
        arrival: 'Pickup',
        banner: const NavigationBanner(
          primary: 'Pickup',
          distanceLabel: '',
          symbol: NavigationBannerSymbol.arrive,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await capture('05-arrival-pickup');
    await tester.pumpWidget(surface(seconds: 155, fontFamily: font));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      await capture('motion-${frame.toString().padLeft(3, '0')}');
    }
    await capture('06-timer');
    await tester.pumpWidget(surface(seconds: 156, fontFamily: font));
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      await capture('waiting-motion-${frame.toString().padLeft(3, '0')}');
    }
    for (
      var tick = 0;
      tick < 50 &&
          find.byKey(const ValueKey('island-waiting-name')).evaluate().isEmpty;
      tick++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Waiting for Angelica'), findsOneWidget);
    await capture('07-rider-message');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      surface(
        seconds: 155,
        fontFamily: font,
        waitingMessage: 'Waiting at stop 2',
        waitingAtStop: true,
      ),
    );
    await capture('10b-stop-timer');
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
    await capture('10c-stop-message');
    await tester.pumpWidget(
      surface(
        fontFamily: font,
        arrival: 'Destination',
        banner: const NavigationBanner(
          primary: 'Destination',
          distanceLabel: '',
          symbol: NavigationBannerSymbol.arrive,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 800));
    await capture('11-arrival-destination');
    await tester.tap(find.text('Arriving soon'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('trip-default-island')), findsOneWidget);
    await capture('00-default');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Route instructions use the route island: distance large, no cut text',
    (tester) async {
      await tester.pumpWidget(
        surface(
          banner: const NavigationBanner(
            primary: 'Turn right in 180 m',
            distanceLabel: '180 m',
            roadName: 'Sveavägen',
            symbol: NavigationBannerSymbol.right,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final shell = find.byKey(const ValueKey('island-morph-shell'));
      expect(
        tester.getSize(shell),
        const Size(320 - 24, AdaptiveTripIsland.routeHeight),
      );
      // The distance is shown once, large; the instruction without it.
      expect(find.text('Turn right'), findsOneWidget);
      expect(find.text('Sveavägen'), findsOneWidget);
      expect(find.byKey(const ValueKey('island-distance')), findsOneWidget);
      expect(find.byKey(const ValueKey('island-route-strip')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'No radar button on the route island; radar stays in the long-press tools',
    (tester) async {
      var radar = 0;
      await tester.pumpWidget(
        surface(radarVisible: true, radar: () => radar++),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('trip-guidance-island')), findsOneWidget);
      expect(find.byKey(const ValueKey('island-radar')), findsNothing);
      expect(find.byTooltip('Turn Exclusive offers on'), findsNothing);
      await tester.longPress(find.byKey(const ValueKey('island-morph-shell')));
      await tester.pumpAndSettle();
      // While driving a rider only Exclusive offers come (Q18).
      await tester.tap(find.text('Turn Exclusive offers on'));
      await tester.pumpAndSettle();
      expect(radar, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
  testWidgets('Large number is the distance to the point, never the route', (
    tester,
  ) async {
    String? number() {
      final distance = find.byKey(const ValueKey('island-distance'));
      if (distance.evaluate().isEmpty) return null;
      return tester.widget<Text>(distance).textSpan!.toPlainText();
    }

    Future<void> show({
      required NavigationBanner banner,
      String? arrival,
      bool arrived = false,
    }) async {
      await tester.pumpWidget(
        surface(banner: banner, arrival: arrival, arrived: arrived),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('trip-guidance-island')), findsOneWidget);
    }

    // Arriving soon: the distance to the pickup itself.
    await show(
      arrival: 'Pickup',
      banner: const NavigationBanner(
        primary: 'Pickup',
        distanceLabel: 'in 150 m',
        symbol: NavigationBannerSymbol.arrive,
      ),
    );
    expect(find.text('Arriving soon'), findsOneWidget);
    expect(number(), '150m');
    // At the pickup, waiting there, or no distance known: icon only.
    await show(
      arrival: 'Pickup',
      arrived: true,
      banner: const NavigationBanner(
        primary: 'Pickup ahead',
        distanceLabel: 'in 30 m',
        symbol: NavigationBannerSymbol.arrive,
      ),
    );
    expect(find.text('Near pickup'), findsOneWidget);
    expect(number(), isNull);
    await show(
      banner: const NavigationBanner(
        primary: 'Pickup',
        distanceLabel: 'Waiting for rider',
        symbol: NavigationBannerSymbol.arrive,
      ),
    );
    expect(number(), isNull);
    await show(
      banner: const NavigationBanner(
        primary: 'Navigate to pickup',
        distanceLabel: 'Route updating…',
      ),
    );
    expect(number(), isNull);
    // A turn: the distance to the turn.
    await show(
      banner: const NavigationBanner(
        primary: 'Exit left in 700 m',
        distanceLabel: '700 m',
        symbol: NavigationBannerSymbol.exitLeft,
      ),
    );
    expect(number(), '700m');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Every island has one 0.5 px white contour', (tester) async {
    List<Border> contours() => [
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('island-morph-shell')),
          matching: find.byType(DecoratedBox),
        ),
      ))
        if ((box.decoration as BoxDecoration?)?.border case final Border b
            when b.top.color.a > 0)
          b,
    ];
    // Route panel, status pill and waiting pill: the morph draws it.
    for (final island in [
      surface(),
      surface(
        banner: const NavigationBanner(
          primary: 'Turn right',
          distanceLabel: '',
          status: 'Recalculating route…',
        ),
      ),
      surface(seconds: 125),
    ]) {
      await tester.pumpWidget(island);
      await tester.pump(const Duration(seconds: 1));
      final border = contours().single;
      expect(border.top.width, IslandMorph.contourWidth);
      expect(border.top.color, Colors.white);
      expect(border.isUniform, isTrue);
    }
    // The Home island inside: its own contour only, 0.5 px once scaled.
    await tester.tap(find.byKey(const ValueKey('island-morph-shell')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('trip-default-island')), findsOneWidget);
    final border = contours().single;
    expect(border.top.color, Colors.white);
    expect(
      border.top.width * TripIslandGeometry.scale,
      closeTo(IslandMorph.contourWidth, 1e-9),
    );
    expect(
      tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(DigitalIslandShell),
          matching: find.byType(AnimatedContainer),
        ).first,
      ).decoration,
      isA<BoxDecoration>().having((d) => d.border, 'no second border', isNull),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('Same size: only the text changes, no morph', (tester) async {
    const right = NavigationBanner(
      primary: 'Turn right in 180 m',
      distanceLabel: '180 m',
      roadName: 'Sveavägen',
      symbol: NavigationBannerSymbol.right,
    );
    const left = NavigationBanner(
      primary: 'Turn left in 90 m',
      distanceLabel: '90 m',
      roadName: 'Kungsgatan',
      symbol: NavigationBannerSymbol.left,
    );
    await tester.pumpWidget(surface(banner: right));
    await tester.pump(const Duration(seconds: 1));
    final shell = find.byKey(const ValueKey('island-morph-shell'));
    final size = tester.getSize(shell);
    await tester.pumpWidget(surface(banner: left));
    await tester.pump();
    // The new text is there at once; the old one is gone, not fading.
    expect(find.text('Turn left'), findsOneWidget);
    expect(find.text('Turn right'), findsNothing);
    expect(tester.getSize(shell), size);
    for (final frame in [16, 100, 250]) {
      await tester.pump(Duration(milliseconds: frame));
      expect(tester.getSize(shell), size);
      expect(find.text('Turn right'), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Touch shows the Home island at exactly Home size', (
    tester,
  ) async {
    await tester.pumpWidget(surface());
    await tester.tap(find.byKey(const ValueKey('island-morph-shell')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('trip-default-island')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('island-morph-shell'))),
      const Size(TripIslandGeometry.width, TripIslandGeometry.height),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('Trip island sits exactly where Home draws its island', (
    tester,
  ) async {
    late double top;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
        child: Builder(
          builder: (context) {
            top = AdaptiveTripIsland.islandTop(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(top, 43, reason: 'Home: max(top padding - 4, 10).');
  });
  testWidgets('Normal islands stay compact at phone width', (tester) async {
    await tester.pumpWidget(surface(width: 375));
    final driving = tester.getSize(
      find.byKey(const ValueKey('island-morph-shell')),
    );
    expect(driving, const Size(375 - 24, AdaptiveTripIsland.routeHeight));
    await tester.pumpWidget(surface(width: 375, seconds: 155));
    await tester.pump(const Duration(seconds: 1));
    final waiting = tester.getSize(
      find.byKey(const ValueKey('island-morph-shell')),
    );
    expect(waiting.height, TripIslandGeometry.height);
    expect(waiting.width, lessThanOrEqualTo(TripIslandGeometry.maximumWidth));
    expect(waiting.width, closeTo(TripIslandGeometry.width, .001));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Waiting digit ticks keep geometry stable and stop message is distinct',
    (tester) async {
      await tester.pumpWidget(
        surface(seconds: 9, waitingMessage: 'Waiting at stop 2'),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('island-morph-shell')),
      );
      await tester.pumpWidget(
        surface(seconds: 10, waitingMessage: 'Waiting at stop 2'),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('island-morph-shell'))),
        size,
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Waiting at stop 2'), findsOneWidget);
      expect(find.text('Waiting for Angelica'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Long waiting names and larger text fit narrow screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface(
        seconds: 125,
        width: 280,
        textScale: 1.6,
        waitingMessage: 'Waiting for Angelica Alexandra',
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getSize(find.byKey(const ValueKey('island-morph-shell'))).width,
      lessThanOrEqualTo(256),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Island presents one maneuver and relocated route; touch restores after idle',
    (tester) async {
      var route = 0;
      await tester.pumpWidget(surface(route: () => route++));
      expect(find.text('Roundabout, exit 3'), findsOneWidget);
      // Swedish roundabout: counterclockwise, exit number on the icon.
      final cue = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<RoundaboutCuePainter>()
          .single;
      expect(cue.exitNumber, '3');
      expect(find.text('Sveavägen 20'), findsNothing);
      expect(find.text('To pickup'), findsNothing);
      expect(find.text('Sveavägen'), findsOneWidget);
      await tester.tap(find.byTooltip('Trip route and options'));
      await tester.pump();
      expect(
        route,
        1,
        reason: 'Touching the island must not swallow its controls.',
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('trip-default-island')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('trip-default-island')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.byKey(const ValueKey('trip-guidance-island')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trip-default-island')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Waiting alternates timer and rider name, then disposes timers', (
    tester,
  ) async {
    await tester.pumpWidget(surface(seconds: 125));
    expect(
      find.byWidgetPredicate(
        (w) => w is IslandRollingClock && w.text == '02:05',
      ),
      findsOneWidget,
    );
    expect(find.text('Waiting for Angelica'), findsNothing);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Waiting for Angelica'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is IslandRollingClock && w.text == '02:05',
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.byWidgetPredicate(
        (w) => w is IslandRollingClock && w.text == '02:05',
      ),
      findsOneWidget,
    );
    expect(find.text('Waiting for Angelica'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
