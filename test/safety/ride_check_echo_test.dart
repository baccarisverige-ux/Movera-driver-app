// Contract `onTrip.rideCheck.ask`: the server's "Is everything OK?" comes
// as a `trip_projection` event WITHOUT a version change and the app must
// open the card. After this phone's own Start the trip stream dropped it
// as the echo of that Start (same status `in_trip`, same version), so the
// driver was never asked and the server opened a false "no answer" case
// (Rules audits/impact/driver-ftl-findings-2026-11-19.md, finding A).
//
// The app's real stream reader and real trip commands, a fake server.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

void main() {
  final origin = Uri.parse('https://api.test.movera.se');
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  // The phone's clock in these tests.
  final now = DateTime.utc(2026, 11, 19, 16, 10, 30);
  const askedAt = '2026-11-19T16:10:00Z';
  const answerBy = '2026-11-19T16:12:00Z';

  late List<FutureOr<http.Response> Function(http.Request)> answers;
  late LiveTripCommands trips;
  late ApiDriverRealtime realtime;
  late List<StreamController<List<int>>> streams;
  late List<DriverRealtimeEvent> events;
  late StreamSubscription<DriverRealtimeEvent> sub;

  setUp(() {
    answers = [];
    streams = [];
    events = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    trips = LiveTripCommands(
      api: ApiClient(
        client: MockClient((request) async => answers.removeAt(0)(request)),
        baseUri: origin,
        tokens: tokens,
      ),
    );
    realtime = ApiDriverRealtime(
      client: MockClient.streaming((request, _) async {
        final stream = StreamController<List<int>>();
        streams.add(stream);
        return http.StreamedResponse(stream.stream, 200);
      }),
      apiBase: origin.replace(path: '/api/v1'),
      accessToken: tokens.readAccess,
      trips: trips,
      reconnectDelay: (_) => Duration.zero,
      now: () => now,
    );
  });
  tearDown(() async {
    await sub.cancel();
    realtime.dispose();
  });

  Map<String, dynamic> check(
    String checkId, {
    String answerBy = answerBy,
    Map<String, dynamic> answers = const <String, dynamic>{},
  }) => {
    'checkId': checkId,
    'trigger': 'long_stop',
    'askedAt': askedAt,
    'answerBy': answerBy,
    'answers': answers,
  };

  // One envelope as the server builds it (rideCheckServer.ts
  // sendRideCheckEvent): the trip as it is, with its UNCHANGED version.
  Future<void> send(
    int sequence, {
    required String status,
    required int version,
    Map<String, dynamic>? rideCheck,
    String kind = 'trip_projection',
    String tripId = 't1',
  }) async {
    streams.last.add(
      utf8.encode(
        'id: $sequence\ndata: ${jsonEncode({
          'eventId': 'e$sequence',
          'tripId': tripId,
          'sequence': sequence,
          'version': version,
          'kind': kind,
          'occurredAt': askedAt,
          'serverTime': askedAt,
          'projection': {'tripId': tripId, 'status': status, 'version': version, 'rideCheck': ?rideCheck},
        })}\n\n',
      ),
    );
    await pumpEventQueue();
  }

  Future<void> listen([String tripId = 't1']) async {
    sub = realtime.subscribe(tripId).listen(events.add);
    await pumpEventQueue();
  }

  /// This phone's own Start: board (rider_onboard v8), start (in_trip v9).
  Future<void> ownStart() async {
    trips.observe({'tripId': 't1', 'status': 'arrived', 'version': 7});
    answers
      ..add(
        (_) => json(200, {
          'tripId': 't1',
          'status': 'rider_onboard',
          'version': 8,
        }),
      )
      ..add(
        (_) => json(200, {'tripId': 't1', 'status': 'in_trip', 'version': 9}),
      );
    expect((await trips.start('t1')).ok, isTrue);
  }

  Iterable<DriverRealtimeEvent> withCheck(String checkId) =>
      events.where((e) => e.live?.rideCheck?.checkId == checkId);

  test('after this phone\'s own Start (in_trip v9) the server ride check '
      '(in_trip, same v9) reaches the trip screen', () async {
    await ownStart();
    await listen();
    // The echo of Start itself: rightly dropped.
    await send(20, status: 'in_trip', version: 9);
    expect(events, isEmpty);
    // 2 minutes standing: the server asks.
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(
      withCheck('srv_a'),
      hasLength(1),
      reason: 'the ride check event was dropped as an "own echo"',
    );
    expect(events.single.status, TripStatus.inTrip);
    expect(realtime.lastSequence, 27);
  });

  test('the same checkId again (the rider answered, an own-command echo '
      'that still carries it) stays suppressed', () async {
    await ownStart();
    await listen();
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    // The rider answered: the same check, no version change.
    await send(
      28,
      status: 'in_trip',
      version: 9,
      rideCheck: check('srv_a', answers: {'rider': 'ok'}),
    );
    // Any later echo at the own version carries the trip's check too.
    await send(29, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(events, hasLength(1));
    expect(withCheck('srv_a'), hasLength(1));
  });

  test('a second check (a new checkId) on the same trip passes too, '
      'once', () async {
    await ownStart();
    await listen();
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    await send(40, status: 'in_trip', version: 9, rideCheck: check('srv_b'));
    await send(41, status: 'in_trip', version: 9, rideCheck: check('srv_b'));
    expect(withCheck('srv_a'), hasLength(1));
    expect(withCheck('srv_b'), hasLength(1));
    expect(events, hasLength(2));
  });

  test('an ordinary echo (no ride check) is still suppressed', () async {
    await ownStart();
    await listen();
    await send(19, status: 'rider_onboard', version: 8);
    await send(20, status: 'in_trip', version: 9);
    await send(21, status: 'in_trip', version: 9);
    expect(events, isEmpty);
    expect(realtime.lastSequence, 21);
  });

  test('a check that passed before this phone\'s own Start (no own command '
      'yet) is known: the echo of Start that carries it stays '
      'suppressed', () async {
    // The app was reopened with the rider on board; the server asks.
    trips.observe({'tripId': 't1', 'status': 'rider_onboard', 'version': 8});
    await listen();
    await send(
      27,
      status: 'rider_onboard',
      version: 8,
      rideCheck: check('srv_a'),
    );
    expect(withCheck('srv_a'), hasLength(1));
    // Start: the answer and its echo carry the trip's check.
    answers.add(
      (_) => json(200, {
        'tripId': 't1',
        'status': 'in_trip',
        'version': 9,
        'rideCheck': check('srv_a'),
      }),
    );
    expect((await trips.start('t1')).ok, isTrue);
    await send(30, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(events, hasLength(1));
  });

  test('an echo whose check this driver already answered, or whose time is '
      'over, is still suppressed (the card would not open)', () async {
    await ownStart();
    await listen();
    await send(
      27,
      status: 'in_trip',
      version: 9,
      rideCheck: check('srv_a', answers: {'driver': 'ok'}),
    );
    await send(
      28,
      status: 'in_trip',
      version: 9,
      rideCheck: check('srv_old', answerBy: '2026-11-19T16:10:29Z'),
    );
    expect(events, isEmpty);
  });

  test('a broken ride check on an echo is still suppressed', () async {
    await ownStart();
    await listen();
    await send(27, status: 'in_trip', version: 9, rideCheck: {'checkId': ''});
    await send(
      28,
      status: 'in_trip',
      version: 9,
      rideCheck: {'checkId': 'srv_x', 'trigger': 'not_a_trigger'},
    );
    expect(events, isEmpty);
  });

  test('the echo of this phone\'s own Finish stays suppressed, also when '
      'it carries a check the stream never passed', () async {
    await ownStart();
    answers.add(
      (_) => json(200, {'tripId': 't1', 'status': 'completed', 'version': 10}),
    );
    expect((await trips.complete('t1')).ok, isTrue);
    await listen();
    await send(31, status: 'completed', version: 10, rideCheck: check('srv_a'));
    expect(events, isEmpty);
  });

  test('ride check while not in trip: before the rider is on board the '
      'echo of own Arrive that carries a new check is passed on (the trip '
      'screen decides), the plain echo is not', () async {
    trips.observe({'tripId': 't1', 'status': 'driver_to_pickup', 'version': 6});
    answers.add(
      (_) => json(200, {'tripId': 't1', 'status': 'arrived', 'version': 7}),
    );
    expect((await trips.arrive('t1')).ok, isTrue);
    await listen();
    await send(15, status: 'arrived', version: 7);
    expect(events, isEmpty);
    await send(16, status: 'arrived', version: 7, rideCheck: check('srv_a'));
    await send(17, status: 'arrived', version: 7, rideCheck: check('srv_a'));
    expect(withCheck('srv_a'), hasLength(1));
    expect(events, hasLength(1));
  });

  test('no own command on this phone (app restarted on the trip): the '
      'same-version ride check passes, as before', () async {
    trips.observe({'tripId': 't1', 'status': 'in_trip', 'version': 9});
    await listen();
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(withCheck('srv_a'), hasLength(1));
  });

  test('a check that came while no screen was listening is not counted as '
      'handed over: the next message that carries it passes', () async {
    await ownStart();
    await listen();
    await sub.cancel();
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(events, isEmpty);
    sub = realtime.subscribe('t1').listen(events.add);
    await pumpEventQueue();
    await send(28, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    await send(29, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    expect(withCheck('srv_a'), hasLength(1));
  });

  test('another trip starts clean: its own check is not held back by the '
      'trip before', () async {
    await ownStart();
    await listen();
    await send(27, status: 'in_trip', version: 9, rideCheck: check('srv_a'));
    await sub.cancel();
    events.clear();
    trips.observe({'tripId': 't2', 'status': 'arrived', 'version': 3});
    answers
      ..add(
        (_) => json(200, {
          'tripId': 't2',
          'status': 'rider_onboard',
          'version': 4,
        }),
      )
      ..add(
        (_) => json(200, {'tripId': 't2', 'status': 'in_trip', 'version': 5}),
      );
    expect((await trips.start('t2')).ok, isTrue);
    await listen('t2');
    await send(
      9,
      status: 'in_trip',
      version: 5,
      rideCheck: check('srv_a'),
      tripId: 't2',
    );
    expect(withCheck('srv_a'), hasLength(1));
  });

  test('a driver_cancelled event that carries an open check is never a '
      'question: the echo of this phone\'s own cancel stays '
      'suppressed', () async {
    await ownStart();
    answers.add(
      (_) => json(200, {
        'tripId': 't1',
        'status': 'driver_cancelled',
        'version': 10,
      }),
    );
    expect((await trips.cancel('t1', reasonCode: 'other')).ok, isTrue);
    await listen();
    await send(
      31,
      status: 'driver_cancelled',
      version: 10,
      kind: 'driver_cancelled',
      rideCheck: check('srv_a'),
    );
    expect(events, isEmpty);
  });

  for (final status in ['searching', 'requested']) {
    test('the echo of this phone\'s own cancel that put the trip back in '
        'the queue ($status) stays suppressed, also when it carries an '
        'open check', () async {
      await ownStart();
      answers.add(
        (_) => json(200, {'tripId': 't1', 'status': status, 'version': 10}),
      );
      expect((await trips.cancel('t1', reasonCode: 'other')).ok, isTrue);
      await listen();
      await send(31, status: status, version: 10, rideCheck: check('srv_q'));
      expect(events, isEmpty);
    });
  }
}
