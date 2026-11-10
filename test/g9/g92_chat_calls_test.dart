import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/chat/chat_message_alert.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_chat_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.18.56 §78 (G9 part 2, owner Q79–Q85), the driver part:
/// quick replies from the options route, the header line, automatic
/// messages, the translate link with "See original", the trip sheet's
/// message card, the message alert and the incoming-call push link.
void main() {
  late LiveDriverServices live;
  late List<http.Request> requests;
  late http.Response Function() translateAnswer;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  final contract =
      jsonDecode(File('contracts/contract.json').readAsStringSync())
          as Map<String, dynamic>;
  final defaults = contract['configDefaults']['chat'] as Map<String, dynamic>;

  Map<String, dynamic> options() => {
    'quickReplies': defaults['quickReplies']['driver'],
    'quickRepliesOn': true,
    'maxLength': 2000,
    'sound': true,
    'sheetAutoOpen': 'new_message',
    'readAloudDefault': false,
    'translation': true,
    'headerLine': contract['chat']['header']['text'],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverAppTexts.language = 'en';
    requests = [];
    translateAnswer = () => json(503, {
      'code': 'unavailable',
      'message': 'Soon.',
      'reason': 'coming_soon',
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/trips/t1/messages/options') {
        return json(200, options());
      }
      if (path == '/api/v1/trips/t1/messages/translate') {
        return translateAnswer();
      }
      if (path == '/api/v1/trips/t1/messages') {
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return json(201, {
            'messageId': 'srv1',
            'tripId': 't1',
            'from': 'driver',
            // The server writes a chip in the rider's language.
            'text': body['quickReplyId'] != null
                ? 'OK, uppfattat!'
                : body['text'],
            if (body['quickReplyId'] != null)
              'quickReplyId': body['quickReplyId'],
            'at': '2026-11-10T08:05:00Z',
          });
        }
        return json(200, {
          'items': [
            {
              'messageId': 'a1',
              'tripId': 't1',
              'from': 'driver',
              'text': "I've arrived at the pickup point.",
              'auto': 'arrived',
              'at': '2026-11-10T08:00:00Z',
            },
            {
              'messageId': 'r1',
              'tripId': 't1',
              'from': 'rider',
              'text': 'Hej, var är du?',
              'at': '2026-11-10T08:01:00Z',
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
    ChatMessageAlert.debugAlert = null;
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

  testWidgets('the 5 driver chips from the options route, the header line, '
      'no report or block button', (tester) async {
    await show(tester);
    expect(
      requests.any((r) => r.url.path == '/api/v1/trips/t1/messages/options'),
      isTrue,
    );
    expect(find.text('Problem? Use Support or SOS'), findsOneWidget);
    for (final id in [
      'on_my_way',
      'five_min',
      'traffic',
      'where_are_you',
      'ok_got_it',
    ]) {
      expect(find.byKey(ValueKey('chat-quick-reply-$id')), findsOneWidget);
    }
    expect(find.text('OK, got it!'), findsOneWidget);
    expect(find.textContaining('Report'), findsNothing);
    expect(find.textContaining('Block'), findsNothing);
  });

  testWidgets('a chip is sent with its id and reads in the driver\'s '
      'language', (tester) async {
    await show(tester);
    final chip = find.byKey(const ValueKey('chat-quick-reply-ok_got_it'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final post = requests.lastWhere(
      (r) => r.method == 'POST' && r.url.path == '/api/v1/trips/t1/messages',
    );
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['quickReplyId'], 'ok_got_it');
    expect(find.text('OK, uppfattat!'), findsNothing);
    // The chip in the bar and the sent bubble.
    expect(find.text('OK, got it!'), findsNWidgets(2));
    // Its echo on the stream (rider's language) is not shown twice.
    live.chat.receive(
      't1',
      const RealtimeMessage(
        messageId: 'srv1',
        from: 'driver',
        text: 'OK, uppfattat!',
        quickReplyId: 'ok_got_it',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OK, uppfattat!'), findsNothing);
    expect(find.text('OK, got it!'), findsNWidgets(2));
  });

  testWidgets('the server\'s "I\'ve arrived" is marked automatic', (
    tester,
  ) async {
    await show(tester);
    expect(find.text("I've arrived at the pickup point."), findsOneWidget);
    expect(find.textContaining('Automatic · '), findsOneWidget);
  });

  testWidgets('503 coming_soon says "Translation coming soon"', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('chat-translate')));
    await tester.pumpAndSettle();
    final post = requests.lastWhere(
      (r) => r.url.path == '/api/v1/trips/t1/messages/translate',
    );
    expect(jsonDecode(post.body), {'messageId': 'r1', 'to': 'en'});
    expect(find.text('Translation coming soon'), findsOneWidget);
    expect(find.text('Hej, var är du?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('translated, "See original" switches back, then "Translate" '
      'again without a new request', (tester) async {
    translateAnswer = () => json(200, {
      'messageId': 'r1',
      'to': 'en',
      'text': 'Hi, where are you?',
    });
    await show(tester);
    expect(find.text('Translate to English'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-translate')));
    await tester.pumpAndSettle();
    expect(find.text('Hi, where are you?'), findsOneWidget);
    expect(find.text('Hej, var är du?'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chat-see-original')));
    await tester.pumpAndSettle();
    expect(find.text('Hej, var är du?'), findsOneWidget);
    expect(find.text('Translate to English'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-translate')));
    await tester.pumpAndSettle();
    expect(find.text('Hi, where are you?'), findsOneWidget);
    expect(
      requests
          .where((r) => r.url.path == '/api/v1/trips/t1/messages/translate')
          .length,
      1,
    );
  });

  test('the translate target is the driver\'s own language', () {
    DriverAppTexts.language = 'fr';
    expect(LiveTripChat.translateTarget, 'fr');
    DriverAppTexts.language = 'ar';
    expect(LiveTripChat.translateTarget, 'en');
  });

  testWidgets('a new message shows the sheet card and calls onNew; the '
      'rider\'s automatic "I\'m on my way" too', (tester) async {
    final seen = <String>[];
    final alerts = TripChatAlerts(
      chat: live.chat,
      tripId: 't1',
      onNew: (message, _) => seen.add(message.text),
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
    expect(find.byKey(const ValueKey('active-ride-chat-card')), findsNothing);
    live.chat.receive(
      't1',
      const RealtimeMessage(
        messageId: 'w1',
        from: 'rider',
        text: "I'm on my way to the car.",
        auto: 'on_my_way',
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, ["I'm on my way to the car."]);
    expect(find.byKey(const ValueKey('active-ride-chat-card')), findsOneWidget);
    expect(find.text('From Maya · Automatic'), findsOneWidget);
    expect(find.text('OK, got it!'), findsOneWidget);
    // A chip on the card sends it and the card goes.
    await tester.tap(find.byKey(const ValueKey('chat-quick-reply-five_min')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-ride-chat-card')), findsNothing);
    expect(
      requests.any(
        (r) =>
            r.method == 'POST' &&
            r.url.path == '/api/v1/trips/t1/messages' &&
            r.body.contains('five_min'),
      ),
      isTrue,
    );
    // Own messages and history reads never raise the card.
    await live.chat.load('t1');
    await tester.pumpAndSettle();
    expect(seen, hasLength(1));
  });

  test('no card while Chat shows the thread', () async {
    final seen = <String>[];
    final alerts = TripChatAlerts(
      chat: live.chat,
      tripId: 't1',
      onNew: (message, _) => seen.add(message.text),
    )..start();
    await live.chat.open('t1');
    live.chat.receive(
      't1',
      const RealtimeMessage(messageId: 'z1', from: 'rider', text: 'hi'),
    );
    expect(seen, isEmpty);
    expect(alerts.card, isNull);
    live.chat.close('t1');
    alerts.dispose();
  });

  test('message alert: sound per admin, vibration per Accessibility, read '
      'aloud per the driver\'s switch (else the admin default)', () async {
    final done = <String>[];
    ChatMessageAlert.debugAlert = done.add;
    final repo = SettingsRepository();
    await ChatMessageAlert.forMessage(
      'Hi',
      sound: true,
      readAloudDefault: false,
      repository: repo,
    );
    expect(done, ['sound', 'vibrate']);
    done.clear();
    await ChatMessageAlert.forMessage(
      'Hi',
      sound: false,
      readAloudDefault: true,
      repository: repo,
    );
    expect(done, ['vibrate', 'speak:Hi']);
    done.clear();
    await repo.save('sound', {'readRiderMessages': false});
    await ChatMessageAlert.forMessage(
      'Hi',
      sound: false,
      readAloudDefault: true,
      repository: repo,
    );
    expect(done, ['vibrate']);
  });

  test('the incoming-call push opens the trip', () {
    const open = PushOpen(
      notificationId: 'n1',
      deepLink: 'movera-driver://trips/t%201/call',
    );
    expect(open.callTripId, 't 1');
    expect(open.routeChangeTripId, isNull);
    expect(
      const PushOpen(
        notificationId: 'n2',
        deepLink: 'movera-driver://trips/t1',
      ).callTripId,
      isNull,
    );
  });

  test('options parse with the contract defaults', () {
    final parsed = TripChatOptions.fromJson(options());
    expect(parsed.chips.map((r) => r.id), [
      'on_my_way',
      'five_min',
      'traffic',
      'where_are_you',
      'ok_got_it',
    ]);
    expect(parsed.opensSheet, isTrue);
    expect(
      TripChatOptions.fromJson({...options(), 'quickRepliesOn': false}).chips,
      isEmpty,
    );
  });

  test('texts in sv / fr / en', () {
    final sv = lookupAppLocalizations(const Locale('sv'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(sv.chatTranslationComingSoon, 'Översättning kommer snart');
    expect(fr.chatTranslationComingSoon, 'Traduction bientôt disponible');
    expect(sv.chatTranslateTo(sv.chatOwnLanguageName), 'Översätt till svenska');
    expect(fr.chatHeaderLine, 'Un problème ? Utilisez Support ou SOS');
    expect(tr.chatSeeOriginal, 'See original');
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
