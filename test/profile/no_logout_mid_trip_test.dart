// Finder A3 (2026-11-07): the trip drawer opens Profile, and Log out there
// signed the driver out in the middle of a trip (no trip check in
// _confirmLogout / signOutDriver / main.dart _logout). The trip stayed live
// on the server and the rider saw a frozen car. While a trip is active the
// app now says "Finish the trip first." and does not log out.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int Function()> _pumpProfile(
  WidgetTester tester,
  DriverSessionController session,
) async {
  var logouts = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: DriverRuntimeScope(
        session: session,
        homeBuilder: () => const Scaffold(body: Text('HOME')),
        logout: () async => logouts++,
        child: const DriverProfile(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return () => logouts;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Log out during an active trip is refused', (tester) async {
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    session.beginTrip('trp_1');
    final logouts = await _pumpProfile(tester, session);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Finish the trip first.'), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);
    expect(logouts(), 0);
    expect(session.activeTripId, 'trp_1');
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('Log out works again once the trip has ended', (tester) async {
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    session.beginTrip('trp_1');
    session.endTrip();
    final logouts = await _pumpProfile(tester, session);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(logouts(), 1);
    expect(find.text('HOME'), findsOneWidget);
  });
}
