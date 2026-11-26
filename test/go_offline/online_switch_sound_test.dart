import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/sound/offer_alert.dart';
import 'package:movera/core/sound/online_switch_sound.dart';
import 'package:movera/core/sound/phone_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../widget/home_suite/_helpers.dart';

/// Owner 2026-11-26: a sound on going online / offline, quiet on silent
/// and with the driver's General volume at 0; no "Go offline?" question;
/// the sheet comes down only when it was up.
void main() {
  late List<String> alerts;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OnlineSwitchSound.debugReset();
    alerts = <String>[];
    OnlineSwitchSound.debugAlert = alerts.add;
    PhoneSoundCheck.debugRead = () async => PhoneSound.on;
    OfferAlertSettings.reset();
  });

  tearDown(() {
    OnlineSwitchSound.debugReset();
    PhoneSoundCheck.debugRead = null;
    OfferAlertSettings.reset();
  });

  test('online rises, offline falls, each with a light haptic', () async {
    await OnlineSwitchSound.wentOnline();
    await OnlineSwitchSound.wentOffline();
    expect(alerts, <String>[
      'haptic',
      'sound:${OnlineSwitchSound.online}',
      'haptic',
      'sound:${OnlineSwitchSound.offline}',
    ]);
  });

  test('the phone on silent: no sound', () async {
    PhoneSoundCheck.debugRead = () async => PhoneSound.off;
    await OnlineSwitchSound.wentOffline();
    expect(alerts, <String>['haptic']);
  });

  test('General volume at 0 in Sound & voice: no sound', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'movera_driver_settings_section_sound':
          '{"schemaVersion":1,"values":{"generalVolume":0.0}}',
    });
    await OnlineSwitchSound.wentOnline();
    expect(alerts, <String>['haptic']);
  });

  test('Vibration off: no haptic, sound still plays', () async {
    OfferAlertSettings.vibrate.value = false;
    await OnlineSwitchSound.wentOnline();
    expect(alerts, <String>['sound:${OnlineSwitchSound.online}']);
  });

  testWidgets('Home: sheet up, tap → offline at once, sheet down, sounds', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump();
    expect(find.text('LIVE'), findsOneWidget);
    expect(alerts, contains('sound:${OnlineSwitchSound.online}'));

    await openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.controller!.panelPosition, greaterThan(0.5));
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-hold-off')));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Go offline?'), findsNothing);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(alerts.last, 'sound:${OnlineSwitchSound.offline}');
    expect(panel.controller!.panelPosition, closeTo(0, 0.02));
    expectNoException(tester);
  });

  testWidgets('Home: sheet down, tap → offline, the sheet stays down', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.controller!.panelPosition, closeTo(0, 0.02));
    await tester.tap(find.text('LIVE'));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Go offline?'), findsNothing);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(panel.controller!.panelPosition, closeTo(0, 0.02));
    expect(alerts.last, 'sound:${OnlineSwitchSound.offline}');
    expectNoException(tester);
  });
}
