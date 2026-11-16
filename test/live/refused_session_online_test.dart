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
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';

/// Follow-ups to the offer-feed cursor fix (Rules
/// audits/impact/driver-offer-cursor-supervisor.md N1 and N3).
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
    'expiresAt': '2026-11-15T14:30:26Z',
    'fare': {'amountMinor': 4717, 'currency': 'SEK'},
    'source': 'system',
    'pickup': {'address': 'Södertälje centrum', 'lat': 59.1955, 'lng': 17.6253},
    'dropoff': {'address': 'Arlanda', 'lat': 59.6498, 'lng': 17.9238},
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

String _jwt(String driverId) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': driverId})}.sig';
}

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
  late List<http.BaseRequest> feedsAsked;
  late List<StreamController<List<int>>> feeds;
  late List<String> availability;

  http.Client server() {
    feedsAsked = [];
    feeds = [];
    availability = [];
    return MockClient.streaming((request, _) async {
      final path = request.url.path;
      http.StreamedResponse json(Object body) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        200,
        headers: {'content-type': 'application/json'},
      );
      if (path.endsWith('/driver/offers/stream')) {
        feedsAsked.add(request);
        final feed = StreamController<List<int>>();
        feeds.add(feed);
        return http.StreamedResponse(feed.stream, 200);
      }
      if (path.endsWith('/driver/profile')) {
        return json({'onlineStatus': 'offline', 'version': 3});
      }
      if (path.endsWith('/driver/availability')) {
        final body = jsonDecode((request as http.Request).body) as Map;
        availability.add('${body['onlineStatus']}');
        return json({'onlineStatus': body['onlineStatus'], 'version': 4});
      }
      if (path.endsWith('/driver/offers')) return json({'items': []});
      return json({});
    });
  }

  Future<List<String>> shown(ApiDispatchRepository dispatch) async => [
    for (final offer in await dispatch.watchNearbyOffers().first) offer.id,
  ];

  test('N1: a token that cannot be read for one connect is not "another '
      'driver": the same driver keeps his cursor and his offers', () async {
    String? token = _jwt('drv_A');
    final dispatch = ApiDispatchRepository(
      client: server(),
      baseUri: Uri.parse('https://api.test.movera.invalid/api/v1'),
      accessToken: () async => token,
      reconnectDelay: (_) => Duration.zero,
    );
    addTearDown(dispatch.dispose);
    await dispatch.connect();
    await pumpEventQueue();
    feeds.last.add(_event(600));
    await pumpEventQueue();
    expect(await shown(dispatch), ['o600']);

    // The phone's secure store failed once: no token for this connect.
    for (final unreadable in <String?>[null, 'not-a-jwt']) {
      token = unreadable;
      await dispatch.connect();
      await pumpEventQueue();
      expect(feedsAsked.last.url.queryParameters['after'], '600');
      expect(feedsAsked.last.headers['Last-Event-ID'], '600');
      expect(await shown(dispatch), ['o600']);
    }

    // His token reads again: still his cursor.
    token = _jwt('drv_A');
    await dispatch.connect();
    await pumpEventQueue();
    expect(feedsAsked.last.url.queryParameters['after'], '600');
    expect(await shown(dispatch), ['o600']);

    // A readable token of another driver still lets go of both.
    token = _jwt('drv_B');
    await dispatch.connect();
    await pumpEventQueue();
    expect(feedsAsked.last.url.queryParameters, isNot(contains('after')));
    expect(await shown(dispatch), isEmpty);
  });

  test(
    'N3: a session refused while online leaves nothing online: the old '
    'feed is closed and the next driver\'s Go online opens his own',
    () async {
      final client = server();
      final tokens = MemoryTokenStore()
        ..save(access: _jwt('drv_A'), refresh: 'r1');
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
      final session = DriverSessionController(
        repository: MemoryDriverSessionRepository(),
      );
      addTearDown(session.dispose);
      live.attach(session);

      // Driver A is online with his feed open.
      expect(await live.presence.goOnline(), isNull);
      session.setOnline(true);
      await pumpEventQueue();
      expect(feedsAsked, hasLength(1));
      expect(feeds.single.hasListener, isTrue);

      // The server refuses his session (main.dart `_sessionExpired`): the
      // tokens are gone and nobody tapped Go offline.
      await tokens.clear();
      live.signedOut();
      await pumpEventQueue();
      expect(
        feeds.single.hasListener,
        isFalse,
        reason: 'driver A\'s feed must not stay open for the next driver',
      );
      expect(live.presence.serverOnline, isFalse);
      expect(session.isOnline, isFalse, reason: 'Home must not show online');
      expect(availability, ['online'], reason: 'no call without a session');

      // Driver B signs in and goes online: his own feed, at once.
      await tokens.save(access: _jwt('drv_B'), refresh: 'r2');
      live.signedIn();
      expect(await live.presence.goOnline(), isNull);
      await pumpEventQueue();
      expect(availability, ['online', 'online']);
      expect(feedsAsked, hasLength(2), reason: 'Go online opens a new feed');
      expect(feedsAsked.last.url.queryParameters, isNot(contains('after')));
      feeds.last.add(utf8.encode('id: 50\n\n'));
      feeds.last.add(_event(51));
      await pumpEventQueue();
      expect(await shown(live.dispatch), ['o51']);
    },
  );

  test('a session refused on a trip keeps the trip and its location', () async {
    final client = server();
    final tokens = MemoryTokenStore()
      ..save(access: _jwt('drv_A'), refresh: 'r1');
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
    final session = DriverSessionController(
      repository: MemoryDriverSessionRepository(),
    );
    addTearDown(session.dispose);
    live.attach(session);
    expect(await live.presence.goOnline(), isNull);
    session.setOnline(true);
    session.beginTrip('trip-1');
    await pumpEventQueue();

    live.signedOut();
    await pumpEventQueue();
    expect(session.activeTripId, 'trip-1');
    expect(session.availableAfterTrip, isTrue);
    expect(live.presence.serverOnline, isTrue);
  });
}
