import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// uat-d2 (owner, device check): the "Demo mode — no account" landing
/// screen is gone. Log out ends on Home.
void main() {
  testWidgets('Log out opens Home, not a landing screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = DriverSessionController();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRuntimeScope(
          session: session,
          homeBuilder: () => const Scaffold(body: Text('HOME')),
          logout: () async {},
          child: const DriverProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
  });
}
