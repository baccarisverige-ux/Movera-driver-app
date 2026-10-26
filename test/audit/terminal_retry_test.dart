import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlakyClear extends MemoryActiveRideRepository {
  int failures = 2;

  @override
  Future<void> clear() async {
    if (failures > 0) {
      failures--;
      throw StateError('storage busy');
    }
    await super.clear();
  }
}

void main() {
  testWidgets(
    'a failed rider-cancellation save is retried without user action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FlakyClear();
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: AcceptRide(
              tripId: 'flaky-trip',
              initialStage: ActiveRideStage.waitingForRider,
              activeRideRepository: repo,
              realtime: realtime,
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      realtime.emit(
        tripId: 'flaky-trip',
        kind: DriverRealtimeKind.riderCancelled,
        status: TripStatus.cancelledByRider,
      );
      // Two failures, then 1 s and 2 s backoff; no Retry tap.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repo.failures, 0);
      expect(find.text('Rider cancelled'), findsOneWidget);
      final history = await PrefsTripHistoryRepository().list();
      expect(history.where((row) => row.tripId == 'flaky-trip'), hasLength(1));
      expect(history.single.status, TripStatus.cancelledByRider);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
