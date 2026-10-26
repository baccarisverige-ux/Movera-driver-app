import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

void main() {
  testWidgets('scheduled decisions disclose temporary nonbinding behavior', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    expect(find.textContaining('Preview — not binding'), findsOneWidget);
  });
}
