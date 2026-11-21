import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/money/money.dart';
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

  Map<String, Object?> period(int tripCount, Map<String, int>? rideCounts) => {
    'periodStart': '2026-11-11T23:00:00Z',
    'periodEnd': '2026-11-12T23:00:00Z',
    'tripCount': tripCount,
    'net': {'amountMinor': 100, 'currency': 'SEK'},
    'tips': {'amountMinor': 0, 'currency': 'SEK'},
    'cashCollected': {'amountMinor': 0, 'currency': 'SEK'},
    'rideCounts': ?rideCounts,
  };

  Future<void> pumpWith(
    WidgetTester tester,
    Future<EarningsTotals> Function() totals,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: DriverRideHistory(
            // This phone lists 2 of the period's rides only.
            loadHistory: () async => [
              ride('c', TripStatus.completed),
              ride('x', TripStatus.cancelledByDriver),
            ],
            loadTotals: ({required DateTime from, DateTime? to}) => totals(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String rides(WidgetTester tester) {
    final card = find.ancestor(
      of: find.text('Rides'),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_MetricCard',
      ),
    );
    return tester
        .widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .where((d) => d != 'Rides')
        .single!;
  }

  testWidgets('server rideCounts: Rides and View all N use the server sum', (
    tester,
  ) async {
    Money.zoneCurrency = 'SEK';
    await pumpWith(
      tester,
      () async => EarningsTotals.of({
        'currency': 'SEK',
        'periods': [
          period(4, {'completed': 4, 'cancelled': 2, 'noShow': 1}),
          period(1, {'completed': 1, 'cancelled': 0, 'noShow': 2}),
        ],
      }),
    );
    // 5 completed + 2 cancelled + 3 no-show; not the 2 on this phone, not
    // tripCount 5.
    expect(rides(tester), '10');
    expect(find.text('View all 10 rides'), findsOneWidget);
  });

  testWidgets('older server (no rideCounts): both show its tripCount', (
    tester,
  ) async {
    await pumpWith(
      tester,
      () async => EarningsTotals.of({
        'currency': 'SEK',
        'periods': [period(4, null), period(1, null)],
      }),
    );
    expect(rides(tester), '5');
    expect(find.text('View all 5 rides'), findsOneWidget);
  });

  testWidgets('server read failed: both show the listed rides', (tester) async {
    await pumpWith(tester, () async => throw const FormatException('down'));
    expect(rides(tester), '2');
    expect(find.text('View all 2 rides'), findsOneWidget);
  });

  test(
    'EarningsTotals.rideCount: all kinds summed; any period missing → null',
    () {
      EarningsTotals of(List<Map<String, Object?>> periods) =>
          EarningsTotals.of({'currency': 'SEK', 'periods': periods});
      expect(
        of([
          period(2, {'completed': 2, 'cancelled': 1, 'noShow': 1}),
        ]).rideCount,
        4,
      );
      expect(
        of([
          period(2, {'completed': 2, 'cancelled': 1, 'noShow': 1}),
          period(1, null),
        ]).rideCount,
        isNull,
      );
      expect(of([]).rideCount, isNull);
      expect(
        of([
          period(1, {'completed': 1, 'cancelled': -1, 'noShow': 0}),
        ]).rideCount,
        isNull,
      );
    },
  );
}
