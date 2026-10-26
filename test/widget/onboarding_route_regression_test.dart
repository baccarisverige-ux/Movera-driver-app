import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/navigation.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/take%20id%20photo/take_id_photo.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/dropdown.dart';

Future<GlobalKey<NavigatorState>> _open(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Scaffold(body: Text('Existing home')),
      ),
    ),
  );
  navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => child));
  await tester.pumpAndSettle();
  return navigator;
}

void main() {
  testWidgets(
    'ID preview returns to the existing home once without creating an app root',
    (tester) async {
      await _open(tester, const TakeIdPhoto());
      expect(find.textContaining('Sample image only.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(
                TextButton,
                'Retake unavailable in this preview',
              ),
            )
            .onPressed,
        isNull,
      );
      final finish = tester
          .widget<FilledButton>(find.byKey(const ValueKey('id-preview-return')))
          .onPressed!;
      finish();
      finish();
      await tester.pumpAndSettle();
      expect(find.text('Existing home'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(TakeIdPhoto), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('covered ID preview cannot unwind a newer route', (tester) async {
    final navigator = await _open(tester, const TakeIdPhoto());
    final finish = tester
        .widget<FilledButton>(find.byKey(const ValueKey('id-preview-return')))
        .onPressed!;
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
    );
    await tester.pumpAndSettle();
    finish();
    await tester.pumpAndSettle();
    expect(find.text('Covering route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding callbacks preserve covered step and resume normally',
    (tester) async {
      final navigator = await _open(tester, const AdditionalInfoNavigation());
      final page = tester.widget<PageView>(find.byType(PageView)).controller!;
      final next = tester
          .widget<CustomButton>(find.byType(CustomButton))
          .onPressed!;
      final back = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Back',
            ),
          )
          .onPressed!;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covering route')),
        ),
      );
      await tester.pumpAndSettle();
      next();
      back();
      await tester.pumpAndSettle();
      expect(page.page, 0);
      expect(find.text('Covering route'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      next();
      await tester.pumpAndSettle();
      expect(page.page, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vehicle plate accepts letters and only one type selector is presented',
    (tester) async {
      await _open(tester, const AdditionalInfoNavigation());
      final plate = tester.widget<TextField>(
        find.byWidgetPredicate(
          // driver-u99: the sample plate is a hint, the field starts empty.
          (w) => w is TextField && w.decoration?.hintText == 'AQS - 140',
        ),
      );
      expect(plate.keyboardType, TextInputType.text);
      expect(plate.textCapitalization, TextCapitalization.characters);
      expect(find.byType(AppDropdownField), findsOneWidget);
      final year = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Enter model year',
        ),
      );
      expect(year.keyboardType, TextInputType.number);
      expect(year.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion advances onboarding without an intermediate page animation',
    (tester) async {
      await _open(tester, const AdditionalInfoNavigation(), reduceMotion: true);
      final page = tester.widget<PageView>(find.byType(PageView)).controller!;
      tester.widget<CustomButton>(find.byType(CustomButton)).onPressed!();
      await tester.pump();
      expect(page.page, 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
