import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/common/chat/chat.dart';

/// A live build: Chat shows the trip's messages from the server (the
/// rider's on the left), sends through it, and keeps a message that was
/// not sent for a retry. The demo's local chat is untouched.
void main() {
  late List<http.Request> posts;
  late List<http.Response Function()> postAnswers;
  late LiveDriverServices live;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> message(String id, String from, String text, String at) =>
      {'messageId': id, 'tripId': 'live-trip', 'from': from, 'text': text, 'at': at};

  setUp(() {
    posts = [];
    postAnswers = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/trips/live-trip/messages') {
        if (request.method == 'GET') {
          return json(200, {
            'items': [message('m1', 'rider', 'Where are you?', '2026-10-25T10:00:00Z')],
            'nextCursor': null,
          });
        }
        posts.add(request);
        return postAnswers.removeAt(0)();
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });

  tearDown(() async {
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => const MaterialApp(
        home: Chat(riderDisplayName: 'Maya', tripId: 'live-trip'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  testWidgets('the history is read on opening; the rider\'s message sits on '
      'the left and the demo notice is gone', (tester) async {
    await show(tester);
    expect(find.text('Where are you?'), findsOneWidget);
    final bubble = tester.getRect(find.byKey(const ValueKey<String>('chat-rider-message')));
    expect(bubble.center.dx, lessThan(375 / 2), reason: 'left-aligned');
    expect(find.text(tr.chatLocalDemo), findsNothing);
    expect(find.text(tr.chatLocalNotSent), findsNothing);
    expect(find.byTooltip(tr.chatSend), findsOneWidget);
    expect(live.chat.unreadOf('live-trip'), 0);
  });

  testWidgets('a message is sent to the server and shown once with its time; '
      'one the rider sends meanwhile appears at once', (tester) async {
    await show(tester);
    postAnswers.add(() => json(201,
        message('m2', 'driver', 'Coming now', '2026-10-25T10:01:00Z')));
    await send(tester, 'Coming now');
    expect(posts.single.url.path, '/api/v1/trips/live-trip/messages');
    expect(jsonDecode(posts.single.body), {'text': 'Coming now'});
    expect(find.text('Coming now'), findsOneWidget);
    expect(find.text(tr.chatSending), findsNothing);
    expect(find.text(tr.chatLocalNotSent), findsNothing);
    final own = tester.getRect(find.byKey(const ValueKey<String>('chat-own-message')));
    expect(own.center.dx, greaterThan(375 / 2), reason: 'right-aligned');

    live.chat.receive('live-trip', RealtimeMessage(
      messageId: 'm3',
      from: 'rider',
      text: 'Thanks',
      at: DateTime.utc(2026, 10, 25, 10, 2),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thanks'), findsOneWidget);
    // Chat is open: read as it arrives.
    expect(live.chat.unreadOf('live-trip'), 0);
  });

  testWidgets('a message that was not sent stays, says so, and a tap sends '
      'it again with the same key', (tester) async {
    await show(tester);
    postAnswers
      ..add(() => throw http.ClientException('lost'))
      ..add(() => json(201, message('m4', 'driver', 'Outside', '2026-10-25T10:03:00Z')));
    await send(tester, 'Outside');
    expect(find.text('Outside'), findsOneWidget);
    expect(find.text(tr.chatNotSentTapToRetry), findsOneWidget);
    expect(find.text(tr.authErrOffline), findsOneWidget, reason: 'the usual snack bar');

    await tester.tap(find.text('Outside'));
    await tester.pumpAndSettle();
    expect(posts, hasLength(2));
    expect(posts[1].headers['Idempotency-Key'], posts[0].headers['Idempotency-Key']);
    expect(find.text('Outside'), findsOneWidget);
    expect(find.text(tr.chatNotSentTapToRetry), findsNothing);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
