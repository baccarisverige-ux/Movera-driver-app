import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// G5 live test 2026-10-31 (bug 6): after Go online no
/// `POST /driver/location` went out for about 6 min, until the emulated
/// GPS moved. The server marks a driver stale after 120 s. The fix the
/// server took with Go online goes out at once, and the ticks follow on
/// the interval whether or not the position changes.
void main() {
  late List<http.Request> sent;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      sent.add(request);
      return http.Response(
        jsonEncode({'accepted': 1}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );

  List<http.Request> locations() => sent
      .where((r) => r.url.path == LiveLocationReporter.locationPath)
      .toList();

  setUp(() => sent = []);

  test('the Go online fix is sent at once, even when the GPS gives '
      'nothing new', () async {
    final reporter = LiveLocationReporter(
      api: api(),
      location: _StillGps(answers: false),
      every: const Duration(hours: 1),
      restampHeldFix: false,
    );
    final first = <String, Object?>{
      'lat': 59.3326,
      'lng': 18.0649,
      'accuracy': 5.0,
      'measuredAt': DateTime.now().toUtc().toIso8601String(),
    };
    reporter.start(first: first);
    await pumpEventQueue();
    expect(locations(), hasLength(1));
    final fix =
        ((jsonDecode(locations().single.body) as Map)['fixes'] as List).single;
    expect(fix, first);
    reporter.stop();
  });

  test('a phone standing still (no stream event) still sends every '
      'interval', () async {
    final reporter = LiveLocationReporter(
      api: api(),
      location: _StillGps(answers: true),
      every: const Duration(milliseconds: 40),
      restampHeldFix: false,
    );
    reporter.start();
    await Future<void>.delayed(const Duration(milliseconds: 190));
    reporter.stop();
    expect(locations().length, greaterThanOrEqualTo(4));
  });
}

/// A GPS that never reports a change on its stream (the car stands).
class _StillGps implements DriverLocationRepository {
  _StillGps({required this.answers});
  final bool answers;

  @override
  Future<DriverLocation> getCurrentPosition() async {
    if (!answers) throw TimeoutException('no new position');
    return DriverLocation(
      point: const GeoPoint(59.3326, 18.0649),
      accuracyMeters: 5,
      measuredAt: DateTime.now(),
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
