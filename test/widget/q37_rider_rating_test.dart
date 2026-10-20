import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DriverRideCompleted())),
            child: const Text('Home'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Home'));
  await tester.pumpAndSettle();
}

// Q37/Q38: after the trip the driver may rate the rider with whole stars
// (1–5), or skip it with Done.
void main() {
  testWidgets('whole stars only, 1 to 5', (tester) async {
    await _open(tester);
    final bar = tester.widget<RatingBar>(find.byType(RatingBar));
    expect(bar.allowHalfRating, isFalse);
    expect(bar.itemCount, 5);
    expect(bar.minRating, 1);
    expect(find.text('Rate Rider'), findsOneWidget);
  });

  testWidgets('a star is optional: Done without one goes Home', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('ride-completed-done')));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRideCompleted), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a star, then Done', (tester) async {
    await _open(tester);
    await tester.tap(find.byType(RatingBar));
    await tester.pump();
    expect(find.text('Rating not sent (demo)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('ride-completed-done')));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRideCompleted), findsNothing);
  });
}
