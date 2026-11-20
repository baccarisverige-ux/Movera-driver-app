import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';

/// Audit 2026-11-20 N5 ("Resor 6" next to "Visa alla 7 resor"), owner
/// 2026-11-20 "Must see all kind": Rides and View all N rides count every
/// ride of the period, completed, cancelled and no-show, and the full list
/// shows each with its status label.
void main() {
  TripHistoryRecord ride(String id, TripStatus status) => TripHistoryRecord(
    tripId: id,
    riderName: 'Karin',
    whenLabel: 'Today',
    pickup: 'Gamla vägen',
    dropoff: 'Solna centrum',
    fare: '152,40 kr',
    category: 'Comfort',
    status: status,
    completedAt: DateTime.now(),
  );

  testWidgets('5 completed + 1 cancelled + 1 no-show: Rides 7, View all 7', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: DriverRideHistory(
            loadHistory: () async => [
              for (var i = 0; i < 5; i++) ride('c$i', TripStatus.completed),
              ride('x', TripStatus.cancelledByRider),
              ride('n', TripStatus.noShow),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.ancestor(
      of: find.text('Rides'),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_MetricCard',
      ),
    );
    expect(find.descendant(of: card, matching: find.text('7')), findsOneWidget);
    expect(find.text('View all 7 rides'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-view-all-rides')));
    await tester.pumpAndSettle();
    for (final s in [
      TripStatus.completed,
      TripStatus.cancelledByRider,
      TripStatus.noShow,
    ]) {
      expect(find.text(tripOutcomeText(s)), findsWidgets);
    }
  });
}
