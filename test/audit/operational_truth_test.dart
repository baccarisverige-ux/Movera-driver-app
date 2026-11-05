import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:movera/presentation/driver/earning%20stats/earning_stats.dart';
import 'package:movera/presentation/driver/my%20queue%20position/components/in_airport_queue.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
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

  /// Every text on screen, scrolled through each list.
  Future<String> texts(WidgetTester tester) async {
    final seen = <String>{};
    void collect() {
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final s = w.data ?? w.textSpan?.toPlainText();
        if (s != null) seen.add(s);
      }
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        seen.add(w.text.toPlainText());
      }
    }

    collect();
    final lists = find.byType(Scrollable);
    for (var n = 0; n < lists.evaluate().length; n++) {
      for (var i = 0; i < 10; i++) {
        await tester.drag(
          lists.at(n),
          const Offset(0, -300),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 50));
        collect();
      }
    }
    return seen.join('\n');
  }

  group('static operational screens are clearly preview data', () {
    testWidgets('Earning stats shows no sample payout or company', (
      tester,
    ) async {
      await pump(tester, const EarningStatsScreen());
      final all = await texts(tester);
      expect(all, isNot(contains(r'$12.00')));
      expect(all, isNot(contains('Skypulse solution pvt')));
      expect(all, isNot(contains('Pakistan')));
    });

    testWidgets('Driving logs shows no invented rest rule', (tester) async {
      await pump(tester, const DrivingLogs());
      expect(
        await texts(tester),
        isNot(contains('after 4.5 hours of driving')),
      );
    });

    testWidgets('Promotions are labelled Preview, never Live', (tester) async {
      await pump(tester, const Promotions());
      expect(find.text('Preview'), findsWidgets);
      expect(find.text('Live'), findsNothing);
    });

    testWidgets('the airport queue says it is a preview', (tester) async {
      await pump(tester, const Scaffold(body: InAirportQueue()));
      expect(
        find.textContaining('Airport queue preview', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('Analytics says it is a preview', (tester) async {
      await pump(tester, const Analytics());
      expect(
        find.textContaining('Analytics preview', findRichText: true),
        findsWidgets,
      );
    });
  });
}
