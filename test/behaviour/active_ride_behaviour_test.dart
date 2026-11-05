import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// B16 (2026-11-04): the trip screen's arrival action, driven through the
/// real AcceptRide. Replaces the source-reading "arrival action remains
/// wired" guard (archived in Rules/archive/old-tests/Movera-driver-app/).
/// The in-memory bus, noting each signal the trip screen sends.
class _SpyRealtime extends MemoryDriverRealtime {
  final signals = <(String, DriverRealtimeKind)>[];

  @override
  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  }) {
    signals.add((tripId, kind));
    return super.sendSignal(tripId: tripId, kind: kind, message: message);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('"I\'ve arrived" sits in the opened sheet, not the collapsed '
      'bar, and tells the rider the driver arrived', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bus = _SpyRealtime();
    addTearDown(bus.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(tripId: 'b16-trip', realtime: bus),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));

    // Collapsed trip bar: no arrival button there.
    final arrived = find.byKey(
      const ValueKey<String>('active-ride-arrived-button'),
    );
    expect(arrived, findsNothing);
    expect(find.text("I've arrived"), findsNothing);

    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    await tester.pump(const Duration(milliseconds: 300));
    expect(arrived, findsOneWidget);
    expect(find.text("I've arrived"), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-headingToPickup')),
      findsWidgets,
    );

    await tester.ensureVisible(arrived);
    await tester.tap(arrived);
    await tester.pump(const Duration(milliseconds: 240));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsWidgets,
    );
    expect(
      bus.signals,
      contains(('b16-trip', DriverRealtimeKind.driverArrived)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
