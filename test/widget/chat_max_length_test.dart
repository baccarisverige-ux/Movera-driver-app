import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/presentation/common/chat/chat.dart';

/// REMINDERS row 28: the chat input stops at the country's chat max length
/// (contract §78 `ChatOptions.maxLength`), so the server never has to
/// refuse a too-long message; a counter shows only near the limit.
void main() {
  late LiveDriverServices live;
  late List<http.Request> posts;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    posts = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/trips/live-trip/messages/options') {
        return json(200, {'maxLength': 100, 'quickReplies': []});
      }
      if (path == '/api/v1/trips/live-trip/messages') {
        if (request.method == 'GET') {
          return json(200, {'items': [], 'nextCursor': null});
        }
        posts.add(request);
        final text = (jsonDecode(request.body) as Map)['text'] as String;
        if (text.length > 100) {
          return json(422, {'code': 'too_long', 'message': 'Too long.'});
        }
        return json(201, {
          'messageId': 'm2',
          'tripId': 'live-trip',
          'from': 'driver',
          'text': text,
          'at': '2026-10-25T10:01:00Z',
        });
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
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => const MaterialApp(
          home: Chat(riderDisplayName: 'Maya', tripId: 'live-trip'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String typed(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('typing past the country max length stops at it, and what '
      'is sent fits', (tester) async {
    await show(tester);
    await tester.enterText(find.byType(TextFormField), 'a' * 150);
    await tester.pump();
    expect(typed(tester).length, 100);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    final sent = (jsonDecode(posts.single.body) as Map)['text'] as String;
    expect(sent.length, 100);
  });

  testWidgets('the counter shows only near the limit', (tester) async {
    await show(tester);
    final counter = find.byKey(const ValueKey<String>('chat-length-counter'));
    await tester.enterText(find.byType(TextFormField), 'a' * 50);
    await tester.pump();
    expect(counter, findsNothing);
    await tester.enterText(find.byType(TextFormField), 'a' * 95);
    await tester.pump();
    expect(find.text('95/100'), findsOneWidget);
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
