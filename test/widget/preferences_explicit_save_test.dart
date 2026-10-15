import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';

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

Future<void> _open(WidgetTester tester, _Settings repo) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Preferences(repository: repo)));
  await tester.pumpAndSettle();
}

VoidCallback _save(WidgetTester tester) => tester
    .widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Save preferences'),
    )
    .onPressed!;

void main() {
  testWidgets('explicit Save rejects repeated callbacks and permits retry', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    final save = _save(tester);
    save();
    save();
    await tester.pump();
    expect(repo.writes, hasLength(1));
    expect(find.text('Saving preferences…'), findsOneWidget);
    repo.writes.single.completeError(StateError('Disk unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Changes not saved — Retry'), findsOneWidget);
    _save(tester)();
    expect(repo.writes, hasLength(2));
    repo.writes.last.complete();
    await tester.pumpAndSettle();
    // The six categories admin allows for the car (Q27).
    expect(find.text('6 ride categories saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older explicit Save cannot announce unsaved newer selections', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    _save(tester)();
    final edit = tester
        .widget<InkWell>(
          find.ancestor(
            of: find.text('Movera Pet'),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!;
    edit();
    expect(repo.writes, hasLength(2));
    repo.writes.first.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    repo.writes.last.completeError(StateError('New selection not saved'));
    await tester.pumpAndSettle();
    expect(find.text('Changes not saved — Retry'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
