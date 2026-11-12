import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_config_parts.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/zones/driver_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/safety/emergency_numbers.dart';
import 'package:movera/core/notifications/driver_notifications.dart';

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('location denied');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// Owner 2026-10-27 (settings flow, contract v0.8.0): the driver app reads
/// its settings from the server, puts each newer document in use at once,
/// keeps the last good one, and follows the auto-offline rule.
void main() {
  final base = Uri.parse('https://api.movera.invalid/api/v1');
  Map<String, dynamic> document(int version, {int radarSeconds = 25}) => {
    'version': version,
    'zoneId': 'Z001',
    'currency': 'SEK',
    'timeZone': 'Europe/Stockholm',
    'offers': {
      'radarSeconds': radarSeconds,
      'exclusiveSeconds': 20,
      'exclusiveWhileDriving': {'on': true, 'count': 2},
      'autoOffline': {'on': true, 'missedExclusive': 10},
      'offerCard': {'pickupAddress': false},
      'exclusiveReasons': [
        {'id': 'nearby', 'text': 'Nära dig', 'on': true},
      ],
    },
    'pickupPay': {
      'offers': {'radar': true, 'exclusive': false},
      'byCategory': {
        'economy': {
          'enabled': true,
          'ranges': [
            {
              'fromKm': 0,
              'toKm': null,
              'perKm': {'amountMinor': 250, 'currency': 'SEK'},
              'perMin': {'amountMinor': 80, 'currency': 'SEK'},
            },
          ],
        },
      },
    },
    'rideCheck': {'stopMinutes': 4, 'finishFarFromDropoffKm': 2.5},
    'texts': {
      'byLanguage': {
        'sv': {'island.online': 'Radar på nu'},
      },
    },
    'notices': {
      'off': ['highDemand'],
    },
    'cancelFees': {'driverSharePct': 80},
  };

  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    PickupPayConfig.current = const PickupPayConfig();
    RideCheckAdminConfig.current = const RideCheckAdminConfig();
    DriverAppTexts.overrides = const DriverAppTextOverrides();
    DriverNoticeRules.current = const DriverNoticeRules();
    DriverCancelFees.current = const DriverCancelFees();
    ExclusiveAnswers.instance.reset();
  });

  test(
    'GET /driver/config is put in use at once: offers, pickup pay, ride '
    'check, texts, notices and cancel fees; an older version is ignored',
    () async {
      var version = 4;
      final cache = MemoryDriverConfigCache();
      final config = LiveDriverConfig(
        client: MockClient(
          (request) async => http.Response(jsonEncode(document(version)), 200),
        ),
        apiBase: base,
        accessToken: () async => 'token-1',
        cache: cache,
      );
      await config.start();
      expect(config.current?.version, 4);
      final rules = DriverOfferRules.current;
      expect(rules.radarTime, const Duration(seconds: 25));
      expect(rules.exclusiveAcceptTime, const Duration(seconds: 20));
      expect(rules.exclusiveWhileDrivingCount, 2);
      expect(rules.autoOfflineAfter, 10);
      expect(rules.card.pickupAddress, isFalse);
      // G4-E7 (v0.18.6): an old document's exclusiveReasons are ignored.
      expect(
        rules.reasonText('nearby'),
        isNot('Nära dig'),
        reason: 'offers.exclusiveReasons is deprecated',
      );
      expect(PickupPayConfig.current.categories['economy']?.krPerKm, 2.5);
      expect(PickupPayConfig.current.kinds, {PickupPayOfferKind.radar});
      expect(RideCheckAdminConfig.current.longStopMinutes, 4);
      expect(RideCheckAdminConfig.current.finishFarFromDropoffKm, 2.5);
      expect(
        DriverAppTexts.overrides.byLanguage['sv']?['island.online'],
        'Radar på nu',
      );
      expect(
        DriverNoticeRules.current.allows(DriverNoticeKind.highDemand),
        isFalse,
      );
      expect(DriverCancelFees.current.driverPartOf(6500), 5200);
      expect(cache.document?['version'], 4);

      version = 3;
      await config.refresh();
      expect(config.current?.version, 4);
      config.dispose();
    },
  );

  test('no server: the last document kept on the device is used', () async {
    final cache = MemoryDriverConfigCache()
      ..document = document(7, radarSeconds: 30);
    final config = LiveDriverConfig(
      client: MockClient((_) async => throw http.ClientException('offline')),
      apiBase: base,
      accessToken: () async => null,
      cache: cache,
    );
    await config.start();
    expect(config.current?.version, 7);
    expect(DriverOfferRules.current.radarTime, const Duration(seconds: 30));
    config.dispose();
  });

  test(
    'config_published on /driver/config/stream fetches the new document',
    () async {
      var version = 4;
      final events = StreamController<List<int>>();
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            return http.StreamedResponse(events.stream, 200);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(document(version)))),
            200,
          );
        }),
        apiBase: base,
        accessToken: () async => 'token-1',
        cache: MemoryDriverConfigCache(),
      );
      await config.start();
      await config.watch();
      final changed = Completer<void>();
      config.addListener(() {
        if (!changed.isCompleted) changed.complete();
      });
      version = 5;
      events.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"driver_app_config","zoneId":"Z001","version":5}\n\n',
        ),
      );
      await changed.future.timeout(const Duration(seconds: 2));
      expect(config.current?.version, 5);
      config.dispose();
      await events.close();
    },
  );

  test(
    'the server set the driver offline (driverOffline): the app follows',
    () {
      var offline = 0;
      final dispatch = ApiDispatchRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: base,
        accessToken: () async => null,
      )..onDriverOffline = () => offline++;
      dispatch.ingest({
        'eventId': 'evt_1',
        'sequence': 1,
        'kind': 'offer_updated',
        'occurredAt': '2026-10-27T10:00:00Z',
        'serverTime': '2026-10-27T10:00:00Z',
        'driverOffline': true,
        'offer': {
          'offerId': 'ofr_1',
          'tripId': 'trp_1',
          'kind': 'exclusive',
          'status': 'declined',
        },
      });
      expect(offline, 1);
    },
  );

  test(
    'an accepted offer (Radar too) and going online start the row again',
    () {
      final answers = ExclusiveAnswers.instance;
      const rules = DriverOfferRules(autoOfflineAfter: 3);
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isFalse);
      answers.accepted();
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isTrue);
    },
  );

  test('Job 3 / L19: back in the foreground, the settings are read again '
      'and a newer version is put in use', () async {
    var version = 4;
    var gets = 0;
    final config = LiveDriverConfig(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/driver/config')) gets++;
        return http.Response(
          jsonEncode(document(version, radarSeconds: 25 + version)),
          200,
        );
      }),
      apiBase: base,
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
    );
    addTearDown(config.dispose);
    await config.start();
    expect(config.current?.version, 4);
    // Admin published while the phone was in the background.
    version = 5;
    await config.resumed();
    expect(gets, 2);
    expect(config.current?.version, 5);
    expect(DriverOfferRules.current.radarTime, const Duration(seconds: 30));
  });

  test('Job 3 / L19: a resume while a connect is in flight leaves one '
      'settings stream, not two', () async {
    var open = 0;
    final gate = Completer<void>();
    final config = LiveDriverConfig(
      client: MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/driver/config')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(document(4)))),
            200,
          );
        }
        // The first stream answers late (still connecting at resume).
        if (!gate.isCompleted) await gate.future;
        late final StreamController<List<int>> body;
        body = StreamController<List<int>>(
          onListen: () => open++,
          onCancel: () => open--,
        );
        return http.StreamedResponse(body.stream, 200);
      }),
      apiBase: base,
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
    );
    addTearDown(config.dispose);
    await config.start();
    unawaited(config.watch());
    await Future<void>.delayed(Duration.zero);
    final resumed = config.resumed();
    gate.complete();
    await resumed;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(open, 1);
  });

  group('G17: the settings of the zone the driver is in', () {
    const tunis = 'TN-TUN';
    const tunisia = [
      {
        'kind': 'police',
        'number': '197',
        'label': {'sv': 'Polis', 'fr': 'Police', 'en': 'Police'},
      },
      {
        'kind': 'ambulance',
        'number': '190',
        'label': {
          'sv': 'Ambulans (SAMU)',
          'fr': 'SAMU (ambulance)',
          'en': 'Ambulance (SAMU)',
        },
      },
    ];
    const sweden = [
      {
        'kind': 'general',
        'number': '112',
        'label': {'sv': 'Larmnummer', 'fr': 'Urgences', 'en': 'Emergency'},
      },
      {
        'kind': 'police',
        'number': '11414',
        'label': {'sv': 'Polisen', 'fr': 'Police', 'en': 'Police'},
      },
    ];
    // The SE document has the higher version: a zone change must still
    // take the TN one.
    Map<String, dynamic> tn() => {
      ...document(3),
      'zoneId': tunis,
      'currency': 'TND',
      'timeZone': 'Africa/Tunis',
      'emergencyNumbers': tunisia,
    };
    Map<String, dynamic> se() => {...document(9), 'emergencyNumbers': sweden};
    List<String> numbers() => [
      for (final row in EmergencyNumbers.current) row.number,
    ];

    setUp(() {
      EmergencyNumbers.reset();
      Money.forgetZone();
    });
    tearDown(() {
      EmergencyNumbers.reset();
      Money.forgetZone();
    });

    /// The server: the TN document only when `?zoneId=TN-TUN`, else the
    /// driver's account zone (Sweden). Streams stay open until closed.
    ({
      http.Client client,
      List<Uri> gets,
      List<Uri> streams,
      List<StreamController<List<int>>> open,
    })
    server({Future<void>? hold}) {
      final gets = <Uri>[];
      final streams = <Uri>[];
      final open = <StreamController<List<int>>>[];
      final client = MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/driver/config/stream')) {
          streams.add(request.url);
          final body = StreamController<List<int>>();
          open.add(body);
          return http.StreamedResponse(body.stream, 200);
        }
        gets.add(request.url);
        if (hold != null) await hold;
        final zone = request.url.queryParameters['zoneId'];
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(zone == tunis ? tn() : se()))),
          200,
        );
      });
      return (client: client, gets: gets, streams: streams, open: open);
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('in Tunis: GET /driver/config and its stream name the zone; the '
        'numbers are Police 197 and SAMU 190 and amounts are in TND', () async {
      final fake = server();
      final config = LiveDriverConfig(
        client: fake.client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => tunis,
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      await config.watch();
      await settle();
      expect(fake.gets.single.queryParameters['zoneId'], tunis);
      expect(fake.streams.single.queryParameters['zoneId'], tunis);
      expect(fake.streams.single.path, '/api/v1/driver/config/stream');
      expect(config.current?.zoneId, tunis);
      expect(numbers(), ['197', '190']);
      expect(Money.zoneCurrency, 'TND');
    });

    test('the zone changes (Stockholm, then a trip in Tunis): read again '
        'for the new zone and the stream opens again for it', () async {
      final fake = server();
      String? zone = 'Z001';
      final config = LiveDriverConfig(
        client: fake.client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => zone,
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      await config.watch();
      await settle();
      expect(numbers(), ['112', '11414']);
      expect(fake.streams.single.queryParameters['zoneId'], 'Z001');

      zone = tunis;
      await config.zoneChanged();
      await settle();
      expect(fake.gets.last.queryParameters['zoneId'], tunis);
      expect(config.current?.zoneId, tunis);
      expect(config.current?.version, 3);
      expect(numbers(), ['197', '190']);
      expect(fake.streams, hasLength(2));
      expect(fake.streams.last.queryParameters['zoneId'], tunis);
      expect(fake.open.first.hasListener, isFalse, reason: 'old one closed');

      // The same zone again: nothing is asked.
      final asked = fake.gets.length;
      await config.zoneChanged();
      await settle();
      expect(fake.gets, hasLength(asked));
      expect(fake.streams, hasLength(2));
    });

    test('a restart in Tunis shows the saved TN numbers first, never SE '
        '(one saved copy per zone)', () async {
      final cache = MemoryDriverConfigCache();
      await cache.write(se(), zoneId: 'Z001');
      await cache.write(tn(), zoneId: tunis);
      final hold = Completer<void>();
      final fake = server(hold: hold.future);
      final config = LiveDriverConfig(
        client: fake.client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => tunis,
        cache: cache,
      );
      addTearDown(config.dispose);
      final started = config.start();
      await settle();
      // The server has not answered yet.
      expect(numbers(), ['197', '190']);
      expect(config.current?.zoneId, tunis);
      hold.complete();
      await started;
      expect(numbers(), ['197', '190']);
      expect(fake.gets.single.queryParameters['zoneId'], tunis);
    });

    test(
      '§89: a restart before the zone is known shows the last saved '
      'document (Tunis) and asks without zoneId (the server picks)',
      () async {
        final cache = MemoryDriverConfigCache();
        await cache.write(tn(), zoneId: tunis);
        final hold = Completer<void>();
        final fake = server(hold: hold.future);
        final config = LiveDriverConfig(
          client: fake.client,
          apiBase: base,
          accessToken: () async => 'token-1',
          zoneId: () => null,
          cache: cache,
        );
        addTearDown(config.dispose);
        final started = config.start();
        await settle();
        expect(numbers(), ['197', '190']);
        hold.complete();
        await started;
        expect(fake.gets.single.queryParameters.containsKey('zoneId'), isFalse);
        expect(config.zoneId, isNull);
      },
    );

    test('§89: versions are per zone. SE v7 to TN: the TN stream opens '
        'without Last-Event-ID 7 and a TN v4 publish is taken', () async {
      final streams = <http.BaseRequest>[];
      final bodies = <StreamController<List<int>>>[];
      var tnUp = false;
      var tnVersion = 3;
      final client = MockClient.streaming((request, _) async {
        final zone = request.url.queryParameters['zoneId'];
        if (request.url.path.endsWith('/driver/config/stream')) {
          streams.add(request);
          final body = StreamController<List<int>>();
          bodies.add(body);
          return http.StreamedResponse(body.stream, 200);
        }
        if (zone == tunis && !tnUp) {
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 503);
        }
        final doc = zone == tunis
            ? {...tn(), 'version': tnVersion}
            : {...se(), 'version': 7};
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(doc))),
          200,
        );
      });
      String? zone = 'Z001';
      final config = LiveDriverConfig(
        client: client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => zone,
        retryAfter: const Duration(milliseconds: 1),
        retryMax: const Duration(milliseconds: 1),
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      await config.watch();
      await settle();
      expect(streams.single.headers['Last-Event-ID'], '7');

      // In Tunis, but the first TN read fails: SE v7 is still in use.
      zone = tunis;
      await config.zoneChanged();
      await settle();
      expect(config.current?.version, 7);
      expect(streams, hasLength(2));
      expect(streams.last.url.queryParameters['zoneId'], tunis);
      expect(streams.last.headers.containsKey('Last-Event-ID'), isFalse);

      // TN publishes v4 (lower than SE's 7): it is read and taken.
      tnUp = true;
      tnVersion = 4;
      bodies.last.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"driver_app_config",'
          '"zoneId":"$tunis","version":4}\n\n',
        ),
      );
      await settle();
      expect(config.current?.zoneId, tunis);
      expect(config.current?.version, 4);
      expect(numbers(), ['197', '190']);

      // The TN stream drops and opens again: Last-Event-ID is TN's own.
      await bodies.last.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await settle();
      expect(streams.last.url.queryParameters['zoneId'], tunis);
      expect(streams.last.headers['Last-Event-ID'], '4');
    });

    test('§89: with neither a trip nor a zone at the position, the app asks '
        'without zoneId again (the server picks)', () async {
      final fake = server();
      String? zone = tunis;
      final config = LiveDriverConfig(
        client: fake.client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => zone,
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      await config.watch();
      await settle();
      zone = null;
      await config.zoneChanged();
      await settle();
      expect(fake.gets.last.queryParameters.containsKey('zoneId'), isFalse);
      expect(fake.streams.last.queryParameters.containsKey('zoneId'), isFalse);
      expect(fake.streams, hasLength(2));
    });

    test('a zone change with nothing saved for it never shows the other '
        "country's numbers while the new document loads", () async {
      var hold = Completer<void>()..complete();
      final gets = <Uri>[];
      final client = MockClient((request) async {
        gets.add(request.url);
        await hold.future;
        final zone = request.url.queryParameters['zoneId'];
        return http.Response(jsonEncode(zone == tunis ? tn() : se()), 200);
      });
      String? zone = 'Z001';
      final config = LiveDriverConfig(
        client: client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => zone,
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      expect(numbers(), ['112', '11414']);
      hold = Completer<void>();
      zone = tunis;
      final changed = config.zoneChanged();
      await settle();
      expect(numbers(), isNot(contains('11414')));
      hold.complete();
      await changed;
      await settle();
      expect(numbers(), ['197', '190']);
    });

    test('zone unknown and nothing saved: asked without zoneId as before '
        "(the server serves the account's zone)", () async {
      final fake = server();
      final config = LiveDriverConfig(
        client: fake.client,
        apiBase: base,
        accessToken: () async => 'token-1',
        zoneId: () => null,
        cache: MemoryDriverConfigCache(),
      );
      addTearDown(config.dispose);
      await config.start();
      expect(fake.gets.single.queryParameters.containsKey('zoneId'), isFalse);
      expect(numbers(), ['112', '11414']);
    });

    test('the live build: the trip zone first, else the zone around the '
        "phone's position; a new zone is read at once", () async {
      SharedPreferences.setMockInitialValues({});
      DriverStartPosition.clearMemory();
      DriverZones.useServer([
        const DriverZone(
          id: tunis,
          country: 'TN',
          polygon: [
            [36.6, 10.0],
            [36.6, 10.4],
            [37.0, 10.4],
            [37.0, 10.0],
          ],
        ),
        const DriverZone(
          id: 'Z001',
          country: 'SE',
          polygon: [
            [59.0, 17.5],
            [59.0, 18.5],
            [59.6, 18.5],
            [59.6, 17.5],
          ],
        ),
      ]);
      addTearDown(() {
        DriverZones.forget();
        DriverStartPosition.clearMemory();
      });
      final gets = <String?>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/driver/config') {
          final zone = request.url.queryParameters['zoneId'];
          gets.add(zone);
          return http.Response(jsonEncode(zone == tunis ? tn() : se()), 200);
        }
        return http.Response('', 503);
      });
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final live = LiveDriverServices(
        client: client,
        origin: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
        location: _NoGps(),
        locationEvery: const Duration(hours: 1),
      );
      expect(live.zoneNow(), isNull);
      // Home saw the phone in Tunis.
      await DriverStartPosition.save(const GeoPoint(36.8, 10.18));
      expect(live.zoneNow(), tunis);
      await live.config.start();
      expect(gets.last, tunis);
      expect(numbers(), ['197', '190']);
      // §89: a held booked ride and a queued next trip do not count.
      live.trips.observe({
        'tripId': 'trp_held',
        'version': 1,
        'kind': 'scheduled',
        'status': 'accepted',
        'zoneId': 'Z001',
      });
      live.trips.observe({
        'tripId': 'trp_queued',
        'version': 1,
        'status': 'accepted',
        'nextAfterTripId': 'trp_other',
        'zoneId': 'Z001',
      });
      expect(live.zoneNow(), tunis);
      // A trip of the Stockholm zone (the trip's zoneId wins).
      live.trips.observe({
        'tripId': 'trp_1',
        'version': 1,
        'status': 'accepted',
        'zoneId': 'Z001',
      });
      expect(live.zoneNow(), 'Z001');
      await settle();
      expect(gets.last, 'Z001');
      expect(numbers(), ['112', '11414']);
      // The trip ended: back to the zone of the position.
      live.trips.observe({
        'tripId': 'trp_1',
        'version': 2,
        'status': 'completed',
        'zoneId': 'Z001',
      });
      await settle();
      expect(live.zoneNow(), tunis);
      expect(gets.last, tunis);
      expect(numbers(), ['197', '190']);
      await live.dispose();
      expect(DriverStartPosition.onMoved, isNull);
    });
  });
}
