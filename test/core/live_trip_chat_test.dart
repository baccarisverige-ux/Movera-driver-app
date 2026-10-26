import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

/// The trip's chat on the live wire (contract v0.5.4): a message goes out
/// as `POST /trips/{tripId}/messages`, the history is read once with
/// `GET`, and the trip's event stream brings every message as
/// `kind: message`.
void main() {
  final origin = Uri.parse('https://api.test.movera.se');

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> message(
    String id,
    String from,
    String text, {
    String at = '2026-10-25T10:00:00Z',
  }) => {'messageId': id, 'tripId': 't1', 'from': from, 'text': text, 'at': at};

  RealtimeMessage onStream(
    String id,
    String from,
    String text, {
    int minute = 0,
  }) => RealtimeMessage(
    messageId: id,
    from: from,
    text: text,
    at: DateTime.utc(2026, 10, 25, 10, minute),
  );

  late List<http.Request> requests;
  late List<FutureOr<http.Response> Function(http.Request)> answers;
  late MemoryTokenStore tokens;
  late LiveTripChat chat;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      if (answers.isEmpty)
        return json(500, {'code': 'internal', 'message': 'No.'});
      return answers.removeAt(0)(request);
    }),
    baseUri: origin,
    tokens: tokens,
  );

  setUp(() {
    requests = [];
    answers = [];
    tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    chat = LiveTripChat(api: api());
  });

  group('sending', () {
    test('a message goes out with the contract headers and body; the '
        'server\'s copy replaces this phone\'s', () async {
      answers.add(
        (_) => json(
          201,
          message(
            'm1',
            'driver',
            'At the north entrance',
            at: '2026-10-25T10:00:05Z',
          ),
        ),
      );
      final sending = chat.send('t1', '  At the north entrance ');
      // Shown at once, on its way.
      final copy = chat.thread('t1').messages.single;
      expect(copy.own, isTrue);
      expect(copy.state, TripChatSendState.sending);
      expect(copy.text, 'At the north entrance');
      expect((await sending).ok, isTrue);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/trips/t1/messages');
      expect(request.headers['Authorization'], 'Bearer a1');
      expect(request.headers['X-Api-Version'], ApiClient.apiVersion);
      expect(
        request.headers['X-Request-Id'],
        matches(RegExp(r'^[0-9a-f]{32}$')),
      );
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(
        request.headers['Idempotency-Key'],
        matches(RegExp(r'^[0-9a-f]{32}$')),
      );
      expect(request.headers['Idempotency-Key'], copy.messageId);
      expect(jsonDecode(request.body), {'text': 'At the north entrance'});

      final sent = chat.thread('t1').messages.single;
      expect(sent.messageId, 'm1');
      expect(sent.state, TripChatSendState.sent);
      expect(sent.at, DateTime.utc(2026, 10, 25, 10, 0, 5));
      expect(chat.unreadOf('t1'), 0);
    });

    test('no answer: the message stays, marked not sent; the retry is the '
        'same message (same key)', () async {
      answers
        ..add((_) => throw http.ClientException('lost'))
        ..add((_) => json(201, message('m2', 'driver', 'Outside')));
      final first = await chat.send('t1', 'Outside');
      expect(first.ok, isFalse);
      expect(first.message, tr.authErrOffline);
      final copy = chat.thread('t1').messages.single;
      expect(copy.state, TripChatSendState.failed);
      expect(copy.text, 'Outside');

      expect((await chat.retry('t1', copy)).ok, isTrue);
      expect(requests, hasLength(2));
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[0].headers['Idempotency-Key'],
      );
      expect(requests[1].body, requests[0].body);
      expect(chat.thread('t1').messages.single.messageId, 'm2');
      expect(chat.thread('t1').messages.single.state, TripChatSendState.sent);
    });

    test('a refusal is said plainly and the text is kept', () async {
      answers.add(
        (_) => json(409, {'code': 'conflict', 'message': 'Trip is over.'}),
      );
      final outcome = await chat.send('t1', 'Hello?');
      expect(outcome.ok, isFalse);
      expect(outcome.message, tr.chatSendFailed);
      final copy = chat.thread('t1').messages.single;
      expect(copy.state, TripChatSendState.failed);
      expect(copy.text, 'Hello?');
    });

    test('the stream\'s echo of this phone\'s own message, before the '
        'answer, does not show it twice', () async {
      final answer = Completer<http.Response>();
      answers.add((_) => answer.future);
      final sending = chat.send('t1', 'Coming');
      chat.receive('t1', onStream('m3', 'driver', 'Coming', minute: 1));
      expect(chat.thread('t1').messages.map((m) => m.messageId), ['m3']);
      expect(chat.thread('t1').messages.single.state, TripChatSendState.sent);
      expect(chat.unreadOf('t1'), 0);
      answer.complete(json(201, message('m3', 'driver', 'Coming')));
      expect((await sending).ok, isTrue);
      expect(chat.thread('t1').messages.map((m) => m.messageId), ['m3']);
    });
  });

  group('history', () {
    test('opening Chat reads the history once and counts what is there as '
        'read; closed, new messages are unread again', () async {
      chat.receive('t1', onStream('m1', 'rider', 'Where are you?'));
      expect(chat.unreadOf('t1'), 1);
      answers.add(
        (_) => json(200, {
          'items': [
            message('m1', 'rider', 'Where are you?'),
            message('m0', 'driver', 'On my way', at: '2026-10-25T09:59:00Z'),
          ],
          'nextCursor': null,
        }),
      );
      expect(await chat.open('t1'), isTrue);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/trips/t1/messages');
      expect(requests.single.url.queryParameters['limit'], '200');
      expect(requests.single.headers['Authorization'], 'Bearer a1');
      // Oldest first; the one the stream brought is not shown twice.
      expect(chat.thread('t1').messages.map((m) => m.messageId), ['m0', 'm1']);
      expect(chat.unreadOf('t1'), 0);

      // Open: read as it arrives.
      chat.receive('t1', onStream('m2', 'rider', 'Ok', minute: 2));
      expect(chat.unreadOf('t1'), 0);
      chat.close('t1');
      chat.receive('t1', onStream('m3', 'rider', 'Hurry', minute: 3));
      expect(chat.unreadOf('t1'), 1);

      // Opened again: no second read.
      expect(await chat.open('t1'), isTrue);
      expect(requests, hasLength(1));
      expect(chat.unreadOf('t1'), 0);
      expect(chat.thread('t1').messages.map((m) => m.messageId), [
        'm0',
        'm1',
        'm2',
        'm3',
      ]);
    });

    test(
      'a history that could not be read is said; reading again works',
      () async {
        answers.add(
          (_) => json(503, {'code': 'unavailable', 'message': 'Later.'}),
        );
        expect(await chat.open('t1'), isFalse);
        expect(chat.thread('t1').loaded, isFalse);
        answers.add(
          (_) => json(200, {
            'items': [message('m0', 'rider', 'Hi')],
            'nextCursor': null,
          }),
        );
        expect(await chat.load('t1'), isTrue);
        expect(chat.thread('t1').messages.single.text, 'Hi');
        expect(chat.thread('t1').loaded, isTrue);
      },
    );

    test('sign-out forgets every thread', () async {
      chat.receive('t1', onStream('m1', 'rider', 'Hi'));
      chat.reset();
      expect(chat.unreadOf('t1'), 0);
      expect(chat.thread('t1').messages, isEmpty);
    });
  });

  group('trip events', () {
    late List<http.BaseRequest> opened;
    late List<StreamController<List<int>>> streams;
    late LiveTripCommands trips;
    late ApiDriverRealtime realtime;

    setUp(() {
      opened = [];
      streams = [];
      trips = LiveTripCommands(api: api());
      // The accept answer: nothing to read before the stream.
      trips.observe({'tripId': 't1', 'status': 'in_trip', 'version': 8});
      realtime = ApiDriverRealtime(
        client: MockClient.streaming((request, _) async {
          opened.add(request);
          final stream = StreamController<List<int>>();
          streams.add(stream);
          return http.StreamedResponse(stream.stream, 200);
        }),
        apiBase: origin.replace(path: '/api/v1'),
        accessToken: tokens.readAccess,
        trips: trips,
        chat: chat,
        reconnectDelay: (_) => Duration.zero,
      );
    });

    tearDown(() => realtime.dispose());

    String sse(
      int sequence,
      String kind, {
      int version = 8,
      Map<String, dynamic>? message,
    }) =>
        'id: $sequence\ndata: ${jsonEncode({'eventId': 'e$sequence', 'tripId': 't1', 'sequence': sequence, 'version': version, 'kind': kind, 'occurredAt': '2026-10-25T10:00:00Z', 'serverTime': '2026-10-25T10:00:00Z', if (message != null) 'message': message})}\n\n';

    test('a message event reaches the chat and its unread count, whatever '
        'its version; the screen still hears it', () async {
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      final s = streams.single;
      // A message never changes the trip: a replay after a drop carries
      // the version of its time, older than the one known here.
      s.add(
        utf8.encode(
          sse(
            9,
            'message',
            version: 7,
            message: message('m1', 'rider', 'Where are you?'),
          ),
        ),
      );
      s.add(
        utf8.encode(
          sse(
            10,
            'message',
            message: message(
              'm2',
              'driver',
              'Coming',
              at: '2026-10-25T10:00:30Z',
            ),
          ),
        ),
      );
      await pumpEventQueue();
      expect(chat.thread('t1').messages.map((m) => m.text), [
        'Where are you?',
        'Coming',
      ]);
      // Only the rider's counts.
      expect(chat.unreadOf('t1'), 1);
      expect(events.map((e) => e.kind), [
        DriverRealtimeKind.message,
        DriverRealtimeKind.message,
      ]);
      expect(events.first.chat?.text, 'Where are you?');
      expect(trips.versionOf('t1'), 8);
      await sub.cancel();
    });

    test('the stream back after a drop: the history is read again', () async {
      answers.add((_) => json(200, {'items': <Object>[], 'nextCursor': null}));
      expect(await chat.open('t1'), isTrue);
      chat.close('t1');
      final sub = realtime.subscribe('t1').listen((_) {});
      await pumpEventQueue();
      expect(requests, hasLength(1));
      streams.single.add(utf8.encode(sse(9, 'location')));
      await pumpEventQueue();

      answers.add(
        (_) => json(200, {
          'items': [message('m5', 'rider', 'Missed while down')],
          'nextCursor': null,
        }),
      );
      await streams.single.close();
      await pumpEventQueue();
      expect(opened, hasLength(2));
      expect(requests.map((r) => r.url.path), [
        '/api/v1/trips/t1/messages',
        '/api/v1/trips/t1/messages',
      ]);
      expect(chat.thread('t1').messages.single.text, 'Missed while down');
      expect(chat.unreadOf('t1'), 1);
      await sub.cancel();
    });
  });
}
