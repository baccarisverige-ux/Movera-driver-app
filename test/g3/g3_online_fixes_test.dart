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
    dispatch.onDriverOffline = () => session.setOnline(false);
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
