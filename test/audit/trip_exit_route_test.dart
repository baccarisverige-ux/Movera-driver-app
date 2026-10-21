import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Audit 2026-10-21, D1: a trip exit must leave the trip screen itself, even
// when chat or another page is open on top of it (driver-40), and a driver
// cancel must free the session so Home takes offers again (driver-j2-7).

Future<void> _settle(WidgetTester tester, [int frames = 30]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpHomeWithTrip(
  WidgetTester tester, {
  required DriverSessionController session,
  required MemoryDriverRealtime realtime,
  ActiveRideStage stage = ActiveRideStage.waitingForRider,
}) async {
  SharedPreferences.setMockInitialValues({});
  CompletionJournal.resetForTesting();
  IslandMessages.reset();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AcceptRide(
                    tripId: 'exit-trip',
                    riderName: 'Angelica',
                    initialStage: stage,
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
  ));
  await tester.tap(find.text('Home'));
  await _settle(tester, 12);
  expect(find.byType(AcceptRide), findsOneWidget);
}

void _openChildPage(WidgetTester tester) {
  Navigator.of(tester.element(find.byType(AcceptRide))).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('child page')),
    ),
  );
}

/// The trip's side menu, as the island's menu button opens it.
Future<void> _openTripDrawer(WidgetTester tester) async {
  final scaffold = find
      .descendant(of: find.byType(AcceptRide), matching: find.byType(Scaffold))
      .first;
  tester.state<ScaffoldState>(scaffold).openDrawer();
  await _settle(tester, 12);
  expect(tester.state<ScaffoldState>(scaffold).isDrawerOpen, isTrue);
}

void main() {
  testWidgets('rider cancel while a page is open on the trip goes back to Home', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    await _pumpHomeWithTrip(tester, session: session, realtime: realtime);

    _openChildPage(tester);
    await _settle(tester, 12);
    expect(find.text('child page'), findsOneWidget);

    realtime.emit(
      tripId: 'exit-trip',
      kind: DriverRealtimeKind.riderCancelled,
      status: TripStatus.cancelledByRider,
    );
    await _settle(tester);

    expect(find.text('child page'), findsNothing);
    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(session.activeTripId, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('authoritative outcome while a page is open on the trip goes back to Home', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    await _pumpHomeWithTrip(tester, session: session, realtime: realtime, stage: ActiveRideStage.onTrip);

    _openChildPage(tester);
    await _settle(tester, 12);

    realtime.emit(
      tripId: 'exit-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.cancelledByAdmin,
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('trip-outcome-acknowledge')));
    await _settle(tester);

    expect(find.text('child page'), findsNothing);
    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('driver cancel frees the session so the driver is available again', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    await _pumpHomeWithTrip(tester, session: session, realtime: realtime, stage: ActiveRideStage.onTrip);
    expect(session.activeTripId, 'exit-trip');
    expect(session.availableForOffers, isFalse);

    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await _settle(tester, 6);
    await tester.tap(find.byKey(const ValueKey<String>('active-ride-cancel-option')));
    await _settle(tester, 6);
    await tester.tap(find.byKey(
      const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
    ));
    await _settle(tester, 6);
    await tester.tap(find.byKey(const ValueKey<String>('confirm-trip-cancellation')));
    await _settle(tester);

    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(session.activeTripId, isNull);
    expect(session.availableForOffers, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // driver-fixrev-2: the open drawer is local history on the trip route, so
  // a plain pop only closed the menu and left a dead trip screen.
  testWidgets('driver-fixrev-2: admin reassign with the side menu open goes back to Home', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    await _pumpHomeWithTrip(tester, session: session, realtime: realtime, stage: ActiveRideStage.headingToPickup);
    await _openTripDrawer(tester);

    realtime.emit(
      tripId: 'exit-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.searching,
    );
    await _settle(tester);

    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('driver-fixrev-2: rider cancel with the side menu open goes back to Home', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    await _pumpHomeWithTrip(tester, session: session, realtime: realtime);
    await _openTripDrawer(tester);

    realtime.emit(
      tripId: 'exit-trip',
      kind: DriverRealtimeKind.riderCancelled,
      status: TripStatus.cancelledByRider,
    );
    await _settle(tester);

    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(session.activeTripId, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
