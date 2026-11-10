import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';

// Owner 2026-11-10: keep the long press to go offline; a tap shows the
// "Hold to go offline" hint.
void main() {
  Future<List<int>> pump(WidgetTester tester) async {
    final fired = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RadarHoldOff(
              onConfirmed: () => fired.add(1),
              child: const SizedBox.square(dimension: 104),
            ),
          ),
        ),
      ),
    );
    return fired;
  }

  final hold = find.byKey(const ValueKey<String>('home-radar-hold-off'));
  final hint = find.byKey(const ValueKey<String>('hold-to-go-offline-hint'));

  testWidgets('a tap shows the hold hint and does not go offline', (
    tester,
  ) async {
    final fired = await pump(tester);
    await tester.tap(hold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(hint, findsOneWidget);
    expect(find.text('Hold to go offline'), findsOneWidget);
    expect(fired, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(hint, findsNothing);
  });

  testWidgets('a long hold still goes offline, no hint', (tester) async {
    final fired = await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fired, [1]);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(hint, findsNothing);
    await tester.pumpAndSettle();
  });
}
