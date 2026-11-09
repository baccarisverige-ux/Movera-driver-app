// Owner screenshots 2026-11-07 17:14 (driver, fr): the trip detail's
// addresses end with ", Sweden" (the geocoder's full address). The rider
// app shows "street, town" (compactAddress); the driver detail and list
// now do the same.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';

void main() {
  testWidgets('trip detail: no ", Sweden" after the addresses', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'trp_addr',
              riderName: 'Anna',
              whenLabel: '07/11/2026, 17:14',
              pickup: 'Klockarvägen 35, 123 45 Stockholm, Sweden',
              dropoff: 'Klockarvägen 37, 123 45 Stockholm, Sweden',
              fare: '60,00 kr',
              category: 'Movera',
              paymentMethod: 'Cash',
            ),
            loadRideChecks: (_) async => const [],
            loadPath: (_) async => null,
            loadTip: (_) async => null,
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Sweden'), findsNothing);
    expect(find.text('Klockarvägen 35, 123 45 Stockholm'), findsOneWidget);
    expect(find.text('Klockarvägen 37, 123 45 Stockholm'), findsOneWidget);
  });
}
