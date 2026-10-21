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
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the journal's clear and a background save on demand.
class _Gated extends MemoryActiveRideRepository {
  Completer<void>? holdClear;
  Completer<void>? holdSave;
  bool clearStarted = false;

  @override
  Future<void> save(PersistedActiveRide ride) async {
    final pending = holdSave;
    if (pending != null) {
      await pending.future;
    }
    await super.save(ride);
  }

  @override
  Future<void> clear() async {
    clearStarted = true;
    final pending = holdClear;
    if (pending != null) {
      await pending.future;
    }
    await super.clear();
  }
}

void main() {
  // driver-r3-12: a background save that starts while the journal records
  // an authoritative terminal projection must not drop that projection.
  testWidgets('an authoritative cancel survives a background save during the journal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Gated();
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(
          tripId: 'bg-save-trip',
          initialStage: ActiveRideStage.onTrip,
          activeRideRepository: repo,
          realtime: realtime,
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    final clear = repo.holdClear = Completer<void>();
    realtime.emit(tripId: 'bg-save-trip', kind: DriverRealtimeKind.tripProjection, status: TripStatus.cancelledByAdmin);
    for (var i = 0; i < 20 && !repo.clearStarted; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.clearStarted, isTrue);
    // The lock-screen save starts while the journal is still writing.
    final save = repo.holdSave = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    repo.holdClear = null;
    clear.complete();
    await tester.pump(const Duration(milliseconds: 50));
    repo.holdSave = null;
    save.complete();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TripOutcomeSheet), findsOneWidget);
    expect(await repo.read(), isNull);
    final history = await PrefsTripHistoryRepository().list();
    expect(history.where((row) => row.tripId == 'bg-save-trip').map((row) => row.status), [TripStatus.cancelledByAdmin]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
