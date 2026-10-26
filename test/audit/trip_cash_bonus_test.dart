// driver-u61: Movera's bonus is in the fare but the rider never pays it,
// so a cash trip collects the fare without it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3279, 18.0615),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _middle(WidgetTester tester) async {
  if (find
          .byKey(const ValueKey('active-ride-arrived-button'))
          .evaluate()
          .isNotEmpty ||
      find
          .byKey(const ValueKey('active-ride-primary-action'))
          .evaluate()
          .isNotEmpty ||
      find
          .byKey(const ValueKey('active-ride-collect-cash'))
          .evaluate()
          .isNotEmpty) {
    return;
  }
  tester
      .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .controller!
      .animatePanelToSnapPoint();
  await _settle(tester, 17);
}

Future<String> _cashShown(WidgetTester tester, AcceptRide ride) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(home: ride),
    ),
  );
  await _settle(tester, 10);
  await _middle(tester);
  await tester.tap(find.byKey(const ValueKey('active-ride-arrived-button')));
  await _settle(tester, 6);
  await _middle(tester);
  final slide = find.byKey(const ValueKey('active-ride-primary-action'));
  await tester.drag(slide, const Offset(320, 0));
  await _settle(tester, 6);
  await _middle(tester);
  final collect = find.byKey(
    const ValueKey<String>('active-ride-collect-cash'),
  );
  expect(collect, findsOneWidget);
  await tester.ensureVisible(collect);
  await tester.tap(collect);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final amount = tester
      .widget<Text>(find.byKey(const ValueKey<String>('cash-collect-amount')))
      .data!;
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 10);
  return amount;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(
      autoOffline: false,
      exclusiveWhileDriving: false,
    );
  });
  tearDown(() {
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  testWidgets('cash + Movera bonus: the rider pays the fare without it', (
    tester,
  ) async {
    final location = _Loc();
    final amount = await _cashShown(
      tester,
      AcceptRide(
        fare: '152,40 kr',
        paidByCash: true,
        driverBonus: Money.ore(4000),
        riderName: 'Karin',
        category: 'Comfort',
        locationRepository: location,
        waitNow: () => tester.binding.clock.now(),
      ),
    );
    expect(amount, '112,40 kr');
    expect(find.text('152,40 kr'), findsNothing);
    await location.updates.close();
  });

  testWidgets('a server cash amount still wins', (tester) async {
    final location = _Loc();
    final amount = await _cashShown(
      tester,
      AcceptRide(
        fare: '152,40 kr',
        cashToCollect: '120 kr',
        paidByCash: true,
        driverBonus: Money.ore(4000),
        riderName: 'Karin',
        category: 'Comfort',
        locationRepository: location,
        waitNow: () => tester.binding.clock.now(),
      ),
    );
    expect(amount, '120 kr');
    await location.updates.close();
  });

  testWidgets('cash without a bonus collects the fare', (tester) async {
    final location = _Loc();
    final amount = await _cashShown(
      tester,
      AcceptRide(
        fare: '152,40 kr',
        paidByCash: true,
        riderName: 'Karin',
        category: 'Comfort',
        locationRepository: location,
        waitNow: () => tester.binding.clock.now(),
      ),
    );
    expect(amount, '152,40 kr');
    await location.updates.close();
  });
}
