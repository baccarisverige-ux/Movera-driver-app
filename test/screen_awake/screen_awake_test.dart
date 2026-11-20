// Audit 2026-11-20 (app lifecycle) item 2: the screen stays on while a trip
// is active (heading to pickup, at pickup, in trip) and only then.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/device/screen_awake.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ScreenAwake.channelName);
  late List<Object?> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add('${call.method}:${call.arguments}');
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ScreenAwake.instance = ScreenAwake();
  });

  test('on while one screen holds it; tells the phone only changes', () {
    final awake = ScreenAwake(supported: () => true);
    final a = Object(), b = Object();
    awake.hold(a, keep: true);
    awake.hold(b, keep: true);
    awake.release(a);
    expect(awake.on, isTrue);
    awake.release(b);
    expect(awake.on, isFalse);
    expect(calls, ['keepOn:true', 'keepOn:false']);
  });

  test('a web or desktop build tells no phone', () {
    final awake = ScreenAwake(supported: () => false);
    awake.hold(Object(), keep: true);
    expect(calls, isEmpty);
  });

  for (final stage in ActiveRideStage.values) {
    testWidgets('the trip screen keeps the screen on ($stage)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
      ScreenAwake.instance = ScreenAwake(supported: () => true);
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
              tripId: 'awake-${stage.name}',
              riderName: 'Angelica',
              initialStage: stage,
              activeRideRepository: MemoryActiveRideRepository(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(ScreenAwake.instance.on, isTrue);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(ScreenAwake.instance.on, isFalse);
      expect(calls.first, 'keepOn:true');
      expect(calls.last, 'keepOn:false');
    });
  }
}
