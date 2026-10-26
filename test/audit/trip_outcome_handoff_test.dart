import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = PersistedActiveRide(
  tripId: 'trip-a',
  stage: ActiveRideStage.onTrip,
  riderName: 'Alva',
  fare: '111,02 kr',
  pickupAddress: 'Hantverkargatan 4, Stockholm',
  dropoffAddress: 'Ringvägen, Södermalm',
  pickupLat: 59.3295,
  pickupLng: 18.0475,
  dropoffLat: 59.3125,
  dropoffLng: 18.0750,
  nextTripId: 'trip-b',
  next: PersistedQueuedTrip(
    tripId: 'trip-b',
    riderName: 'Bo',
    fare: '96,40 kr',
    category: 'Movera',
    pickup: 'Klarabergsgatan, Stockholm',
    dropoff: 'Gärdet, Stockholm',
    pickupLat: 59.3316,
    pickupLng: 18.0592,
    dropoffLat: 59.3417,
    dropoffLng: 18.1004,
  ),
);

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final status in [
    TripStatus.cancelledByAdmin,
    TripStatus.noShow,
    TripStatus.failed,
    TripStatus.completed,
  ]) {
    testWidgets(
      '$status with a secured next trip hands off instead of orphaning it',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        CompletionJournal.resetForTesting();
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = PrefsActiveRideRepository();
        await repo.save(_a);
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
                            _a,
                            activeRideRepository: repo,
                            sessionController: session,
                            realtime: realtime,
                            waybillRepository:
                                InMemoryWaybillRepository.instance,
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
        expect(session.activeTripId, 'trip-a');

        realtime.emit(
          tripId: 'trip-a',
          kind: DriverRealtimeKind.tripProjection,
          status: status,
        );
        await _settle(tester);

        expect(
          find.byKey(const ValueKey<String>('trip-outcome-sheet')),
          findsOneWidget,
        );
        expect(find.text(tripOutcomeCopy(status).title), findsOneWidget);
        expect(
          find.textContaining('trip ended:', findRichText: true),
          findsNothing,
        );
        expect((await repo.read())?.tripId, 'trip-b');

        await tester.tap(
          find.byKey(const ValueKey<String>('trip-outcome-acknowledge')),
        );
        await _settle(tester, 30);

        final ride = tester.widget<AcceptRide>(find.byType(AcceptRide));
        expect(ride.tripId, 'trip-b');
        expect(session.activeTripId, 'trip-b');
        expect(InMemoryWaybillRepository.instance.current?.tripId, 'trip-b');
        final history = await PrefsTripHistoryRepository().list();
        expect(history.single.tripId, 'trip-a');
        expect(history.single.status, status);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }

  test('outcome copy is human readable for every terminal status', () {
    for (final status in TripStatus.values.where((s) => s.isTerminal)) {
      final copy = tripOutcomeCopy(status);
      expect(
        copy.title,
        isNot(matches(RegExp(r'[a-z][A-Z]'))),
        reason: 'no raw camelCase wire names',
      );
      expect(copy.body, isNotEmpty);
    }
  });
}
