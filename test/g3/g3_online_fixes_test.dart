import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/session/driver_session_controller.dart';

/// Driver 03c, bugs found on live after the group 3 merge (2026-10-30).
void main() {
  final origin = Uri.parse('https://api.test.movera.se');

  http.StreamedResponse json(int status, Object body) => http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    status,
    headers: {'content-type': 'application/json'},
  );

  late List<http.BaseRequest> requests;
  late List<String> availability;
  late StreamController<List<int>> feed;
  late String onlineStatus;
  late int version;

  /// movera-server as the live test saw it: the driver is offline, Go
  /// online is accepted, and the offer feed is open.
  Future<http.StreamedResponse> server(
    http.BaseRequest request,
    http.ByteStream body,
  ) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/v1/driver/profile') {
      return json(200, {
        'driverId': 'd1',
        'onlineStatus': onlineStatus,
        'version': version,
      });
    }
    if (path == '/api/v1/driver/availability') {
      final sent = jsonDecode(await body.bytesToString()) as Map;
      availability.add(sent['onlineStatus'] as String);
      onlineStatus = sent['onlineStatus'] as String;
      version++;
      return json(200, {
        'driverId': 'd1',
        'onlineStatus': onlineStatus,
        'version': version,
      });
    }
    if (path == '/api/v1/driver/offers/stream') {
      return http.StreamedResponse(feed.stream, 200);
    }
    if (path == '/api/v1/driver/offers') {
      return json(200, {'items': <Object>[], 'nextCursor': null});
    }
    return json(200, {'accepted': 1});
  }

  setUp(() {
    requests = [];
    availability = [];
    feed = StreamController<List<int>>();
    onlineStatus = 'offline';
    version = 4;
    DriverSetOfflineNotice.instance.clear();
    DriverAreaWatch.instance.reset();
  });

  // Not awaited: a feed nobody listened to never finishes closing.
  tearDown(() => unawaited(feed.close()));

  ({
    ApiDispatchRepository dispatch,
    LivePresence presence,
    LiveLocationReporter reporter,
    DriverSessionController session,
  })
  live({Future<Object?> Function()? locationBlock}) {
    final client = MockClient.streaming(server);
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final api = ApiClient(client: client, baseUri: origin, tokens: tokens);
    final dispatch = ApiDispatchRepository(
      client: client,
      baseUri: origin.replace(path: '/api/v1'),
      accessToken: tokens.readAccess,
      reconnectDelay: (_) => const Duration(hours: 1),
    );
    final reporter = LiveLocationReporter(
      api: api,
      location: _Gps(),
      every: const Duration(hours: 1),
    );
    final presence = LivePresence(
      api: api,
      dispatch: dispatch,
      reporter: reporter,
      locationBlock: locationBlock,
    );
    final session = DriverSessionController();
    // As LiveDriverServices.attach wires them.
    presence.attach(session);
    dispatch.onDriverOffline = LiveDriverServices.missedOffersOffline(session);
    return (
      dispatch: dispatch,
      presence: presence,
      reporter: reporter,
      session: session,
    );
  }

  void send(Map<String, Object?> event, {int? id}) => feed.add(
    utf8.encode(
      '${id == null ? '' : 'id: $id\n'}data: ${jsonEncode(event)}\n\n',
    ),
  );

  Map<String, Object?> missedRun({
    required int sequence,
    required DateTime occurredAt,
    required DateTime serverTime,
  }) => {
    'eventId': 'e$sequence',
    'sequence': sequence,
    'kind': 'offer_withdrawn',
    'occurredAt': occurredAt.toIso8601String(),
    'serverTime': serverTime.toIso8601String(),
    'offer': {'offerId': 'old$sequence', 'status': 'expired'},
    'driverOffline': true,
  };

  group('HIGH: the first Go online after a start is not undone', () {
    test('live test: the feed replays an old "set offline" (auto-offline '
        'from earlier) right after Go online; the driver stays online and '
        'the app sends no offline', () async {
      final app = live();
      app.session.beginGoingOnline();
      expect(await app.presence.goOnline(), isNull);
      app.session.completeGoingOnline();
      await pumpEventQueue();
      // The replay: the run of missed Exclusive offers that set the driver
      // offline three hours ago (same server clock as now).
      final now = DateTime.now().toUtc();
      send(
        missedRun(
          sequence: 41,
          occurredAt: now.subtract(const Duration(hours: 3)),
          serverTime: now,
        ),
        id: 41,
      );
      await pumpEventQueue();
      await pumpEventQueue();
      expect(app.session.isOnline, isTrue);
      expect(availability, ['online'], reason: 'no offline sent by the app');
      expect(onlineStatus, 'online');
      app.reporter.stop();
      await app.dispatch.dispose();
      app.session.dispose();
    });

    test('a phone clock hours off does not matter: the event\'s age is the '
        'server\'s own', () async {
      final app = live();
      app.session.beginGoingOnline();
      await app.presence.goOnline();
      app.session.completeGoingOnline();
      await pumpEventQueue();
      // The server's clock is a day ahead of the phone's.
      final serverNow = DateTime.now().toUtc().add(const Duration(days: 1));
      send(
        missedRun(
          sequence: 7,
          occurredAt: serverNow.subtract(const Duration(minutes: 20)),
          serverTime: serverNow,
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();
      expect(app.session.isOnline, isTrue);
      expect(availability, ['online']);
      app.reporter.stop();
      await app.dispatch.dispose();
      app.session.dispose();
    });

    test('a run of missed offers after Go online still sets the driver '
        'offline (contract §6.7)', () async {
      final app = live();
      app.session.beginGoingOnline();
      await app.presence.goOnline();
      app.session.completeGoingOnline();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final now = DateTime.now().toUtc();
      send(missedRun(sequence: 42, occurredAt: now, serverTime: now));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(app.session.isOnline, isFalse);
      expect(availability, ['online', 'offline']);
      // Owner 2026-10-31: the offline card says why.
      expect(DriverSetOfflineNotice.instance.value, isTrue);
      expect(
        DriverSetOfflineNotice.instance.reason,
        DriverOfflineReason.missedOffers,
      );
      app.reporter.stop();
      await app.dispatch.dispose();
      app.session.dispose();
    });

    test('the feed\'s cursor (an `id:` with no data) is kept: a reconnect '
        'goes on from it, not from 0', () async {
      final seen = <http.BaseRequest>[];
      final feeds = <StreamController<List<int>>>[];
      final repo = ApiDispatchRepository(
        client: MockClient.streaming((request, _) async {
          seen.add(request);
          final next = StreamController<List<int>>();
          feeds.add(next);
          return http.StreamedResponse(next.stream, 200);
        }),
        baseUri: origin.replace(path: '/api/v1'),
        accessToken: () async => 'token',
        reconnectDelay: (_) => Duration.zero,
      );
      await repo.connect();
      expect(seen.single.url.queryParameters, isNot(contains('after')));
      // movera-server: a feed opened without a cursor starts at the newest
      // event and says which one.
      feeds.single.add(utf8.encode(': stream open\n\nid: 812\n\n'));
      await pumpEventQueue();
      expect(repo.lastSequence, 812);
      await repo.connect();
      expect(seen.last.url.queryParameters['after'], '812');
      expect(seen.last.headers['Last-Event-ID'], '812');
      await repo.dispose();
      for (final f in feeds) {
        unawaited(f.close());
      }
    });
  });

  group('03c fixes: no offer is lost around Go online or a network loss', () {
    final offer = {
      'offerId': 'gap1',
      'tripId': 'trip-gap1',
      'kind': 'exclusive',
      'status': 'open',
      'version': 1,
      'expiresAt': '2026-10-30T12:00:15Z',
      'fare': {'amountMinor': 4717, 'currency': 'SEK'},
      'source': 'system',
      'pickup': {
        'address': 'Södertälje centrum',
        'lat': 59.1955,
        'lng': 17.6253,
      },
      'dropoff': {'address': 'Södertälje syd', 'lat': 59.1622, 'lng': 17.6461},
      'categoryId': 'economy',
      'paymentMethod': 'card',
      'pickupEtaSeconds': 180,
      'pickupMeters': 900,
      'tripSeconds': 720,
      'tripMeters': 5200,
    };

    ({
      ApiDispatchRepository repo,
      List<http.BaseRequest> seen,
      List<StreamController<List<int>>> feeds,
    })
    feedRepo({List<Object> Function()? snapshot}) {
      final seen = <http.BaseRequest>[];
      final feeds = <StreamController<List<int>>>[];
      final repo = ApiDispatchRepository(
        client: MockClient.streaming((request, _) async {
          seen.add(request);
          if (request.url.path == '/api/v1/driver/offers') {
            return json(200, {
              'items': snapshot?.call() ?? <Object>[],
              'nextCursor': null,
            });
          }
          final next = StreamController<List<int>>();
          feeds.add(next);
          return http.StreamedResponse(next.stream, 200);
        }),
        baseUri: origin.replace(path: '/api/v1'),
        accessToken: () async => 'token',
        reconnectDelay: (_) => Duration.zero,
      );
      return (repo: repo, seen: seen, feeds: feeds);
    }

    List<http.BaseRequest> streams(List<http.BaseRequest> seen) => seen
        .where((r) => r.url.path == '/api/v1/driver/offers/stream')
        .toList();

    test('a cursor of 0 (`id: 0`, a driver with no offer events yet) is a '
        'cursor: the reconnect sends after=0, so offers made in the gap '
        'are replayed', () async {
      final f = feedRepo();
      await f.repo.connect();
      expect(
        streams(f.seen).single.url.queryParameters,
        isNot(contains('after')),
      );
      f.feeds.single.add(utf8.encode(': stream open\n\nid: 0\n\n'));
      await pumpEventQueue();
      expect(f.repo.lastSequence, 0);
      // Network loss: the feed ends; the app reconnects by itself.
      await f.feeds.single.close();
      await pumpEventQueue();
      await pumpEventQueue();
      final reconnect = streams(f.seen).last;
      expect(streams(f.seen), hasLength(2));
      expect(reconnect.url.queryParameters['after'], '0');
      expect(reconnect.headers['Last-Event-ID'], '0');
      await f.repo.dispose();
      for (final feed in f.feeds) {
        unawaited(feed.close());
      }
    });

    test('every reconnect after a lost feed reloads the open offers '
        '(GET /driver/offers) as well', () async {
      var items = <Object>[];
      final f = feedRepo(snapshot: () => items);
      await f.repo.connect();
      f.feeds.single.add(utf8.encode('id: 3\n\n'));
      await pumpEventQueue();
      expect(
        f.seen.where((r) => r.url.path == '/api/v1/driver/offers'),
        isEmpty,
      );
      // Made while the phone was away.
      items = [offer];
      await f.feeds.single.close();
      await pumpEventQueue();
      await pumpEventQueue();
      expect(streams(f.seen), hasLength(2));
      expect(
        f.seen.where((r) => r.url.path == '/api/v1/driver/offers'),
        hasLength(1),
      );
      await pumpEventQueue();
      expect((await f.repo.watchNearbyOffers().first).map((o) => o.id), [
        'gap1',
      ]);
      await f.repo.dispose();
      for (final feed in f.feeds) {
        unawaited(feed.close());
      }
    });
  });

  group('MEDIUM: Go online is blocked by the phone\'s location', () {
    for (final (name, block) in [
      (
        'not allowed for good',
        const LocationPermissionDeniedException(forever: true),
      ),
      ('not allowed', const LocationPermissionDeniedException()),
      (
        'location services off',
        const DriverLocationException('Location services are turned off.'),
      ),
    ]) {
      test('$name: "Turn on location to go online", and the server is not '
          'asked (even if it still has a recent fix)', () async {
        final app = live(locationBlock: () async => block);
        expect(await app.presence.goOnline(), tr.locationRequired);
        expect(requests, isEmpty);
        expect(app.presence.serverOnline, isFalse);
        expect(app.reporter.running, isFalse);
        await app.dispatch.dispose();
        app.session.dispose();
      });
    }

    test('location on and allowed: Go online goes on', () async {
      final app = live(locationBlock: () async => null);
      expect(await app.presence.goOnline(), isNull);
      expect(availability, ['online']);
      app.reporter.stop();
      await app.dispatch.dispose();
      app.session.dispose();
    });
  });
}

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
