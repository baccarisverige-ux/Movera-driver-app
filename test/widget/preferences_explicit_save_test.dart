import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/claim_lock.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';

/// Owner 2026-11-25: no Save button on the ride types screen; each tap saves
/// at once, no success message; a failed save shows a short error and the
/// box goes back. (File name kept from the old explicit-Save test.)
class _Settings extends SettingsRepository {
  final writes = <Completer<void>>[];
  final values = <List<bool>>[];
  @override
  Future<Map<String, dynamic>> read(String section) async => {};
  @override
  Future<void> save(String section, Map<String, dynamic> values) {
    this.values.add(List<bool>.of(values['selected'] as List<bool>));
    final write = Completer<void>();
    writes.add(write);
    return write.future;
  }
}

const _delay = Duration(milliseconds: 400);
final _on = find.byKey(const ValueKey('ride-type-box-on'));
final _off = find.byKey(const ValueKey('ride-type-box-off'));

Future<void> _open(WidgetTester tester, _Settings repo) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Preferences(repository: repo)));
  await tester.pumpAndSettle();
}

Future<void> _tapPet(WidgetTester tester) async {
  await tester.tap(find.text('Movera Pet'));
  await tester.pump();
}

void main() {
  tearDown(() {
    DriverAppTexts.language = 'en';
    ClaimLock.set(false);
  });

  testWidgets('no Save button on the screen', (tester) async {
    await _open(tester, _Settings());
    expect(find.text('Save preferences'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('a tap saves once, with no success message', (tester) async {
    final repo = _Settings();
    await _open(tester, repo);
    final total = _on.evaluate().length;
    await _tapPet(tester);
    expect(repo.writes, isEmpty, reason: 'short wait joins quick taps');
    await tester.pump(_delay);
    expect(repo.writes, hasLength(1));
    expect(repo.values.single.where((v) => !v), hasLength(1));
    repo.writes.single.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('saved'), findsNothing);
    expect(find.textContaining('Saving'), findsNothing);
    expect(_off, findsOneWidget);
    expect(_on, findsNWidgets(total - 1));
  });

  testWidgets('quick taps send one request with the last state', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    await _tapPet(tester);
    await _tapPet(tester);
    await _tapPet(tester);
    await tester.pump(_delay);
    expect(repo.writes, hasLength(1));
    expect(repo.values.single.where((v) => !v), hasLength(1));
    repo.writes.single.complete();
    await tester.pumpAndSettle();

    // On then off again before the wait ends: nothing changed, no request.
    await _tapPet(tester);
    await _tapPet(tester);
    await tester.pump(_delay);
    expect(repo.writes, hasLength(1));
  });

  testWidgets('a tap during a save goes after it; the last state wins', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    await _tapPet(tester);
    await tester.pump(_delay);
    expect(repo.writes, hasLength(1));
    await tester.tap(find.text('Movera'));
    await tester.pump(_delay);
    expect(repo.writes, hasLength(1), reason: 'never two at once');
    repo.writes.first.complete();
    await tester.pump();
    expect(repo.writes, hasLength(2));
    expect(repo.values.last.where((v) => !v), hasLength(2));
    repo.writes.last.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(_off, findsNWidgets(2));
  });

  for (final (lang, text) in const [
    ('en', 'Not saved, try again'),
    ('fr', 'Pas enregistré, réessayez'),
    ('sv', 'Inte sparat, försök igen'),
  ]) {
    testWidgets('[$lang] a failed save shows the error and the box goes back', (
      tester,
    ) async {
      DriverAppTexts.language = lang;
      final repo = _Settings();
      await _open(tester, repo);
      final total = _on.evaluate().length;
      await tester.tap(_on.first);
      await tester.pump(_delay);
      expect(_off, findsOneWidget);
      repo.writes.single.completeError(StateError('Server said no'));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      expect(_off, findsNothing);
      expect(_on, findsNWidgets(total));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed older save is not shown when a newer one succeeds', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    await _tapPet(tester);
    await tester.pump(_delay);
    await tester.tap(find.text('Movera'));
    await tester.pump(_delay);
    repo.writes.first.completeError(StateError('Older failed'));
    await tester.pump();
    expect(repo.writes, hasLength(2));
    repo.writes.last.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(_off, findsNWidgets(2));
  });

  testWidgets('no tap and no save while a claim is with dispatch', (
    tester,
  ) async {
    final repo = _Settings();
    await _open(tester, repo);
    ClaimLock.set(true);
    await tester.pump();
    await tester.tap(find.text('Movera Pet'), warnIfMissed: false);
    await tester.pump(_delay);
    expect(repo.writes, isEmpty);
    expect(_off, findsNothing);
  });

  testWidgets('leaving right after a tap still saves it', (tester) async {
    final repo = _Settings();
    await _open(tester, repo);
    await _tapPet(tester);
    await tester.pumpWidget(const SizedBox());
    expect(repo.writes, hasLength(1));
    repo.writes.single.completeError(StateError('Late failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
