import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';

class _ContactsRepository extends SettingsRepository {
  final reads = <Completer<Map<String, dynamic>>>[];
  final writes = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> read(String section) {
    final result = Completer<Map<String, dynamic>>();
    reads.add(result);
    return result.future;
  }

  @override
  Future<void> save(String section, Map<String, dynamic> values) async {
    writes.add(values);
  }
}

const _savedContacts = <String, dynamic>{
  'rows': [
    {'name': 'Saved person', 'phone': '+46701234567'},
  ],
};

Future<void> _open(WidgetTester tester, _ContactsRepository repository) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, child) => MaterialApp(home: child),
      child: EmergencyContactsScreen(repository: repository),
    ),
  );
  await tester.pump();
}

VoidCallback _retry(WidgetTester tester) => tester
    .widget<TextButton>(
      find.widgetWithText(
        TextButton,
        'Could not load trusted contacts — Retry',
      ),
    )
    .onPressed!;

void _expectAddBlocked(WidgetTester tester) {
  expect(
    tester
        .widget<IconButton>(find.byKey(const ValueKey('add-emergency-contact')))
        .onPressed,
    isNull,
  );
}

void main() {
  testWidgets('repeated contacts Retry shares one restore before adding', (
    tester,
  ) async {
    final repository = _ContactsRepository();
    await _open(tester, repository);
    _expectAddBlocked(tester);
    repository.reads.single.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    final retry = _retry(tester);
    retry();
    retry();
    await tester.pump();
    expect(repository.reads, hasLength(2));
    _expectAddBlocked(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repository.reads.last.complete(_savedContacts);
    await tester.pumpAndSettle();
    expect(find.text('Saved person'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-emergency-contact')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'New person');
    await tester.enterText(find.byType(TextFormField).at(1), '+46701740621');
    await tester.tap(find.text('Save contact'));
    await tester.pumpAndSettle();
    expect(find.text('Saved person'), findsOneWidget);
    expect(find.text('New person'), findsOneWidget);
    expect(repository.writes.single['rows'], hasLength(2));
    expect(repository.reads, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed contacts Retry releases lock but keeps adding blocked', (
    tester,
  ) async {
    final repository = _ContactsRepository();
    await _open(tester, repository);
    repository.reads.single.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    _retry(tester)();
    await tester.pump();
    repository.reads.last.completeError(StateError('Still unavailable'));
    await tester.pumpAndSettle();
    _expectAddBlocked(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    _retry(tester)();
    await tester.pump();
    expect(repository.reads, hasLength(3));
    repository.reads.last.complete(_savedContacts);
    await tester.pumpAndSettle();
    expect(find.text('Saved person'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('add-emergency-contact')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contacts restore completion after disposal is ignored', (
    tester,
  ) async {
    for (final fail in [false, true]) {
      final repository = _ContactsRepository();
      await _open(tester, repository);
      await tester.pumpWidget(const SizedBox());
      if (fail) {
        repository.reads.single.completeError(
          StateError('Storage unavailable'),
        );
      } else {
        repository.reads.single.complete(_savedContacts);
      }
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });
}
