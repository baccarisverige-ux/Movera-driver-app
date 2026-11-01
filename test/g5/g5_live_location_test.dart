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

  test('G5 live re-test: a still phone keeps sending its last OS fix every '
      'tick for > 3 min (fake time), never re-stamped; the server would '
      'otherwise mark it stale after 120 s', () async {
    var now = DateTime.utc(2026, 11, 1, 12);
    final reporter = LiveLocationReporter(
      api: api(),
      location: _StillGps(answers: false),
      every: const Duration(hours: 1),
      now: () => now,
      restampHeldFix: false,
    );
    final first = <String, Object?>{
      'lat': 59.3326,
      'lng': 18.0649,
      'accuracy': 5.0,
      'measuredAt': now.toIso8601String(),
    };
    reporter.start(first: first);
    await pumpEventQueue();
    // Ticks every 10 s for 4 minutes: every one sends.
    for (var i = 0; i < 24; i++) {
      now = now.add(LiveLocationReporter.defaultEvery);
      expect(await reporter.sendNow(), isTrue, reason: 'tick $i');
    }
    expect(locations(), hasLength(25));
    final stamps = {
      for (final r in locations())
        (((jsonDecode(r.body) as Map)['fixes'] as List).single
            as Map)['measuredAt'],
    };
    expect(stamps, {'2026-11-01T12:00:00.000Z'}, reason: 'the OS time kept');
    // Checker: a fresh ask never falls back to the old fix.
    expect(await reporter.sendNow(fresh: true), isFalse);
    // Past the server's 10 min limit the old fix is not sent.
    now = now.add(const Duration(minutes: 7));
    expect(await reporter.sendNow(), isFalse);
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

  webGroup(() => sent, api);
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

/// G5 live re-test round 2 (web build on GitHub Pages): Chromium gives a
/// still position once (the Go online read) and then nothing: the watch
/// only errors (timeout) and one-shot reads time out.
class _WebStillGps implements DriverLocationRepository {
  _WebStillGps(this.now);
  final DateTime Function() now;
  int reads = 0;
  final StreamController<DriverLocation> stream =
      StreamController<DriverLocation>.broadcast();

  @override
  Future<DriverLocation> getCurrentPosition() async {
    reads++;
    if (reads > 1) throw TimeoutException('no new position');
    return DriverLocation(
      point: const GeoPoint(59.3326, 18.0649),
      accuracyMeters: 20,
      measuredAt: now(),
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      stream.stream;
}

void webGroup(List<http.Request> Function() sent, ApiClient Function() api) {
  test('web: a still tab keeps sending the held fix (stamped now) every '
      'tick for 6 min; a re-online takes the held fix', () async {
    var now = DateTime.utc(2026, 11, 1, 1, 52, 53);
    final gps = _WebStillGps(() => now);
    final reporter = LiveLocationReporter(
      api: api(),
      location: gps,
      every: const Duration(hours: 1),
      now: () => now,
      restampHeldFix: true,
    );
    final first = await reporter.freshFix();
    expect(first, isNotNull);
    reporter.start(first: first);
    await pumpEventQueue();
    // Chromium's watch: only timeout errors for a still position.
    gps.stream.addError(TimeoutException('watch timeout'));
    await pumpEventQueue();
    for (var i = 0; i < 36; i++) {
      now = now.add(LiveLocationReporter.defaultEvery);
      expect(await reporter.sendNow(), isTrue, reason: 'tick $i');
    }
    final posts = sent()
        .where((r) => r.url.path == LiveLocationReporter.locationPath)
        .toList();
    expect(posts, hasLength(37));
    final last =
        (((jsonDecode(posts.last.body) as Map)['fixes'] as List).single as Map);
    expect(last['measuredAt'], now.toIso8601String());
    // Offline, then Go online again: the held fix answers (stamped now).
    reporter.stop();
    now = now.add(const Duration(minutes: 1));
    final again = await reporter.freshFix();
    expect(again?['measuredAt'], now.toIso8601String());
    await gps.stream.close();
  });
}
