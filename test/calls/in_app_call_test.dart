import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/calls/call_engine.dart';
import 'package:movera/core/calls/trip_call_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_trip_calls.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:movera/presentation/common/chat/trip_call.dart';

/// v0.18.38 §62 (fix job 8, owner G15 2026-11-05: "In-app calls only",
/// "Both rider and driver", "Just 'Call failed'"): the driver calls the
/// rider inside the app (WebRTC; the server relays the signalling) and
/// answers the rider's call. Fail-before: main opens the dialer with a
/// masked number or says "Calls coming soon – use the chat".
class FakeEngine implements CallEngine {
  final List<String> did = [];
  List<Map<String, dynamic>>? ice;
  @override
  void Function(Map<String, dynamic> candidate)? onCandidate;
  @override
  void Function(CallMediaState state)? onMedia;
  @override
  Future<void> open(List<Map<String, dynamic>> iceServers) async {
    ice = iceServers;
    did.add('open');
  }

  @override
  Future<String> createOffer() async {
    did.add('offer');
    return 'v=0 driver-offer';
  }

  @override
  Future<String> acceptOffer(String sdp) async {
    did.add('acceptOffer:$sdp');
    return 'v=0 driver-answer';
  }

  @override
  Future<void> acceptAnswer(String sdp) async => did.add('acceptAnswer:$sdp');
  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async =>
      did.add('candidate:${candidate['candidate']}');
  @override
  Future<void> setMuted(bool muted) async => did.add('muted:$muted');
  @override
  Future<void> setSpeaker(bool on) async => did.add('speaker:$on');
  @override
  Future<void> close() async => did.add('close');
}

class FakeApi implements CallApi {
  final List<String> sent = [];
  final List<Map<String, dynamic>> signals = [];
  Object? startError;
  @override
  Future<Map<String, dynamic>> start(String tripId) async {
    sent.add('start:$tripId');
    if (startError != null) throw startError!;
    return {
      'tripId': tripId,
      'mode': 'in_app',
      'callId': 'cll_1',
      'ice': {
        'servers': [
          {
            'urls': ['stun:stun.example.test:3478'],
          },
        ],
        'ttlSeconds': 900,
      },
      'ringSeconds': 30,
      'maxCallMin': 15,
      'expiresAt': '2026-11-05T12:15:00Z',
    };
  }

  @override
  Future<void> answer(String callId) async => sent.add('answer:$callId');
  @override
  Future<void> end(String callId, String reason) async =>
      sent.add('end:$callId:$reason');
  @override
  Future<void> signal(String callId, Map<String, dynamic> body) async =>
      signals.add(body);
}

Map<String, dynamic> callOf(String from, String state) => {
  'callId': 'cll_1',
  'tripId': 't1',
  'from': from,
  'to': from == 'driver' ? 'rider' : 'driver',
  'state': state,
  'startedAt': '2026-11-05T12:00:00Z',
  'answeredAt': null,
  'endedAt': null,
  'endedReason': null,
  'seconds': 0,
};

void main() {
  test('the call event kinds are known and pass after the trip ended', () {
    for (final wire in [
      'call_ringing',
      'call_answered',
      'call_signal',
      'call_ended',
      'call_missed',
    ]) {
      final kind = DriverRealtimeKind.tryParse(wire);
      expect(kind, isNotNull, reason: wire);
      expect(kind!.passesAfterTerminal, isTrue, reason: wire);
    }
  });

  test('outgoing: start, the rider answers, offer → answer → connected, '
      'hang up ends it', () async {
    final api = FakeApi();
    final engine = FakeEngine();
    final session = TripCallSession.outgoing(
      api: api,
      engine: engine,
      tripId: 't1',
      side: 'driver',
    );
    await session.start();
    expect(api.sent, ['start:t1']);
    expect(session.state, TripCallState.calling);
    expect(engine.ice!.single['urls'], ['stun:stun.example.test:3478']);
    await session.receive('call_answered', callOf('driver', 'answered'));
    expect(engine.did, contains('offer'));
    expect(api.signals.first, {'type': 'offer', 'sdp': 'v=0 driver-offer'});
    await session.receive('call_signal', {
      'callId': 'cll_1',
      'from': 'rider',
      'type': 'answer',
      'sdp': 'v=0 rider-answer',
    });
    expect(engine.did, contains('acceptAnswer:v=0 rider-answer'));
    // Own echoes are ignored.
    await session.receive('call_signal', {
      'callId': 'cll_1',
      'from': 'driver',
      'type': 'offer',
      'sdp': 'x',
    });
    engine.onCandidate!({
      'candidate': 'candidate:1',
      'sdpMid': '0',
      'sdpMLineIndex': 0,
    });
    await Future<void>.delayed(Duration.zero);
    expect(api.signals.last['type'], 'ice');
    engine.onMedia!(CallMediaState.connected);
    expect(session.state, TripCallState.connected);
    await session.toggleMute();
    await session.toggleSpeaker();
    expect(engine.did, containsAll(['muted:true', 'speaker:true']));
    await session.hangUp();
    expect(api.sent.last, 'end:cll_1:hangup');
    expect(session.state, TripCallState.ended);
    expect(engine.did.last, 'close');
  });

  test('incoming: the rider calls, the driver answers, the offer gets an '
      'answer', () async {
    final api = FakeApi();
    final engine = FakeEngine();
    final session = TripCallSession.incoming(
      api: api,
      engine: engine,
      call: IncomingCall.fromJson(callOf('rider', 'ringing')),
      side: 'driver',
      ice: const [],
    );
    expect(session.state, TripCallState.ringing);
    await session.answer();
    expect(api.sent, ['answer:cll_1']);
    await session.receive('call_signal', {
      'callId': 'cll_1',
      'from': 'rider',
      'type': 'offer',
      'sdp': 'v=0 rider-offer',
    });
    expect(engine.did, contains('acceptOffer:v=0 rider-offer'));
    expect(api.signals.single, {'type': 'answer', 'sdp': 'v=0 driver-answer'});
  });

  test('decline and missed end the call; a failure says only "Call failed" '
      '(owner G15)', () async {
    final api = FakeApi();
    final declined = TripCallSession.incoming(
      api: api,
      engine: FakeEngine(),
      call: IncomingCall.fromJson(callOf('rider', 'ringing')),
      side: 'driver',
      ice: const [],
    );
    await declined.decline();
    expect(api.sent.last, 'end:cll_1:declined');
    expect(declined.state, TripCallState.ended);

    final missed = TripCallSession.outgoing(
      api: FakeApi(),
      engine: FakeEngine(),
      tripId: 't1',
      side: 'driver',
    );
    await missed.start();
    await missed.receive('call_missed', callOf('driver', 'missed'));
    expect(missed.state, TripCallState.ended);

    final refused = FakeApi()..startError = StateError('no network');
    final failing = TripCallSession.outgoing(
      api: refused,
      engine: FakeEngine(),
      tripId: 't1',
      side: 'driver',
    );
    await failing.start();
    expect(failing.state, TripCallState.failed);
    expect(tr.callFailed, 'Call failed');

    final dropApi = FakeApi();
    final engine = FakeEngine();
    final dropped = TripCallSession.outgoing(
      api: dropApi,
      engine: engine,
      tripId: 't1',
      side: 'driver',
    );
    await dropped.start();
    engine.onMedia!(CallMediaState.failed);
    await Future<void>.delayed(Duration.zero);
    expect(dropped.state, TripCallState.failed);
    expect(dropApi.sent.last, 'end:cll_1:failed');
  });

  test('the call texts in sv, fr and en', () {
    final sv = lookupAppLocalizations(const Locale('sv'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(sv.callFailed, 'Samtalet misslyckades');
    expect(fr.callFailed, "L'appel a échoué");
    expect(sv.callIncomingFromRider, isNotEmpty);
    expect(fr.callCalling, 'Appel en cours…');
  });

  group('callRider', () {
    late List<http.Response> answers;
    LiveTripChat chat() => LiveTripChat(
      api: ApiClient(
        client: MockClient((_) async => answers.removeAt(0)),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      ),
    );
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

    Future<BuildContext> host(WidgetTester tester) async {
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
      return ctx;
    }

    testWidgets('an in-app answer opens the call screen (not "coming soon", '
        'nothing dialled)', (tester) async {
      answers = [
        json({
          'tripId': 't1',
          'mode': 'in_app',
          'callId': 'cll_1',
          'ice': {'servers': [], 'ttlSeconds': 900},
          'ringSeconds': 30,
          'maxCallMin': 15,
          'expiresAt': '2026-11-05T12:15:00Z',
        }),
      ];
      final ctx = await host(tester);
      final dialled = <Uri>[];
      unawaited(
        callRider(
          ctx,
          tripId: 't1',
          chat: chat(),
          engine: FakeEngine.new,
          dial: (uri) async {
            dialled.add(uri);
            return true;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TripCallScreen), findsOneWidget);
      expect(find.text(tr.callCalling), findsOneWidget);
      expect(find.text(tr.callUnavailableUseChat), findsNothing);
      expect(dialled, isEmpty);
    });

    testWidgets('a refused call says only "Call failed"', (tester) async {
      answers = [
        json({
          'code': 'invalid_transition',
          'message': 'No.',
          'reason': 'call_window_closed',
        }, 409),
      ];
      final ctx = await host(tester);
      await callRider(ctx, tripId: 't1', chat: chat(), engine: FakeEngine.new);
      await tester.pump();
      expect(find.text(tr.callFailed), findsOneWidget);
      expect(find.byType(TripCallScreen), findsNothing);
    });
  });
}
