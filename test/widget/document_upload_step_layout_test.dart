import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/auth/additional detail/screens/vehicle_insurance.dart';
import 'package:movera/presentation/driver/auth/additional detail/screens/vehicle_registeration.dart';

void main() {
  for (final insurance in [false, true]) {
    for (final size in [
      const Size(320, 568),
      const Size(568, 320),
      const Size(375, 812),
    ]) {
      testWidgets(
        '${insurance ? 'insurance' : 'registration'} step controls remain reachable at 200% in $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var cameras = 0;
          final Widget page = insurance
              ? AdditionDetailVehicleInsurance(
                  circleProgress: (_, _) => const SizedBox(),
                  capturePhoto: () async {
                    cameras++;
                    return null;
                  },
                )
              : AdditionDetailVehicleRegisteration(
                  circleProgress: (_, _) => const SizedBox(),
                  capturePhoto: () async {
                    cameras++;
                    return null;
                  },
                );
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (_, _) => MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      const SizedBox(height: 60),
                      Expanded(child: page),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final camera = find.widgetWithText(TextButton, 'Open Camera');
          await tester.ensureVisible(camera);
          await tester.pumpAndSettle();
          await tester.tap(camera);
          await tester.pumpAndSettle();
          expect(cameras, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
