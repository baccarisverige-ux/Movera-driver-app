// Wave 5 D5.3 (part a): small semantics checks, one per audit finding.
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_card.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

Future<void> _frames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The trip screen at [stage], its sheet at the middle snap point.
Future<void> _trip(WidgetTester tester, ActiveRideStage stage) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: AcceptRide(
        initialStage: stage,
        activeRideRepository: MemoryActiveRideRepository(),
      ),
    ),
  ));
  await _frames(tester);
  tester
      .widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last)
      .controller!
      .animatePanelToSnapPoint();
  await _frames(tester, 14);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Widget _island({
  NavigationBanner? banner,
  double progress = .42,
  VoidCallback? onRoute,
  String? navigationStatus,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 220,
          child: AdaptiveTripIsland(
            banner: banner,
            status: 'To pickup',
            address: 'Sveavägen 20',
            detail: 'Picking up Angelica',
            eta: '2 min',
            progress: progress,
            navigationStatus: navigationStatus,
            waitingMessage: 'Waiting for Angelica',
            lastTripLabel: '120 kr',
            onRadar: () {},
            onMenu: () {},
            onSearch: () {},
            onHistory: () {},
            onRoute: onRoute ?? () {},
            onSafety: () {},
            onWait: () {},
          ),
        ),
      ),
    );

/// The island's one button node (it reads the ETA among the rest).
SemanticsNode _islandNode(WidgetTester tester) =>
    tester.getSemantics(find.bySemanticsLabel(RegExp('2 min')).first);

void main() {
  testWidgets('driver-u63: the trip slide is read once', (tester) async {
    final semantics = tester.ensureSemantics();
    await _trip(tester, ActiveRideStage.waitingForRider);
    final slide = find.bySemanticsLabel(RegExp('start trip', caseSensitive: false));
    expect(slide, findsOneWidget);
    final node = tester.getSemantics(slide);
    // One label, not the action merged with the slide's own text.
    expect(node.label, isNot(contains('\n')), reason: node.label);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await _unmount(tester);
    semantics.dispose();
  });

  testWidgets('driver-u67: "I\'ve arrived" away from pickup is readable '
      'and says why', (tester) async {
    final semantics = tester.ensureSemantics();
    final previous = DriverRuntimeConfig.current;
    // A real build: arriving needs a GPS fix near the pickup.
    DriverRuntimeConfig.current = DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: previous.externalRouting,
      skipAccountActivation: previous.skipAccountActivation,
      liveMapTicker: previous.liveMapTicker,
      reservationPopup: previous.reservationPopup,
      islandHint: previous.islandHint,
      radarSound: previous.radarSound,
      adminDemoOffers: previous.adminDemoOffers,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    await _trip(tester, ActiveRideStage.headingToPickup);
    final button =
        find.byKey(const ValueKey<String>('active-ride-arrived-button'));
    final style = tester.widget<FilledButton>(button).style!;
    // 5F6B72 on EEEFF1 is about 5:1 (8E979B was 2.6:1).
    expect(style.foregroundColor!.resolve(<WidgetState>{}),
        const Color(0xFF5F6B72));
    expect(tester.getSemantics(button).hint,
        'Move within 100 m of the pickup to arrive.');
    await _unmount(tester);
    semantics.dispose();
  });

  group('the route island speaks the driver\'s language', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DriverLanguage.choose('fr');
    });

    testWidgets('driver-u90: the turn cue reads the turn, not its Dart name',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_island(
        banner: const NavigationBanner(
          primary: 'Sveavägen',
          distanceLabel: '150 m',
          symbol: NavigationBannerSymbol.slightLeft,
        ),
      ));
      await _frames(tester, 40);
      // The island is one button; the cue is the first thing it reads.
      final label = _islandNode(tester).label;
      expect(label.split('\n').first, 'Tournez légèrement à gauche');
      expect(label, isNot(contains('slightLeft')));
      await _unmount(tester);
      semantics.dispose();
    });

    testWidgets('driver-48: route progress is read in French',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_island(
        banner: const NavigationBanner(
          primary: 'Continuez tout droit',
          distanceLabel: '1,2 km',
          symbol: NavigationBannerSymbol.straight,
        ),
      ));
      await _frames(tester, 40);
      final island = _islandNode(tester);
      expect(island.label, contains('Progression de l’itinéraire'));
      expect(island.value, '42 %');
      await _unmount(tester);
      semantics.dispose();
    });
  });

  group('driver-u94: trip options open from a 48 px touch box', () {
    testWidgets('the trip card ••• is 48 x 48', (tester) async {
      const more = ValueKey<String>('more');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TripCard(
            title: 'Your trip',
            fare: '111,02 kr',
            points: const [],
            footer: 'Comfort · Nils',
            onMore: () {},
            moreKey: more,
          ),
        ),
      ));
      expect(tester.getSize(find.byKey(more)), const Size(48, 48));
    });

    testWidgets('the island info button takes touches around it',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_island(
        onRoute: () => opened++,
        navigationStatus: 'Route unavailable — retry',
      ));
      await _frames(tester, 40);
      expect(find.byKey(const ValueKey('trip-status-island')), findsOneWidget);
      final info = tester.getRect(find.byIcon(Icons.info_outline_rounded));
      final island =
          tester.getRect(find.byKey(const ValueKey('trip-status-island')));
      // 44 px down from the icon's top, 48 px across from its left edge:
      // beside the 24 px slot and below the island both open the options.
      await tester.tapAt(Offset(info.left + 46, info.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(info.top + 44, greaterThan(island.bottom));
      await tester.tapAt(Offset(info.center.dx, info.top + 44 - 0.5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(opened, 2);
      await _unmount(tester);
    });
  });

  for (final (name, screen, words) in <(String, Widget, String Function())>[
    ('the terms consent', const DriverCreateAccount(),
        () => tr.byContinuingIAgreeTo),
    ('the code explanation', const DriverPhoneVerification(),
        () => tr.codeDeliveryUnavailableDemo),
  ]) {
    testWidgets('driver-u102: $name follows the system text size',
        (tester) async {
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: screen,
        ),
      ));
      await tester.pump();
      final text = tester.widget<RichText>(find.byWidgetPredicate((w) =>
          w is RichText && w.text.toPlainText().contains(words())));
      expect(text.textScaler, const TextScaler.linear(1.5));
    });
  }
}
