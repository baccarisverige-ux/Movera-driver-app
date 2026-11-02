import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _old = PersistedActiveRide(
  tripId: 'trip-old',
  stage: ActiveRideStage.onTrip,
  riderName: 'Alva',
  fare: '111,02 kr',
  pickupAddress: 'Hantverkargatan 4, Stockholm',
  dropoffAddress: 'Ringvägen, Södermalm',
  pickupLat: 59.3295,
  pickupLng: 18.0475,
  dropoffLat: 59.3125,
  dropoffLng: 18.0750,
);

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// G9 live 2026-11-02: "Driver app showed an old 'Resan är klar' sheet from
/// an earlier trip on first open". A trip restored on opening the app that
/// the server already finished goes Home without the sheet; a trip seen
/// open on this screen still gets it.
void main() {
  Future<(MemoryDriverRealtime, PrefsActiveRideRepository)> open(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = PrefsActiveRideRepository();
    await repo.save(_old);
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final session = DriverSessionController()..setOnline(true);
    InMemoryWaybillRepository.instance.reset();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey<String>('open-ride'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AcceptRide.fromPersisted(
                        _old,
                        activeRideRepository: repo,
                        sessionController: session,
                        realtime: realtime,
                        waybillRepository: InMemoryWaybillRepository.instance,
                      ),
                    ),
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-ride')));
    await _settle(tester);
    return (realtime, repo);
  }

  testWidgets('a restored trip that already ended goes Home with no sheet', (
    tester,
  ) async {
    final (realtime, repo) = await open(tester);
    realtime.emit(
      tripId: 'trip-old',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.completed,
    );
    await _settle(tester, 30);
    expect(
      find.byKey(const ValueKey<String>('trip-outcome-sheet')),
      findsNothing,
    );
    expect(find.byType(AcceptRide), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(await repo.read(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a trip seen open here still shows "Trip completed"', (
    tester,
  ) async {
    final (realtime, _) = await open(tester);
    realtime.emit(
      tripId: 'trip-old',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.inTrip,
    );
    await _settle(tester);
    realtime.emit(
      tripId: 'trip-old',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.completed,
    );
    await _settle(tester, 30);
    expect(
      find.byKey(const ValueKey<String>('trip-outcome-sheet')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
