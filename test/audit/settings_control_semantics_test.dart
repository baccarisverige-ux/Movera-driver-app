import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/sound%20&%20voice/sound_voice.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (var index = 0; index < 2; index++) {
    testWidgets(
      'accessibility switch $index has independent name and persisted semantic action',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          // Both off first (vibration starts on by default, owner
          // 2026-10-31), so each switch is seen turning on alone.
          await tester.runAsync(
            () => SettingsRepository().save('accessibility', {
              'flash': false,
              'vibration': false,
            }),
          );
          await tester.pumpWidget(const MaterialApp(home: Accessibility()));
          await tester.pumpAndSettle();
          final node = tester.getSemantics(find.byType(Switch).at(index));
          expect(
            node.getSemanticsData().label,
            index == 0 ? 'Flash for requests' : 'Vibration for requests',
          );
          tester.binding.performSemanticsAction(
            SemanticsActionEvent(
              viewId: tester.view.viewId,
              nodeId: node.id,
              type: SemanticsAction.tap,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<Switch>(find.byType(Switch).at(index)).value,
            isTrue,
          );
          expect(
            tester.widget<Switch>(find.byType(Switch).at(1 - index)).value,
            isFalse,
          );
          final saved = await SettingsRepository().read('accessibility');
          expect(saved[index == 0 ? 'flash' : 'vibration'], isTrue);
          expect(saved[index == 0 ? 'vibration' : 'flash'], isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      },
    );
  }
  testWidgets(
    'volume slider has name percentage and semantic adjustment persists',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const MaterialApp(home: SoundAndVoice()));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(
          find.bySemanticsLabel('General volume'),
        );
        expect(node.getSemanticsData().label, 'General volume');
        expect(node.getSemanticsData().value, '35%');
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: SemanticsAction.increase,
          ),
        );
        await tester.pumpAndSettle();
        final value = tester.widget<Slider>(find.byType(Slider)).value;
        expect(value, greaterThan(.35));
        expect(
          (await SettingsRepository().read('sound'))['generalVolume'],
          value,
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );
}
