// Finder A2 (2026-11-07): the trip's rider sheet showed a made-up count:
// « 312 rides » (AcceptRide's default, also for a trip restored from the
// server, whose projection has no count) or « 0 rides » (an offer with no
// riderTrips, read as 0). The count shows only when the server sends one.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

Future<void> _openRiderSheet(WidgetTester tester, AcceptRide trip) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(home: trip),
    ),
  );
  await tester.pump(const Duration(milliseconds: 160));
  tester
      .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .controller!
      .animatePanelToSnapPoint();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 520));
  await tester.pump(const Duration(milliseconds: 300));
  final card = find.byKey(const ValueKey<String>('active-ride-rider-card'));
  await tester.tap(
    find.descendant(of: card, matching: find.byType(InkWell)).first,
    warnIfMissed: false,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('rider-sheet-initials')), findsOneWidget);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('no count sent: no « 312 rides » / « 0 rides »', (tester) async {
    final bus = MemoryDriverRealtime();
    addTearDown(bus.dispose);
    await _openRiderSheet(tester, AcceptRide(tripId: 'a2-trip', realtime: bus));
    expect(find.textContaining('312'), findsNothing);
    expect(find.textContaining('0 rides'), findsNothing);
    await _end(tester);
  });

  testWidgets('a count of 0 (an offer with no riderTrips) is not shown', (
    tester,
  ) async {
    final bus = MemoryDriverRealtime();
    addTearDown(bus.dispose);
    await _openRiderSheet(
      tester,
      AcceptRide(tripId: 'a2-trip', realtime: bus, riderTrips: 0),
    );
    expect(find.textContaining('0 rides'), findsNothing);
    await _end(tester);
  });

  testWidgets('a real count is shown', (tester) async {
    final bus = MemoryDriverRealtime();
    addTearDown(bus.dispose);
    await _openRiderSheet(
      tester,
      AcceptRide(tripId: 'a2-trip', realtime: bus, riderTrips: 27),
    );
    expect(find.textContaining('27 rides'), findsOneWidget);
    await _end(tester);
  });
}
