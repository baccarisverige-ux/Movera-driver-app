import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// driver-u164: a reservation request whose pickup time has passed leaves
// the Requests tab and the Home dot count, and can no longer be accepted.
// The fast test day starts at 07:00 and runs 30 times faster: the
// requests are at 07:40 (80 s) and 08:05 (130 s).

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(ScheduledRideStore.reset);
  tearDown(ScheduledRideStore.reset);

  testWidgets('passed requests are not open, listed or counted', (
    tester,
  ) async {
    final start = ScheduledClock.instance.now();
    expect(start.hour, 7);
    ScheduledRideStore.categoriesChanged();
    expect(ScheduledRideStore.openRequests.value, 2);
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);

    // 07:45: the 07:40 pickup has passed, the 08:05 one has not.
    await tester.pump(const Duration(seconds: 90));
    ScheduledRideStore.categoriesChanged();
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(ScheduledRideStore.openRequests.value, 1);
    await _open(tester);
    expect(find.text('Gamla vägen, Stockholm'), findsNothing);
    expect(find.text('Högsätravägen, Lidingö'), findsOneWidget);

    // 08:10: both have passed.
    await tester.pump(const Duration(seconds: 50));
    ScheduledRideStore.categoriesChanged();
    await tester.pumpAndSettle();
    expect(ScheduledRideStore.openRequests.value, 0);
    expect(find.text('Högsätravägen, Lidingö'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accept on a request whose pickup passed meanwhile is refused', (
    tester,
  ) async {
    await _open(tester);
    await tester.ensureVisible(find.text('Högsätravägen, Lidingö').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Högsätravägen, Lidingö').first);
    await tester.pumpAndSettle();
    // The details stay open past the 08:05 pickup.
    await tester.pump(const Duration(seconds: 140));
    final accept = find.textContaining('Accept  •');
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(find.textContaining('Accepted · pickup 08:05'), findsNothing);
    expect(
      ScheduledRideStore.upcoming.where((r) => r.pickupTime == '08:05'),
      isEmpty,
    );
    expect(find.text('No longer available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home stops counting a request once its pickup time passes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(sessionController: DriverSessionController()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ScheduledRideStore.openRequests.value, 2);
    // 07:45, then 08:10: nothing else changes the store meanwhile.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(ScheduledRideStore.openRequests.value, 1);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(ScheduledRideStore.openRequests.value, 0);
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });
}
