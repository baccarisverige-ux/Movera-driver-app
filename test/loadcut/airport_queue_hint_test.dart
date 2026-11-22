// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_config.dart';

/// Contract v0.18.145 (`contract.json#loadCut.airportQueueLive`, S4c load
/// cut): the airport queue is read again on the settings stream's
/// `airport_queue_changed` hint and on every stream (re)connect, at most
/// once per 5 s; the timer is a 60 s fallback (was 20 s).
void main() {
  test('the fallback poll is 60 s and hints read at most every 5 s', () {
    expect(AirportQueue.every, const Duration(seconds: 60));
    expect(AirportQueue.hintGap, const Duration(seconds: 5));
  });

  test('a hint reads at once, a second one inside 5 s once at its end; '
      'between hints only the 60 s timer', () {
    fakeAsync((async) {
      var reads = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == AirportQueue.path) reads++;
          return http.Response(
            jsonEncode({'status': 'not_in_area'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      );
      final queue = AirportQueue();
      queue.hint();
      async.flushMicrotasks();
      expect(reads, 0, reason: 'no screen polls the queue: a hint is ignored');
      queue.startPolling(api);
      async.flushMicrotasks();
      expect(reads, 1, reason: 'the first read when polling starts');
      async.elapse(const Duration(seconds: 6));
      queue.hint();
      async.flushMicrotasks();
      expect(reads, 2);
      queue.hint();
      queue.hint();
      async.elapse(const Duration(seconds: 1));
      expect(reads, 2, reason: 'inside the 5 s gap');
      async.elapse(const Duration(seconds: 5));
      expect(reads, 3, reason: 'one read at the end of the gap');
      async.elapse(const Duration(seconds: 30));
      expect(reads, 3, reason: 'no 20 s poll any more');
      async.elapse(const Duration(seconds: 20));
      expect(reads, 4, reason: 'the 60 s fallback');
      queue.stopPolling();
      queue.hint();
      async.elapse(const Duration(seconds: 120));
      expect(reads, 4);
    });
  });

  test('the settings stream: airport_queue_changed and every stream open '
      'ask for a read', () async {
    var asked = 0;
    final events = StreamController<List<int>>();
    final opened = Completer<void>();
    final config = LiveDriverConfig(
      client: MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/stream')) {
          if (!opened.isCompleted) opened.complete();
          return http.StreamedResponse(events.stream, 200);
        }
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
      }),
      apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
      onAirportQueueChanged: () => asked++,
    );
    await config.watch();
    await opened.future;
    await Future<void>.delayed(Duration.zero);
    expect(asked, 1, reason: 'the stream opened: read once');
    events.add(
      utf8.encode(
        'data: {"eventId":"e1","kind":"airport_queue_changed",'
        '"areaId":"AQ-ARN","occurredAt":"x","serverTime":"y"}\n\n',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(asked, 2);
    // The L20 one stream hands its settings events over the same way.
    config.deliver({'kind': 'airport_queue_changed', 'areaId': 'AQ-ARN'});
    config.oneStreamOpened();
    expect(asked, 4);
    config.dispose();
    await events.close();
  });
}
