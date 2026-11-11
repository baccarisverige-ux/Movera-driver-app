import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_chat_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.18.64 §85 (owner 2026-11-11: "the language must arrive with
/// the receiver language and the translate when click on it must open
/// original language"): a message from the rider shows translated into the
/// driver's language; "See original" shows it as written, a second tap the
/// translation again; a failure shows the original with no notice.
void main() {
  late LiveDriverServices live;
  late List<http.Request> requests;
  late http.Response Function(Map<String, dynamic> body) translateAnswer;
  late bool autoTranslate;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  List<http.Request> translateRequests() => requests
      .where((r) => r.url.path == '/api/v1/trips/t1/messages/translate')
      .toList();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverAppTexts.language = 'en';
    requests = [];
    autoTranslate = true;
    translateAnswer = (body) => json(200, {
      'messageId': body['messageId'],
      'to': 'en',
      'text': 'Hi, where are you?',
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/trips/t1/messages/options') {
        return json(200, {
          'quickReplies': const [],
          'quickRepliesOn': true,
          'maxLength': 2000,
          'sound': true,
          'sheetAutoOpen': 'new_message',
          'readAloudDefault': false,
          'translation': true,
          'autoTranslate': autoTranslate,
          'headerLine': const {'en': 'Problem? Use Support or SOS'},
        });
      }
      if (path == '/api/v1/trips/t1/messages/translate') {
        return translateAnswer(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
      }
      if (path == '/api/v1/trips/t1/messages') {
        return json(200, {
          'items': [
            {
              'messageId': 'd1',
              'tripId': 't1',
              'from': 'driver',
              'text': 'Jag kommer',
              'lang': 'sv',
              'at': '2026-11-11T08:00:00Z',
            },
            {
              'messageId': 'r1',
              'tripId': 't1',
              'from': 'rider',
              'text': 'Hej, var är du?',
              'lang': 'sv',
              'at': '2026-11-11T08:01:00Z',
            },
            {
              'messageId': 'r2',
              'tripId': 't1',
              'from': 'rider',
              'text': 'Thanks!',
              'quickReplyId': 'thanks',
              'lang': 'en',
              'at': '2026-11-11T08:02:00Z',
            },
          ],
          'nextCursor': null,
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
        builder: (_, __) => MaterialApp(
          home: Chat(
            riderDisplayName: 'Maya',
            tripId: 't1',
            liveChat: live.chat,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the rider\'s message arrives translated; "See original" '
      'shows it as written, a second tap the translation, one request', (
    tester,
  ) async {
    await show(tester);
    final asked = translateRequests();
    expect(asked, hasLength(1), reason: 'only r1: d1 is own, r2 is in en');
    expect(jsonDecode(asked.single.body), {
      'messageId': 'r1',
      'to': 'en',
      'auto': true,
    });
    expect(find.text('Hi, where are you?'), findsOneWidget);
    expect(find.text('Hej, var är du?'), findsNothing);
    // Own message and a chip already in English: as written.
    expect(find.text('Jag kommer'), findsOneWidget);
    expect(find.text('Thanks!'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-see-original')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-see-original')));
    await tester.pumpAndSettle();
    expect(find.text('Hej, var är du?'), findsOneWidget);
    expect(find.text('Hi, where are you?'), findsNothing);
    final back = find.byKey(const ValueKey('chat-translate')).first;
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Hi, where are you?'), findsOneWidget);
    expect(translateRequests(), hasLength(1));
  });

  testWidgets('a new message on the stream arrives translated too', (
    tester,
  ) async {
    translateAnswer = (body) => json(200, {
      'messageId': body['messageId'],
      'to': 'en',
      'text': body['messageId'] == 'r3' ? 'I am at the door' : 'Hi',
    });
    await show(tester);
    live.chat.receive(
      't1',
      const RealtimeMessage(
        messageId: 'r3',
        from: 'rider',
        text: 'Jag står vid dörren',
        lang: 'sv',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('I am at the door'), findsOneWidget);
    expect(find.text('Jag står vid dörren'), findsNothing);
  });

  testWidgets('503 coming_soon: the original, no notice, and no request for '
      'the next message (stops for the trip)', (tester) async {
    translateAnswer = (_) => json(503, {
      'code': 'unavailable',
      'message': 'Soon.',
      'reason': 'coming_soon',
    });
    await show(tester);
    expect(find.text('Hej, var är du?'), findsOneWidget);
    expect(find.text('Translation coming soon'), findsNothing);
    expect(find.byKey(const ValueKey('chat-call-notice')), findsNothing);
    expect(find.text('Translate to English'), findsNWidgets(2));
    live.chat.receive(
      't1',
      const RealtimeMessage(messageId: 'r4', from: 'rider', text: 'Hallå?'),
    );
    await tester.pumpAndSettle();
    expect(translateRequests(), hasLength(1));
  });

  testWidgets('a network error: the original, no notice, no retry loop', (
    tester,
  ) async {
    translateAnswer = (_) => json(500, {'code': 'internal', 'message': 'x'});
    await show(tester);
    expect(find.text('Hej, var är du?'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-call-notice')), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(translateRequests(), hasLength(1));
  });

  testWidgets('autoTranslate off (admin): nothing asked by itself; a tap '
      'still translates (no auto flag)', (tester) async {
    autoTranslate = false;
    await show(tester);
    expect(translateRequests(), isEmpty);
    expect(find.text('Hej, var är du?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-translate')).first);
    await tester.pumpAndSettle();
    expect(find.text('Hi, where are you?'), findsOneWidget);
    expect(jsonDecode(translateRequests().single.body), {
      'messageId': 'r1',
      'to': 'en',
    });
  });

  test('before the options are read nothing is asked; an older server '
      '(no autoTranslate) means off', () async {
    await live.chat.load('t1');
    expect(translateRequests(), isEmpty);
    expect(
      TripChatOptions.fromJson(const {'translation': true}).autoTranslate,
      isFalse,
    );
  });

  testWidgets('the trip sheet card shows the translation; read aloud waits '
      'for it', (tester) async {
    Future<String>? spoken;
    translateAnswer = (body) => json(200, {
      'messageId': body['messageId'],
      'to': 'en',
      'text': 'Where are you parked?',
    });
    final alerts = TripChatAlerts(
      chat: live.chat,
      tripId: 't1',
      onNew: (message, _) => spoken = live.chat.spokenText('t1', message),
    )..start();
    addTearDown(alerts.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripChatCard(
            alerts: alerts,
            riderFirstName: 'Maya',
            onOpen: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    live.chat.receive(
      't1',
      const RealtimeMessage(
        messageId: 'r5',
        from: 'rider',
        text: 'Var står du?',
        lang: 'sv',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('active-ride-chat-card-text')))
          .data,
      'Where are you parked?',
    );
    String? said;
    unawaited(spoken!.then((text) => said = text));
    await tester.pump();
    expect(said, 'Where are you parked?');
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
