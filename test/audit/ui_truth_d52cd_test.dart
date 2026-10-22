// Wave 5 D5.2 (UI truth), parts c and d: history, safety, scheduled rides
// and map widgets show only what really happened.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

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
}
