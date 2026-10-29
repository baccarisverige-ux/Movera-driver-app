import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/session/driver_session_controller.dart';

/// Live builds (MOVERA_AUTH_REQUIRED): availability, location batches, the
/// trip's commands and its live events go to movera-server, through fake
/// HTTP clients here.
void main() {
  final origin = Uri.parse('https://api.test.movera.se');

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> error(
    String code, {
    String? reason,
    Object? projection,
  }) => {
    'code': code,
    'message': 'The server says no.',
    'requestId': 'r',
    'retryable': false,
    if (reason != null) 'reason': reason,
    if (projection != null) 'projection': projection,
  };

  late List<http.Request> requests;
  late List<FutureOr<http.Response> Function(http.Request)> answers;
  late MemoryTokenStore tokens;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      if (answers.isEmpty) return json(500, error('internal'));
      return answers.removeAt(0)(request);
    }),
    baseUri: origin,
    tokens: tokens,
  );

  Map<String, dynamic> body(http.Request request) =>
      Map<String, dynamic>.from(jsonDecode(request.body) as Map);

  setUp(() {
    requests = [];
    answers = [];
    tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
  });

  group('location batches', () {
    test(
      'a fix goes out as the contract GeoFix and is kept for arrive',
      () async {
        final reporter = LiveLocationReporter(
          api: api(),
          location: _FixedLocation(),
        );
        answers.add(
          (_) =>
              json(200, {'accepted': 1, 'serverTime': '2026-10-25T10:00:00Z'}),
        );
        expect(await reporter.sendNow(), isTrue);
        expect(requests.single.url.path, '/api/v1/driver/location');
        expect(requests.single.headers['Idempotency-Key'], isNotEmpty);
        final fix = (body(requests.single)['fixes'] as List).single as Map;
        expect(fix['lat'], 59.3326);
        expect(fix['lng'], 18.0649);
        expect(fix['accuracy'], 8.0);
        expect(fix['heading'], 90.0);
        expect(fix['speedMps'], 5.0);
        expect(fix['moving'], isTrue);
        expect(fix['measuredAt'], '2026-10-25T10:00:00.000Z');
        expect(reporter.lastFix, fix);
      },
    );

    test('no fix (no permission, no signal): nothing is sent', () async {
      final reporter = LiveLocationReporter(
        api: api(),
        location: _FixedLocation(fails: true),
      );
      expect(await reporter.sendNow(), isFalse);
      expect(requests, isEmpty);
    });

    test('start sends at once and then every interval; stop ends it', () async {
      answers.addAll(
        List.generate(
          10,
          (_) =>
              (_) => json(200, {'accepted': 1}),
        ),
      );
      final reporter = LiveLocationReporter(
        api: api(),
        location: _FixedLocation(),
        every: const Duration(milliseconds: 40),
      );
      reporter.start();
      await pumpEventQueue();
      expect(requests, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requests.length, greaterThanOrEqualTo(2));
      reporter.stop();
      final sent = requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(requests, hasLength(sent));
    });
  });

  group('availability', () {
    late _FakeDispatch dispatch;
    late LivePresence presence;
    late LiveLocationReporter reporter;

    setUp(() {
      final client = api();
      dispatch = _FakeDispatch();
      reporter = LiveLocationReporter(
        api: client,
        location: _FixedLocation(),
        every: const Duration(hours: 1),
      );
      presence = LivePresence(
        api: client,
        dispatch: dispatch,
        reporter: reporter,
      );
    });

    tearDown(() => reporter.stop());

    test('going online sends the profile version and a fix; the feed and '
        'location start', () async {
      answers
        ..add(
          (_) => json(200, {
            'driverId': 'd1',
            'onlineStatus': 'offline',
            'version': 4,
          }),
        )
        ..add(
          (_) => json(200, {
            'driverId': 'd1',
            'onlineStatus': 'online',
            'version': 5,
          }),
        )
        ..add((_) => json(200, {'accepted': 1}));
      expect(await presence.goOnline(), isNull);
      expect(requests[0].method, 'GET');
      expect(requests[0].url.path, '/api/v1/driver/profile');
      expect(requests[1].url.path, '/api/v1/driver/availability');
      final sent = body(requests[1]);
      expect(sent['expectedVersion'], 4);
      expect(sent['onlineStatus'], 'online');
      expect((sent['location'] as Map)['lat'], 59.3326);
      expect(presence.serverOnline, isTrue);
      expect(dispatch.connects, 1);
      expect(dispatch.refreshes, 1);
      expect(reporter.running, isTrue);
    });

    test('a stale version is sent again with the server\'s', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 4}))
        ..add(
          (_) => json(
            409,
            error(
              'version_mismatch',
              projection: {'onlineStatus': 'offline', 'version': 6},
            ),
          ),
        )
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 7}))
        ..add((_) => json(200, {'accepted': 1}));
      expect(await presence.goOnline(), isNull);
      expect(body(requests[2])['expectedVersion'], 6);
      // A new body is a new command: a new key.
      expect(
        requests[2].headers['Idempotency-Key'],
        isNot(requests[1].headers['Idempotency-Key']),
      );
    });

    test('a refusal is said plainly and nothing starts', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 4}))
        ..add(
          (_) => json(
            409,
            error(
              'invalid_transition',
              reason: 'no_vehicle',
              projection: {'onlineStatus': 'offline', 'version': 4},
            ),
          ),
        );
      expect(await presence.goOnline(), tr.liveOnlineNoVehicle);
      expect(presence.serverOnline, isFalse);
      expect(dispatch.connects, 0);
      expect(reporter.running, isFalse);
    });

    test('no connection: the driver reads so', () async {
      final presence = LivePresence(
        api: ApiClient(
          client: MockClient((_) async => throw http.ClientException('down')),
          baseUri: origin,
          tokens: tokens,
        ),
        dispatch: dispatch,
        reporter: reporter,
      );
      expect(await presence.goOnline(), tr.authErrOffline);
    });

    test('going offline closes the feed and tells the server', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 1}))
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 2}))
        ..add((_) => json(200, {'accepted': 1}));
      await presence.goOnline();
      await pumpEventQueue();
      requests.clear();
      answers
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 2}))
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 3}));
      expect(await presence.goOffline(), isNull);
      expect(dispatch.disconnects, 1);
      expect(reporter.running, isFalse);
      expect(body(requests[1]), {
        'expectedVersion': 2,
        'onlineStatus': 'offline',
      });
      expect(presence.serverOnline, isFalse);
    });

    test('offline on a trip: the server\'s reason is shown', () async {
      presence.serverOnline = true;
      answers
        ..add((_) => json(200, {'onlineStatus': 'on_trip', 'version': 9}))
        ..add((_) => json(409, error('invalid_transition', reason: 'on_trip')));
      expect(await presence.goOffline(), tr.liveOfflineOnTrip);
    });

    test('D11: after a restart the server\'s stale online is turned '
        'offline, once', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 7}))
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 8}));
      await presence.settleAfterStart();
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/v1/driver/profile',
        'POST /api/v1/driver/availability',
      ]);
      expect(body(requests[1]), {
        'expectedVersion': 7,
        'onlineStatus': 'offline',
      });
      requests.clear();
      await presence.settleAfterStart();
      expect(requests, isEmpty);
      expect(dispatch.connects, 0);
    });

    test('D11: a trip under way, or a server already offline, is left '
        'alone', () async {
      answers.add((_) => json(200, {'onlineStatus': 'on_trip', 'version': 3}));
      await presence.settleAfterStart();
      expect(requests.map((r) => r.method), ['GET']);
    });

    test('D11: going online right after the start is not undone', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 1}))
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 2}))
        ..add((_) => json(200, {'accepted': 1}));
      final online = presence.goOnline();
      await presence.settleAfterStart();
      expect(await online, isNull);
      await pumpEventQueue();
      expect(
        requests
            .where((r) => r.method == 'POST')
            .map((r) => body(r)['onlineStatus']),
        isNot(contains('offline')),
      );
    });

    test('an offline the app decided (after a trip, a hold) reaches the '
        'server too', () async {
      final session = DriverSessionController();
      presence.attach(session);
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 1}))
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 2}))
        ..add((_) => json(200, {'accepted': 1}));
      session.beginGoingOnline();
      await presence.goOnline();
      session.completeGoingOnline();
      await pumpEventQueue();
      requests.clear();
      answers
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 2}))
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 3}));
      session.suspend();
      await pumpEventQueue();
      expect(requests.map((r) => r.url.path), [
        '/api/v1/driver/profile',
        '/api/v1/driver/availability',
      ]);
      expect(body(requests[1])['onlineStatus'], 'offline');
      presence.detach();
      session.dispose();
    });
  });

  group('trip steps', () {
    late LiveTripCommands trips;

    Map<String, dynamic> trip(String status, int version) => {
      'tripId': 't1',
      'status': status,
      'version': version,
    };

    setUp(() {
      trips = LiveTripCommands(
        api: api(),
        lastFix: () => {
          'lat': 59.33,
          'lng': 18.06,
          'accuracy': 5,
          'measuredAt': '2026-10-25T10:00:00Z',
        },
      );
      // The accept answer.
      trips.observe(trip('accepted', 3));
    });

    test(
      'arrive heads to the pickup first, each with the version it has',
      () async {
        answers
          ..add((_) => json(200, trip('driver_to_pickup', 4)))
          ..add((_) => json(200, trip('arrived', 5)));
        final outcome = await trips.arrive('t1');
        expect(outcome.ok, isTrue);
        expect(requests.map((r) => r.url.path), [
          '/api/v1/trips/t1/head-to-pickup',
          '/api/v1/trips/t1/arrive',
        ]);
        expect(body(requests[0]), {'expectedVersion': 3});
        expect(body(requests[1])['expectedVersion'], 4);
        expect((body(requests[1])['location'] as Map)['lat'], 59.33);
        expect(trips.statusOf('t1'), 'arrived');
        expect(trips.isOwnEcho('t1', 'arrived'), isTrue);
        expect(trips.isOwnEcho('t1', 'cancelled_by_rider'), isFalse);
      },
    );

    test('not at the pickup: refused in plain words, the echo is not '
        'waited for', () async {
      trips.observe(trip('driver_to_pickup', 4));
      answers.add(
        (_) => json(
          409,
          error(
            'invalid_transition',
            reason: 'not_at_pickup',
            projection: trip('driver_to_pickup', 4),
          ),
        ),
      );
      final outcome = await trips.arrive('t1');
      expect(outcome.ok, isFalse);
      expect(outcome.message, tr.liveTripNotAtPickup);
      expect(trips.isOwnEcho('t1', 'arrived'), isFalse);
    });

    test('contract v0.17.3 §26: the final price before Collect cash, and '
        'complete sends the cash shown', () async {
      trips.observe(trip('in_trip', 8));
      Map<String, dynamic> sek(int minor) => {
        'amountMinor': minor,
        'currency': 'SEK',
      };
      answers
        ..add(
          (_) => json(200, {
            'tripId': 't1',
            'total': sek(5400),
            'cashDue': sek(5000),
            'driverEarnings': sek(3920),
            'earlyEnd': true,
            'fareLines': const [],
          }),
        )
        ..add((_) => json(200, trip('completed', 9)));
      final preview = await trips.previewComplete('t1');
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/api/v1/driver/trips/t1/complete-preview',
      );
      expect(preview!.total.minorUnits, 5400);
      expect(preview.cashDue.minorUnits, 5000);
      expect(preview.earlyEnd, isTrue);
      expect(preview.driverEarnings!.minorUnits, 3920);
      expect(trips.previewOf('t1'), same(preview));
      expect(
        (await trips.complete('t1', cashCollected: preview.cashDue)).ok,
        isTrue,
      );
      expect(body(requests[1]), {
        'cashCollected': sek(5000),
        'expectedVersion': 8,
      });
    });

    test('a refused or malformed preview is null', () async {
      answers
        ..add(
          (_) => json(
            409,
            error(
              'invalid_transition',
              reason: 'trip_not_on_board',
              projection: trip('arrived', 5),
            ),
          ),
        )
        ..add((_) => json(200, {'tripId': 't1', 'total': 'x'}))
        ..add(
          (_) => json(200, {
            'tripId': 't1',
            'total': {'amountMinor': 1, 'currency': 'SEK'},
            'cashDue': {'amountMinor': 1, 'currency': 'EUR'},
            'earlyEnd': false,
          }),
        )
        ..add(
          (_) => json(200, {
            'tripId': 't1',
            'total': {'amountMinor': 1.5, 'currency': 'SEK'},
            'cashDue': {'amountMinor': 1, 'currency': 'SEK'},
            'earlyEnd': false,
          }),
        );
      expect(await trips.previewComplete('t1'), isNull);
      expect(trips.previewOf('t1'), isNull);
      expect(trips.statusOf('t1'), 'arrived');
      expect(await trips.previewComplete('t1'), isNull);
      expect(await trips.previewComplete('t1'), isNull);
      expect(await trips.previewComplete('t1'), isNull);
    });

    test('a stale version is retried once with the server\'s', () async {
      trips.observe(trip('arrived', 5));
      answers
        ..add(
          (_) => json(
            409,
            error('version_mismatch', projection: trip('arrived', 6)),
          ),
        )
        ..add((_) => json(200, trip('rider_onboard', 7)))
        ..add((_) => json(200, trip('in_trip', 8)));
      expect((await trips.start('t1')).ok, isTrue);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/trips/t1/board',
        '/api/v1/trips/t1/board',
        '/api/v1/trips/t1/start',
      ]);
      expect(body(requests[1])['expectedVersion'], 6);
      expect(body(requests[2])['expectedVersion'], 7);
    });

    test('no answer: the retry is the same command (same key)', () async {
      trips.observe(trip('in_trip', 8));
      answers
        ..add((_) => throw http.ClientException('lost'))
        ..add((_) => json(200, trip('completed', 9)));
      final first = await trips.complete('t1');
      expect(first.ok, isFalse);
      expect(first.message, tr.authErrOffline);
      // It may have reached the server: its echo still counts as ours.
      expect(trips.isOwnEcho('t1', 'completed'), isTrue);
      expect((await trips.complete('t1')).ok, isTrue);
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[0].headers['Idempotency-Key'],
      );
    });

    test('a step the trip already passed is not sent again', () async {
      trips.observe(trip('in_trip', 8));
      expect((await trips.start('t1')).ok, isTrue);
      expect(requests, isEmpty);
    });

    test('cancel and no-show carry the reason code', () async {
      trips.observe(trip('arrived', 5));
      answers.add((_) => json(200, trip('no_show', 6)));
      expect(
        (await trips.noShow('t1', reasonCode: 'rider_no_show')).ok,
        isTrue,
      );
      expect(requests.single.url.path, '/api/v1/trips/t1/no-show');
      expect(body(requests.single), {
        'reasonCode': 'rider_no_show',
        'expectedVersion': 5,
      });

      trips.observe({
        'tripId': 't2',
        'status': 'driver_to_pickup',
        'version': 2,
      });
      answers.add(
        (_) => json(200, {'tripId': 't2', 'status': 'searching', 'version': 3}),
      );
      expect(
        (await trips.cancel('t2', reasonCode: 'unsafe_pickup')).ok,
        isTrue,
      );
      expect(requests.last.url.path, '/api/v1/trips/t2/cancel');
      expect(body(requests.last), {
        'reasonCode': 'unsafe_pickup',
        'expectedVersion': 2,
      });
      expect(trips.isOwnEcho('t2', 'searching'), isTrue);
    });

    test('a trip not known yet is read first', () async {
      final fresh = LiveTripCommands(api: api());
      answers
        ..add(
          (_) =>
              json(200, {'tripId': 't9', 'status': 'arrived', 'version': 11}),
        )
        ..add(
          (_) => json(200, {
            'tripId': 't9',
            'status': 'rider_onboard',
            'version': 12,
          }),
        )
        ..add(
          (_) =>
              json(200, {'tripId': 't9', 'status': 'in_trip', 'version': 13}),
        );
      expect((await fresh.start('t9')).ok, isTrue);
      expect(requests.first.method, 'GET');
      expect(requests.first.url.path, '/api/v1/trips/t9');
      expect(body(requests[1])['expectedVersion'], 11);
    });

    test('an older projection never replaces a newer one', () {
      trips.observe(trip('arrived', 5));
      trips.observe(trip('driver_to_pickup', 4));
      expect(trips.statusOf('t1'), 'arrived');
      expect(trips.versionOf('t1'), 5);
    });
  });

  group('trip events', () {
    late List<http.BaseRequest> opened;
    late List<StreamController<List<int>>> streams;
    late List<int> statuses;
    late LiveTripCommands trips;
    late ApiDriverRealtime realtime;

    setUp(() {
      opened = [];
      streams = [];
      statuses = [];
      trips = LiveTripCommands(api: api());
      realtime = ApiDriverRealtime(
        client: MockClient.streaming((request, _) async {
          opened.add(request);
          final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
          if (status != 200) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{}')),
              status,
            );
          }
          final stream = StreamController<List<int>>();
          streams.add(stream);
          return http.StreamedResponse(stream.stream, 200);
        }),
        apiBase: origin.replace(path: '/api/v1'),
        accessToken: tokens.readAccess,
        trips: trips,
        reconnectDelay: (_) => Duration.zero,
      );
    });

    tearDown(() => realtime.dispose());

    String sse(int sequence, String kind, {String? status, int version = 1}) =>
        'id: $sequence\ndata: ${jsonEncode({
          'eventId': 'e$sequence',
          'tripId': 't1',
          'sequence': sequence,
          'version': version,
          'kind': kind,
          'occurredAt': '2026-10-25T10:00:00Z',
          'serverTime': '2026-10-25T10:00:00Z',
          if (status != null) 'projection': {'tripId': 't1', 'status': status},
        })}\n\n';

    test('the stream is read as SSE; a rider cancel reaches the screen and '
        'versions reach the commands', () async {
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      expect(opened.single.url.path, '/api/v1/trips/t1/events');
      expect(opened.single.headers['Accept'], 'text/event-stream');
      expect(opened.single.headers['Authorization'], 'Bearer a1');
      streams.single.add(utf8.encode(': stream open\n\n'));
      streams.single.add(
        utf8.encode(sse(1, 'trip_projection', status: 'accepted', version: 3)),
      );
      streams.single.add(
        utf8.encode(
          sse(2, 'trip_projection', status: 'cancelled_by_rider', version: 4),
        ),
      );
      await pumpEventQueue();
      expect(events.map((e) => e.status), [
        TripStatus.accepted,
        TripStatus.cancelledByRider,
      ]);
      expect(trips.versionOf('t1'), 4);
      await sub.cancel();
    });

    test('the echo of this phone\'s own step is not passed on', () async {
      trips.observe({'tripId': 't1', 'status': 'in_trip', 'version': 8});
      answers.add(
        (_) => json(200, {'tripId': 't1', 'status': 'completed', 'version': 9}),
      );
      await trips.complete('t1');
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      streams.single.add(
        utf8.encode(sse(5, 'trip_projection', status: 'completed', version: 9)),
      );
      streams.single.add(utf8.encode(sse(6, 'location', version: 9)));
      await pumpEventQueue();
      expect(events.map((e) => e.kind), [DriverRealtimeKind.location]);
      await sub.cancel();
    });

    test('a dropped stream resumes after the last sequence', () async {
      final sub = realtime.subscribe('t1').listen((_) {});
      await pumpEventQueue();
      streams.single.add(
        utf8.encode(sse(3, 'trip_projection', status: 'arrived')),
      );
      await pumpEventQueue();
      await streams.single.close();
      await pumpEventQueue();
      expect(opened, hasLength(2));
      expect(opened.last.url.queryParameters['after'], '3');
      expect(opened.last.headers['Last-Event-ID'], '3');
      await sub.cancel();
    });

    test('the replay of the trip\'s history before the accept is not passed '
        'on (it read as the trip taken back)', () async {
      // The accept answer made version 4 known.
      trips.observe({'tripId': 't1', 'status': 'accepted', 'version': 4});
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      final s = streams.single;
      s.add(
        utf8.encode(sse(1, 'trip_projection', status: 'requested', version: 1)),
      );
      s.add(
        utf8.encode(sse(2, 'trip_projection', status: 'searching', version: 2)),
      );
      s.add(
        utf8.encode(sse(3, 'trip_projection', status: 'offered', version: 3)),
      );
      s.add(
        utf8.encode(sse(4, 'trip_projection', status: 'accepted', version: 4)),
      );
      s.add(
        utf8.encode(
          sse(5, 'trip_projection', status: 'driver_to_pickup', version: 5),
        ),
      );
      await pumpEventQueue();
      expect(
        events.any((e) => e.status?.isReleasedToDispatch ?? false),
        isFalse,
      );
      expect(events.last.status, TripStatus.driverToPickup);
      expect(realtime.lastSequence, 5);
      await sub.cancel();
    });

    test('nothing known yet (a restored screen): the trip is read before the '
        'stream, so its history is still told from news', () async {
      answers.add(
        (_) => json(200, {'tripId': 't1', 'status': 'arrived', 'version': 6}),
      );
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      expect(trips.versionOf('t1'), 6);
      final s = streams.single;
      s.add(
        utf8.encode(sse(2, 'trip_projection', status: 'searching', version: 2)),
      );
      s.add(
        utf8.encode(
          sse(7, 'trip_projection', status: 'cancelled_by_rider', version: 7),
        ),
      );
      await pumpEventQueue();
      expect(events.map((e) => e.status), [TripStatus.cancelledByRider]);
      await sub.cancel();
    });

    test('a trip that is not this driver\'s any more ends here as handed '
        'back', () async {
      statuses.add(404);
      final events = <DriverRealtimeEvent>[];
      final sub = realtime.subscribe('t1').listen(events.add);
      await pumpEventQueue();
      expect(events.single.status, TripStatus.searching);
      expect(events.single.status!.isReleasedToDispatch, isTrue);
      await sub.cancel();
    });
  });

  group('offers', () {
    test('the accept answer gives the trip\'s first version; a 401 renews '
        'the session and sends the same command again', () async {
      final seen = <http.Request>[];
      final accepted = <Map<String, dynamic>>[];
      var renewed = 0;
      final steps = <http.Response Function()>[
        () => json(200, {
          'items': [_offer()],
          'nextCursor': null,
        }),
        () => json(401, error('unauthorized')),
        () => json(200, {
          'tripId': 'trip-o1',
          'status': 'accepted',
          'version': 3,
        }),
      ];
      final repo = ApiDispatchRepository(
        client: MockClient((request) async {
          seen.add(request);
          return steps.removeAt(0)();
        }),
        baseUri: origin.replace(path: '/api/v1'),
        accessToken: () async => 'token',
        renewSession: () async => renewed++,
        onAccepted: accepted.add,
      );
      final listed = repo.watchNearbyOffers().skip(1).first;
      repo.refreshOffers();
      await listed;
      final result = await repo.claimOffer('o1');
      expect(result.isSuccess, isTrue);
      expect(renewed, 1);
      expect(
        seen[1].headers['Idempotency-Key'],
        seen[2].headers['Idempotency-Key'],
      );
      expect(accepted.single['version'], 3);
      await repo.dispose();
    });

    test('disconnect closes the feed, clears the offers and does not '
        'reconnect', () async {
      final feeds = <StreamController<List<int>>>[];
      final repo = ApiDispatchRepository(
        client: MockClient.streaming((request, _) async {
          final feed = StreamController<List<int>>();
          feeds.add(feed);
          return http.StreamedResponse(feed.stream, 200);
        }),
        baseUri: origin.replace(path: '/api/v1'),
        accessToken: () async => 'token',
        reconnectDelay: (_) => Duration.zero,
      );
      await repo.connect();
      feeds.single.add(
        utf8.encode(
          'data: ${jsonEncode({'kind': 'offer_created', 'sequence': 1, 'offer': _offer()})}\n\n',
        ),
      );
      await pumpEventQueue();
      final lists = <int>[];
      final sub = repo.watchNearbyOffers().listen(
        (offers) => lists.add(offers.length),
      );
      await repo.disconnect();
      await pumpEventQueue();
      expect(repo.feedLive, isFalse);
      expect(lists, [1, 0]);
      expect(feeds, hasLength(1));
      await sub.cancel();
      await repo.dispose();
    });
  });
}

Map<String, dynamic> _offer() => {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2099-01-01T00:00:00Z',
  'fare': {'amountMinor': 15000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 12000, 'currency': 'SEK'},
  'priority': false,
  'source': 'system',
  'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'Vasagatan 1'},
  'dropoff': {'lat': 59.31, 'lng': 18.07, 'address': 'Götgatan 1'},
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 240,
  'pickupMeters': 1200,
  'tripSeconds': 900,
  'tripMeters': 4200,
};

class _FixedLocation implements DriverLocationRepository {
  _FixedLocation({this.fails = false});

  final bool fails;

  @override
  Future<DriverLocation> getCurrentPosition() async {
    if (fails) throw StateError('no fix');
    return DriverLocation(
      point: const GeoPoint(59.3326, 18.0649),
      headingDegrees: 90,
      speedMetersPerSecond: 5,
      accuracyMeters: 8,
      measuredAt: DateTime.utc(2026, 10, 25, 10),
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

class _FakeDispatch implements ApiDispatchRepository {
  int connects = 0;
  int disconnects = 0;
  int refreshes = 0;
  bool live = false;

  @override
  Future<void> connect() async {
    connects++;
    live = true;
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    live = false;
  }

  @override
  void refreshOffers() => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
