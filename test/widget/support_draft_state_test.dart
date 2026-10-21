import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';

class _Support extends LocalSupportRepository {
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  bool failUpdate = false;
  @override
  Future<Map<String, dynamic>> read() async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Unreadable support');
    return {};
  }

  @override
  Future<void> update(String field, Object value) async {
    if (failUpdate) throw StateError('Storage full');
  }
}

void main() {
  testWidgets(
    'draft action is disabled during restore and on restore failure',
    (tester) async {
      final repository = _Support()
        ..pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(home: SupportInboxScreen(repository: repository)),
      );
      final action = find.byType(FloatingActionButton);
      expect(tester.widget<FloatingActionButton>(action).onPressed, isNull);
      repository.pending!.completeError(StateError('Unreadable support'));
      await tester.pumpAndSettle();
      expect(tester.widget<FloatingActionButton>(action).onPressed, isNull);
      expect(find.text('Could not load local support — Retry'), findsOneWidget);
      repository.pending = null;
      await tester.tap(find.text('Could not load local support — Retry'));
      await tester.pumpAndSettle();
      expect(tester.widget<FloatingActionButton>(action).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('draft validation clears as corrected fields become valid', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SupportInboxScreen(repository: _Support())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft local ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft in demo'));
    await tester.pump();
    expect(find.text('Enter a subject'), findsOneWidget);
    expect(find.text('Enter a message'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Valid subject');
    await tester.pump();
    expect(find.text('Enter a subject'), findsNothing);
    expect(find.text('Enter a message'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Valid message');
    await tester.pump();
    expect(find.text('Enter a message'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a failing draft autosave says so once, not per keystroke '
      '(driver-r4-25)', (tester) async {
    final repository = _Support()..failUpdate = true;
    await tester.pumpWidget(
      MaterialApp(home: SupportInboxScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft local ticket'));
    await tester.pumpAndSettle();
    for (final text in ['A', 'Ap', 'App', 'App c', 'App cr', 'App crash']) {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Could not save local draft.'), findsOneWidget);
    // One SnackBar's time later the notice is gone, not queued again.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Could not save local draft.'), findsNothing);
    // A later save that works clears the failure; the next failure shows.
    repository.failUpdate = false;
    await tester.enterText(find.byType(TextField).first, 'App crashes');
    await tester.pumpAndSettle();
    repository.failUpdate = true;
    await tester.enterText(find.byType(TextField).first, 'App crashes!');
    await tester.pump();
    expect(find.text('Could not save local draft.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
