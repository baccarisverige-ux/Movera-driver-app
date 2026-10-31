import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester
        .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .last
        .controller!
        .animatePanelToSnapPoint();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await tester.pump(const Duration(milliseconds: 240));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Q42/Q43: the waiting fee after the free wait is the driver's and is in
/// the trip's earnings.
void main() {
  setUp(() {
    // G5 checker round 1: the zone's served terms (no app prices).
    WaitingRules.current = DriverAppConfig.fromJson({
      'currency': 'SEK',
      'waiting': {
        'freeWaitMin': 5,
        'perMin': {'amountMinor': 1226, 'currency': 'SEK'},
        'noShowAfterMin': 5,
        'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
        'driverSharePct': 80,
      },
    }).waiting;
    addTearDown(() => WaitingRules.current = const WaitingRules());
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
  });
  tearDown(InMemoryWaybillRepository.instance.reset);

  testWidgets('6:30 at pickup: 90 paid seconds land in the earnings', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 20, 12);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = MemoryActiveRideRepository();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'wait-fee-trip',
            fare: '100,00 kr',
            initialStage: ActiveRideStage.waitingForRider,
            initialWaitSeconds: 6 * 60 + 30,
            waitNow: () => now,
            activeRideRepository: saved,
            waybillRepository: InMemoryWaybillRepository.instance,
          ),
        ),
      ),
    );
    await _frames(tester);
    // The island counts the paid part only: 6:30 − 5:00.
    expect(
      tester
          .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
          .paidSeconds,
      90,
    );

    await _slide(tester); // Start the trip: the pickup wait is over.
    final onTrip = await saved.read();
    expect(onTrip?.paidWaitSeconds, 90);
    expect(onTrip?.acceptedAt, isNotNull);

    await _slide(tester); // Complete.
    await tester.pump(const Duration(milliseconds: 220));
    final confirm = find.byKey(const ValueKey('finish-soon-finish'));
    if (confirm.evaluate().isNotEmpty) await tester.tap(confirm);
    for (
      var i = 0;
      i < 60 && find.byType(DriverRideCompleted).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.byType(DriverRideCompleted), findsOneWidget);
    // 90 s at 12,26 kr / min = 18,39 kr, 100% to the driver.
    final last = InMemoryWaybillRepository.instance.last!;
    expect(last.fare, '118,39 kr');
    expect(last.waitingFee, '18,39 kr');
    // Owner decision 2026-10-27: one amount, the fee is in it, no line.
    expect(find.text('118,39 kr'), findsWidgets);
    expect(
      find.byKey(const ValueKey('ride-completed-waiting-fee')),
      findsNothing,
    );
    expect(find.textContaining('waiting fee'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
