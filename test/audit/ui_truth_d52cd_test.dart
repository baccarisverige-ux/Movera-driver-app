// Wave 5 D5.2 (UI truth), parts c and d: history, safety, scheduled rides
// and map widgets show only what really happened.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';

import '../../integration_test/headless_map_platform.dart';

/// [screen] as the app's first route on a phone.
Future<void> _show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

/// Trip details of [status] for a 152,40 kr trip with a 40 kr bonus.
Future<void> _detail(WidgetTester tester,
    {TripStatus status = TripStatus.completed,
    List<RideCheckRecord> checks = const []}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: DriverRideHistoryDetail(
        record: TripHistoryRecord(
          tripId: 'trip-1',
          riderName: 'Karin',
          whenLabel: '15/10/2026, 07:59',
          pickup: 'Gamla vägen',
          dropoff: 'Solna centrum',
          fare: '152,40 kr',
          category: 'Comfort',
          status: status,
          driverBonus: '40 kr',
        ),
        loadRideChecks: (_) async => checks,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  testWidgets("driver-u151: Ride completed names the payment in the driver's "
      'language and never calls an in-app payment Card', (tester) async {
    DriverAppTexts.language = 'sv';
    await _show(tester, const DriverRideCompleted(paidByCash: false));
    expect(find.text('I appen'), findsOneWidget);
    expect(find.text('Card'), findsNothing);
    await _show(tester, const DriverRideCompleted(paidByCash: true));
    expect(find.text('Kontant'), findsOneWidget);
  });

  testWidgets('driver-83: a cancelled trip shows no ride cost and no bonus',
      (tester) async {
    await _detail(tester, status: TripStatus.cancelledByDriver);
    expect(find.text('152,40 kr'), findsNothing);
    expect(find.byKey(const ValueKey('history-driver-bonus')), findsNothing);
    tester.takeException();
  });

  testWidgets("driver-u156: a Ride check alert kept in the demo outbox is not "
      "shown as 'Movera safety team alerted'", (tester) async {
    final at = DateTime(2026, 10, 15, 7, 50);
    await _detail(tester, checks: [
      RideCheckRecord(
        id: 'rc-1',
        tripId: 'trip-1',
        trigger: RideCheckTrigger.longStop,
        reason: 'Your car has stopped for 4 min',
        openedAt: at,
        answeredAt: at,
        alertSent: true,
      ),
    ]);
    expect(find.text('Movera safety team alerted'), findsNothing);
    expect(find.text(
            'Demo: alert kept on this phone only. No one at Movera was notified.'),
        findsOneWidget);
    tester.takeException();
  });

  testWidgets('driver-85: with only cancelled trips, History says there is no '
      'completed ride and counts the trips it lists', (tester) async {
    await _show(tester, DriverRideHistory(loadHistory: () async => [
          for (var i = 0; i < 3; i++)
            TripHistoryRecord(
              tripId: 'c$i',
              riderName: 'Karin',
              whenLabel: 'Today',
              pickup: 'Gamla vägen',
              dropoff: 'Solna centrum',
              fare: '152,40 kr',
              category: 'Comfort',
              status: TripStatus.cancelledByDriver,
              completedAt: DateTime.now(),
            ),
        ]));
    expect(find.text('No completed rides in this period.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-view-all-rides')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 rides in'), findsOneWidget);
  });
}
