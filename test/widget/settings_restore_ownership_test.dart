import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/sound & voice/sound_voice.dart';

class _Settings extends SettingsRepository {
  Completer<Map<String, dynamic>> restore = Completer();
  int reads = 0;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> read(String section) {
    reads++;
    return restore.future;
  }

  @override
  Future<void> save(String section, Map<String, dynamic> values) async {
    writes.add(Map.of(values));
  }
}

void _expectBlocked(WidgetTester tester) {
  for (final control in tester.widgetList<Switch>(find.byType(Switch))) {
    expect(control.onChanged, isNull);
  }
  for (final control in tester.widgetList<Slider>(find.byType(Slider))) {
    expect(control.onChanged, isNull);
  }
  final save = find.widgetWithText(OutlinedButton, 'Save preferences');
  if (save.evaluate().isNotEmpty) {
    expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
    final category = find.ancestor(
      of: find.text('Movera Pet'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(category).onTap, isNull);
  }
}

void main() {
  final surfaces = <String, Widget Function(_Settings)>{
    'accessibility': (repo) => Accessibility(repository: repo),
    'sound': (repo) => SoundAndVoice(repository: repo),
    'categories': (repo) => Preferences(repository: repo),
  };
  final saved = <String, Map<String, dynamic>>{
    'accessibility': {'flash': true, 'vibration': false},
    'sound': {
      'generalVolume': .8,
      'alwaysPlayRequests': false,
      'voiceNavigation': false,
      'readRiderMessages': true,
    },
    'categories': {
      'selected': [false, true, false, true, false, true, false, true],
    },
  };
  for (final entry in surfaces.entries) {
    testWidgets(
      '${entry.key} cannot overwrite saved fields during delayed restore',
      (tester) async {
        final repo = _Settings();
        await tester.pumpWidget(MaterialApp(home: entry.value(repo)));
        await tester.pump();
        _expectBlocked(tester);
        expect(repo.writes, isEmpty);
        repo.restore.complete(saved[entry.key]);
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        if (entry.key == 'accessibility') {
          final control = tester.widget<Switch>(find.byType(Switch).at(1));
          expect(control.value, isFalse);
          control.onChanged!(true);
          await tester.pumpAndSettle();
          expect(repo.writes.last, {'flash': true, 'vibration': true});
        } else if (entry.key == 'sound') {
          final slider = tester.widget<Slider>(find.byType(Slider));
          expect(slider.value, .8);
          slider.onChanged!(.6);
          await tester.pumpAndSettle();
          expect(repo.writes.last, {
            'generalVolume': .6,
            'alwaysPlayRequests': false,
            'voiceNavigation': false,
            'readRiderMessages': true,
          });
        } else {
          final category = find.ancestor(
            of: find.text('Movera Pet'),
            matching: find.byType(InkWell),
          );
          tester.widget<InkWell>(category).onTap!();
          await tester.pumpAndSettle();
          expect(repo.writes.last['selected'], [
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
          ]);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${entry.key} failed restore blocks edits until guarded retry succeeds',
      (tester) async {
        final repo = _Settings();
        await tester.pumpWidget(MaterialApp(home: entry.value(repo)));
        await tester.pump();
        repo.restore.completeError(StateError('Local storage unavailable'));
        await tester.pumpAndSettle();
        _expectBlocked(tester);
        final retry = find.text('Could not load saved preferences — Retry');
        expect(retry, findsOneWidget);
        repo.restore = Completer();
        final callback = tester
            .widget<TextButton>(
              find.ancestor(of: retry, matching: find.byType(TextButton)),
            )
            .onPressed!;
        callback();
        callback();
        await tester.pump();
        expect(repo.reads, 2, reason: 'Repeated Retry shares one restore');
        _expectBlocked(tester);
        repo.restore.complete(saved[entry.key]);
        await tester.pumpAndSettle();
        expect(retry, findsNothing);
        expect(repo.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
