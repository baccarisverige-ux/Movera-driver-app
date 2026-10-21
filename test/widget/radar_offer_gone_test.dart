import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  testWidgets('a front Radar trip that disappears blurs out with an island note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // nearby-1 is the first Radar trip on Home; here it vanishes from the
    // feed (rider cancelled, expired…) shortly after it appears.
    final dispatch = DemoDispatchRepository(
      externalClaimOfferId: 'nearby-1',
      externalClaimDelay: DriverOfferRules.current.exclusiveAcceptTime +
          const Duration(milliseconds: 4000),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    final card = find.byKey(const ValueKey<String>('radar-offer-card-nearby-1'));
    expect(card, findsOneWidget);

    // It was the front card: the island says why, the card blurs out.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));
    final said = IslandMessages.posted.map((m) => m.title);
    expect(said, contains('Trip unavailable'));
    expect(said, isNot(contains('Taken by another driver')));
    expect(find.byType(ImageFiltered), findsWidgets);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    dispatch.dispose();
  });

  testWidgets('a Radar trip not picked in time keeps its card but Match fades', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dispatch = DemoDispatchRepository(
      externalClaimDelay: const Duration(minutes: 5),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    final match = find.byKey(const ValueKey<String>('radar-match-nearby-1'));
    expect(tester.widget<FilledButton>(match).onPressed, isNotNull);

    // Past Dispatch's time on the radar (15 s).
    await tester.pump(DriverOfferRules.current.radarTime + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(match, findsOneWidget);
    expect(tester.widget<FilledButton>(match).onPressed, isNull);
    expect(
      find.byKey(const ValueKey<String>('radar-offer-card-nearby-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    dispatch.dispose();
  });

  testWidgets('new Radar trips join the deck by themselves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dispatch = DemoDispatchRepository(
      externalClaimDelay: const Duration(minutes: 5),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 6200));
    await tester.pump(const Duration(milliseconds: 400));
    // New trips join the deck by themselves, no refresh on Home; the
    // badge on top counts every open Radar trip.
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('radar-offer-card-'),
    );
    expect(cards.evaluate().length, greaterThan(1));
    expect(find.byKey(const ValueKey<String>('radar-home-refresh')), findsNothing);
    final badge = find.byKey(const ValueKey<String>('radar-home-all-offers'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('ALL OFFERS')),
      findsOneWidget,
    );
    // Eleven, not twelve: the Electric trip is not a category the demo
    // car drives (Q27). The cash demo trips (R8-4, R9) and the two
    // RideCheck demo trips count too.
    expect(find.descendant(of: badge, matching: find.text('11')), findsOneWidget);

    // The radar reads Accept while the deck shows.
    expect(find.byKey(const ValueKey<String>('home-radar-accept')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    dispatch.dispose();
  });
}
