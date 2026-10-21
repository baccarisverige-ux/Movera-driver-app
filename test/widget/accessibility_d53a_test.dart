// Wave 5 D5.3 (part a): small semantics checks, one per audit finding.
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
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

Widget _island({NavigationBanner? banner, double progress = .42}) =>
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
            waitingMessage: 'Waiting for Angelica',
            lastTripLabel: '120 kr',
            onRadar: () {},
            onMenu: () {},
            onSearch: () {},
            onHistory: () {},
            onRoute: () {},
            onSafety: () {},
            onWait: () {},
          ),
        ),
      ),
    );

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
}
