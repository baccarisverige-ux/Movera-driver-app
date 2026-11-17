import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/one_stream.dart';

/// L20 stream (contract v0.18.122, contract.json#driverOneStream; owner
/// 2026-11-17 "Yes, with switch (Rec.)", Rules audits/load/l20-1-design.md
/// §3): with DriverAppConfig.realtime.oneStream on, an online driver phone
/// holds ONE live connection, GET /driver/stream, whose events go to the
/// offer list (by sequence) and to the settings (by kind); off, or a 404
/// from an older server: the two streams as before.
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
    'expiresAt': '2099-11-17T08:00:26Z',
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

class _Server {
  _Server({
    required this.oneStream,
    this.oneStreamStatus = 200,
    this.errorReason,
  });
  bool oneStream;
  int oneStreamStatus;
  final String? errorReason;
  int version = 5;
  int configReads = 0;
  final asked = <http.BaseRequest>[];
  final open = <String, int>{};
  final feeds = <String, List<StreamController<List<int>>>>{};

  int get openStreams => open.values.fold(0, (a, b) => a + b);

  http.Client client() => MockClient.streaming((request, _) async {
    final path = request.url.path;
    http.StreamedResponse json(Object body) =>
        http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200);
    for (final stream in [
      '/driver/stream',
      '/driver/offers/stream',
      '/driver/config/stream',
    ]) {
      if (path.endsWith(stream)) {
        asked.add(request);
        if (stream == '/driver/stream' && oneStreamStatus != 200) {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'code': 'not_found',
                  if (errorReason != null) 'reason': errorReason,
                }),
              ),
            ),
            oneStreamStatus,
          );
        }
        late StreamController<List<int>> feed;
        feed = StreamController<List<int>>(
          onListen: () => open[stream] = (open[stream] ?? 0) + 1,
          onCancel: () => open[stream] = (open[stream] ?? 1) - 1,
        );
        (feeds[stream] ??= []).add(feed);
        return http.StreamedResponse(feed.stream, 200);
      }
    }
    if (path.endsWith('/driver/config')) {
      configReads++;
      return json({
        'version': version,
        'zoneId': request.url.queryParameters['zoneId'] ?? 'Z001',
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
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final base = Uri.parse('https://api.test.movera.invalid/api/v1');

  Future<({ApiDispatchRepository dispatch, LiveDriverConfig config})> phone(
    _Server server, {
    Duration retry = Duration.zero,
    String? Function()? zoneOf,
  }) async {
    String? zone() => zoneOf == null ? 'Z001' : zoneOf();
    final client = server.client();
    final dispatch = ApiDispatchRepository(
      client: client,
      baseUri: base,
      accessToken: () async => 'token-1',
      reconnectDelay: (_) => retry,
    );
    final config = LiveDriverConfig(
      client: client,
      apiBase: base,
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
      zoneId: zone,
    );
    linkOneStream(dispatch: dispatch, config: config);
    await config.start();
    await config.watch();
    await dispatch.connect();
    await _settle();
    return (dispatch: dispatch, config: config);
  }

  test('switch off: the two streams as before (offers + settings)', () async {
    final server = _Server(oneStream: false);
    final p = await phone(server);
    expect(server.open, {
      '/driver/config/stream': 1,
      '/driver/offers/stream': 1,
    });
    expect(
      server.asked.where((r) => r.url.path.endsWith('/driver/stream')),
      isEmpty,
    );
    await p.dispatch.disconnect();
    p.config.dispose();
  });

  test(
    'switch on: one connection; its events reach the offer list and the settings; '
    'the id <offer sequence>.<config version> resumes both halves',
    () async {
      final server = _Server(oneStream: true);
      final p = await phone(server);
      expect(server.openStreams, 1, reason: '${server.open}');
      expect(server.open['/driver/stream'], 1);
      final first = server.asked.lastWhere(
        (r) => r.url.path.endsWith('/driver/stream'),
      );
      expect(first.url.queryParameters['zoneId'], 'Z001');
      expect(
        first.url.queryParameters['after'],
        isNull,
        reason: 'no cursor yet',
      );

      final feed = server.feeds['/driver/stream']!.last;
      feed.add(utf8.encode('id: 2.5\n\n'));
      feed.add(utf8.encode('id: 3.5\ndata: ${jsonEncode(_offer(3))}\n\n'));
      await _settle();
      expect(
        [for (final o in await p.dispatch.watchNearbyOffers().first) o.id],
        ['o3'],
      );

      server.version = 6;
      final reads = server.configReads;
      feed.add(
        utf8.encode(
          'id: 3.6\ndata: ${jsonEncode({'eventId': 'c1', 'kind': 'config_published', 'doc': 'driver_app_config', 'zoneId': 'Z001', 'version': 6})}\n\n',
        ),
      );
      await _settle();
      expect(
        server.configReads,
        greaterThan(reads),
        reason: 'config_published reads the document',
      );
      expect(p.config.current?.version, 6);

      // A dropped connection reconnects with both halves.
      await feed.close();
      await _settle();
      final again = server.asked.lastWhere(
        (r) => r.url.path.endsWith('/driver/stream'),
      );
      expect(again, isNot(same(first)));
      expect(again.url.queryParameters['after'], '3.6');
      expect(again.headers['Last-Event-ID'], '3.6');
      expect(server.openStreams, 1, reason: '${server.open}');
      await p.dispatch.disconnect();
      await _settle();
      // Offline: the settings keep their own single stream.
      expect(server.open['/driver/stream'], 0);
      expect(server.open['/driver/config/stream'], 1);
      p.config.dispose();
    },
  );

  test(
    'switch on but the server answers 404 (older server): the two streams',
    () async {
      final server = _Server(oneStream: true, oneStreamStatus: 404);
      final p = await phone(server);
      expect(server.open, {
        '/driver/config/stream': 1,
        '/driver/offers/stream': 1,
      });
      // It is not asked again while the app runs.
      final tries = server.asked
          .where((r) => r.url.path.endsWith('/driver/stream'))
          .length;
      await p.dispatch.disconnect();
      await p.dispatch.connect();
      await _settle();
      expect(
        server.asked.where((r) => r.url.path.endsWith('/driver/stream')).length,
        tries,
      );
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test(
    'the switch turned off in a settings update: back to the two streams',
    () async {
      final server = _Server(oneStream: true);
      final p = await phone(server);
      expect(server.open['/driver/stream'], 1);
      server
        ..oneStream = false
        ..version = 7;
      await p.config.refresh();
      await _settle();
      expect(server.open['/driver/stream'], 0);
      expect(server.open['/driver/config/stream'], 1);
      expect(server.open['/driver/offers/stream'], 1);
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );
  test('switch on while offline opens no offer feed (MF-1)', () async {
    final server = _Server(oneStream: false);
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
      zoneId: () => 'Z001',
    );
    linkOneStream(dispatch: dispatch, config: config);
    await config.start();
    await config.watch();
    await _settle();
    server
      ..oneStream = true
      ..version = 8;
    await config.refresh();
    await _settle();
    expect(
      server.asked.where(
        (r) =>
            r.url.path.endsWith('/driver/stream') ||
            r.url.path.endsWith('/driver/offers/stream'),
      ),
      isEmpty,
    );
    expect(server.open['/driver/config/stream'], 1);
    config.dispose();
  });

  test(
    '404 zone_not_found opens the two old streams this time only (MF-2)',
    () async {
      // The real server's shape: code not_found, reason zone_not_found.
      final server = _Server(
        oneStream: true,
        oneStreamStatus: 404,
        errorReason: 'zone_not_found',
      );
      final p = await phone(server, retry: const Duration(hours: 1));
      expect(
        server.asked.where((r) => r.url.path.endsWith('/driver/stream')),
        isNotEmpty,
      );
      // Offers keep flowing on the old stream; the one stream is not
      // marked as missing.
      expect(server.open['/driver/offers/stream'], 1);
      expect(p.dispatch.oneStreamRefused, isFalse);
      server.oneStreamStatus = 200;
      await p.dispatch.disconnect();
      await p.dispatch.connect();
      await _settle();
      expect(server.open['/driver/stream'], 1);
      await p.dispatch.disconnect();
      p.config.dispose();
    },
  );

  test('zone fallback (404 zone_not_found): the settings keep their own stream '
      'and still take config_published (supervisor gap 1)', () async {
    final server = _Server(
      oneStream: true,
      oneStreamStatus: 404,
      errorReason: 'zone_not_found',
    );
    final p = await phone(server, retry: const Duration(hours: 1));
    expect(server.open['/driver/config/stream'], 1, reason: '${server.open}');
    expect(server.open['/driver/stream'] ?? 0, 0);
    expect(p.config.onOneStream, isFalse);
    server.version = 9;
    final reads = server.configReads;
    server.feeds['/driver/config/stream']!.last.add(
      utf8.encode(
        'data: ${jsonEncode({'eventId': 'c9', 'kind': 'config_published', 'doc': 'driver_app_config', 'zoneId': 'Z001', 'version': 9})}\n\n',
      ),
    );
    await _settle();
    expect(server.configReads, greaterThan(reads));
    expect(p.config.current?.version, 9);
    await p.dispatch.disconnect();
    p.config.dispose();
  });

  test('zone change on the one stream: it opens again naming the new zone, '
      'still one connection (supervisor gap 2)', () async {
    final server = _Server(oneStream: true);
    var zone = 'Z001';
    final p = await phone(server, zoneOf: () => zone);
    expect(server.open['/driver/stream'], 1);
    final first = server.asked.lastWhere(
      (r) => r.url.path.endsWith('/driver/stream'),
    );
    expect(first.url.queryParameters['zoneId'], 'Z001');
    zone = 'Z002';
    await p.config.zoneChanged();
    await _settle();
    final again = server.asked.lastWhere(
      (r) => r.url.path.endsWith('/driver/stream'),
    );
    expect(again, isNot(same(first)));
    expect(again.url.queryParameters['zoneId'], 'Z002');
    expect(server.openStreams, 1, reason: '${server.open}');
    expect(server.open['/driver/config/stream'] ?? 0, 0);
    expect(p.config.onOneStream, isTrue);
    await p.dispatch.disconnect();
    p.config.dispose();
  });
}
