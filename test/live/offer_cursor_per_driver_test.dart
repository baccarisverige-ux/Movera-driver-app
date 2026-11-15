import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/today_earnings.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, staging 2026-11-15 14:30–14:53 UTC (Rules
/// audits/impact/deploy-dispatch-stall.md §3): driver A signed out and
/// driver B signed in on the same phone. The offer feed kept A's cursor;
/// offer sequences are per driver and B's were lower, so every live offer
/// event of B (Exclusive, Radar, the admin's hand-sent ones) was dropped
/// until the app came back to the front.
Map<String, dynamic> _offer(int sequence, {String payment = 'card'}) => {
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
    'paymentMethod': payment,
    'pickupEtaSeconds': 180,
    'pickupMeters': 900,
    'tripSeconds': 720,
    'tripMeters': 5200,
  },
};

List<int> _event(int sequence) =>
    utf8.encode('id: $sequence\ndata: ${jsonEncode(_offer(sequence))}\n\n');

/// An access token as movera-server signs it: a JWT whose `sub` is the
/// driver id (src/auth/service.ts `signAccessToken({ sub: subjectId … })`).
String _jwt(String driverId, {int issue = 1}) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  // `zones` puts the base64url letters `-` and `_` in the token.
  final payload = part({
    'sub': driverId,
    'actor': 'driver',
    'iat': issue,
    'zones': ['>>>', '???'],
  });
  assert(payload.contains('-') && payload.contains('_'));
  return '${part({'alg': 'HS256'})}.$payload.sig';
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

  http.Client server() {
    feedsAsked = [];
    feeds = [];
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
        return json({'onlineStatus': body['onlineStatus'], 'version': 4});
      }
      if (path.endsWith('/driver/offers')) return json({'items': []});
      return json({});
    });
  }

  ApiDispatchRepository repo(http.Client client, String? Function() token) =>
      ApiDispatchRepository(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.invalid/api/v1'),
        accessToken: () async => token(),
        reconnectDelay: (_) => Duration.zero,
      );

  Future<List<String>> shown(ApiDispatchRepository dispatch) async => [
    for (final offer in await dispatch.watchNearbyOffers().first) offer.id,
  ];

  group('the offer feed cursor belongs to one driver', () {
    test('driver A at 600 signs out, driver B signs in at 50: the feed '
        'opens without A\'s cursor and B\'s offer 51 shows', () async {
      final client = server();
      // Tokens that say nothing about the driver: only the sign-out
      // itself can reset the feed here.
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

      // Driver A, online, his feed at sequence 600.
      expect(await live.presence.goOnline(), isNull);
      await pumpEventQueue();
      feeds.last.add(_event(600));
      await pumpEventQueue();
      expect(live.dispatch.lastSequence, 600);
      expect(await shown(live.dispatch), ['o600']);

      // Sign out (main.dart `_logout`: offline first, then the session).
      await live.presence.goOffline();
      live.signedOut();
      expect(await shown(live.dispatch), isEmpty);

      // Driver B signs in on the same phone and goes online.
      await tokens.save(access: 'b1', refresh: 'r2');
      live.signedIn();
      expect(await live.presence.goOnline(), isNull);
      await pumpEventQueue();
      expect(feedsAsked, hasLength(2));

      // The server says where B's feed starts, then makes his offer.
      feeds.last.add(utf8.encode('id: 50\n\n'));
      feeds.last.add(_event(51));
      await pumpEventQueue();
      expect(await shown(live.dispatch), ['o51']);
      expect(live.dispatch.lastSequence, 51);
      expect(feedsAsked.last.url.queryParameters, isNot(contains('after')));
      expect(feedsAsked.last.headers, isNot(contains('Last-Event-ID')));
    });

    test('no sign-out at all (the session was refused, the app only got '
        'a new token): another driver\'s token drops the cursor and the '
        'offers', () async {
      var token = _jwt('drv_A');
      final dispatch = repo(server(), () => token);
      addTearDown(dispatch.dispose);
      await dispatch.connect();
      await pumpEventQueue();
      feeds.last.add(_event(600));
      await pumpEventQueue();
      expect(await shown(dispatch), ['o600']);

      // Driver B's session, with nothing telling the feed.
      token = _jwt('drv_B');
      await dispatch.connect();
      await pumpEventQueue();
      expect(feedsAsked.last.url.queryParameters, isNot(contains('after')));
      expect(feedsAsked.last.headers, isNot(contains('Last-Event-ID')));
      expect(await shown(dispatch), isEmpty, reason: 'A\'s offer is not B\'s');
      feeds.last.add(utf8.encode('id: 50\n\n'));
      feeds.last.add(_event(51));
      await pumpEventQueue();
      expect(await shown(dispatch), ['o51']);
    });

    test('the same driver with a renewed token keeps his cursor', () async {
      var token = _jwt('drv_A');
      final dispatch = repo(server(), () => token);
      addTearDown(dispatch.dispose);
      await dispatch.connect();
      await pumpEventQueue();
      feeds.last.add(_event(600));
      await pumpEventQueue();

      token = _jwt('drv_A', issue: 2);
      await dispatch.connect();
      await pumpEventQueue();
      expect(feedsAsked.last.url.queryParameters['after'], '600');
      expect(feedsAsked.last.headers['Last-Event-ID'], '600');
      expect(await shown(dispatch), ['o600']);
    });

    test('a killed app: the cursor is kept nowhere on the phone, so the '
        'next start opens the feed without one', () async {
      SharedPreferences.setMockInitialValues({});
      final client = server();
      final before = repo(client, () => _jwt('drv_A'));
      await before.connect();
      await pumpEventQueue();
      feeds.last.add(_event(600));
      await pumpEventQueue();
      expect(before.lastSequence, 600);
      // Killed: nothing is closed or signed out.
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);

      final after = repo(client, () => _jwt('drv_B'));
      addTearDown(before.dispose);
      addTearDown(after.dispose);
      await after.connect();
      await pumpEventQueue();
      expect(feedsAsked.last.url.queryParameters, isNot(contains('after')));
      feeds.last.add(utf8.encode('id: 50\n\n'));
      feeds.last.add(_event(51));
      await pumpEventQueue();
      expect(await shown(after), ['o51']);
    });
  });

  group('other per-driver state the sign-out lets go', () {
    LiveDriverServices services() {
      final client = server();
      final tokens = MemoryTokenStore();
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
      return live;
    }

    test('Cash rides off (driver A\'s switch) does not hide the next '
        'driver\'s cash offers', () {
      addTearDown(DriverOfferPreferences.reset);
      DriverOfferPreferences.acceptsCash.value = false;
      services().signedOut();
      expect(DriverOfferPreferences.acceptsCash.value, isTrue);
    });

    test('TODAY on the island does not keep driver A\'s earnings', () async {
      addTearDown(TodayEarnings.reset);
      await TodayEarnings.refresh(read: () async => const []);
      expect(TodayEarnings.label.value, isNotNull);
      services().signedOut();
      expect(TodayEarnings.label.value, isNull);
    });
  });
}
