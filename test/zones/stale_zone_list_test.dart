import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/zones/driver_zone.dart';

/// Owner 2026-11-10 ("Yes, fix now"): the zone list kept on the device is
/// read again when the app comes back, and a failed read while an old copy
/// is in use is retried (bounded). The server is the final judge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(DriverZones.forget);

  Map<String, Object?> zone(String id) => {
    'zoneId': id,
    'polygon': [
      [59, 17],
      [60, 17],
      [60, 19],
    ],
  };

  LiveDriverZones live(
    http.Response Function(int read) answer, {
    List<Duration>? retryDelays,
    void Function()? onRead,
  }) {
    var reads = 0;
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    return LiveDriverZones(
      api: ApiClient(
        client: MockClient((request) async {
          onRead?.call();
          return answer(++reads);
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      cache: MemoryDriverZonesCache(),
      retryDelays: retryDelays,
    );
  }

  http.Response ok(List<String> ids) => http.Response(
    jsonEncode({
      'zones': [for (final id in ids) zone(id)],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
  http.Response down() => http.Response('{"code":"X"}', 503);

  testWidgets('coming back to the app reads the zones again', (tester) async {
    var reads = 0;
    final zones = live((_) => ok(['Z001']), onRead: () => reads++);
    zones.watchResume();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(reads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(reads, 1);
    zones.dispose();
  });

  test('a failed read with an old copy in use is retried (bounded)', () async {
    {
      DriverZones.useServer([DriverZone.fromJson(zone('Z001'))!]);
      var reads = 0;
      final zones = live(
        (n) => n < 3 ? down() : ok(['Z001', 'TN-TC']),
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
        ],
        onRead: () => reads++,
      );
      await zones.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(reads, 3);
      expect(DriverZones.offers('TN-TC'), isTrue);
    }
  });

  test('retries stop after the last delay', () async {
    {
      DriverZones.useServer([DriverZone.fromJson(zone('Z001'))!]);
      var reads = 0;
      final zones = live(
        (_) => down(),
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
        ],
        onRead: () => reads++,
      );
      await zones.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(reads, 3);
    }
  });
}
