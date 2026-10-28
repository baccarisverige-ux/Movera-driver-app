import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/common/chat/trip_call.dart';

/// Contract v0.13.0 §22 in the driver's Chat: closed at drop-off, calls
/// only through the masked number (503 call_unavailable today).
void main() {
  late List<http.Response> answers;

  LiveTripChat live() => LiveTripChat(
    api: ApiClient(
      client: MockClient((_) async {
        if (answers.isEmpty) {
          return http.Response(
            jsonEncode({'items': [], 'nextCursor': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return answers.removeAt(0);
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    ),
  );

  http.Response error(int status, String code, String reason) => http.Response(
    jsonEncode({'code': code, 'message': 'No.', 'reason': reason}),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() => answers = []);

  Future<void> pump(WidgetTester tester, LiveTripChat chat) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: Chat(riderDisplayName: 'Maya', tripId: 't1', liveChat: chat),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('after drop-off the input is off with a clear line', (
    tester,
  ) async {
    final chat = live()..markClosed('t1');
    await pump(tester, chat);
    expect(find.text(tr.chatClosedAfterTrip), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
  });

  testWidgets('503 call_unavailable: use the chat, nothing dialled', (
    tester,
  ) async {
    final chat = live();
    await pump(tester, chat);
    answers.add(error(503, 'unavailable', 'call_unavailable'));
    answers.add(error(503, 'unavailable', 'call_unavailable'));
    await tester.tap(find.byTooltip(tr.callRider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(tr.callUnavailableUseChat), findsOneWidget);
  });

  testWidgets('a proxy number is dialled; 409 closes the chat', (tester) async {
    final chat = live();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    answers.add(
      http.Response(
        jsonEncode({
          'tripId': 't1',
          'proxyNumber': '+46101234567',
          'expiresAt': '2026-10-28T10:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final dialled = <Uri>[];
    await callRider(
      ctx,
      tripId: 't1',
      chat: chat,
      dial: (uri) async {
        dialled.add(uri);
        return true;
      },
    );
    expect(dialled, [Uri(scheme: 'tel', path: '+46101234567')]);

    answers.add(error(409, 'invalid_transition', 'chat_closed'));
    await callRider(ctx, tripId: 't1', chat: chat);
    await tester.pump();
    expect(chat.thread('t1').closed, isTrue);
    expect(find.text(tr.chatClosedAfterTrip), findsOneWidget);
  });
}
