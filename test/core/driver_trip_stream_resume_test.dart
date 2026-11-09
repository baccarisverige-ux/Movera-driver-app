// S6 I-2 (2026-11-07): after a short background (< 45 s) the trip screen
// trusted a half-open stream: reconnectAndResync returned while `_open`
// was true, so a status the server sent meanwhile reached the screen only
// when the 45 s watchdog fired (S6 X2: 22 s after resume).
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/live/api_driver_realtime.dart';

class _Client extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<StreamController<List<int>>> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
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
  test('back from hidden: an open stream is opened again after the last '
      'sequence', () {
    fakeAsync((async) {
      final client = _Client();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      realtime.ingest({
        'tripId': 'trp_1',
        'sequence': 7,
        'version': 7,
        'kind': 'location',
      });
      async.elapse(const Duration(seconds: 5));
      expect(realtime.connected, isTrue);
      unawaited(realtime.reconnectAndResync('trp_1', reopen: true));
      async.flushMicrotasks();
      expect(client.requests, hasLength(2));
      expect(client.requests.last.url.queryParameters['after'], '7');
      expect(client.requests.last.headers['Last-Event-ID'], '7');
      realtime.dispose();
    });
  });

  test('a gap resync (no reopen) still keeps a stream that is alive', () {
    fakeAsync((async) {
      final client = _Client();
      final realtime = ApiDriverRealtime(
        client: client,
        apiBase: Uri.parse('https://api.example.test/api/v1'),
        accessToken: () async => 'token',
      );
      realtime.subscribe('trp_1').listen((_) {});
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      unawaited(realtime.reconnectAndResync('trp_1'));
      async.flushMicrotasks();
      expect(client.requests, hasLength(1));
      realtime.dispose();
    });
  });
}
