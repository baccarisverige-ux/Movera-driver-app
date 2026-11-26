import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';

// Owner 2026-11-26 ("animated ringer icon, but classy"): the Important
// reminders bell rings once when the box appears and again when a new
// reminder comes in; it rests in between, never loops, and stays still with
// reduce motion.

Map<String, Object?> _line(String kind) => {
  'kind': kind,
  'level': 'due_soon',
  'documentType': 'insurance',
  'daysLeft': 12,
};

DriverReminderList _list(int n) => DriverReminderList.fromJson({
  'items': [for (var i = 0; i < n; i++) _line('document_expiring')],
});

double _angle(WidgetTester tester) {
  final rotate = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byKey(ReminderBell.bellKey),
          matching: find.byType(Transform),
        )
        .first,
  );
  // The rotation's sine sits at row 1, column 0 of the matrix.
  return rotate.transform.entry(1, 0);
}

Future<void> _pump(
  WidgetTester tester,
  DriverRemindersStore store, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: ImportantRemindersBox(store: store, onFix: (_) {}),
      ),
    ),
  ),
);

void main() {
  test('a ring swings both ways, dies away and ends at rest', () {
    final samples = [
      for (var i = 1; i < 100; i++) ReminderBell.angleAt(i / 100),
    ];
    expect(samples.any((a) => a > 0.1), isTrue);
    expect(samples.any((a) => a < -0.1), isTrue);
    expect(samples.every((a) => a.abs() <= ReminderBell.maxAngle), isTrue);
    // The last swing is much smaller than the first.
    final firstPeak = samples
        .take(20)
        .map((a) => a.abs())
        .reduce((a, b) => a > b ? a : b);
    final lastPeak = samples
        .skip(70)
        .map((a) => a.abs())
        .reduce((a, b) => a > b ? a : b);
    expect(lastPeak, lessThan(firstPeak / 4));
    expect(ReminderBell.angleAt(0), 0);
    expect(ReminderBell.angleAt(1), 0);
  });

  testWidgets('rings once when the box appears, then rests (no loop)', (
    tester,
  ) async {
    final store = DriverRemindersStore()..replace(_list(2));
    await _pump(tester, store);
    await tester.pump(const Duration(milliseconds: 90));
    expect(_angle(tester).abs(), greaterThan(0.05));
    await tester.pumpAndSettle();
    expect(_angle(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a new reminder rings again; one fewer does not', (tester) async {
    final store = DriverRemindersStore()..replace(_list(2));
    await _pump(tester, store);
    await tester.pumpAndSettle();

    store.replace(_list(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_angle(tester), 0);

    store.replace(_list(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_angle(tester).abs(), greaterThan(0.05));
    await tester.pumpAndSettle();
    expect(_angle(tester), 0);
  });

  testWidgets('reduce motion: the bell never moves', (tester) async {
    final store = DriverRemindersStore()..replace(_list(2));
    await _pump(tester, store, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 90));
    expect(_angle(tester), 0);
    store.replace(_list(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_angle(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
