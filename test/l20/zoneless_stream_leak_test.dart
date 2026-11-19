import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/one_stream.dart';

/// L20 fix (Test Lab run 44513034674): right after sign-in the settings
/// stream opens without a zone (`GET /driver/config/stream`, slow answer);
/// the zone becomes known while it waits and the zoned one opens. The
/// zone-less answer that arrived during the zone's read was kept and then
/// overwritten (never closed), so the phone held one extra connection, also
/// after the one stream took the settings over.
class _Server {
  _Server(this.oneStream);
  final bool oneStream;
  final open = <String, int>{};
  final zonelessGate = Completer<void>();
  final zonedReadGate = Completer<void>();

  http.Client client() => MockClient.streaming((request, _) async {
    final path = request.url.path;
    final zone = request.url.queryParameters['zoneId'];
    http.StreamedResponse json(Object body) =>
        http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200);
    for (final s in [
      '/driver/stream',
      '/driver/offers/stream',
      '/driver/config/stream',
    ]) {
      if (path.endsWith(s)) {
        if (s == '/driver/config/stream' && zone == null) {
          await zonelessGate.future;
        }
        final feed = StreamController<List<int>>(
          onListen: () => open[s] = (open[s] ?? 0) + 1,
          onCancel: () => open[s] = (open[s] ?? 1) - 1,
        );
        return http.StreamedResponse(feed.stream, 200);
      }
    }
    if (path.endsWith('/driver/config')) {
      if (zone != null) await zonedReadGate.future;
      return json({
        'version': 5,
        'zoneId': zone ?? 'Z001',
        'currency': 'SEK',
        'timeZone': 'Europe/Stockholm',
        'realtime': {'oneStream': oneStream},
      });
    }
    if (path.endsWith('/driver/offers')) return json({'items': []});
    return json({});
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<Map<String, int>> _run(bool oneStream) async {
  final server = _Server(oneStream);
  final base = Uri.parse('https://api.test.movera.invalid/api/v1');
  String? zone;
  final client = server.client();
  final dispatch = ApiDispatchRepository(
    client: client,
    baseUri: base,
    accessToken: () async => 'token-1',
    reconnectDelay: (_) => Duration.zero,
  );
  final config = LiveDriverConfig(
    client: client,
    apiBase: base,
    accessToken: () async => 'token-1',
    cache: MemoryDriverConfigCache(),
    zoneId: () => zone,
  );
  linkOneStream(dispatch: dispatch, config: config);
  await config.start();
  unawaited(config.watch()); // zone-less stream: its answer waits
  await _settle();
  zone = 'Z001';
  final changed = config.zoneChanged(); // reads Z001 (waits)
  await _settle();
  server.zonelessGate.complete(); // the zone-less answer arrives now
  await _settle();
  server.zonedReadGate.complete();
  await changed;
  await _settle();
  await dispatch.connect(); // goes online
  await _settle();
  final result = {
    for (final e in server.open.entries)
      if (e.value != 0) e.key: e.value,
  };
  await dispatch.disconnect();
  config.dispose();
  return result;
}

void main() {
  test('one stream on: exactly one open connection (the one stream)', () async {
    expect(await _run(true), {'/driver/stream': 1});
  });

  test('one stream off: offers + one settings stream', () async {
    expect(await _run(false), {
      '/driver/offers/stream': 1,
      '/driver/config/stream': 1,
    });
  });

  test(
    'offer feed: a stale 200 answer is closed at once, never drained',
    () async {
      final gate = Completer<void>();
      var open = 0;
      final client = MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/driver/offers/stream')) {
          await gate.future;
          final feed = StreamController<List<int>>(
            onListen: () => open++,
            onCancel: () => open--,
          );
          return http.StreamedResponse(feed.stream, 200);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'items': []}))),
          200,
        );
      });
      final dispatch = ApiDispatchRepository(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.invalid/api/v1'),
        accessToken: () async => 'token-1',
        reconnectDelay: (_) => const Duration(hours: 1),
      );
      unawaited(dispatch.connect());
      await _settle();
      await dispatch.disconnect(); // the waiting answer is now stale
      gate.complete();
      await _settle();
      expect(open, 0, reason: 'the stale event stream must not stay open');
    },
  );
}
