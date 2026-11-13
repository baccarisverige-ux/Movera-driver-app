import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/deferred_screens.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Device run 7 (2026-11-12): on the trip screen the side menu could not be
// closed with the phone's Back. The trip's PopScope(canPop: false) beat the
// open drawer, so Back did nothing. Back now closes the menu first and
// still never leaves an active trip.

Future<void> _settle(WidgetTester tester, [int frames = 30]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpTrip(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  CompletionJournal.resetForTesting();
  IslandMessages.reset();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final realtime = MemoryDriverRealtime();
  addTearDown(realtime.dispose);
  final session = DriverSessionController()..setOnline(true);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                // The trip's own route, as Home and the Radar push it.
                onPressed: () => Navigator.push(
                  context,
                  ActiveRideTransition(
                    AcceptRide(
                      tripId: 'back-trip',
                      riderName: 'Angelica',
                      initialStage: ActiveRideStage.headingToPickup,
                      activeRideRepository: MemoryActiveRideRepository(),
                      sessionController: session,
                      realtime: realtime,
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Home'));
  await _settle(tester, 12);
  expect(find.byType(AcceptRide), findsOneWidget);
}

ScaffoldState _tripScaffold(WidgetTester tester) => tester.state(
  find
      .descendant(of: find.byType(AcceptRide), matching: find.byType(Scaffold))
      .first,
);

Future<void> _openMenu(WidgetTester tester) async {
  _tripScaffold(tester).openDrawer();
  await _settle(tester, 12);
  expect(_tripScaffold(tester).isDrawerOpen, isTrue);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _settle(tester, 20);
}

/// The trip screen is the top route and its menu is closed.
void _expectTripOnTop(WidgetTester tester) {
  expect(find.byType(AcceptRide), findsOneWidget);
  expect(find.text('Home'), findsNothing);
  expect(_tripScaffold(tester).isDrawerOpen, isFalse);
  expect(find.byKey(const ValueKey('driver-side-menu')), findsNothing);
  expect(
    ModalRoute.of(tester.element(find.byType(AcceptRide)))!.isCurrent,
    isTrue,
  );
}

Future<void> _tearDown(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadDeferredScreens);

  testWidgets('trip: menu open, Back closes the menu, trip on top', (
    tester,
  ) async {
    await _pumpTrip(tester);
    await _openMenu(tester);

    await _back(tester);

    _expectTripOnTop(tester);
    await _tearDown(tester);
  });

  testWidgets(
    'trip: menu, Ride history, Back, Back closes the menu, trip on top',
    (tester) async {
      await _pumpTrip(tester);
      await _openMenu(tester);

      await tester.tap(find.text('Ride history').first);
      await _settle(tester, 30);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'DriverRideHistory',
        ),
        findsOneWidget,
      );

      // First Back closes Ride history and shows the menu again.
      await _back(tester);
      expect(_tripScaffold(tester).isDrawerOpen, isTrue);
      // Second Back closes the menu.
      await _back(tester);

      _expectTripOnTop(tester);
      await _tearDown(tester);
    },
  );

  testWidgets('trip: Back with no menu open never leaves the trip', (
    tester,
  ) async {
    await _pumpTrip(tester);

    await _back(tester);
    await _back(tester);

    _expectTripOnTop(tester);
    await _tearDown(tester);
  });

  testWidgets('trip: Back after the menu closed still stays on the trip', (
    tester,
  ) async {
    await _pumpTrip(tester);
    await _openMenu(tester);
    await _back(tester);
    _expectTripOnTop(tester);

    await _back(tester);

    _expectTripOnTop(tester);
    await _tearDown(tester);
  });
}
