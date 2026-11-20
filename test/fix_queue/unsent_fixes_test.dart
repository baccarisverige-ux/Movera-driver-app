// Audit 2026-11-20 (app lifecycle) item 4: the positions of a network drop
// are kept (bounded) and sent with the next fix once the network is back.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';

void main() {
  final start = DateTime.utc(2026, 11, 20, 12);
  late DateTime now;
  late bool networkUp;
  late int status;
  late List<List<Object?>> batches;

  LiveLocationReporter reporter() => LiveLocationReporter(
    api: ApiClient(
      client: MockClient((request) async {
        if (!networkUp) throw http.ClientException('offline');
        batches.add(
          (jsonDecode(request.body) as Map<String, dynamic>)['fixes'] as List,
        );
        return http.Response(
          jsonEncode(
            status == 200
                ? {'accepted': 1}
                : {'code': 'validation_failed', 'message': 'x'},
          ),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    ),
    location: _NoGps(),
    every: const Duration(hours: 1),
    now: () => now,
    restampHeldFix: false,
  );

  Map<String, Object?> fix(int second) => {
    'lat': 59.33,
    'lng': 18.06,
    'accuracy': 5.0,
    'measuredAt': start.add(Duration(seconds: second)).toIso8601String(),
  };

  setUp(() {
    now = start;
    networkUp = false;
    status = 200;
    batches = [];
  });

  test('the fixes of a drop go with the next send, oldest first', () async {
    final r = reporter();
    for (final s in [0, 10, 20]) {
      now = start.add(Duration(seconds: s));
      expect(await r.sendNow(first: fix(s)), isFalse);
    }
    expect(r.unsent, hasLength(3));
    networkUp = true;
    now = start.add(const Duration(seconds: 30));
    expect(await r.sendNow(first: fix(30)), isTrue);
    expect(batches.single, [fix(0), fix(10), fix(20), fix(30)]);
    expect(r.unsent, isEmpty);
  });

  test(
    'bounded: only the newest are kept; too old ones are left out',
    () async {
      final r = reporter();
      final n = LiveLocationReporter.maxQueued + 5;
      for (var s = 0; s < n; s++) {
        await r.sendNow(first: fix(s));
      }
      expect(r.unsent, hasLength(LiveLocationReporter.maxQueued));
      expect(r.unsent.first, fix(5));
      networkUp = true;
      now = start.add(const Duration(minutes: 10, seconds: 20));
      await r.sendNow(first: fix(620));
      // Measured more than 10 min ago: the server drops them, so not sent.
      expect(batches.single.first, fix(20));
      expect(batches.single.last, fix(620));
    },
  );

  test('a 401 (sign-in renewing) keeps the queue', () async {
    final r = reporter();
    await r.sendNow(first: fix(0));
    networkUp = true;
    status = 401;
    expect(await r.sendNow(first: fix(10)), isFalse);
    expect(r.unsent, [fix(0), fix(10)]);
  });

  test('a refused batch is not kept', () async {
    final r = reporter();
    await r.sendNow(first: fix(0));
    networkUp = true;
    status = 400;
    expect(await r.sendNow(first: fix(10)), isFalse);
    expect(r.unsent, isEmpty);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      DriverLocation(point: const GeoPoint(59.33, 18.06), accuracyMeters: 5);

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
