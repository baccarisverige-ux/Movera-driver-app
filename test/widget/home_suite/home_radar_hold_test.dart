// Owner decision (session-2026-11-06, restated 2026-11-28): the Home
// online radar with the sheet open works like the trip radar: a 1 s hold
// fills the green ring and goes offline. Owner correction 2026-11-28:
// a short tap shows NO hint and does nothing. Owner update 2026-11-28:
// sheet up, the radar reads "Hold · OFF" (tr.hold, tr.orbOff) like the
// trip radar; subtitle and semantics label unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  final radar = find.byKey(const ValueKey<String>('home-radar-hold-off'));
  final hint = find.byKey(const ValueKey<String>('hold-to-go-offline-hint'));

  Future<void> goOnlineAndOpen(WidgetTester tester) async {
    await pumpHome(tester, const Size(375, 812));
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);
    await openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(radar, findsOneWidget);
  }

  testWidgets('Home radar (sheet open): Hold · OFF, hold-only off', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await goOnlineAndOpen(tester);
    final w = tester.widget<RadarHoldOff>(
      find.ancestor(of: radar, matching: find.byType(RadarHoldOff)),
    );
    expect(w.tapGoes, isFalse);
    expect(w.tapHint, isFalse);
    expect(w.ownHaptics, isFalse);
    expect(w.semanticsLabel, 'Tap to go offline');
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Tap'), findsNothing);
    expect(find.text('Go offline'), findsOneWidget);
  });

  testWidgets('Home radar: a short tap does nothing (no hint, stays online)', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await goOnlineAndOpen(tester);
    await tester.tap(radar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(hint, findsNothing);
    expect(find.text('Hold to go offline'), findsNothing);
    expect(find.text('Tap to scan'), findsNothing);
    expect(radar, findsOneWidget, reason: 'still online, sheet open');
    await advanceAnimation(tester, const Duration(seconds: 3));
    expect(hint, findsNothing);
    expect(radar, findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Home radar: a 1 s hold goes offline once', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await goOnlineAndOpen(tester);
    final gesture = await tester.startGesture(tester.getCenter(radar));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await gesture.up();
    await advanceAnimation(tester, const Duration(milliseconds: 900));
    expect(find.text('Go offline?'), findsNothing);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(hint, findsNothing);
    expectNoException(tester);
  });
}
