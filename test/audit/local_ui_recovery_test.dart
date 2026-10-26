import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'support draft remains reachable above keyboard and restores after closing',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const SupportInboxScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft local ticket'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      final subject = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Subject',
      );
      final message = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Tell us what happened',
      );
      await tester.ensureVisible(subject);
      await tester.enterText(subject, 'Help with pickup');
      await tester.ensureVisible(message);
      await tester.enterText(message, 'Keep this draft locally');
      await tester.pumpAndSettle();
      final save = find.text('Save draft in demo');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      nav.currentState!.pop();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft local ticket'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(subject).controller!.text,
        'Help with pickup',
      );
      expect(
        tester.widget<TextField>(message).controller!.text,
        'Keep this draft locally',
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // Route disposal and acknowledged local writes finish after the pop animation.
      for (
        var i = 0;
        i < 30 && find.text('Help with pickup').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.text('Local ticket draft'), findsNothing);
      await tester.scrollUntilVisible(find.text('Help with pickup'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Help with pickup'), findsOneWidget);
      expect(find.text('LOCAL DRAFT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ride preferences restore changed selection after screen recreation',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Preferences()));
      await tester.pumpAndSettle();
      // Admin allows six categories for the car (Q27).
      await tester.tap(find.text('Comfort'));
      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 6 active'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: Preferences()));
      await tester.pumpAndSettle();
      expect(find.text('4 of 6 active'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('ride preferences keep older saves and enable new categories', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsRepository().save('categories', {
      'selected': [false, true, true, true, true, true, true],
    });
    await tester.pumpWidget(const MaterialApp(home: Preferences()));
    await tester.pumpAndSettle();
    // Movera off; Booster Seat, added later, on. XL and Electric are not
    // allowed for the car.
    expect(find.text('5 of 6 active'), findsOneWidget);
  });
}
