import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/zones/driver_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingCache implements DriverZonesCache {
  @override
  Future<Map<String, dynamic>?> read() async => throw StateError('x');
  @override
  Future<void> write(Map<String, dynamic> answer) async =>
      throw StateError('x');
}

ApiClient _api(
  List<http.Request> seen,
  http.Response Function(http.Request) answer,
) {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  return ApiClient(
    client: MockClient((request) async {
      seen.add(request);
      return answer(request);
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  final fixture =
      jsonDecode(File('contracts/fixtures/zones.json').readAsStringSync())
          as Map<String, dynamic>;
  final contract =
      jsonDecode(File('contracts/contract.json').readAsStringSync())
          as Map<String, dynamic>;
  final seeds = {
    for (final s in (contract['zones'] as Map)['seed'] as List)
      (s as Map)['zoneId']: s,
  };

  /// `GET /driver/zones` over the fixture: the open zones, with the seed's
  /// names; [extra] added.
  Map<String, Object?> answer([
    List<Map<String, Object?>> extra = const [],
  ]) => {
    'zones': [
      for (final z in fixture['zones'] as List)
        if ((z as Map)['open'] == true) {...seeds[z['zoneId']] as Map, ...z},
      ...extra,
    ],
  };

  tearDown(DriverZones.forget);

  group('DriverZone', () {
    test('every fixture point by polygon, open zones only', () {
      DriverZones.useServer(LiveDriverZones.parse(answer())!);
      expect(DriverZones.server!.map((z) => z.id), ['FR-PC', 'CDG', 'ORY']);
      for (final p in fixture['points'] as List) {
        final point = p as Map;
        final expected = point['zoneId'] == 'TN-TC' ? null : point['zoneId'];
        expect(
          DriverZones.zoneAt(
            (point['lat'] as num).toDouble(),
            (point['lng'] as num).toDouble(),
          )?.id,
          expected,
          reason: '${point['name']}',
        );
      }
      expect(
        DriverZones.nameOf('CDG', 'fr'),
        'Aéroport Paris-Charles de Gaulle',
      );
      expect(DriverZones.nameOf('Z001', 'sv'), isNull);
      expect(DriverZones.byId(null), isNull);
      expect(DriverZones.offers('FR-PC'), isTrue);
      expect(DriverZones.offers('Z001'), isFalse);
    });

    test('without the server list every zone is offered', () {
      expect(DriverZones.server, isNull);
      expect(DriverZones.offers('Z001'), isTrue);
      expect(DriverZones.zoneAt(48.85, 2.35), isNull);
      expect(DriverZones.nameOf('FR-PC', 'sv'), isNull);
    });

    test('an edge point is inside; names fall back', () {
      const square = [
        [0.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
        [1.0, 0.0],
      ];
      expect(polygonHolds(square, 0, 0.5), isTrue);
      expect(polygonHolds(square, 0.5, 0.5), isTrue);
      expect(polygonHolds(square, 2, 0.5), isFalse);
      final zone = DriverZone.fromJson({'zoneId': 'X', 'polygon': square})!;
      expect(zone.nameIn('sv'), 'X');
      expect(zone.contains(5, 5), isFalse);
      final named = DriverZone.fromJson({
        'zoneId': 'Y',
        'polygon': square,
        'names': {'fr': 'Ici', 'sv': ' ', 1: 'x'},
        'country': 'FR',
        'currency': 'EUR',
        'timeZone': 'Europe/Paris',
      })!;
      expect(named.nameIn('sv'), 'Ici');
      expect(DriverZone.fromJson(named.toJson())!.currency, 'EUR');
    });

    test('fromJson refuses what is not a zone', () {
      expect(DriverZone.fromJson('x'), isNull);
      expect(DriverZone.fromJson({'zoneId': ''}), isNull);
      expect(DriverZone.fromJson({'zoneId': 'X', 'polygon': 'x'}), isNull);
      for (final bad in [
        [
          [0],
        ],
        [
          ['a', 0],
        ],
        [
          [0, 0],
          [1, 1],
        ],
      ]) {
        expect(DriverZone.fromJson({'zoneId': 'X', 'polygon': bad}), isNull);
      }
      expect(LiveDriverZones.parse('x'), isNull);
      expect(LiveDriverZones.parse({'zones': 'x'}), isNull);
      expect(
        LiveDriverZones.parse({
          'zones': [
            'x',
            {...(answer()['zones'] as List).first as Map, 'open': false},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('LiveDriverZones', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('PrefsDriverZonesCache round-trips', () async {
      const cache = PrefsDriverZonesCache();
      expect(await cache.read(), isNull);
      await cache.write({'zones': <Object?>[]});
      expect(await cache.read(), {'zones': <Object?>[]});
      SharedPreferences.setMockInitialValues({PrefsDriverZonesCache.key: '1'});
      expect(await cache.read(), isNull);
    });

    test('kept answer first, then the server, kept again', () async {
      final seen = <http.Request>[];
      final cache = MemoryDriverZonesCache()
        ..answer = {
          'zones': [
            {
              'zoneId': 'Z001',
              'polygon': [
                [59, 17],
                [60, 17],
                [60, 19],
              ],
            },
          ],
        };
      final live = LiveDriverZones(
        api: _api(seen, (_) => _json(answer())),
        cache: cache,
      );
      final ids = <List<String>>[];
      live.addListener(
        () => ids.add([for (final z in DriverZones.server!) z.id]),
      );
      await live.start();
      expect(seen.single.url.path, '/api/v1/driver/zones');
      expect(ids, [
        ['Z001'],
        ['FR-PC', 'CDG', 'ORY'],
      ]);
      expect((cache.answer!['zones'] as List).length, 3);
    });

    test('a failing server or cache keeps what is in use', () async {
      final bad = LiveDriverZones(
        api: _api([], (_) => _json({'x': 1})),
        cache: _FailingCache(),
      );
      await bad.start();
      expect(DriverZones.server, isNull);
      final ok = LiveDriverZones(
        api: _api([], (_) => _json(answer())),
        cache: _FailingCache(),
      );
      expect(await ok.refresh(), isTrue);
      expect(DriverZones.server, hasLength(3));
    });

    test('config_published with doc zones reads the zones again', () async {
      final events = StreamController<List<int>>();
      var published = 0;
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            return http.StreamedResponse(events.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 't',
        cache: MemoryDriverConfigCache(),
        onZonesPublished: () => published++,
      );
      await config.watch();
      events.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"zones","zoneId":"CDG",'
          '"version":2}\n\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(published, 1);
      expect(config.current, isNull);
      config.dispose();
      await events.close();
    });
  });

  group('onboarding cities', () {
    test('the contract list without the server', () {
      expect(DriverOnboardingRules.isOpen('SE'), isTrue);
      expect(DriverOnboardingRules.isOpen('TN'), isFalse);
      expect(DriverOnboardingRules.citiesOf('FR').single.cityId, 'paris');
    });

    test('a city whose zone is not open on the server is left out', () {
      DriverZones.useServer(LiveDriverZones.parse(answer())!);
      expect(DriverOnboardingRules.citiesOf('FR').single.zoneId, 'FR-PC');
      expect(DriverOnboardingRules.citiesOf('SE'), isEmpty);
      expect(DriverOnboardingRules.isOpen('SE'), isFalse);
      expect(DriverOnboardingRules.isOpen('FR'), isTrue);
      expect(DriverOnboardingRules.citiesOf('XX'), isEmpty);
    });
  });
}
