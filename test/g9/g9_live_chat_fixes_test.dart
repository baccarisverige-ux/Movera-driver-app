import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/common/chat/chat.dart';

/// G9 live re-check 2026-11-02 (audits/live-g9-2026-11-02.md), the fixes
/// that need no owner decision, through the real Chat screen and the real
/// HTTP client: support is "Movera", the call answer never covers the
/// write field, the decided call text, the chat starts at the top, the
/// hint is capitalised, and a language pick is saved to the account.
void main() {
  late LiveDriverServices live;
  late List<http.Request> requests;
  var profileVersion = 3;
  var profileLanguage = 'sv';

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> message(String id, String from, String text) => {
    'messageId': id,
    'tripId': 'live-trip',
    'from': from,
    'text': text,
    'at': '2026-11-02T06:0${id.substring(1)}:00Z',
  };

  Map<String, dynamic> driver() => {
    'driverId': 'drv_1',
    'version': profileVersion,
    'accountStatus': 'active',
    'onlineStatus': 'offline',
    'firstName': 'Test',
    'language': profileLanguage,
    'zoneIds': ['Z001'],
    'categoryIds': ['economy'],
    'documents': <Object>[],
  };

  late ApiClient api;

  setUp(() {
    requests = [];
    profileVersion = 3;
    profileLanguage = 'sv';
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/trips/live-trip/messages') {
        return json(200, {
          'items': [
            message('m1', 'rider', 'Rider hello'),
            message('m2', 'support', 'Support note'),
          ],
          'nextCursor': null,
        });
      }
      if (path == '/api/v1/trips/live-trip/call') {
        return json(503, {
          'code': 'unavailable',
          'message': 'No calls.',
          'reason': 'call_unavailable',
        });
      }
      if (path == '/api/v1/driver/profile') {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['expectedVersion'] != profileVersion) {
            return json(409, {'code': 'version_mismatch', 'message': 'Old.'});
          }
          profileLanguage = body['language'] as String;
          profileVersion++;
        }
        return json(200, driver());
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    api = ApiClient(
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
    DriverLanguage.saveToAccount = null;
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
            tripId: 'live-trip',
            liveChat: live.chat,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a support message is labelled "Movera"; the rider\'s is not', (
    tester,
  ) async {
    await show(tester);
    final label = find.byKey(const ValueKey<String>('chat-support-sender'));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, 'Movera');
    final labelRect = tester.getRect(label);
    final supportRect = tester.getRect(find.text('Support note'));
    expect(labelRect.bottom, lessThanOrEqualTo(supportRect.top));
  });

  test('a new support message is not counted as "from the rider"', () {
    final thread = live.chat.thread('live-trip');
    live.chat.receive(
      'live-trip',
      const RealtimeMessage(messageId: 'x1', from: 'rider', text: 'a'),
    );
    expect(thread.unread, 1);
    expect(thread.unreadFromSupport, 0);
    live.chat.receive(
      'live-trip',
      const RealtimeMessage(messageId: 'x2', from: 'support', text: 'b'),
    );
    expect(thread.unread, 2);
    expect(thread.unreadFromSupport, 1);
    expect(tr.chatNewMessagesAny(2), '2 new messages');
    expect(
      lookupAppLocalizations(const Locale('sv')).chatNewMessagesAny(2),
      '2 nya meddelanden',
    );
  });

  testWidgets('the conversation starts at the top', (tester) async {
    await show(tester);
    final first = tester.getRect(find.text('Rider hello'));
    expect(first.top, lessThan(812 / 3), reason: 'not anchored at the bottom');
    expect(
      tester.getRect(find.text('Rider hello')).top,
      lessThan(tester.getRect(find.text('Support note')).top),
    );
  });

  testWidgets('the call answer is the decided text and never covers the '
      'write field or the send button', (tester) async {
    await show(tester);
    await tester.tap(find.byTooltip(tr.callRider));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    final notice = find.byKey(const ValueKey<String>('chat-call-notice'));
    expect(notice, findsOneWidget);
    // v0.18.38 §62 (owner G15 "Just 'Call failed'").
    expect(find.text('Call failed'), findsOneWidget);
    final field = tester.getRect(find.byType(TextFormField));
    final send = tester.getRect(find.byTooltip(tr.chatSend));
    expect(tester.getRect(notice).bottom, lessThanOrEqualTo(field.top));
    expect(tester.getRect(notice).bottom, lessThanOrEqualTo(send.top));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
  });

  test('the decided call text and the capitalised hint in sv, fr and en', () {
    expect(
      lookupAppLocalizations(const Locale('sv')).chatSendMessageHint,
      'Skicka meddelande…',
    );
    expect(
      lookupAppLocalizations(const Locale('fr')).chatSendMessageHint,
      'Envoyer un message…',
    );
    expect(
      lookupAppLocalizations(const Locale('en')).chatSendMessageHint,
      'Send message…',
    );
  });

  test(
    'a language pick is saved to the account (PATCH /driver/profile)',
    () async {
      final session = DriverAccountSession(
        repository: DriverAccountRepository(api),
      );
      await session.refresh();
      DriverLanguage.saveToAccount = session.saveLanguage;
      // Another phone changed the profile: the save reads it again once.
      profileVersion = 4;
      SharedPreferences.setMockInitialValues({});
      await DriverLanguage.choose('fr', SettingsRepository());
      await pumpEventQueue();
      final patches = requests.where((r) => r.method == 'PATCH').toList();
      expect(patches, isNotEmpty);
      expect(jsonDecode(patches.last.body), {
        'expectedVersion': 4,
        'language': 'fr',
      });
      expect(profileLanguage, 'fr');
      expect(session.account?.language, 'fr');
      DriverLanguage.resetForTest();
    },
  );
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
