// L-c (owner 2026-11-06 "Remove it (Safe)"): the trip screen's give-back (end trip
// early) reasons no longer say "Doesn't count"; each reason shows only its own line.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('L-c: the give-back reasons never say "Doesn\'t count"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'lc-giveback',
            riderName: 'Angelica',
            initialStage: ActiveRideStage.onTrip,
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await _settle(tester, 12);
    final cancel = find.byKey(
      const ValueKey<String>('active-ride-cancel-option'),
    );
    await tester.ensureVisible(cancel);
    await _settle(tester, 8);
    await tester.tap(cancel);
    await _settle(tester, 16);
    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-reasons-sheet')),
      findsOneWidget,
    );
    expect(find.text('Vehicle problem'), findsOneWidget);
    expect(
      find.text('A vehicle issue makes it unsafe to continue'),
      findsOneWidget,
    );
    expect(find.textContaining('Doesn’t count'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
