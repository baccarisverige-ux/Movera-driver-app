// Wave 5 D5.2 (UI truth), part a: messages the app shows must be backed
// by what really happened.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/presentation/common/chat/chat.dart';

/// Opens Chat for [tripId] on its own route; returns the navigator.
Future<NavigatorState> _openChat(WidgetTester tester, String tripId) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Trip')),
    ),
  ));
  navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Chat(riderDisplayName: 'Maya', tripId: tripId)));
  await tester.pumpAndSettle();
  return navigator.currentState!;
}

Future<void> _save(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(LocalChatMessages.reset);

  test('driver-u20: outside the demo the admin area demand never promises '
      'a trip soon, a busy area or rising demand', () {
    final tips = IslandWaitingSignals.fromHome(
      const DriverHomeAdminContentService().load(),
      now: DateTime(2026, 10, 21, 9),
    ).tips().map((t) => t.title);
    expect(tips, isNot(contains('Expect a trip in 2–5 min')));
    expect(tips, isNot(contains('Busy area · trips expected soon')));
    expect(tips, isNot(contains('Demand rising near you')));
  });

  testWidgets('driver-u54: a message saved locally is still there when Chat '
      'is opened again for the same trip', (tester) async {
    final navigator = await _openChat(tester, 'trip-1');
    await _save(tester, 'At the north entrance');
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Chat(riderDisplayName: 'Maya', tripId: 'trip-1')));
    await tester.pumpAndSettle();
    expect(find.text('At the north entrance'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Chat(riderDisplayName: 'Sara', tripId: 'trip-2')));
    await tester.pumpAndSettle();
    expect(find.text('At the north entrance'), findsNothing);
  });
}
