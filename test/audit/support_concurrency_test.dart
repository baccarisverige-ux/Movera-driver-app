import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';

class _DelayedSupport extends LocalSupportRepository {
  final result = Completer<void>();
  int writes = 0;
  @override
  Future<Map<String, dynamic>> read() async => {
    'tickets': [
      {
        'subject': 'Race ticket',
        'preview': 'First message',
        'messages': [
          {'text': 'First message'},
        ],
      },
    ],
  };
  @override
  Future<void> update(String field, Object value) {
    writes++;
    return result.future;
  }
}

void main() {
  testWidgets(
    'pending support save prevents duplicates and preserves newer composer text',
    (tester) async {
      final repo = _DelayedSupport();
      await tester.pumpWidget(
        MaterialApp(home: SupportInboxScreen(repository: repo)),
      );
      await tester.pump();
      await tester.tap(find.text('Race ticket'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Save me');
      await tester.tap(find.byKey(const ValueKey('local-reply-save')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('local-reply-save')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'New draft');
      expect(repo.writes, 1);
      repo.result.complete();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'New draft',
      );
      expect(find.text('Save me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
