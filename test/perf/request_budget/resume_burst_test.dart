// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/core/live/driver_app_resume.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'request_budget_harness.dart';

/// D12-5: the requests `LiveDriverServices.resumed` sends (main.dart's
/// AppLifecycleListener) when the app comes back. G27: the burst runs the
/// app's own listeners on a real lifecycle change: main.dart's
/// ([driverAppResumed]: the live services and the legal texts) and the
/// zones' own ([LiveDriverZones.watchResume], started by `signedIn`).
class _Client extends CountingClient {
  /// SSE streams opened while true never send a line (a dead socket).
  bool silent = false;
  final List<StreamController<List<int>>> _quiet = [];

  /// Own SSE streams: a cancel answered in the fake zone (the plain
  /// controller's cancel future lives in the root zone, which fake time
  /// never runs, so a reconnect would wait forever here).
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/driver/events') {
      sent.add((at: now(), key: endpointKey(request)));
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"items": []}')),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/driver/zones') {
      sent.add((at: now(), key: endpointKey(request)));
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"zones": []}')),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (request.headers['Accept'] != 'text/event-stream') {
      return super.send(request);
    }
    sent.add((at: now(), key: endpointKey(request)));
    Timer? beat;
    final c = StreamController<List<int>>(onCancel: () async => beat?.cancel());
    if (!silent) {
      beat = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!c.isClosed) c.add(utf8.encode(': hb\n'));
      });
    }
    _quiet.add(c);
    return http.StreamedResponse(c.stream, 200);
  }

  @override
  void closeAll() {
    super.closeAll();
    for (final c in _quiet) {
      if (!c.isClosed) unawaited(c.close());
    }
  }
}

class _Phone implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      const DriverLocation(point: GeoPoint(41.33, 19.82), accuracyMeters: 5);
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// Online idle for 5 minutes, then a resume: what goes out in 1 s.
Map<String, int> burst({
  required bool streamsSilent,
  Duration away = const Duration(minutes: 5),
}) {
  late Map<String, int> result;
  fakeAsync((async) {
    final client = _Client()
      ..now = (() => async.elapsed)
      ..silent = streamsSilent;
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final origin = Uri.parse('https://budget.invalid');
    DateTime clock() => DateTime.utc(2026, 11, 11).add(async.elapsed);
    final api = ApiClient(client: client, baseUri: origin, tokens: tokens);
    final live = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: api,
      location: _Phone(),
      now: clock,
    );
    // main.dart: the legal texts on start, and its resume listener.
    final legal = DriverLegal(
      api: api,
      cache: MemoryDriverLegalCache(),
      now: clock,
    );
    unawaited(legal.start(country: 'SE'));
    final listener = AppLifecycleListener(
      onResume: () => driverAppResumed(live: live, legal: legal),
    );
    live.signedIn();
    client.onlineStatus = 'online';
    unawaited(live.presence.goOnline());
    // The phone goes away and comes back, one state at a time (as the
    // platform reports it).
    final binding = WidgetsBinding.instance;
    void walk(List<AppLifecycleState> states) {
      for (final state in states) {
        binding.handleAppLifecycleStateChanged(state);
      }
    }

    walk(const [
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    async.elapse(away);
    final from = client.sent.length;
    walk(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    async.elapse(const Duration(seconds: 5));
    listener.dispose();
    live.zones.dispose();
    result = <String, int>{};
    for (final r in client.sent.skip(from)) {
      result[r.key] = (result[r.key] ?? 0) + 1;
    }
    unawaited(live.dispose());
    client.closeAll();
    async.elapse(const Duration(minutes: 2));
  });
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Before D12-5 a resume sent all six below even with healthy streams.
  const full = {
    'POST /api/v1/driver/location': 1,
    'GET /api/v1/driver/offers/stream (SSE open)': 1,
    'GET /api/v1/driver/offers': 1,
    'GET /api/v1/driver/config/stream (SSE open)': 1,
    'GET /api/v1/driver/config': 1,
    'GET /api/v1/driver/events': 1,
    // G27: read 5 minutes ago, so due again.
    'GET /api/v1/driver/zones': 1,
    'GET /api/v1/legal/SE': 1,
  };

  test('D12-5: a resume with live streams keeps them: the position and '
      'the events (read 5 min ago) only', () {
    expect(burst(streamsSilent: false), {
      'POST /api/v1/driver/location': 1,
      'GET /api/v1/driver/events': 1,
      // G27: the zones and the legal texts, read 5 minutes ago.
      'GET /api/v1/driver/zones': 1,
      'GET /api/v1/legal/SE': 1,
    });
    // Away 30 s: the events too were read less than a minute ago.
    expect(burst(streamsSilent: false, away: const Duration(seconds: 30)), {
      'POST /api/v1/driver/location': 1,
    });
  });

  test('D12-5: a resume after the streams went quiet (no line for 20 s) '
      'reopens both and reads config, offers and events again', () {
    expect(burst(streamsSilent: true), full);
  });

  test('D12-5: a resume right after sign-in does not read the events '
      'twice', () {
    final sent = burst(streamsSilent: true, away: const Duration(seconds: 30));
    expect(sent.containsKey('GET /api/v1/driver/events'), isFalse);
    // The streams had no line: they are reopened; config read first.
    expect(sent['GET /api/v1/driver/config'], 1);
    expect(sent['GET /api/v1/driver/offers/stream (SSE open)'], 1);
  });

  test('D12-5: Home badges on resume only when read 60 s ago or more', () {
    final t = DateTime.utc(2026, 11, 11, 9);
    expect(badgesDueOnResume(null, t), isTrue);
    expect(
      badgesDueOnResume(t.subtract(const Duration(seconds: 30)), t),
      isFalse,
    );
    expect(
      badgesDueOnResume(t.subtract(const Duration(seconds: 60)), t),
      isTrue,
    );
  });

  test('G27: a resume 30 s after the last read sends no legal or zones '
      'read (main.dart\'s listener and zones.watchResume)', () {
    final sent = burst(streamsSilent: false, away: const Duration(seconds: 30));
    expect(sent.keys.where((k) => k.startsWith('GET /api/v1/legal/')), isEmpty);
    expect(sent.containsKey('GET /api/v1/driver/zones'), isFalse);
    expect(sent, {'POST /api/v1/driver/location': 1});
  });

  test('G27: a resume 60 s or more after the last read reads the legal '
      'texts and the zones again', () {
    final sent = burst(streamsSilent: false, away: const Duration(seconds: 61));
    expect(sent['GET /api/v1/legal/SE'], 1);
    expect(sent['GET /api/v1/driver/zones'], 1);
  });
}
