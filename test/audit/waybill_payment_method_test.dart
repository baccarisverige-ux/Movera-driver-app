import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// driver-u173: the waybill said "Payment: In the app" for every trip, also
/// for a cash trip the driver was paid for in the car.
class _PendingLocation implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// The waybill AcceptRide begins for a trip, opened in the sheet.
Future<void> _waybillOf(WidgetTester tester, {required bool cash}) async {
  final waybills = InMemoryWaybillRepository.instance..reset();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: AcceptRide(
          tripId: cash ? 'cash-trip' : 'card-trip',
          fare: '104,80 kr',
          paidByCash: cash,
          locationRepository: _PendingLocation(),
          activeRideRepository: MemoryActiveRideRepository(),
          waybillRepository: waybills,
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final record = waybills.current!;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showMoveraWaybillSheet(context, record),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    InMemoryWaybillRepository.instance.reset();
  });

  testWidgets('a cash trip waybill says Cash, not In the app', (tester) async {
    await _waybillOf(tester, cash: true);
    expect(find.text('In the app'), findsNothing);
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('a card trip waybill still says In the app', (tester) async {
    await _waybillOf(tester, cash: false);
    expect(find.text('In the app'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
  });
}
