import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/scheduled rides/scheduled_rides.dart';

Future<void> openScheduled(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ScheduledRidesScreen(),
              ),
            ),
            child: const Text('Open scheduled'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open scheduled'));
  await tester.pumpAndSettle();
}

VoidCallback filledAction(WidgetTester tester, String label) => tester
    .widget<FilledButton>(
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
    )
    .onPressed!;

Future<void> openCancellation(WidgetTester tester) async {
  await tester.tap(find.text('Accepted'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Södermalm, Stockholm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cancel reservation'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vehicle issue'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(ScheduledRideStore.reset);

  testWidgets('accept returns once without closing the scheduled list', (
    tester,
  ) async {
    await openScheduled(tester);
    await tester.tap(find.text('Gamla vägen, Stockholm'));
    await tester.pumpAndSettle();
    final accept = filledAction(tester, 'Accept  •  126.75 kr');
    accept();
    accept();
    await tester.pumpAndSettle();
    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    // The 08:05 request clashes with it, so it left the list too (Q9).
    expect(ScheduledRideStore.openRequests.value, 0);
    expect(find.text('Gamla vägen, Stockholm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated reason and confirmation preserve cancellation flow', (
    tester,
  ) async {
    await openScheduled(tester);
    await openCancellation(tester);
    final next = filledAction(tester, 'Continue');
    next();
    next();
    await tester.pumpAndSettle();
    expect(find.text('Cancel this reservation?'), findsOneWidget);
    final confirm = filledAction(tester, 'Cancel reservation');
    confirm();
    confirm();
    await tester.pumpAndSettle();
    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    expect(find.text('Södermalm, Stockholm'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(ScheduledRideStore.openRequests.value, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeated keep leaves the reservation details and record intact',
    (tester) async {
      await openScheduled(tester);
      await openCancellation(tester);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final keep = tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Keep reservation'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed!;
      keep();
      keep();
      await tester.pumpAndSettle();
      expect(find.text('Sample reservation'), findsOneWidget);
      expect(find.text('Cancel reservation'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Södermalm, Stockholm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('repeated details Back preserves the scheduled list', (
    tester,
  ) async {
    await openScheduled(tester);
    await tester.tap(find.text('Gamla vägen, Stockholm'));
    await tester.pumpAndSettle();
    final back = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == 'Back',
          ),
        )
        .onPressed!;
    back();
    back();
    await tester.pumpAndSettle();
    expect(find.byType(ScheduledRidesScreen), findsOneWidget);
    expect(ScheduledRideStore.openRequests.value, 2);
    expect(tester.takeException(), isNull);
  });
}
