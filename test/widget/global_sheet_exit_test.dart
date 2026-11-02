import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/presentation/driver/accept ride/rider_cancelled_sheet.dart';
import 'package:movera/presentation/driver/accept ride/trip_outcome_sheet.dart';
import 'package:movera/presentation/driver/accept ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/home/components/trip_problem_sheet.dart';
import 'package:movera/presentation/driver/my queue position/my_queue_pos.dart';

Future<BuildContext> _owner(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final nav = GlobalKey<NavigatorState>();
  late BuildContext context;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('Root owner')),
      ),
    ),
  );
  nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (value) {
        context = value;
        return const Scaffold(body: Text('Trip owner'));
      },
    ),
  );
  await tester.pumpAndSettle();
  return context;
}

Future<void> _entered(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final sheets = <String, (Future<void> Function(BuildContext), String)>{
    'rider cancellation': (
      (context) =>
          showRiderCancelledSheet(context, riderName: 'Rider', wasOnTrip: true),
      'rider-cancelled-acknowledge',
    ),
    'terminal outcome': (
      (context) => showTripOutcomeSheet(
        context,
        status: TripStatus.noShow,
        hasNext: false,
      ),
      'trip-outcome-acknowledge',
    ),
    // The paused-account sheet cannot be closed (G16 Q16-3): its own test
    // is in test/audit/live_cleanup_test.dart.
  };
  for (final entry in sheets.entries) {
    testWidgets(
      '${entry.key} repeated acknowledgement preserves active owner',
      (tester) async {
        final context = await _owner(tester);
        entry.value.$1(context);
        await _entered(tester);
        final button = tester.widget<FilledButton>(
          find.byKey(ValueKey(entry.value.$2)),
        );
        button.onPressed!();
        button.onPressed!();
        await tester.pumpAndSettle();
        expect(find.text('Trip owner'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('queue repeated close preserves owner', (tester) async {
    final context = await _owner(tester);
    showMyQueuePositionSheet<void>(context);
    await _entered(tester);
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Close queue position',
      ),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Trip owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('trip problem action closes once and runs once', (tester) async {
    final context = await _owner(tester);
    var actions = 0;
    showTripProblemSheet(
      context,
      title: 'Problem',
      message: 'Retry local storage',
      actionLabel: 'Retry',
      onAction: () => actions++,
    );
    await _entered(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('trip-problem-action')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Trip owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('no-show cancellation action closes once and runs once', (
    tester,
  ) async {
    final context = await _owner(tester);
    var actions = 0;
    showWaitingTimeSheet(
      context,
      readSeconds: () => 301,
      onNoShow: () => actions++,
    );
    await _entered(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('waiting-no-show-cancel')),
    );
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('waiting-no-show-cancel')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Trip owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
