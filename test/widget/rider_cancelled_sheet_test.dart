import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/rider_cancelled_sheet.dart';

void main() {
  for (final wasOnTrip in <bool>[false, true]) {
    testWidgets(
      'rider-cancelled surface renders ${wasOnTrip ? 'mid-trip' : 'pre-pickup'} state',
      (tester) async {
        var acknowledged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RiderCancelledSheet(
                riderName: 'Rider',
                wasOnTrip: wasOnTrip,
                onAcknowledge: () => acknowledged = true,
              ),
            ),
          ),
        );

        expect(
          find.byKey(
            ValueKey<String>(
              wasOnTrip
                  ? 'rider-cancelled-mid-trip'
                  : 'rider-cancelled-pre-pickup',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(wasOnTrip ? 'Rider ended the trip' : 'Rider cancelled'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('rider-cancelled-acknowledge')),
        );
        await tester.pump();

        expect(acknowledged, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rider cancellation cannot be dismissed from the barrier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showRiderCancelledSheet(
                  context,
                  riderName: 'Rider',
                  wasOnTrip: true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('rider-cancelled-mid-trip')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('rider-cancelled-mid-trip')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('rider-cancelled-acknowledge')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('rider-cancelled-mid-trip')),
      findsNothing,
    );
  });
}
