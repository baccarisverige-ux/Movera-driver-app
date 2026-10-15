import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/sound & voice/sound_voice.dart';

class _Settings extends SettingsRepository {
  final writes = <Completer<void>>[];
  @override
  Future<Map<String, dynamic>> read(String section) async => {};
  @override
  Future<void> save(String section, Map<String, dynamic> values) {
    final write = Completer<void>();
    writes.add(write);
    return write.future;
  }
}

VoidCallback _edit(WidgetTester tester, String surface) {
  if (surface == 'sound') {
    final change = tester.widget<Slider>(find.byType(Slider)).onChanged!;
    return () => change(.7);
  }
  if (surface == 'accessibility') {
    final change = tester.widget<Switch>(find.byType(Switch).first).onChanged!;
    return () => change(true);
  }
  return tester
      .widget<InkWell>(
        find.ancestor(
          of: find.text('Movera Pet'),
          matching: find.byType(InkWell),
        ),
      )
      .onTap!;
}

void main() {
  final surfaces = <String, Widget Function(_Settings)>{
    'categories': (repo) => Preferences(repository: repo),
    'accessibility': (repo) => Accessibility(repository: repo),
    'sound': (repo) => SoundAndVoice(repository: repo),
  };
  for (final entry in surfaces.entries) {
    Future<void> open(WidgetTester tester, _Settings repo) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: entry.value(repo)));
      await tester.pumpAndSettle();
    }

    testWidgets(
      '${entry.key} failed save remains visible and Retry is single flight',
      (tester) async {
        final repo = _Settings();
        await open(tester, repo);
        _edit(tester, entry.key)();
        repo.writes.single.completeError(StateError('Write failed'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('Changes not saved — Retry'), findsOneWidget);
        final retry = tester
            .widget<TextButton>(
              find.byKey(const ValueKey('settings-save-retry')),
            )
            .onPressed!;
        retry();
        retry();
        await tester.pump();
        expect(repo.writes, hasLength(2));
        repo.writes.last.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-save-retry')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${entry.key} an older failed write cannot override the latest successful save',
      (tester) async {
        final repo = _Settings();
        await open(tester, repo);
        final edit = _edit(tester, entry.key);
        edit();
        edit();
        expect(repo.writes, hasLength(2));
        repo.writes.last.complete();
        await tester.pumpAndSettle();
        repo.writes.first.completeError(StateError('Older write failed'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-save-retry')), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${entry.key} disposed editing and late save callbacks are ignored',
      (tester) async {
        final repo = _Settings();
        await open(tester, repo);
        final edit = _edit(tester, entry.key);
        edit();
        await tester.pumpWidget(const SizedBox());
        edit();
        repo.writes.single.completeError(StateError('Late failure'));
        await tester.pumpAndSettle();
        expect(repo.writes, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
