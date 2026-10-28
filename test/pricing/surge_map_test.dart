import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/core/surge/api_surge_map.dart';
import 'package:movera/core/surge/surge_map.dart';
import 'package:movera/presentation/driver/home/components/home_map_layers.dart';

/// A source the test answers by hand.
class _Source implements SurgeMapSource {
  final List<FutureOr<List<DriverSurgeZone>> Function()> answers = [];
  int calls = 0;

  @override
  Future<List<DriverSurgeZone>> fetch() async {
    calls++;
    if (answers.isEmpty) throw StateError('no answer');
    return answers.removeAt(0)();
  }
}

const _bounds = SurgeBounds(
  south: 59.30,
  west: 18.00,
  north: 59.32,
  east: 18.04,
);
const _zone = DriverSurgeZone(
  zoneId: 'Z001',
  level: SurgeLevel.medium,
  bounds: _bounds,
);
const _high = DriverSurgeZone(
  zoneId: 'Z002',
  level: SurgeLevel.high,
  bounds: _bounds,
);

/// Contract v0.7.2 §17 (owner 2026-10-28): the driver sees a surge only as
/// a coloured zone on Home's map, and the waiting tip "High boost nearby"
/// within 3 km. No surge notice, no multiplier, no money.
void main() {
  group('GET /driver/surge-map', () {
    test('reads level and rectangle; never a multiplier', () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'at': '2026-10-28T10:00:00Z',
              'zones': [
                {
                  'zoneId': 'Z001',
                  'level': 'medium',
                  'bounds': {
                    'south': 59.30,
                    'west': 18.00,
                    'north': 59.32,
                    'east': 18.04,
                  },
                },
                // Not usable: unknown level, missing bounds, inverted box.
                {'zoneId': 'Z9', 'level': 'max', 'bounds': _boundsJson},
                {'zoneId': 'Z8', 'level': 'low'},
                {
                  'zoneId': 'Z7',
                  'level': 'low',
                  'bounds': {'south': 2, 'west': 0, 'north': 1, 'east': 1},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      );
      final zones = await ApiSurgeMapSource(api: api).fetch();
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/driver/surge-map');
      expect(zones, [_zone]);
    });

    test('an answer without zones is an error (the last zones stay)', () {
      expect(() => surgeZonesFromJson({'at': 'x'}), throwsFormatException);
    });
  });

  group('map polygons', () {
    test('a filled rectangle per zone: ~40 % fill, 2 px edge, no text', () {
      final polygons = surgeZonePolygons([
        _zone,
        const DriverSurgeZone(
          zoneId: 'Z003',
          level: SurgeLevel.low,
          bounds: _bounds,
        ),
        _high,
      ]).toList();
      expect(polygons, hasLength(3));
      for (final polygon in polygons) {
        expect(polygon.points, hasLength(4));
        expect(polygon.strokeWidth, 2);
        expect(polygon.fillColor.a, closeTo(0.4, 0.01));
        expect(
          polygon.strokeColor.toARGB32() & 0xFFFFFF,
          polygon.fillColor.toARGB32() & 0xFFFFFF,
        );
        expect(polygon.strokeColor.a, 1);
        expect(polygon.consumeTapEvents, isFalse);
        expect(polygon.holes, isEmpty);
      }
      expect(polygons[0].strokeColor.toARGB32(), 0xFFFF8A3D);
      expect(polygons[1].strokeColor.toARGB32(), 0xFFFFC79E);
      expect(polygons[2].strokeColor.toARGB32(), 0xFFE5482B);
      expect(polygons[0].points.first.latitude, 59.30);
      expect(polygons[0].points.first.longitude, 18.00);
    });

    test('the demo shows one zone of each level near the driver', () {
      const at = GeoPoint(59.3293, 18.0686);
      final zones = DemoSurgeMapSource.zonesAround(at);
      expect(zones.map((z) => z.level).toSet(), SurgeLevel.values.toSet());
      for (final zone in zones) {
        final km = zone.bounds.distanceMetersTo(at) / 1000;
        expect(km, inInclusiveRange(0.3, 3.5), reason: zone.zoneId);
      }
      expect(nearSurgeZone(at, zones), isTrue);
    });
  });

  group('the 3 km tip rule', () {
    // 1 km of latitude.
    const kmLat = 1 / 110.574;

    test('inside, under 3 km and over 3 km', () {
      expect(nearSurgeZone(const GeoPoint(59.31, 18.02), [_zone]), isTrue);
      expect(
        nearSurgeZone(GeoPoint(59.32 + 2.9 * kmLat, 18.02), [_zone]),
        isTrue,
      );
      expect(
        nearSurgeZone(GeoPoint(59.30 - 3.1 * kmLat, 18.02), [_zone]),
        isFalse,
      );
      expect(nearSurgeZone(const GeoPoint(59.31, 18.02), const []), isFalse);
      expect(nearSurgeZone(null, [_zone]), isFalse);
    });

    test('any level counts, the nearest edge counts', () {
      const low = DriverSurgeZone(
        zoneId: 'Z003',
        level: SurgeLevel.low,
        bounds: _bounds,
      );
      // East of the box, 2 km at this latitude (~56.9 km per degree).
      expect(
        nearSurgeZone(const GeoPoint(59.31, 18.04 + 2 / 56.9), [low]),
        isTrue,
      );
    });

    test('the tip says only "High boost nearby": no money, number, zone', () {
      final config = const DriverHomeAdminContentService().load();
      final now = DateTime(2026, 10, 28, 23, 59);
      final near = IslandWaitingSignals.fromHome(
        config,
        now: now,
        boostNearby: true,
      ).tips().where((t) => t.id == 'boost');
      expect(near.single.title, 'High boost nearby');
      expect(near.single.title, isNot(matches(RegExp(r'\d|kr|×'))));
      expect(
        IslandWaitingSignals.fromHome(
          config,
          now: now,
        ).tips().where((t) => t.id == 'boost'),
        isEmpty,
      );
      final demo = IslandWaitingSignals.demo(
        config,
      ).tips().where((t) => t.id == 'boost');
      expect(demo.single.title, 'High boost nearby');
    });
  });

  group('fetch, refresh and keep-last', () {
    testWidgets('asks on going online, then every 60 s while on Home', (
      tester,
    ) async {
      final source = _Source()
        ..answers.addAll([
          () => [_zone],
          () => [_zone, _high],
        ]);
      final map = SurgeMapController(source: source);
      var changes = 0;
      map.addListener(() => changes++);

      map.sync(online: false);
      await tester.pump(const Duration(minutes: 3));
      expect(source.calls, 0, reason: 'offline: nothing is asked');
      expect(map.zones, isEmpty);

      map.sync(online: true);
      await tester.pump();
      expect(source.calls, 1);
      expect(map.zones, [_zone]);
      // A second sync while online does not ask again.
      map.sync(online: true);
      await tester.pump();
      expect(source.calls, 1);

      await tester.pump(const Duration(seconds: 59));
      expect(source.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(source.calls, 2);
      expect(map.zones, [_zone, _high]);
      expect(changes, 2);
      map.dispose();
    });

    testWidgets('a failed call keeps the last answer', (tester) async {
      final source = _Source()
        ..answers.addAll([
          () => [_zone],
          () => throw const SocketException('offline'),
        ]);
      final map = SurgeMapController(source: source)..sync(online: true);
      await tester.pump();
      expect(map.zones, [_zone]);
      await tester.pump(const Duration(seconds: 60));
      expect(source.calls, 2);
      expect(map.zones, [_zone]);
      // No answer queued: the source throws again; still the last zones.
      await tester.pump(const Duration(seconds: 60));
      expect(source.calls, 3);
      expect(map.zones, [_zone]);
      map.dispose();
    });

    testWidgets('offline shows nothing, and a late answer is dropped', (
      tester,
    ) async {
      final late = Completer<List<DriverSurgeZone>>();
      final source = _Source()
        ..answers.addAll([
          () => [_zone],
          () => late.future,
        ]);
      final map = SurgeMapController(source: source)..sync(online: true);
      await tester.pump();
      expect(map.zones, [_zone]);
      await tester.pump(const Duration(seconds: 60));
      expect(source.calls, 2);
      map.sync(online: false);
      expect(map.zones, isEmpty);
      late.complete([_high]);
      await tester.pump();
      expect(map.zones, isEmpty);
      await tester.pump(const Duration(minutes: 5));
      expect(source.calls, 2, reason: 'no reads while offline');
      map.dispose();
    });

    testWidgets('off Home it stops asking; back in front it asks at once', (
      tester,
    ) async {
      final source = _Source()
        ..answers.addAll([
          () => [_zone],
          () => [_high],
          () => [_zone],
        ]);
      final map = SurgeMapController(source: source)..sync(online: true);
      await tester.pump();
      expect(source.calls, 1);

      // The app goes to the background (or a page covers Home).
      map.sync(online: true, onHome: false);
      await tester.pump(const Duration(minutes: 5));
      expect(source.calls, 1);
      expect(map.zones, [_zone], reason: 'kept while away');

      // Back in front.
      map.sync(online: true, onHome: true);
      await tester.pump();
      expect(source.calls, 2);
      expect(map.zones, [_high]);

      map.resumed();
      await tester.pump();
      expect(source.calls, 3);
      map.dispose();
    });
  });

  test('no surge notice remains in the driver app', () {
    final offenders = <String>[];
    final banned = RegExp(
      r'surge_started|surgeNotice|SurgeNotice|surgeMultiplier|isSurge\b|'
      r'tipHighBoostIn|dismissSurge',
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.arb')) {
        continue;
      }
      if (banned.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
    expect(
      File(
        'lib/presentation/driver/notifications/surge_notice_banner.dart',
      ).existsSync(),
      isFalse,
    );
  });
}

const _boundsJson = {
  'south': 59.30,
  'west': 18.00,
  'north': 59.32,
  'east': 18.04,
};
