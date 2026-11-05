import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/presentation/driver/airport_queue/airport_queue_card.dart';

/// Fix job 9 (contract v0.18.36 §60, owner G15 Q5 "Build it for real"): the
/// driver sees his real place in the airport queue from
/// GET /driver/airport-queue; no sample texts; "You left the airport queue"
/// when he leaves it.
const inQueue = {
  'status': 'in_queue',
  'areaId': 'AQ-ARN',
  'airportZoneId': 'ARN',
  'position': 3,
  'ahead': 2,
  'joinedAt': '2026-11-05T12:00:00Z',
  'waitingMin': 14,
};

Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
  ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) =>
        const MaterialApp(home: Scaffold(body: AirportQueueCard(poll: false))),
  ),
);

void main() {
  tearDown(() => AirportQueue.instance.use(null));

  test('the server answer parses; a wrong one is no answer', () {
    final s = AirportQueueStatus.tryParse(inQueue)!;
    expect(s.inQueue, isTrue);
    expect(s.position, 3);
    expect(s.ahead, 2);
    expect(s.waitingMin, 14);
    expect(AirportQueueStatus.tryParse({'status': 'off'})!.inQueue, isFalse);
    expect(AirportQueueStatus.tryParse({'nope': 1}), isNull);
    expect(AirportQueueStatus.tryParse({'status': 'in_queue'}), isNull);
    expect(AirportQueue.path, '/api/v1/driver/airport-queue');
  });

  test(
    'leaving the queue raises the "You left the airport queue" notice once',
    () {
      final queue = AirportQueue.instance;
      var notices = 0;
      void listener() {
        if (queue.takeLeftNotice()) notices++;
      }

      queue.addListener(listener);
      queue.use(AirportQueueStatus.tryParse(inQueue));
      queue.use(AirportQueueStatus.tryParse({'status': 'not_in_area'}));
      queue.use(AirportQueueStatus.tryParse({'status': 'not_in_area'}));
      queue.removeListener(listener);
      expect(notices, 1);
    },
  );

  testWidgets('Home card: his real place, no "Sample" text', (tester) async {
    AirportQueue.instance.use(AirportQueueStatus.tryParse(inQueue));
    await pumpCard(tester);
    expect(find.text('Airport queue'), findsOneWidget);
    expect(find.text('You are number 3 in line'), findsOneWidget);
    expect(find.text('2 drivers ahead · waiting 14 min'), findsOneWidget);
    expect(find.textContaining('Sample'), findsNothing);
    expect(find.textContaining('sample'), findsNothing);
  });

  testWidgets('Home card: nothing when he is not in a queue; the left notice '
      'shows', (tester) async {
    AirportQueue.instance.use(AirportQueueStatus.tryParse(inQueue));
    await pumpCard(tester);
    AirportQueue.instance.use(
      AirportQueueStatus.tryParse({'status': 'not_in_area'}),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('airport-queue-card')), findsNothing);
    expect(find.text('You left the airport queue'), findsOneWidget);
  });

  test('island: the airport tip names his place from the server', () {
    final signals = IslandWaitingSignals.fromHome(
      const DriverHomeAdminContentService().load(),
      now: DateTime.utc(2026, 11, 5, 12),
      airportQueuePlace: 3,
    );
    expect(
      signals.tips().map((t) => t.title),
      contains('Airport queue: you are number 3'),
    );
  });

  test('Home shows the live card, not the sample card, in a live build', () {
    final sheet = File(
      'lib/presentation/driver/home/home_map_sheet.dart',
    ).readAsStringSync();
    expect(sheet, contains('AirportQueueCard('));
    final card = File(
      'lib/presentation/driver/airport_queue/airport_queue_card.dart',
    ).readAsStringSync();
    expect(card, isNot(contains('queueSample')));
  });
}
