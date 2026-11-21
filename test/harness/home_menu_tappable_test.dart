// The device run's HISTORY step (integration_test/staging/trip_money.dart
// `_history`) could not open the menu after Rate → Done: online and
// waiting, the island says "Finding trips" and tucks the menu button
// until it is touched (R13-1). Test Lab run 44951732597.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/staging/driver_steps.dart';
import '../widget/home_suite/_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Finding trips: the harness touches the island, then the menu '
      'takes the tap', (WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    final menu = find.byTooltip('Menu').hitTestable();
    expect(menu, findsOneWidget);

    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 2200));
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Finding trips'), findsOneWidget);

    // What the step did before: waiting alone never brings the menu back.
    expect(menu, findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(menu, findsNothing);

    expect(
      await homeMenuTappable(tester, menu, timeout: const Duration(seconds: 2)),
      isTrue,
    );
    expect(menu, findsOneWidget);
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(find.text('Finding trips'), findsNothing);
    // The touch only closed the waiting face: the island did not move on.
    expect(find.text('•••• kr'), findsOneWidget);

    await tester.tap(menu);
    await advanceAnimation(tester, const Duration(milliseconds: 520));
    expect(byKey('driver-side-menu'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Menu already tappable: the island is not touched', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));
    await wakeIsland(tester);
    final menu = find.byTooltip('Menu').hitTestable();
    expect(
      await homeMenuTappable(tester, menu, timeout: const Duration(seconds: 2)),
      isTrue,
    );
    expect(find.text('•••• kr'), findsOneWidget);
    expectNoException(tester);
  });
}
