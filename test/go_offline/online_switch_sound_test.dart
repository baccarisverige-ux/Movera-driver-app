import 'dart:io';

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

  test('owner 2026-11-27: the cleaned sounds play, the old files stay', () {
    expect(OnlineSwitchSound.online, 'sounds/radar_on_clean.mp3');
    expect(OnlineSwitchSound.offline, 'sounds/radar_off_clean.mp3');
    for (final f in <String>[
      'assets/${OnlineSwitchSound.online}',
      'assets/${OnlineSwitchSound.offline}',
      'assets/sounds/radar_on.mp3',
      'assets/sounds/radar_off.mp3',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
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

  testWidgets('Home: sheet up, 1 s hold → offline, sheet down, sounds', (
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
    // Sheet up the radar reads "Hold · OFF" and only a 1 s hold goes
    // offline (owner 2026-11-28, replaces the 2026-11-26 tap rule).
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Tap'), findsNothing);
    await holdRadarOff(tester);
    await advanceAnimation(tester, const Duration(milliseconds: 900));
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

  testWidgets('Home: sheet up, offline, tap → online, sheet comes down', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(panel.controller!.panelPosition, greaterThan(0.5));
    await tester.tap(find.text('OFF'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('LIVE'), findsOneWidget);
    expect(panel.controller!.panelPosition, closeTo(0, 0.02));
    expectNoException(tester);
  });

  testWidgets('Home: the sheet goes down in one smooth ease, no stop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    await openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    // Owner 2026-11-28: a 1 s hold (not a tap) goes offline. The press
    // registers after the 100 ms tap timeout, then the ring fills 1 s.
    final hold = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('home-radar-hold-off')),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await hold.up();
    for (var i = 0; i < 40 && panel.controller!.panelPosition >= 1.0; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    var last = panel.controller!.panelPosition;
    expect(last, lessThan(1.0));
    // Every frame moves down until the end (no pause, no bounce).
    for (var t = 0; t < 520; t += 40) {
      await tester.pump(const Duration(milliseconds: 40));
      final now = panel.controller!.panelPosition;
      expect(now, lessThan(last), reason: 'at ${t + 40} ms');
      expect(now, greaterThanOrEqualTo(0));
      last = now;
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(panel.controller!.panelPosition, closeTo(0, 0.001));
    expectNoException(tester);
  });
}
