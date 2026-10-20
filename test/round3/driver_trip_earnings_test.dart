import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
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

Future<void> _trip(
  WidgetTester tester, {
  required String fare,
  Money? bonus,
  int waitSeconds = 0,
}) async {
  final now = DateTime(2026, 10, 20, 12);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(
          tripId: 'r3-earnings-trip',
          fare: fare,
          driverBonus: bonus,
          matchedVia: 'Assigned by Movera',
          initialStage: ActiveRideStage.waitingForRider,
          initialWaitSeconds: waitSeconds,
          waitNow: () => now,
          activeRideRepository: MemoryActiveRideRepository(),
          waybillRepository: InMemoryWaybillRepository.instance,
        ),
      ),
    ),
  );
  await _frames(tester);
  await _slide(tester); // Start the trip.
  await _slide(tester); // Complete.
  await tester.pump(const Duration(milliseconds: 220));
  final confirm = find.byKey(const ValueKey('finish-soon-finish'));
  if (confirm.evaluate().isNotEmpty) await tester.tap(confirm);
  for (var i = 0;
      i < 60 && find.byType(DriverRideCompleted).evaluate().isEmpty;
      i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pump(const Duration(milliseconds: 1100));
  expect(find.byType(DriverRideCompleted), findsOneWidget);
}

/// Round 3: Movera's bonus and the waiting fee in the trip's earnings.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
  });
  tearDown(() {
    InMemoryWaybillRepository.instance.reset();
    WaitingRules.current = const WaitingRules();
  });

  testWidgets('an admin offer with a bonus: "incl. +30 kr Movera bonus"', (
    tester,
  ) async {
    await _trip(
      tester,
      fare: '128,60 kr',
      bonus: const Money(minorUnits: 3000),
    );
    final last = InMemoryWaybillRepository.instance.last!;
    expect(last.fare, '128,60 kr');
    expect(last.driverBonus, '30 kr');
    expect(find.text('incl. +30 kr Movera bonus'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('EUR: the waiting fee is added in euros', (tester) async {
    WaitingRules.current = const WaitingRules(
      base: WaitingTerms(
        freeMinutes: 5,
        perMinute: Money(minorUnits: 50, currency: 'EUR'),
        noShowAfterMinutes: 5,
        noShowFee: Money(minorUnits: 500, currency: 'EUR'),
      ),
      categories: {},
    );
    await _trip(tester, fare: '24,00 €', waitSeconds: 6 * 60 + 30);
    final last = InMemoryWaybillRepository.instance.last!;
    // 90 paid seconds at 0,50 € / min.
    expect(last.fare, '24,75 €');
    expect(last.waitingFee, '0,75 €');
    expect(find.text('Includes 0,75 € waiting fee'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });

  testWidgets('TND: the waiting fee is added in millimes', (tester) async {
    WaitingRules.current = const WaitingRules(
      base: WaitingTerms(
        freeMinutes: 5,
        perMinute: Money(minorUnits: 300, currency: 'TND'),
        noShowAfterMinutes: 5,
        noShowFee: Money(minorUnits: 3000, currency: 'TND'),
      ),
      categories: {},
    );
    await _trip(tester, fare: '12,500 DT', waitSeconds: 6 * 60 + 30);
    final last = InMemoryWaybillRepository.instance.last!;
    expect(last.fare, '12,950 DT');
    expect(last.waitingFee, '0,450 DT');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
