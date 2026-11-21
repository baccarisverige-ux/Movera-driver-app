import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/one_stream_fallback.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/one_stream.dart';
import 'package:movera/core/logging/driver_log.dart';

/// L20 stream backup (contract v0.18.150, contract.json#driverOneStreamFallback;
/// owner 2026-11-21 08:10 "Switch to old two (Rec.)": "when first down we can
/// use second as backup"): with DriverAppConfig.realtime.oneStream on, after
/// realtime.oneStreamFallback.failuresInARow failed tries of GET /driver/stream
/// in a row the phone opens the two old streams (offers + settings) so offers
/// keep coming; it asks the one stream again after retryOneAfterMinutes (or
/// at app restart). A connected try resets the count; 404 is unchanged.
/// Rule 36: fails on the base branch (the one stream is asked for ever).
Map<String, dynamic> _offer(int sequence) => {
  'eventId': 'e$sequence',
  'sequence': sequence,
  'kind': 'offer_created',
  'offer': {
    'offerId': 'o$sequence',
    'tripId': 'trip-o$sequence',
    'kind': 'exclusive',
    'status': 'open',
    'version': 1,
    'expiresAt': '2099-11-21T08:00:26Z',
    'fare': {'amountMinor': 4717, 'currency': 'SEK'},
    'source': 'system',
    'pickup': {'address': 'Centrum', 'lat': 59.1955, 'lng': 17.6253},
    'dropoff': {'address': 'Arlanda', 'lat': 59.6498, 'lng': 17.9238},
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'pickupEtaSeconds': 180,
    'pickupMeters': 900,
    'tripSeconds': 720,
    'tripMeters': 5200,
  },
};

/// How the server answers the next GET /driver/stream.
enum _One {
  ok,
  busy,
  busyRetryAfter,
  closeAtOnce,
  notFound,
  unauthorized,
  networkError,
}

/// The backup timer, fired by the test (no real minutes).
class _Timers {
  final all = <_FakeTimer>[];
  _FakeTimer? get last => all.isEmpty ? null : all.last;
  Timer create(Duration after, void Function() run) {
    final timer = _FakeTimer(after, run);
    all.add(timer);
    return timer;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.after, this.run);
  final Duration after;
  final void Function() run;
  bool cancelled = false;
  bool fired = false;
  void fire() {
    fired = true;
    run();
  }

  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled && !fired;
  @override
  int get tick => 0;
}

class _Server {
  _Server({this.fallback});
  final Map<String, dynamic>? fallback;
  _One one = _One.busy;

  /// Answers used first, one per GET /driver/stream, before [one].
  final plan = <_One>[];
  int version = 5;
  final asked = <http.BaseRequest>[];
  final open = <String, int>{};
  final feeds = <String, List<StreamController<List<int>>>>{};

  int asks(String stream) =>
      asked.where((r) => r.url.path.endsWith(stream)).length;

  http.Client client() => MockClient.streaming((request, _) async {
    final path = request.url.path;
    http.StreamedResponse json(Object body, [int status = 200]) =>
        http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(body))),
          status,
        );
    for (final stream in [
      '/driver/stream',
      '/driver/offers/stream',
      '/driver/config/stream',
    ]) {
      if (!path.endsWith(stream)) continue;
      asked.add(request);
      if (stream == '/driver/stream') {
        switch (plan.isNotEmpty ? plan.removeAt(0) : one) {
          case _One.busy:
            return json({'code': 'unavailable'}, 503);
          case _One.busyRetryAfter:
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'code': 'unavailable'}))),
              503,
              headers: {'retry-after': '60'},
            );
          case _One.notFound:
            return json({'code': 'not_found'}, 404);
          case _One.unauthorized:
            return json({'code': 'unauthorized'}, 401);
          case _One.networkError:
            throw http.ClientException('no network');
          case _One.closeAtOnce:
            return http.StreamedResponse(const Stream.empty(), 200);
          case _One.ok:
            break;
        }
      }
      late StreamController<List<int>> feed;
      feed = StreamController<List<int>>(
        onListen: () => open[stream] = (open[stream] ?? 0) + 1,
        onCancel: () => open[stream] = (open[stream] ?? 1) - 1,
      );
      (feeds[stream] ??= []).add(feed);
      return http.StreamedResponse(feed.stream, 200);
    }
    if (path.endsWith('/driver/config')) {
      return json({
        'version': version,
        'zoneId': 'Z001',
        'currency': 'SEK',
        'timeZone': 'Europe/Stockholm',
        'realtime': {
          'oneStream': true,
          if (fallback != null) 'oneStreamFallback': fallback,
        },
      });
    }
    if (path.endsWith('/driver/offers')) return json({'items': []});
    return json({});
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final base = Uri.parse('https://api.test.movera.invalid/api/v1');
  final logs = <String>[];
  final sink = DriverLog.sink;
  setUp(() {
    logs.clear();
    DriverLog.sink = (record) => logs.add(record.message);
  });
  tearDown(() => DriverLog.sink = sink);

  Future<
    ({
      ApiDispatchRepository dispatch,
      LiveDriverConfig config,
      DateTime Function() now,
    })
  >
  phone(
    _Server server,
    DateTime Function() clock, {
    Future<void> Function()? renew,
    _Timers? timers,
  }) async {
    final client = server.client();
    final dispatch = ApiDispatchRepository(
      client: client,
      baseUri: base,
      accessToken: () async => 'token-1',
      reconnectDelay: (_) => Duration.zero,
      renewSession: renew,
      now: clock,
      backupTimer: timers?.create,
    );
    final config = LiveDriverConfig(
      client: client,
      apiBase: base,
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
      zoneId: () => 'Z001',
    );
    linkOneStream(dispatch: dispatch, config: config);
    await config.start();
    await config.watch();
    await dispatch.connect();
    await _settle();
    return (dispatch: dispatch, config: config, now: clock);
  }

  test(
    '3 failed tries in a row: the two old streams open (settings too), offers are delivered',
    () async {
      final server = _Server()..one = _One.busy;
      var now = DateTime.utc(2026, 11, 21, 9);
      final p = await phone(server, () => now);
      expect(
        server.asks('/driver/stream'),
        3,
        reason: 'default failuresInARow 3',
      );
      expect(p.dispatch.oneStreamBackup, isTrue);
      expect(p.dispatch.usesOneStream, isFalse);
      expect(server.open['/driver/offers/stream'], 1, reason: '${server.open}');
      expect(server.open['/driver/config/stream'], 1, reason: '${server.open}');
      expect(p.config.onOneStream, isFalse);
      expect(
        logs.where((l) => l.startsWith('offer_feed.one_stream_backup:')),
        hasLength(1),
      );

      server.feeds['/driver/offers/stream']!.last.add(
        utf8.encode('id: 1\ndata: ${jsonEncode(_offer(1))}\n\n'),
      );
      await _settle();
      expect(
        [for (final o in await p.dispatch.watchNearbyOffers().first) o.id],
        ['o1'],
      );
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  Future<void> offerOnOld(_Server server, int sequence) async {
    server.feeds['/driver/offers/stream']!.last.add(
      utf8.encode('id: $sequence\ndata: ${jsonEncode(_offer(sequence))}\n\n'),
    );
    await _settle();
  }

  Future<List<String>> offers(ApiDispatchRepository dispatch) async => [
    for (final o in await dispatch.watchNearbyOffers().first) o.id,
  ];

  test(
    'way back: before the timer no one-stream request; at the timer the one stream opens '
    'next to the old two, which close only once it is connected',
    () async {
      final server = _Server(
        fallback: {'failuresInARow': 2, 'retryOneAfterMinutes': 15},
      )..one = _One.busy;
      final timers = _Timers();
      var now = DateTime.utc(2026, 11, 21, 9);
      final p = await phone(server, () => now, timers: timers);
      expect(
        p.config.oneStreamFallback,
        const OneStreamFallback(failuresInARow: 2, retryOneAfterMinutes: 15),
      );
      expect(server.asks('/driver/stream'), 2);
      expect(p.dispatch.oneStreamBackup, isTrue);
      expect(timers.last!.after, const Duration(minutes: 15));
      server.one = _One.ok;

      // The old offer feed drops before the time: it opens the old one again.
      now = now.add(const Duration(minutes: 20));
      await server.feeds['/driver/offers/stream']!.last.close();
      await _settle();
      expect(
        server.asks('/driver/stream'),
        2,
        reason: 'the timer decides, not the clock',
      );
      expect(server.open['/driver/offers/stream'], 1);

      // The timer: the one stream is asked while the old two stay open.
      final offersAsked = server.asks('/driver/offers/stream');
      timers.last!.fire();
      await _settle();
      expect(server.asks('/driver/stream'), 3);
      expect(server.open, {
        '/driver/offers/stream': 1,
        '/driver/config/stream': 1,
        '/driver/stream': 1,
      });
      expect(p.dispatch.oneStreamBackup, isTrue, reason: 'not connected yet');
      await offerOnOld(server, 1);
      expect(await offers(p.dispatch), [
        'o1',
      ], reason: 'no gap during the return try');

      // A real event on the one stream: adopted, the old two close.
      server.feeds['/driver/stream']!.last.add(
        utf8.encode('id: 2.5\ndata: ${jsonEncode(_offer(2))}\n\n'),
      );
      await _settle();
      expect(p.dispatch.oneStreamBackup, isFalse);
      expect(p.dispatch.usesOneStream, isTrue);
      expect(await offers(p.dispatch), ['o1', 'o2']);
      expect(server.open['/driver/stream'], 1, reason: '${server.open}');
      expect(server.open['/driver/offers/stream'], 0);
      expect(server.open['/driver/config/stream'], 0);
      expect(
        server.asks('/driver/offers/stream'),
        offersAsked,
        reason: 'no reconnect',
      );
      expect(p.config.onOneStream, isTrue);
      expect(
        logs.where((l) => l.startsWith('offer_feed.one_stream_backup_end')),
        hasLength(1),
      );
      // The adopted stream is the feed: a drop reconnects the one stream.
      await server.feeds['/driver/stream']!.last.close();
      await _settle();
      expect(server.asks('/driver/stream'), 4);
      expect(server.open['/driver/stream'], 1);
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test(
    'a failed return try stays on the two old streams with no gap, for another retryOneAfterMinutes',
    () async {
      for (final kind in [_One.busy, _One.closeAtOnce, _One.networkError]) {
        final server = _Server()..one = _One.busy;
        final timers = _Timers();
        final p = await phone(
          server,
          () => DateTime.utc(2026, 11, 21, 9),
          timers: timers,
        );
        expect(p.dispatch.oneStreamBackup, isTrue, reason: '$kind');
        final offersAsked = server.asks('/driver/offers/stream');
        final configAsked = server.asks('/driver/config/stream');
        server.one = kind;
        final first = timers.last!;
        first.fire();
        await _settle();
        expect(
          server.asks('/driver/stream'),
          4,
          reason: 'one return try ($kind)',
        );
        expect(p.dispatch.oneStreamBackup, isTrue, reason: '$kind');
        expect(timers.all, hasLength(2), reason: 'another period ($kind)');
        expect(timers.last!.after, const Duration(minutes: 10));
        expect(
          server.open['/driver/offers/stream'],
          1,
          reason: '$kind ${server.open}',
        );
        expect(
          server.open['/driver/config/stream'],
          1,
          reason: '$kind ${server.open}',
        );
        expect(
          server.asks('/driver/offers/stream'),
          offersAsked,
          reason: 'the old feed was never closed ($kind)',
        );
        expect(
          server.asks('/driver/config/stream'),
          configAsked,
          reason: '$kind',
        );
        await offerOnOld(server, 7);
        expect(await offers(p.dispatch), ['o7'], reason: '$kind');
        expect(
          logs.where((l) => l.contains('the return try failed')),
          isNotEmpty,
        );
        await p.dispatch.disconnect();
        p.config.dispose();
      }
    },
  );

  test(
    'the try that starts the backup opens the old streams at once (no Retry-After wait)',
    () async {
      final server = _Server()
        ..plan.addAll([_One.busy, _One.busy, _One.busyRetryAfter]);
      final p = await phone(
        server,
        () => DateTime.utc(2026, 11, 21, 9),
        timers: _Timers(),
      );
      expect(server.asks('/driver/stream'), 3);
      expect(p.dispatch.oneStreamBackup, isTrue);
      expect(
        server.open['/driver/offers/stream'],
        1,
        reason: 'opened within the settle, not after 60 s',
      );
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test(
    'the backup timer is cancelled on disconnect and dispose; the next connect uses the time left',
    () async {
      final server = _Server()..one = _One.busy;
      final timers = _Timers();
      var now = DateTime.utc(2026, 11, 21, 9);
      final p = await phone(server, () => now, timers: timers);
      final armed = timers.last!;
      await p.dispatch.disconnect();
      expect(armed.cancelled, isTrue);
      // Back online 4 min later: still backup, a timer for the 6 min left.
      now = now.add(const Duration(minutes: 4));
      await p.dispatch.connect();
      await _settle();
      expect(p.dispatch.oneStreamBackup, isTrue);
      expect(server.asks('/driver/stream'), 3);
      expect(timers.last!.after, const Duration(minutes: 6));
      await p.dispatch.disconnect();
      // Back online after the time: the one stream is asked first.
      now = now.add(const Duration(minutes: 7));
      server.one = _One.ok;
      await p.dispatch.connect();
      await _settle();
      expect(p.dispatch.oneStreamBackup, isFalse);
      expect(server.open['/driver/stream'], 1);
      await p.dispatch.disconnect();
      p.config.dispose();

      final other = _Server()..one = _One.busy;
      final more = _Timers();
      final q = await phone(other, () => now, timers: more);
      await q.dispatch.dispose();
      expect(more.last!.cancelled, isTrue);
      q.config.dispose();
    },
  );

  test('forget (another driver) drops the backup and its timer', () async {
    final server = _Server()..one = _One.busy;
    final timers = _Timers();
    final p = await phone(
      server,
      () => DateTime.utc(2026, 11, 21, 9),
      timers: timers,
    );
    expect(p.dispatch.oneStreamBackup, isTrue);
    p.dispatch.forget();
    expect(p.dispatch.oneStreamBackup, isFalse);
    expect(timers.last!.cancelled, isTrue);
    await p.dispatch.disconnect();
    p.config.dispose();
  });

  test(
    'timer end with the phone clock behind: the return try still runs',
    () async {
      final server = _Server()..one = _One.busy;
      final timers = _Timers();
      final clock = DateTime.utc(2026, 11, 21, 9);
      final p = await phone(server, () => clock, timers: timers);
      server.one = _One.ok;
      timers.last!.fire(); // the clock never moved
      await _settle();
      expect(server.asks('/driver/stream'), 4);
      server.feeds['/driver/stream']!.last.add(
        utf8.encode('id: 1.5\ndata: ${jsonEncode(_offer(1))}\n\n'),
      );
      await _settle();
      expect(p.dispatch.oneStreamBackup, isFalse);
      expect(p.dispatch.usesOneStream, isTrue);
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test(
    'a connected try resets the count (2 fails, a real event, 2 fails: no backup)',
    () async {
      final server = _Server()
        ..plan.addAll([_One.busy, _One.busy])
        ..one = _One.ok;
      final p = await phone(server, () => DateTime.utc(2026, 11, 21, 9));
      expect(server.asks('/driver/stream'), 3);
      expect(p.dispatch.oneStreamFailures, 2);
      expect(p.dispatch.usesOneStream, isTrue);
      server.feeds['/driver/stream']!.last.add(
        utf8.encode('id: 1.5\ndata: ${jsonEncode(_offer(1))}\n\n'),
      );
      await _settle();
      expect(
        p.dispatch.oneStreamFailures,
        0,
        reason: 'a real event resets the count',
      );
      // The connected stream drops (not a failed try), then 2 more failures: still below 3.
      server.plan.addAll([_One.busy, _One.busy]);
      await server.feeds['/driver/stream']!.last.close();
      await _settle();
      expect(server.asks('/driver/stream'), 6);
      expect(p.dispatch.oneStreamFailures, 2);
      expect(p.dispatch.oneStreamBackup, isFalse);
      expect(server.open['/driver/stream'], 1);
      expect(server.asks('/driver/offers/stream'), 0, reason: 'no backup');
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test(
    'a 200 that closes at once and a network error are failed tries',
    () async {
      for (final kind in [_One.closeAtOnce, _One.networkError]) {
        final server = _Server()..one = kind;
        final p = await phone(server, () => DateTime.utc(2026, 11, 21, 9));
        expect(server.asks('/driver/stream'), 3, reason: '$kind');
        expect(p.dispatch.oneStreamBackup, isTrue, reason: '$kind');
        expect(
          server.open['/driver/offers/stream'],
          1,
          reason: '$kind ${server.open}',
        );
        expect(
          server.open['/driver/config/stream'],
          1,
          reason: '$kind ${server.open}',
        );
        await p.dispatch.disconnect();
        p.config.dispose();
      }
    },
  );

  test('a 401 the app renews is not a failed try', () async {
    final server = _Server()..one = _One.unauthorized;
    var renewals = 0;
    final p = await phone(
      server,
      () => DateTime.utc(2026, 11, 21, 9),
      renew: () async {
        if (++renewals == 5) server.one = _One.ok;
      },
    );
    expect(renewals, 5);
    expect(p.dispatch.oneStreamBackup, isFalse);
    expect(p.dispatch.usesOneStream, isTrue);
    expect(server.open['/driver/stream'], 1);
    await p.dispatch.disconnect();
    p.config.dispose();
  });

  test(
    '404 (an older server) unchanged: the two streams until restart, no backup',
    () async {
      final server = _Server()..one = _One.notFound;
      final p = await phone(server, () => DateTime.utc(2026, 11, 21, 9));
      expect(server.asks('/driver/stream'), 1);
      expect(p.dispatch.oneStreamRefused, isTrue);
      expect(p.dispatch.oneStreamBackup, isFalse);
      expect(server.open['/driver/offers/stream'], 1);
      expect(server.open['/driver/config/stream'], 1);
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test('app restart: a new phone asks the one stream first again', () async {
    final server = _Server()..one = _One.busy;
    final p = await phone(server, () => DateTime.utc(2026, 11, 21, 9));
    expect(p.dispatch.oneStreamBackup, isTrue);
    await p.dispatch.disconnect();
    p.config.dispose();
    server.one = _One.ok;
    final restarted = await phone(
      server,
      () => DateTime.utc(2026, 11, 21, 9, 1),
    );
    expect(restarted.dispatch.oneStreamBackup, isFalse);
    expect(restarted.dispatch.usesOneStream, isTrue);
    expect(server.open['/driver/stream'], 1);
    await restarted.dispatch.disconnect();
    restarted.config.dispose();
  });

  test('realtime.oneStreamFallback: values in range, else 3 / 10', () {
    expect(
      OneStreamFallback.fromJson(null),
      const OneStreamFallback(failuresInARow: 3, retryOneAfterMinutes: 10),
    );
    expect(
      OneStreamFallback.fromJson({
        'failuresInARow': 1,
        'retryOneAfterMinutes': 60,
      }),
      const OneStreamFallback(failuresInARow: 1, retryOneAfterMinutes: 60),
    );
    expect(
      OneStreamFallback.fromJson({
        'failuresInARow': 0,
        'retryOneAfterMinutes': 61,
      }),
      const OneStreamFallback(),
    );
    expect(
      OneStreamFallback.fromJson({
        'failuresInARow': 2.5,
        'retryOneAfterMinutes': '5',
      }),
      const OneStreamFallback(),
    );
    expect(OneStreamFallback.fromJson('x'), const OneStreamFallback());
  });
}
