import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BQ-V15 (owner driver-g12.md:4 "Real name + rating (Recommended)"):
/// the menu header shows "New driver" (Ny förare / Nouveau chauffeur)
/// until the first rating; with a rating it shows it as before.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverPerformanceConfig.liveBuild = true;
  });

  tearDown(() {
    DriverAppTexts.language = 'en';
    DriverPerformanceConfig.live.value = null;
    DriverPerformanceConfig.featureOn = true;
    DriverPerformanceConfig.liveBuild = false;
  });

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = DriverSessionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRuntimeScope(
          session: controller,
          homeBuilder: () => const SizedBox(),
          child: const Scaffold(body: DriverSideMenu()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (lang, text) in [
    ('en', 'New driver'),
    ('sv', 'Ny förare'),
    ('fr', 'Nouveau chauffeur'),
  ]) {
    testWidgets('no rating yet ($lang): "$text"', (tester) async {
      DriverAppTexts.language = lang;
      DriverPerformanceConfig.live.value = DriverPerformanceConfig.none;
      await pumpMenu(tester);
      expect(find.text(text), findsOneWidget);
      expect(find.text(DriverPerformanceConfig.dash), findsNothing);
    });
  }

  testWidgets('with a rating: the rating as before, no "New driver"', (
    tester,
  ) async {
    DriverAppTexts.language = 'en';
    DriverPerformanceConfig.live.value = DriverPerformanceConfig.fromServer({
      'rating': 4.62,
    });
    await pumpMenu(tester);
    expect(find.text('4.62'), findsOneWidget);
    expect(find.text('New driver'), findsNothing);
  });
}
