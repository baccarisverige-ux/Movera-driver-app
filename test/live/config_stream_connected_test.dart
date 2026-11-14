// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/live/live_driver_config.dart';

/// Driver stream rule (owner 2026-11-13 12:23 UTC "Yes, update rule
/// (Rec.)", same sentence as the rider R3; contract v0.18.83
/// `realtime.connectedRule`), the settings stream GET /driver/config/stream:
/// a stream counts as connected only after it delivered an event or stayed
/// up 30 s; a 200 alone is not connected. Only a connected stream resets
/// the reconnect backoff (5 → 10 → 20 → 40 → 60 s, owner 2026-11-10), so a
/// stream the busy server opens and drops at once keeps backing off and
/// never storms the server. A 429 / 503 Retry-After is honoured (at most
/// 60 s). The offer feed and the trip stream follow it since #578.
void main() {
  final base = Uri.parse('https://api.movera.invalid/api/v1');
  final t0 = DateTime.utc(2026, 11, 13, 12);

  Map<String, dynamic> document() => {
    'version': 4,
    'zoneId': 'Z001',
    'currency': 'SEK',
    'timeZone': 'Europe/Stockholm',
  };

  ({LiveDriverConfig config, List<Duration> opens}) build(
    FakeAsync async,
    http.StreamedResponse Function(int open) stream,
  ) {
    final opens = <Duration>[];
    final config = LiveDriverConfig(
      client: MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/stream')) {
          opens.add(async.elapsed);
          return stream(opens.length);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(document()))),
          200,
        );
      }),
      apiBase: base,
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
      random: math.Random(7),
      now: () => t0.add(async.elapsed),
    );
    return (config: config, opens: opens);
  }

  List<double> gaps(List<Duration> opens) => [
    for (var i = 1; i < opens.length; i++)
      (opens[i] - opens[i - 1]).inMilliseconds / 1000,
  ];

  void near(double gap, int seconds) {
    expect(gap, greaterThanOrEqualTo(seconds * 0.9));
    expect(gap, lessThanOrEqualTo(seconds * 1.1));
  }

  http.StreamedResponse dropAtOnce() =>
      http.StreamedResponse(const Stream.empty(), 200);

  test('open-then-drop: a 200 the server closes at once is not connected; '
      'the backoff keeps growing (no 5 s storm)', () {
    fakeAsync((async) {
      final r = build(async, (_) => dropAtOnce());
      unawaited(r.config.watch());
      async.elapse(const Duration(minutes: 3));
      final g = gaps(r.opens);
      // Before: a reconnect every 5 s for 3 minutes (~36 opens).
      expect(r.opens.length, lessThanOrEqualTo(8));
      const expected = [5, 10, 20, 40, 60];
      for (var i = 0; i < expected.length; i++) {
        near(g[i], expected[i]);
      }
      r.config.dispose();
    });
  });

  test('an event makes the stream connected: after its close the next '
      'wait is 5 s again', () {
    fakeAsync((async) {
      final r = build(async, (open) {
        // Opens 1-3 drop at once (5, 10, 20 s); open 4 delivers an event.
        if (open != 4) return dropAtOnce();
        return http.StreamedResponse(
          Stream.value(
            utf8.encode('data: {"kind":"driver_reservations_changed"}\n\n'),
          ),
          200,
        );
      });
      unawaited(r.config.watch());
      async.elapse(const Duration(seconds: 45));
      expect(r.opens.length, 5);
      final g = gaps(r.opens);
      near(g[0], 5);
      near(g[1], 10);
      near(g[2], 20);
      near(g[3], 5);
      r.config.dispose();
    });
  });

  test('30 s up counts as connected (next wait 5 s); 29 s does not', () {
    for (final (upFor, wait) in [(30, 5), (29, 40)]) {
      fakeAsync((async) {
        final r = build(async, (open) {
          if (open != 4) return dropAtOnce();
          // Open 4 stays up with a heartbeat only (no event), then closes.
          final body = StreamController<List<int>>();
          Timer(
            const Duration(seconds: 15),
            () => body.add(utf8.encode(': heartbeat\n')),
          );
          Timer(Duration(seconds: upFor), body.close);
          return http.StreamedResponse(body.stream, 200);
        });
        unawaited(r.config.watch());
        async.elapse(Duration(seconds: 35 + upFor + wait + 2));
        final g = gaps(r.opens);
        expect(g.length, greaterThanOrEqualTo(4), reason: 'up $upFor s');
        near(g[3] - upFor, wait);
        r.config.dispose();
      });
    }
  });

  test('a 503 with Retry-After 40 is not asked again sooner; over 60 s '
      'waits 60 s', () {
    for (final (header, wait) in [('40', 40), ('300', 60)]) {
      fakeAsync((async) {
        final r = build(
          async,
          (_) => http.StreamedResponse(
            Stream.value(utf8.encode('{"code":"server_busy"}')),
            503,
            headers: {'retry-after': header},
          ),
        );
        unawaited(r.config.watch());
        async.elapse(Duration(seconds: wait - 1));
        expect(r.opens.length, 1, reason: 'Retry-After $header');
        async.elapse(const Duration(seconds: 8));
        expect(r.opens.length, 2, reason: 'Retry-After $header');
        r.config.dispose();
      });
    }
  });
}
