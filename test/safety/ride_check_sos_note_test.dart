// Owner 2026-10-27: Call 112 on the ride check card is also the driver SOS to
// Movera. After it, the card says what happened to the SOS: never "no one
// at Movera was notified" when the SOS was sent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _after112(WidgetTester tester, DriverSosOutcome outcome) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = RideCheckController(
    services: RideCheckServices(
      alerts: DemoSafetyAlertRepository(),
      log: MemoryRideCheckLog(),
      launch: (_) async => true,
      sos: () async => outcome,
    ),
    tripId: 'trip-1',
    tripDetails: () => const SafetyAlertTrip(
      tripId: 'trip-1',
      riderName: 'Angelica',
      riderRating: 4.9,
      pickup: 'Odlarvägen 22',
      dropoff: 'T-Centralen, Stockholm',
      fare: '126 kr',
      category: 'Comfort',
      driverName: 'Movera Driver',
      vehicle: 'Volvo XC60',
      plate: 'ABC 123',
    ),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.active
              ? RideCheckLayer(controller: controller, top: 10, maxHeight: 820)
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  unawaited(
    controller.open(
      RideCheckDetector().demo(
        RideCheckTrigger.possibleCrash,
        DateTime.now(),
        destination: 'T-Centralen, Stockholm',
      ),
      instant: true,
    ),
  );
  await _frames(tester);
  await tester.tap(find.byKey(const ValueKey('ride-check-call-112')));
  await _frames(tester);
}

void main() {
  testWidgets('SOS sent: the card says Movera was alerted, never not', (
    tester,
  ) async {
    await _after112(tester, DriverSosOutcome.sent);
    expect(find.textContaining('Movera safety team alerted'), findsOneWidget);
    expect(find.textContaining('SOS sent with your position'), findsOneWidget);
    expect(find.textContaining('No one at Movera'), findsNothing);
    expect(find.textContaining('Not sent'), findsNothing);
    expect(find.text('Your answer is saved to this trip.'), findsOneWidget);
  });

  testWidgets('SOS not sent: the card says so and to call 112', (tester) async {
    await _after112(tester, DriverSosOutcome.failed);
    expect(find.textContaining('Movera could not be alerted'), findsOneWidget);
    expect(find.textContaining('Movera safety team alerted'), findsNothing);
  });
}
