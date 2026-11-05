import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B16 (2026-11-04): behaviour tests that replace source-reading guards
/// (archived in Rules/archive/old-tests/Movera-driver-app/). Each one opens
/// the real screen and checks what the driver sees.
void main() {
  late DriverRuntimeConfig previous;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    SafetyAudioOption.debugEnabled = null;
  });

  void live() => DriverRuntimeConfig.current = const DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: false,
    skipAccountActivation: true,
    authRequired: true,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(home: child),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('B4: on live, Safety says audio and trip sharing are coming '
      'soon, never "in this demo"', (tester) async {
    live();
    SafetyAudioOption.debugEnabled = true;
    await pump(tester, const Scaffold(body: SafetyToolKits(duringTrip: true)));
    await tester.tap(find.text('Record audio'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Audio recording is coming soon.'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    ScaffoldMessenger.of(
      tester.element(find.byType(SafetyToolKits)),
    ).removeCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Share trip'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Trip sharing is coming soon.'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
