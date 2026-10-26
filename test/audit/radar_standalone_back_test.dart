import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';

void main() {
  testWidgets('standalone Radar Back returns to previous route', (
    tester,
  ) async {
    final dispatch = DemoDispatchRepository(
      newOfferDelay: const Duration(hours: 1),
      externalClaimDelay: const Duration(hours: 1),
    );
    addTearDown(dispatch.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-radar'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RideRequests(dispatchRepository: dispatch),
                ),
              ),
              child: const Text('Open Radar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-radar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RideRequests), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RideRequests), findsNothing);
    expect(find.byKey(const ValueKey('open-radar')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // External dispatch is owned by this test, not by RideRequests. Dispose
    // its demo timers before the widget-test pending-timer invariant runs.
    await tester.pumpWidget(const SizedBox.shrink());
    dispatch.dispose();
    await tester.pump();
  });

  testWidgets('embedded Radar Back still calls Home-owned callback', (
    tester,
  ) async {
    final dispatch = DemoDispatchRepository(
      newOfferDelay: const Duration(hours: 1),
      externalClaimDelay: const Duration(hours: 1),
    );
    addTearDown(dispatch.dispose);
    var closeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequests(
          dispatchRepository: dispatch,
          onCloseRides: (_) => closeCalls++,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(closeCalls, 1);
    expect(find.byType(RideRequests), findsOneWidget);
    expect(tester.takeException(), isNull);
    // External dispatch is owned by this test, not by RideRequests. Dispose
    // its demo timers before the widget-test pending-timer invariant runs.
    await tester.pumpWidget(const SizedBox.shrink());
    dispatch.dispose();
    await tester.pump();
  });
}
