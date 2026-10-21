import 'dart:async';

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

class _HeldSave extends MemoryActiveRideRepository {
  Completer<void>? hold;

  @override
  Future<void> save(PersistedActiveRide ride) async {
    final pending = hold;
    if (pending != null) {
      await pending.future;
    }
    await super.save(ride);
  }
}

void main() {
  // driver-u70: a terminal projection that lands while an earlier
  // projection is still being saved must be applied once that save ends.
  testWidgets('a terminal projection queued behind a draining one is applied', (tester) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _HeldSave();
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(
          tripId: 'queued-trip',
          initialStage: ActiveRideStage.headingToPickup,
          activeRideRepository: repo,
          realtime: realtime,
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    final held = repo.hold = Completer<void>();
    realtime.emit(tripId: 'queued-trip', kind: DriverRealtimeKind.tripProjection, status: TripStatus.arrived);
    await tester.pump(const Duration(milliseconds: 50));
    realtime.emit(tripId: 'queued-trip', kind: DriverRealtimeKind.tripProjection, status: TripStatus.cancelledByAdmin);
    await tester.pump(const Duration(milliseconds: 50));
    repo.hold = null;
    held.complete();
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(await repo.read(), isNull);
    final history = await PrefsTripHistoryRepository().list();
    expect(history.where((row) => row.tripId == 'queued-trip').map((row) => row.status), [TripStatus.cancelledByAdmin]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
