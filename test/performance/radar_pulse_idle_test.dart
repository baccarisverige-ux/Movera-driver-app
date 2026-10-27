import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// P7-D1 (owner decision 2026-10-27): the Radar orb pulses only while the
// driver is online. Offline (also on hold or with an account that is not
// active) the orb stands still and an idle Home schedules no frames.

const _touch = ValueKey<String>('trip-radar-touch-target');

MoveraRadarOrb _orb(WidgetTester tester) => tester
    .widgetList<MoveraRadarOrb>(find.byType(MoveraRadarOrb))
    .where((orb) => orb.touchKey == _touch)
    .single;

Future<DriverSessionController> _pumpHome(
  WidgetTester tester, {
  bool accountPending = false,
}) async {
  ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = DriverSessionController();
  addTearDown(session.dispose);
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: session,
            accountPending: accountPending,
          ),
        ),
      ),
    ),
  );
  // Let the start-up work (recovery, first location, sheet) settle.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return session;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  for (final pending in [false, true]) {
    testWidgets(
      'offline${pending ? ' (account not active)' : ''}: the Radar orb '
      'stands still and idle Home schedules no frames',
      (tester) async {
        await _pumpHome(tester, accountPending: pending);
        // Idle: the island's one pass of light (5.2 s) is over.
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final before = _orb(tester).pulse;
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        expect(_orb(tester).pulse, before, reason: 'no pulse offline');
        expect(_orb(tester).pulse, 0);
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: 'no animation ticker runs offline',
        );
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'frame budget: an idle offline Home draws nothing',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('online: the Radar orb pulses (ticker active)', (tester) async {
    final session = await _pumpHome(tester);
    tester.widget<GestureDetector>(find.byKey(_touch)).onTap!.call();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(session.availableForOffers, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final before = _orb(tester).pulse;
    await tester.pump(const Duration(milliseconds: 700));
    expect(_orb(tester).pulse, isNot(before));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // Back offline: the orb stops again.
    session.setOnline(false);
    // Idle again once the island's "offline" message and its one pass of
    // light are over.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(session.availableForOffers, isFalse);
    expect(_orb(tester).pulse, 0);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
