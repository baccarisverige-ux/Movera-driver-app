// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/zones/driver_zone.dart';

/// Owner 2026-11-10 (step 62 request budgets): (a) the airport queue is
/// read only while online and in a queue or near an airport; (b) the
/// settings stream reconnects with backoff 5 → 10 → 20 → 40 → 60 s
/// (jitter ±10 %), back to 5 s after a successful connect.
void main() {
  const airport = DriverZone(
    id: 'ARN',
    kind: 'airport',
    polygon: [
      [59.64, 17.91],
      [59.64, 17.96],
      [59.66, 17.96],
      [59.66, 17.91],
    ],
  );
  const city = DriverZone(
    id: 'Z001',
    polygon: [
      [59.0, 17.5],
      [59.0, 18.5],
      [59.6, 18.5],
      [59.6, 17.5],
    ],
  );

  group('airport queue: only when it can matter', () {
    test('wanted: online and in a queue, or at / near an airport', () {
      const atArn = GeoPoint(59.65, 17.93);
      const nearArn = GeoPoint(59.63, 17.93); // ~1 km south of the outline
      const town = GeoPoint(59.33, 18.06);
      bool w({bool online = true, bool inQueue = false, GeoPoint? p}) =>
          AirportQueue.wanted(
            online: online,
            inQueue: inQueue,
            point: p,
            zones: const [city, airport],
          );
      expect(w(p: atArn), isTrue);
      expect(w(p: nearArn), isTrue);
      expect(w(p: town), isFalse);
      expect(w(), isFalse, reason: 'no fix yet');
      expect(w(inQueue: true, p: town), isTrue);
      expect(w(online: false, p: atArn), isFalse);
      expect(w(online: false, inQueue: true), isFalse);
      expect(
        AirportQueue.wanted(online: true, inQueue: false, point: atArn),
        isFalse,
        reason: 'zones not read yet',
      );
    });

    test('polling asks the server only while relevant (fake clock)', () {
      fakeAsync((async) {
        var reads = 0;
        final api = ApiClient(
          client: MockClient((_) async {
            reads++;
            return http.Response('{"status":"not_in_area"}', 200);
          }),
          baseUri: Uri.parse('https://api.movera.invalid'),
          tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
        );
        var relevant = false;
        final queue = AirportQueue();
        queue.startPolling(api, relevant: () => relevant);
        async.elapse(const Duration(minutes: 5));
        expect(reads, 0, reason: 'away from any airport: no reads');
        relevant = true;
        async.elapse(const Duration(minutes: 1));
        expect(reads, 3, reason: 'every 20 s near an airport');
        relevant = false;
        async.elapse(const Duration(minutes: 2));
        expect(reads, 3);
        expect(queue.status, isNull, reason: 'the old answer is dropped');
        queue.stopPolling();
      });
    });
  });

  test('settings stream: backoff 5 → 10 → 20 → 40 → 60 s, reset on a '
      'successful connect (fake clock)', () {
    fakeAsync((async) {
      final opens = <Duration>[];
      var refuse = true;
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            opens.add(async.elapsed);
            return refuse
                ? http.StreamedResponse(Stream.value(utf8.encode('{}')), 503)
                : http.StreamedResponse(const Stream.empty(), 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 'token-1',
        cache: MemoryDriverConfigCache(),
        random: math.Random(7),
      );
      unawaited(config.watch());
      async.elapse(const Duration(minutes: 4));
      final gaps = [
        for (var i = 1; i < opens.length; i++)
          (opens[i] - opens[i - 1]).inMilliseconds / 1000,
      ];
      const expected = [5, 10, 20, 40, 60, 60];
      for (var i = 0; i < expected.length; i++) {
        expect(
          gaps[i],
          greaterThanOrEqualTo(expected[i] == 5 ? 5 : expected[i] * 0.9),
        );
        expect(
          gaps[i],
          lessThanOrEqualTo(expected[i] == 60 ? 60 : expected[i] * 1.1),
        );
      }
      // The server is back: a connect that opens (then ends) resets the wait.
      refuse = false;
      async.elapse(const Duration(seconds: 61));
      final reset = opens.length;
      async.elapse(const Duration(seconds: 6));
      expect(opens.length, greaterThan(reset), reason: 'next wait is 5 s');
      config.dispose();
    });
  });
}
