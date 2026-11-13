// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/live/api_driver_realtime.dart';

/// Fix plan 2026-11-13 (supervisor 4, driver): how the driver app behaves
/// when the server is overloaded (G34 load tests: answers late by up to
/// the 10 s pool wait, 503 server_busy with Retry-After 2, streams the
/// server ends after its read retries, B1.9). D1: a lost Accept whose
/// checks are answered late still opens the trip the server gave him.
/// D2: the offer feed and the trip stream back off when the server ends
/// them right after they opened (owner R3 2026-11-13: a stream counts as
/// connected only after an event or 30 s up). D3: the offer feed honours
/// Retry-After on 503 / 429 (at most 60 s). A fake server only.

final _base = Uri.parse('https://api.test.movera.invalid/api/v1');

Map<String, dynamic> _offer({
  String id = 'o1',
  String status = 'open',
  required DateTime expiresAt,
}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': 'exclusive',
  'status': status,
  'version': 1,
  'expiresAt': expiresAt.toUtc().toIso8601String(),
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'A', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'B', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A stopwatch that reads fake time.
class _FakeWatch implements Stopwatch {
  _FakeWatch(this._async);
  final FakeAsync _async;
  Duration _from = Duration.zero;

  @override
  void start() => _from = _async.elapsed;

  @override
  Duration get elapsed => _async.elapsed - _from;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('a lost Accept answer on a busy server', () {
    // The server took the Accept, but answers only after 9 s (its pool
    // queue; acceptAnswerTimeout is 8 s). Each "did my accept go through?"
    // check is answered after 3 s (busy, but well inside the 20 s window).
    test('a check answered after 3 s still opens the trip (it is his)', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 13, 12);
        DateTime now() => start.add(async.elapsed);
        final sent = <String>[];
        late ApiDispatchRepository repo;
        repo = ApiDispatchRepository(
          client: MockClient((request) async {
            sent.add('${request.method} ${request.url.path}');
            final path = request.url.path;
            if (path.endsWith('/driver/offers')) {
              return _json({
                'items': [
                  _offer(expiresAt: start.add(const Duration(seconds: 15))),
                ],
                'nextCursor': null,
              });
            }
            if (path.endsWith('/accept')) {
              await Future<void>.delayed(const Duration(seconds: 9));
              return _json({'tripId': 'trip-o1', 'status': 'driver_to_pickup'});
            }
            // GET /driver/offers/o1: OfferCheck, claimed with his trip.
            await Future<void>.delayed(const Duration(seconds: 3));
            return _json({
              'offer': _offer(
                status: 'claimed',
                expiresAt: start.add(const Duration(seconds: 15)),
              ),
              'trip': {'tripId': 'trip-o1', 'status': 'driver_to_pickup'},
            });
          }),
          baseUri: _base,
          accessToken: () async => 'token',
          now: now,
          stopwatch: () => _FakeWatch(async),
        );
        repo.refreshOffers();
        async.flushMicrotasks();

        ClaimResult? result;
        repo.claimOffer('o1').then((value) => result = value);
        async.elapse(const Duration(seconds: 40));

        expect(result, isNotNull);
        expect(
          result!.outcome,
          ClaimOutcome.success,
          reason:
              'the server claimed the offer for him; a 3 s answer to the '
              'check must not end as "No connection"',
        );
        final checks = sent
            .where((s) => s == 'GET /api/v1/driver/offers/o1')
            .length;
        expect(
          checks,
          lessThanOrEqualTo(2),
          reason: 'no pile of abandoned checks on a busy server',
        );
        repo.dispose();
      });
    });
  });

  group('the offer feed on a busy server (D2, owner R3)', () {
    // Real time: a finished SSE subscription's cancel lives in the root
    // zone, which fake time never runs (see resume_burst_test.dart). The
    // clock is moved by hand.
    test('a feed that ends right after it opened backs off', () async {
      final server = _StreamServer();
      final attempts = <int>[];
      final repo = server.feed(attempts);
      unawaited(repo.connect());
      for (var open = 1; open <= 5; open++) {
        await _until(() => server.opened.length >= open);
        // ": stream open", then the server ends the stream at once.
        await server.opened.last.close();
      }
      await _until(() => attempts.length >= 4);
      repo.dispose();
      expect(attempts.take(4), [
        0,
        1,
        2,
        3,
      ], reason: 'a stream that ended at once is a failed try');
    });

    test('30 s up counts as connected; 29 s does not', () async {
      final server = _StreamServer();
      final attempts = <int>[];
      final repo = server.feed(attempts);
      unawaited(repo.connect());
      await _until(() => server.opened.isNotEmpty);
      await server.opened.last.close(); // at once: wait 0
      await _until(() => server.opened.length >= 2);
      server.clock = server.clock.add(const Duration(seconds: 29));
      await server.opened.last.close(); // 29 s: still backs off (wait 1)
      await _until(() => server.opened.length >= 3);
      server.clock = server.clock.add(const Duration(seconds: 30));
      await server.opened.last.close(); // 30 s: connected (wait 0 again)
      await _until(() => attempts.length >= 3);
      repo.dispose();
      expect(attempts.take(3), [0, 1, 0]);
    });

    test(
      'an event counts as connected; a cursor or heartbeat does not',
      () async {
        final server = _StreamServer();
        final attempts = <int>[];
        final repo = server.feed(attempts);
        unawaited(repo.connect());
        await _until(() => server.opened.isNotEmpty);
        // Only the cursor (`id:` with no data) and a heartbeat: not an event.
        server.opened.last
          ..add(utf8.encode('id: 4\n\n'))
          ..add(utf8.encode(': heartbeat\n\n'));
        await server.opened.last.close();
        await _until(() => server.opened.length >= 2);
        await server.opened.last.close();
        await _until(() => server.opened.length >= 3);
        // A real event, then the server ends the stream.
        server.opened.last.add(
          utf8.encode(
            'id: 5\ndata: ${jsonEncode({'sequence': 5, 'kind': 'offer_created', 'offer': _offer(expiresAt: server.clock.add(const Duration(seconds: 15)))})}\n\n',
          ),
        );
        await pumpEventQueue();
        await server.opened.last.close();
        await _until(() => attempts.length >= 3);
        repo.dispose();
        expect(attempts.take(3), [0, 1, 0]);
      },
    );

    test('a new Go online starts again from the shortest wait', () async {
      final server = _StreamServer();
      final attempts = <int>[];
      final repo = server.feed(attempts);
      unawaited(repo.connect());
      await _until(() => server.opened.isNotEmpty);
      await server.opened.last.close();
      await _until(() => server.opened.length >= 2);
      await server.opened.last.close();
      await _until(() => attempts.length >= 2);
      // The reconnect timer opened a third feed; the driver goes offline
      // (that feed is closed by the app, not lost), then online again.
      await _until(() => server.opened.length >= 3);
      await repo.disconnect();
      unawaited(repo.connect());
      await _until(() => server.opened.length >= 4);
      await server.opened.last.close();
      await _until(() => attempts.length >= 3);
      repo.dispose();
      expect(attempts, [
        0,
        1,
        0,
      ], reason: 'a new Go online starts again from the shortest wait');
    });
  });

  group('the offer feed honours Retry-After (D3)', () {
    for (final status in [503, 429]) {
      test('a $status with Retry-After 2 is not asked again sooner', () {
        fakeAsync((async) {
          final opened = <Duration>[];
          final repo = _busyFeed(async, opened, status: status, header: '2');
          unawaited(repo.connect());
          async.elapse(const Duration(milliseconds: 4100));
          expect(opened.length, greaterThanOrEqualTo(2));
          expect(
            opened[1] - opened[0],
            greaterThanOrEqualTo(const Duration(seconds: 2)),
            reason: 'the server said Retry-After: 2',
          );
          repo.dispose();
        });
      });
    }

    test('a Retry-After over 60 s waits 60 s', () {
      fakeAsync((async) {
        final opened = <Duration>[];
        final repo = _busyFeed(async, opened, header: '600');
        unawaited(repo.connect());
        async.elapse(const Duration(seconds: 59));
        expect(opened.length, 1, reason: 'not before 60 s');
        async.elapse(const Duration(seconds: 2));
        expect(opened.length, 2, reason: 'capped at 60 s, not 600 s');
        repo.dispose();
      });
    });

    test('a longer backoff wins over a shorter Retry-After', () {
      fakeAsync((async) {
        final opened = <Duration>[];
        final repo = _busyFeed(
          async,
          opened,
          header: '2',
          backoff: const Duration(seconds: 5),
        );
        unawaited(repo.connect());
        async.elapse(const Duration(seconds: 6));
        expect(opened.length, 2);
        expect(opened[1] - opened[0], const Duration(seconds: 5));
        repo.dispose();
      });
    });

    test('a 503 without Retry-After keeps the backoff', () {
      fakeAsync((async) {
        final opened = <Duration>[];
        final repo = _busyFeed(async, opened, header: null);
        unawaited(repo.connect());
        async.elapse(const Duration(milliseconds: 1000));
        expect(opened.length, 2);
        expect(opened[1] - opened[0], const Duration(milliseconds: 900));
        repo.dispose();
      });
    });
  });

  group('the trip stream on a busy server (D2, same rule)', () {
    test('a trip stream that ends right after it opened backs off', () async {
      final server = _StreamServer();
      final attempts = <int>[];
      final realtime = server.trip(attempts);
      realtime.subscribe('t1');
      for (var open = 1; open <= 5; open++) {
        await _until(() => server.opened.length >= open);
        await server.opened.last.close();
      }
      await _until(() => attempts.length >= 4);
      realtime.dispose();
      expect(attempts.take(4), [
        0,
        1,
        2,
        3,
      ], reason: 'a stream that ended at once is a failed try');
    });

    test('an event or 30 s up counts as connected', () async {
      final server = _StreamServer();
      final attempts = <int>[];
      final realtime = server.trip(attempts);
      realtime.subscribe('t1');
      await _until(() => server.opened.isNotEmpty);
      await server.opened.last.close(); // at once: wait 0
      await _until(() => server.opened.length >= 2);
      server.clock = server.clock.add(const Duration(seconds: 29));
      await server.opened.last.close(); // 29 s: wait 1
      await _until(() => server.opened.length >= 3);
      server.clock = server.clock.add(const Duration(seconds: 30));
      await server.opened.last.close(); // 30 s: wait 0
      await _until(() => server.opened.length >= 4);
      await server.opened.last.close(); // at once: wait 1
      await _until(() => server.opened.length >= 5);
      server.opened.last.add(
        utf8.encode(
          'id: 3\ndata: ${jsonEncode({'eventId': 'e3', 'tripId': 't1', 'sequence': 3, 'kind': 'message', 'occurredAt': server.clock.toIso8601String(), 'serverTime': server.clock.toIso8601String()})}\n\n',
        ),
      );
      await pumpEventQueue();
      await server.opened.last.close(); // an event: wait 0
      await _until(() => attempts.length >= 5);
      realtime.dispose();
      expect(attempts.take(5), [0, 1, 0, 1, 0]);
    });
  });
}

/// A fake server whose SSE streams stay open until the test ends them;
/// [clock] is the app's clock, moved by hand.
class _StreamServer {
  final List<StreamController<List<int>>> opened =
      <StreamController<List<int>>>[];
  DateTime clock = DateTime.utc(2026, 11, 13, 12);

  http.Client get client => MockClient.streaming((request, _) async {
    final path = request.url.path;
    if (path.endsWith('/driver/offers')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"items":[],"nextCursor":null}')),
        200,
      );
    }
    final stream = StreamController<List<int>>();
    stream.add(utf8.encode(': stream open\n\n'));
    opened.add(stream);
    return http.StreamedResponse(stream.stream, 200);
  });

  ApiDispatchRepository feed(List<int> attempts) => ApiDispatchRepository(
    client: client,
    baseUri: _base,
    accessToken: () async => 'token',
    now: () => clock,
    reconnectDelay: (attempt) {
      attempts.add(attempt);
      return const Duration(milliseconds: 5);
    },
  );

  ApiDriverRealtime trip(List<int> attempts) => ApiDriverRealtime(
    client: client,
    apiBase: _base,
    accessToken: () async => 'token',
    now: () => clock,
    reconnectDelay: (attempt) {
      attempts.add(attempt);
      return const Duration(milliseconds: 5);
    },
  );
}

/// A feed on a server that answers every open with [status] and
/// `Retry-After: header` (none when null).
ApiDispatchRepository _busyFeed(
  FakeAsync async,
  List<Duration> opened, {
  int status = 503,
  String? header,
  Duration backoff = const Duration(milliseconds: 900),
}) => ApiDispatchRepository(
  client: MockClient.streaming((request, _) async {
    opened.add(async.elapsed);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"code":"unavailable","reason":"server_busy",'
          '"retryAfterSeconds":2}',
        ),
      ),
      status,
      headers: {if (header != null) 'retry-after': header},
    );
  }),
  baseUri: _base,
  accessToken: () async => 'token',
  reconnectDelay: (_) => backoff,
);

/// Waits (real time) until [done], at most 3 s.
Future<void> _until(bool Function() done) async {
  final give = DateTime.now().add(const Duration(seconds: 3));
  while (!done()) {
    if (DateTime.now().isAfter(give)) {
      throw TimeoutException('condition not met in 3 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}
