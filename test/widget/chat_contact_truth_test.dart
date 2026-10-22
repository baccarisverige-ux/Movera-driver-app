import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/rider_contact.dart';
import 'package:movera/presentation/common/chat/chat.dart';

void main() {
  testWidgets('chat clearly identifies local demo delivery state', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => const MaterialApp(
          home: Chat(riderDisplayName: 'Maya'),
        ),
      ),
    );

    expect(find.text('Maya'), findsOneWidget);
    expect(
      find.text('Local demo chat · messages are not sent to the rider.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat shows the rider identity and does not dial', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const Chat(riderDisplayName: 'Maya'),
                      ),
                    );
                  },
                  child: const Text('Open chat'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();

    expect(find.text('Maya'), findsOneWidget);
    expect(find.text("Driver’s name"), findsNothing);
    expect(find.textContaining('4670'), findsNothing);
    expect(
      find.text('Local demo chat · messages are not sent to the rider.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(RiderContactPolicy.unavailableMessage));
    await tester.pump();

    expect(find.text(RiderContactPolicy.unavailableMessage), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Chat), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('reachable chat source has no hard-coded tel target', () {
    final appBar = File('lib/presentation/common/chat/components/appbar.dart')
        .readAsStringSync();
    final chat = File('lib/presentation/common/chat/chat.dart').readAsStringSync();
    final ride = File('lib/presentation/driver/accept ride/accept_ride.dart')
            .readAsStringSync() +
        File('lib/presentation/driver/accept ride/accept_ride_panel.dart')
            .readAsStringSync();
    expect(appBar, isNot(contains('tel:')));
    expect(appBar, isNot(contains('46701234567')));
    expect(appBar, isNot(contains('url_launcher')));
    expect(chat, isNot(contains('tel:')));
    expect(ride, contains('Chat(riderDisplayName: widget.riderName, tripId: widget.tripId)'));
    expect(RiderContactPolicy.available, isFalse);
    expect(
      RiderContactPolicy.unavailableMessage,
      'Rider phone contact is not connected in this demo.',
    );
  });
}
