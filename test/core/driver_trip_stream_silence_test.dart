// Finder D2 (2026-11-07), fail-before test: the driver's trip event stream
// (GET /trips/{id}/events) has no silence watchdog. The server sends
// ": heartbeat" every 15 s (movera-server src/realtime/sse.ts HEARTBEAT_MS),
// the offer feed closes a feed silent for 45 s (api_dispatch_repository.dart
// feedIdleTimeout) and the rider's trip stream has one too
// (api_ride_realtime.dart streamSilenceLimit). A half-open trip stream (iPhone
// locked / network change) stays "open" for ever, and the resume resync
// (accept_ride.dart didChangeAppLifecycleState -> _resyncTrip ->
// reconnectAndResync) returns at once while `_open` is true.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/live/api_driver_realtime.dart';

class _SilentStreamClient extends http.BaseClient {
  int requests = 0;
  final List<StreamController<List<int>>> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    // A stream that opened (200, event-stream) and then went silent without
    // closing: what a half-open socket looks like to the app.
    final body = StreamController<List<int>>();
    bodies.add(body);
    return http.StreamedResponse(
      body.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}

void main() {
  test('a trip stream silent for 2 minutes is opened again', () {
    fakeAsync((async) {
      final client = _SilentStreamClient();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      expect(client.requests, 1);
      expect(realtime.connected, isTrue);

      // 2 minutes with not even a heartbeat (server sends one every 15 s).
      async.elapse(const Duration(minutes: 2));
      expect(
        client.requests,
        greaterThan(1),
        reason: 'no silence watchdog: the dead stream is kept as "open"',
      );
      realtime.dispose();
    });
  });

  test('resume resync re-opens a stream that went silent', () {
    fakeAsync((async) {
      final client = _SilentStreamClient();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      // What accept_ride.dart does on AppLifecycleState.resumed.
      unawaited(realtime.reconnectAndResync('trp_1'));
      async.flushMicrotasks();
      expect(
        client.requests,
        greaterThan(1),
        reason: 'reconnectAndResync returns at once while _open is true',
      );
      realtime.dispose();
    });
  });

  test('a heartbeat keeps the stream open (no reconnect)', () {
    fakeAsync((async) {
      final client = _SilentStreamClient();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      for (var i = 0; i < 8; i++) {
        client.bodies.single.add(': heartbeat\n\n'.codeUnits);
        async.elapse(const Duration(seconds: 15));
      }
      expect(client.requests, 1);
      expect(realtime.connected, isTrue);
      realtime.dispose();
    });
  });

  test('resume resync re-opens a stream silent past the limit even when '
      'the watchdog timer has not run yet (timers paused while locked)', () {
    fakeAsync((async) {
      var now = DateTime.utc(2026, 11, 7, 12);
      final client = _SilentStreamClient();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
        now: () => now,
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      // The phone was locked: the wall clock moved, the app's timers not.
      now = now.add(const Duration(minutes: 2));
      expect(realtime.connected, isTrue);
      unawaited(realtime.reconnectAndResync('trp_1'));
      async.flushMicrotasks();
      expect(client.requests, 2);
      realtime.dispose();
    });
  });

  test('resume resync keeps a stream that is alive', () {
    fakeAsync((async) {
      final client = _SilentStreamClient();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      unawaited(realtime.reconnectAndResync('trp_1'));
      async.flushMicrotasks();
      expect(client.requests, 1);
      realtime.dispose();
    });
  });
}
