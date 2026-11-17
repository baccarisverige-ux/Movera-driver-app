import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/live/live_trip_history.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';

/// D18b (owner G11 Q10, Rules decisions/driver-g11.md: "any past month"):
/// History opens on the current month and goes back month by month (never
/// into the future). A past month reads its trips from `GET /driver/trips`
/// with from / to, and its total from `GET /driver/earnings` with the same
/// month bounds, so the total equals the Earnings numbers for that month.
TripHistoryRecord _ride(String id, DateTime at, int minor) => TripHistoryRecord(
  tripId: id,
  riderName: 'Anna',
  whenLabel: '',
  pickup: 'Pickup $id',
  dropoff: 'Dropoff',
  fare: Money(minorUnits: minor, currency: 'SEK').formatted,
  fareMinorUnits: minor,
  category: 'Standard',
  completedAt: at,
);

void main() {
  testWidgets('month picker: current month first, back one month reads '
      'that month from the server, no future month', (tester) async {
    Money.zoneCurrency = 'SEK';
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    final pages = <({DateTime? from, DateTime? to})>[];
    final totals = <({DateTime from, DateTime? to})>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRideHistory(
          loadHistory: () async => const <TripHistoryRecord>[],
          loadServerPage:
              ({String? cursor, DateTime? from, DateTime? to}) async {
                pages.add((from: from, to: to));
                final past = from != null && from.isBefore(thisMonth);
                return DriverTripHistoryPage(
                  items: past
                      ? [
                          _ride(
                            'old',
                            lastMonth.add(const Duration(days: 3)),
                            7700,
                          ),
                          // Ended in the month before: not in this month's list.
                          _ride(
                            'older',
                            lastMonth.subtract(const Duration(hours: 2)),
                            100,
                          ),
                        ]
                      : [_ride('new', now, 1000)],
                );
              },
          loadTotals: ({required DateTime from, DateTime? to}) async {
            totals.add((from: from, to: to));
            final past = from.isBefore(thisMonth);
            return EarningsTotals(
              net: Money(minorUnits: past ? 7700 : 1000, currency: 'SEK'),
              tripCount: 1,
              cashCollected: const Money(minorUnits: 0, currency: 'SEK'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('history-month-next'));
    final back = find.byKey(const ValueKey('history-month-back'));
    expect(back, findsOneWidget);
    // Current month: no later month to go to.
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    expect(totals.last.from, thisMonth);
    expect(totals.last.to, isNull);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(totals.last.from, lastMonth);
    expect(totals.last.to, thisMonth);
    expect(pages.last.to, thisMonth);
    expect(pages.last.from!.isBefore(lastMonth), isTrue);
    expect(find.text('77,00 kr'), findsWidgets);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);

    await tester.tap(find.text('Rides').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pickup old'), findsWidgets);
    expect(find.textContaining('Pickup older'), findsNothing);
    expect(find.textContaining('Pickup new'), findsNothing);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(totals.last.from, thisMonth);
    expect(find.textContaining('Pickup new'), findsWidgets);
  });
}
