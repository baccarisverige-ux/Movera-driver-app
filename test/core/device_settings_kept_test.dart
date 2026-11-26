import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/offer_alert.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tester 2026-11-25 (TestFlight, driver): "Google Maps resets to the
/// default setting" after closing and opening the app. Logout (and another
/// driver's sign-in) removed the Trip settings, Sound & voice and
/// Accessibility sections while memory still showed the choice; the next
/// start then read the defaults. These are device settings now, kept like
/// the language. "Restart" below = in-memory state reset + new repository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void restart() {
    NavigationAppSetting.reset();
    OfferAlertSettings.reset();
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(restart);

  test('Waze survives app restart', () async {
    expect(
      await NavigationAppSetting.save(NavigationApp.waze, SettingsRepository()),
      isTrue,
    );
    restart();
    expect(
      await NavigationAppSetting.load(SettingsRepository()),
      NavigationApp.waze,
    );
  });

  test(
    'device settings survive logout + restart; personal ones do not',
    () async {
      final repo = SettingsRepository();
      await NavigationAppSetting.save(NavigationApp.waze, repo);
      await repo.save('sound', {
        'generalVolume': 0.3,
        'voiceNavigation': false,
      });
      await repo.save('accessibility', {'flash': true, 'vibration': false});
      await repo.save('contacts', {'rows': []});
      await clearLocalUserData();
      restart();
      final fresh = SettingsRepository();
      expect(await NavigationAppSetting.load(fresh), NavigationApp.waze);
      expect((await fresh.read('sound'))['generalVolume'], 0.3);
      expect((await fresh.read('sound'))['voiceNavigation'], isFalse);
      expect((await fresh.read('accessibility'))['vibration'], isFalse);
      await OfferAlertSettings.restore(repository: fresh);
      expect(OfferAlertSettings.vibrate.value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${SettingsRepository.sectionPrefix}contacts'),
        isNull,
      );
    },
  );

  testWidgets('Trip settings shows the saved Waze after a restart', (
    tester,
  ) async {
    await NavigationAppSetting.save(NavigationApp.waze, SettingsRepository());
    await clearLocalUserData();
    restart();
    await tester.pumpWidget(const MaterialApp(home: TripSettings()));
    await tester.runAsync(() => SettingsRepository.settle());
    await tester.pumpAndSettle();
    expect(NavigationAppSetting.current.value, NavigationApp.waze);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('trip-settings-waze')),
        matching: find.byIcon(Icons.radio_button_checked_rounded),
      ),
      findsOneWidget,
    );
  });
}
