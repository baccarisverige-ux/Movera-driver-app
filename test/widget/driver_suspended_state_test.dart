import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/driver_suspended_sheet.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/widgets/layout_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('suspended state sheet is explicit and dismissible', (
    tester,
  ) async {
    var acknowledged = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverSuspendedSheet(onAcknowledge: () => acknowledged = true),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('driver-suspended-state')),
      findsOneWidget,
    );
    expect(find.text('Account access paused'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('driver-suspended-acknowledge')),
    );
    await tester.pump();

    expect(acknowledged, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'suspended driver cannot start Radar and sees authoritative state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = DriverSessionController()..suspend();

      await tester.pumpWidget(
        LayoutViewport(
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            useInheritedMediaQuery: true,
            builder: (_, __) =>
                MaterialApp(home: DriverHome(sessionController: session)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));

      expect(session.status, DriverOnlineStatus.suspended);
      expect(session.isOnline, isFalse);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Tap for details'), findsOneWidget);

      await tester.tap(find.text('PAUSED'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const ValueKey<String>('driver-suspended-state')),
        findsOneWidget,
      );
      expect(session.status, DriverOnlineStatus.suspended);
      expect(session.isOnline, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('R10-7: the island keeps the hold reason and opens its sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = DriverSessionController()..suspend();

    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) =>
              MaterialApp(home: DriverHome(sessionController: session)),
        ),
      ),
    );
    // Past the island's wake-up and any message's time: still on hold.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));

    const reason = 'Account on hold · Contact support';
    expect(find.text(reason), findsOneWidget);

    await tester.tap(find.text(reason));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey<String>('driver-suspended-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
