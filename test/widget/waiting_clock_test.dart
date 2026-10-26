import 'package:movera/core/ride/waiting_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  for (final (seconds, label, expected) in [
    (30, '0:30', Colors.white),
    // After the 5 free minutes the no-show is open too (Q41): red.
    (330, '5:30', const Color(0xFF9E2B33)),
  ]) {
    testWidgets('dark banner clock at ${seconds}s', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: WaitingClock(seconds: seconds, onDark: true)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_labelColor(tester, label), expected);
    });
  }

  testWidgets('dark banner clock in a paid wait before the no-show', (
    tester,
  ) async {
    // Airport pickup: 15 free minutes, no-show from 20.
    WaitingTerms.active = WaitingRules.current.termsFor(
      type: WaitingRideType.airport,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: WaitingClock(seconds: 16 * 60, onDark: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_labelColor(tester, '16:00'), const Color(0xFF146B45));
  });

  testWidgets('light sheet clock keeps ink in the included minutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: WaitingClock(seconds: 30))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_labelColor(tester, '0:30'), const Color(0xFF1C242C));
  });
}
