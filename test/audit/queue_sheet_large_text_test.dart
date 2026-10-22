import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/presentation/driver/my%20queue%20position/my_queue_pos.dart';

void main() {
  for (final size in <Size>[
    const Size(320, 568),
    const Size(568, 320),
    const Size(375, 812),
  ]) {
    testWidgets('queue preview remains reachable at 200% text in $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMyQueuePositionSheet(context),
                    child: const Text('Open queue'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open queue'));
      await tester.pumpAndSettle();

      expect(find.byType(MyQueuePosition), findsOneWidget);
      expect(find.text('Queue unavailable — preview'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The last categories and the dismiss control must both be reachable
      // even after the sheet initially opens in a short landscape viewport.
      await tester.ensureVisible(find.text('Movera XL').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final dismiss = find.byIcon(Icons.keyboard_arrow_down_rounded);
      await tester.ensureVisible(dismiss);
      await tester.pumpAndSettle();
      await tester.tap(dismiss);
      await tester.pumpAndSettle();

      expect(find.byType(MyQueuePosition), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
