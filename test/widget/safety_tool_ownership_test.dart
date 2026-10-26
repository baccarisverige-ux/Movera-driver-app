import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/presentation/driver/safety toolkits/safety_toolkits.dart';

Future<GlobalKey<NavigatorState>> _open(
  WidgetTester tester,
  Future<bool> Function() launch,
) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(body: SafetyToolKits(launchEmergencyDial: launch)),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

VoidCallback _tap(WidgetTester tester, String label) => tester
    .widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    )
    .onTap!;

void main() {
  testWidgets(
    'emergency confirmation and pending dial handoff are single flight',
    (tester) async {
      final dial = Completer<bool>();
      var launches = 0;
      await _open(tester, () {
        launches++;
        return dial.future;
      });
      final contact = _tap(tester, 'Contact 112');
      contact();
      contact();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final confirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Call 112'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(launches, 1);
      contact();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      dial.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the dialer. Dial 112 manually.'),
        findsOneWidget,
      );
      contact();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preferences entry ignores repeated and disposed callbacks', (
    tester,
  ) async {
    await _open(tester, () async => false);
    final preferences = _tap(tester, 'Safety preferences');
    preferences();
    preferences();
    await tester.pumpAndSettle();
    expect(
      find.text('Ride check is on. The others are preview only.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    preferences();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final disposed in [false, true]) {
    testWidgets(
      'late dial result is ignored when owner is ${disposed ? 'disposed' : 'covered'}',
      (tester) async {
        SafetyAudioOption.debugEnabled =
            true; // owner decision 10: offered again
        addTearDown(() => SafetyAudioOption.debugEnabled = null);
        final dial = Completer<bool>();
        final navigator = await _open(tester, () => dial.future);
        final contact = _tap(tester, 'Contact 112');
        final recording = _tap(tester, 'Record audio');
        contact();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Call 112'));
        await tester.pumpAndSettle();
        if (disposed) {
          await tester.pumpWidget(const SizedBox());
        } else {
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covering route')),
            ),
          );
          await tester.pumpAndSettle();
        }
        recording();
        contact();
        dial.complete(true);
        await tester.pumpAndSettle();
        if (!disposed) {
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Emergency dialer opened — confirm the call on your device.',
            ),
            findsNothing,
          );
          expect(
            find.text('Audio recording is unavailable in this demo.'),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
