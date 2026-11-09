import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/deferred_screens.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B9 "Fast app start" (owner 2026-11-04): Settings, Documents and Help load
/// on first open. A driver who taps them in the real menus still gets the
/// screen (after the short first-open spinner).
void main() {
  // The parts download for real outside the fake clock (as on a phone).
  setUpAll(loadDeferredScreens);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder screenNamed(String name) =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  Future<void> tapThrough(WidgetTester tester, String label) async {
    final item = find.text(label).first;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    // Fixed pumps: some screens keep a spinner or animation running.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final (label, screen) in [
    ('Support', 'SupportScreen'),
    ('Settings', 'Settings'),
  ]) {
    testWidgets('side menu "$label" opens $screen', (tester) async {
      await show(tester, const Scaffold(body: DriverSideMenu()));
      await tapThrough(tester, label);
      expect(screenNamed(screen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('deferred-screen-loading')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('profile "Documents" opens DriverDocuments', (tester) async {
    await show(tester, const DriverProfile());
    await tapThrough(tester, 'Documents');
    expect(screenNamed('DriverDocuments'), findsOneWidget);
    expect(find.byKey(const ValueKey('deferred-screen-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
