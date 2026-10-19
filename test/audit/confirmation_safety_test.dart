import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailOnce extends MemoryActiveRideRepository {
  bool fail = false;
  @override Future<void> save(PersistedActiveRide ride) async {
    if (fail) { fail = false; throw StateError('write unavailable'); }
    await super.save(ride);
  }
}

Future<void> _mount(WidgetTester tester, ActiveRideRepository repo) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(designSize: const Size(375,812),
    builder: (_, __) => MaterialApp(home: AcceptRide(
      tripId: 'confirmation-test', initialStage: ActiveRideStage.waitingForRider,
      activeRideRepository: repo))));
  for (var i=0;i<10;i++) { await tester.pump(const Duration(milliseconds:30)); }
  tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last).controller!.animatePanelToSnapPoint();
  for (var i=0;i<14;i++) { await tester.pump(const Duration(milliseconds:50)); }

}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('pointer cancellation above threshold never starts the trip', (tester) async {
    final repo = MemoryActiveRideRepository(); await _mount(tester, repo);
    final action=find.byKey(const ValueKey<String>('active-ride-primary-action'));
    final gesture=await tester.startGesture(tester.getCenter(action));
    await gesture.moveBy(const Offset(320,0)); await tester.pump();
    await gesture.cancel(); await tester.pump(const Duration(milliseconds:300));
    expect((await repo.read())!.stage, ActiveRideStage.waitingForRider);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rejected start can be retried with the same slide', (tester) async {
    final repo=_FailOnce(); await _mount(tester,repo);
    // Reject the first start write, then retry the same action.
    repo.fail=true;
    final action=find.byKey(const ValueKey<String>('active-ride-primary-action'));
    await tester.ensureVisible(action);
    await tester.drag(action,const Offset(320,0));
    for(var i=0;i<10;i++) { await tester.pump(const Duration(milliseconds:30)); }
    expect((await repo.read())!.stage,ActiveRideStage.waitingForRider);
    ScaffoldMessenger.of(tester.element(action)).removeCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds:400));
    await tester.pump();
    await tester.ensureVisible(action);
    await tester.drag(action,const Offset(320,0));
    for(var i=0;i<10;i++) { await tester.pump(const Duration(milliseconds:30)); }
    expect((await repo.read())!.stage,ActiveRideStage.onTrip);
    expect(tester.takeException(),isNull);
  });
}
