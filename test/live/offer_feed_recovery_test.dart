import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// Owner, live test 2026-10-26: "Why driver don't receive rider offers
/// anymore?" Reproduced against the server: when the offer feed went quiet
/// without closing (what a locked or sleeping iPhone leaves behind), the
/// server kept making offers and the app showed none of them; nothing
/// noticed or reopened the feed, not even coming back to the app.
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
    'expiresAt': '2026-10-26T12:00:15Z',
    'fare': {'amountMinor': 4717, 'currency': 'SEK'},
    'source': 'system',
    'pickup': {'address': 'Södertälje centrum', 'lat': 59.1955, 'lng': 17.6253},
    'dropoff': {'address': 'Södertälje syd', 'lat': 59.1622, 'lng': 17.6461},
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'pickupEtaSeconds': 180,
    'pickupMeters': 900,
    'tripSeconds': 720,
    'tripMeters': 5200,
  },
};

List<int> _event(int sequence) =>
    utf8.encode('id: $sequence\ndata: ${jsonEncode(_offer(sequence))}\n\n');

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => const DriverLocation(
    point: GeoPoint(59.1955, 17.6253),
    accuracyMeters: 8,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

void main() {
  group('a feed that goes quiet without closing', () {
    late List<http.BaseRequest> requests;
    late List<StreamController<List<int>>> feeds;

    /// GET /driver/offers: the offers the server still has open.
    late List<Object> open;

    ApiDispatchRepository repo() {
      requests = [];
      feeds = [];
      open = [];
      return ApiDispatchRepository(
        client: MockClient.streaming((request, _) async {
          // 03c: a reconnect also reloads the open offers (none new here);
          // only the feed's own requests are counted.
          if (request.url.path.endsWith('/driver/offers')) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(jsonEncode({'items': open, 'nextCursor': null})),
              ),
              200,
            );
          }
          requests.add(request);
          final feed = StreamController<List<int>>();
          feeds.add(feed);
          return http.StreamedResponse(feed.stream, 200);
        }),
        baseUri: Uri.parse('https://api.test.movera.invalid/api/v1'),
        accessToken: () async => 'token',
        reconnectDelay: (_) => Duration.zero,
        feedIdleTimeout: const Duration(milliseconds: 300),
      );
    }

    test('is opened again from its last sequence; the server heartbeat '
        'keeps a healthy feed open', () async {
      final dispatch = repo();
      addTearDown(dispatch.dispose);
      await dispatch.connect();
      await pumpEventQueue();
      expect(requests, hasLength(1));
      feeds.last.add(_event(1));
      open = [_offer(1)['offer'] as Object];
      await pumpEventQueue();
      expect((await dispatch.watchNearbyOffers().first).map((o) => o.id), [
        'o1',
      ]);

      // The server's `: heartbeat` every 100 ms: nothing reconnects.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        feeds.last.add(utf8.encode(': heartbeat\n\n'));
      }
      expect(requests, hasLength(1));
      expect(dispatch.feedLive, isTrue);

      // Then silence, the socket still open: it is given up and reopened.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters['after'], '1');
      expect(dispatch.feedLive, isTrue);

      // The new feed brings the offer the dead one never delivered.
      feeds.last.add(_event(2));
      await pumpEventQueue();
      expect(
        (await dispatch.watchNearbyOffers().first).map((o) => o.id),
        containsAll(['o1', 'o2']),
      );
    });

    test('after disconnect the quiet timer does not reopen it', () async {
      final dispatch = repo();
      addTearDown(dispatch.dispose);
      await dispatch.connect();
      await pumpEventQueue();
      await dispatch.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(requests, hasLength(1));
    });
  });

  test('back on screen while online: the feed is opened again, the open '
      'offers are read and a position goes out at once', () async {
    final seen = <String>[];
    final client = MockClient.streaming((request, _) async {
      final path = request.url.path;
      seen.add('${request.method} $path');
      http.StreamedResponse json(Object body) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        200,
        headers: {'content-type': 'application/json'},
      );
      if (path == '/api/v1/driver/offers/stream') {
        // Open and silent, like a feed waiting for the next offer.
        return http.StreamedResponse(StreamController<List<int>>().stream, 200);
      }
      if (path == '/api/v1/driver/profile') {
        return json({'onlineStatus': 'offline', 'version': 3});
      }
      if (path == '/api/v1/driver/availability') {
        return json({'onlineStatus': 'online', 'version': 4});
      }
      if (path == '/api/v1/driver/offers') return json({'items': []});
      return json({});
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.invalid'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.invalid'),
        tokens: tokens,
      ),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    addTearDown(live.dispose);

    // Offline: coming back on screen asks the server nothing.
    live.resumed();
    await pumpEventQueue();
    expect(seen, isEmpty);

    expect(await live.presence.goOnline(), isNull);
    await pumpEventQueue();
    int count(String call) => seen.where((s) => s == call).length;
    expect(count('GET /api/v1/driver/offers/stream'), 1);
    final offersBefore = count('GET /api/v1/driver/offers');
    final fixesBefore = count('POST /api/v1/driver/location');

    live.resumed();
    await pumpEventQueue();
    expect(count('GET /api/v1/driver/offers/stream'), 2);
    expect(count('GET /api/v1/driver/offers'), offersBefore + 1);
    expect(count('POST /api/v1/driver/location'), fixesBefore + 1);
  });
}
