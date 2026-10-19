import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingSave extends MemoryActiveRideRepository {
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

Future<void> _mount(
  WidgetTester tester,
  _PendingSave repo,
  MemoryDriverRealtime realtime,
) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(
          tripId: 'pending-trip',
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
}

void main() {
  testWidgets('rider cancellation received during stage persistence is retained', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _PendingSave();
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _mount(tester, repo, realtime);

    PersistedActiveRide? snapshot = await repo.read();
    for (var i = 0; i < 20 && snapshot == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      snapshot = await repo.read();
    }
    expect(snapshot, isNotNull);
    expect(snapshot!.stage, ActiveRideStage.waitingForRider);


  tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last).controller!.animatePanelToSnapPoint();
  for (var i=0;i<14;i++) { await tester.pump(const Duration(milliseconds:50)); }
    repo.hold = Completer<void>();
    final action = find.byKey(const ValueKey<String>('active-ride-primary-action'));
    await tester.ensureVisible(action);
    await tester.drag(action, const Offset(320, 0));
    await tester.pump();
    realtime.emit(
      tripId: 'pending-trip',
      kind: DriverRealtimeKind.riderCancelled,
      status: TripStatus.cancelledByRider,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect((await repo.read())?.stage, ActiveRideStage.waitingForRider);

    final pending = repo.hold;
    repo.hold = null;
    pending?.complete();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await repo.read(), isNull);
    expect(
      (await PrefsTripHistoryRepository().list()).single.status,
      TripStatus.cancelledByRider,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
