import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept ride/waiting_time_sheet.dart';

/// Owner live test 2026-11-01 (G6 fix round): the pickup-wait sheet after
/// the no-show time, on a phone-sized screen.
const _terms = WaitingTerms(
  freeMinutes: 5,
  perMinute: Money(minorUnits: 1226),
  noShowAfterMinutes: 5,
  noShowFee: Money(minorUnits: 6500),
  driverShareNoShowPercent: 80,
);

Future<void> _open(WidgetTester tester, Size size, {Money? share}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('Trip')),
      ),
    ),
  );
  showWaitingTimeSheet(
    nav.currentContext!,
    readSeconds: () => 403,
    terms: _terms,
    noShowDriverShare: share,
    onNoShow: () {},
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('fix 5: the no-show row shows the driver share (52 kr), '
      'not the rider fee (65 kr)', (tester) async {
    await _open(
      tester,
      const Size(390, 844),
      share: const Money(minorUnits: 5200),
    );
    await tester.scrollUntilVisible(
      find.text('52,00 kr'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('52,00 kr'), findsOneWidget);
    expect(find.text('65,00 kr'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fix 5: without the server share, the terms share (80 %)', (
    tester,
  ) async {
    await _open(tester, const Size(390, 844));
    await tester.scrollUntilVisible(
      find.text('52,00 kr'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('65,00 kr'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [Size(320, 568), Size(375, 667), Size(390, 844)]) {
    testWidgets('fix 6: "Rider didn\'t show" is fully on screen above Close, '
        'without scrolling (${size.width.toInt()}×${size.height.toInt()})', (
      tester,
    ) async {
      await _open(tester, size, share: const Money(minorUnits: 5200));
      final noShow = find.byKey(const ValueKey('waiting-no-show-cancel'));
      expect(noShow, findsOneWidget);
      final button = tester.getRect(noShow);
      final close = tester.getRect(find.widgetWithText(FilledButton, 'Close'));
      expect(button.bottom, lessThanOrEqualTo(close.top));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(close.bottom, lessThanOrEqualTo(size.height));
      // Nothing of the list is painted over it: it hit-tests as itself.
      expect(
        tester
            .hitTestOnBinding(button.center)
            .path
            .any((entry) => entry.target == tester.renderObject(noShow)),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
