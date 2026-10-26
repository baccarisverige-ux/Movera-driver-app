import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final (fee, title, status) in <(Money?, String, TripStatus?)>[
    (null, 'Rider cancelled', TripStatus.cancelledByRider),
    (Money.sek(45), 'Rider cancelled · +45 kr', TripStatus.cancelledByRider),
    (Money.ore(0), 'Rider cancelled · no fee', TripStatus.cancelledByRider),
    // driver-j2-4: a rider_cancelled event without a projection status.
    (null, 'Rider cancelled', null),
  ]) {
    testWidgets('rider cancellation goes back home and tells the island: '
        '$title${status == null ? ' (no status)' : ''}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
      IslandMessages.reset();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);

      // A stand-in Home underneath the trip screen.
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AcceptRide(
                          tripId: 'cancel-home-trip',
                          riderName: 'Angelica',
                          initialStage: ActiveRideStage.waitingForRider,
                          activeRideRepository: MemoryActiveRideRepository(),
                          realtime: realtime,
                        ),
                      ),
                    ),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AcceptRide), findsOneWidget);

      realtime.emit(
        tripId: 'cancel-home-trip',
        kind: DriverRealtimeKind.riderCancelled,
        status: status,
        cancelFee: fee,
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Straight back home, no sheet; the island has the news.
      expect(find.byType(AcceptRide), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Rider cancelled'), findsNothing);
      final message = IslandMessages.take();
      expect(message?.title, title);
      expect(message?.priority, IslandPriority.high);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
