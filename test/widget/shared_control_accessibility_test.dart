import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/widgets/checkbox.dart';
import 'package:movera/widgets/custom_btn.dart';

Future<void> _open(
  WidgetTester tester,
  Size size,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shared button applies responsive font scaling once', (
    tester,
  ) async {
    await _open(
      tester,
      const Size(750, 1000),
      CustomButton(centerContent: 'Continue', onPressed: () {}),
    );
    final label = tester.widget<Text>(find.text('Continue'));
    expect(label.style!.fontSize, closeTo(19.2, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long button label wraps without shrinking enlarged text and remains tappable',
    (tester) async {
      var calls = 0;
      const label = 'Queue unavailable — preview';
      await _open(
        tester,
        const Size(320, 568),
        CustomButton(centerContent: label, onPressed: () => calls++),
        scale: 2,
      );
      final text = find.text(label);
      expect(tester.getSize(text).height, greaterThan(40));
      expect(
        tester.getSize(find.byType(CustomButton)).height,
        greaterThanOrEqualTo(tester.getSize(text).height + 24),
      );
      await tester.tap(text);
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'terms control exposes named checked state and toggles normally',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var checked = false;
        await _open(
          tester,
          const Size(375, 812),
          StatefulBuilder(
            builder: (context, setState) => CustomCheckBox(
              value: checked,
              semanticLabel: 'Accept terms and privacy policy',
              onPressed: () => setState(() => checked = !checked),
            ),
          ),
        );
        final checkbox = find.bySemanticsLabel(
          'Accept terms and privacy policy',
        );
        expect(
          tester.getSemantics(checkbox).flagsCollection.isChecked,
          isNot(CheckedState.none),
        );
        expect(
          tester.getSemantics(checkbox).flagsCollection.isChecked,
          CheckedState.isFalse,
        );
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(checked, isTrue);
        expect(
          tester.getSemantics(checkbox).flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );
}
