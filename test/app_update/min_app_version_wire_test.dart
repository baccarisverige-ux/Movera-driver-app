import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/app_update/min_app_version.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_reservations.dart';

/// Contract v0.18.154 P16c: the driver document's appUpdate reaches the rule,
/// the Android / iOS build sends X-App-Version + X-App-Platform, and a 426
/// app_update_required raises the block.
void main() {
  setUp(() {
    MinAppVersion.reset();
    MinAppVersion.running = const AppVersion(1, 4, 0);
    MinAppVersion.platform = 'android';
  });
  tearDown(MinAppVersion.reset);

  test('GET /driver/config: appUpdate.minVersion becomes the rule', () async {
    final config = LiveDriverConfig(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'version': 7,
            'zoneId': 'Z001',
            'currency': 'SEK',
            'appUpdate': {
              'minVersion': {'android': '1.5.0', 'ios': null},
            },
          }),
          200,
        ),
      ),
      apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
      accessToken: () async => 't',
      cache: MemoryDriverConfigCache(),
    );
    await config.refresh();
    expect(MinAppVersion.rule.value.minVersion['android'].toString(), '1.5.0');
    expect(MinAppVersion.required, isTrue);
  });

  test(
    'every API call carries the two headers; 426 raises the block',
    () async {
      final seen = <Map<String, String>>[];
      final api = ApiClient(
        client: MockClient((request) async {
          seen.add(request.headers);
          return http.Response(
            jsonEncode({
              'code': 'upgrade_required',
              'message': 'Update Movera to continue.',
              'requestId': 'r1',
              'retryable': false,
              'reason': 'app_update_required',
            }),
            426,
          );
        }),
        baseUri: Uri.parse('https://api.movera.invalid'),
        tokens: MemoryTokenStore(),
      );
      await expectLater(
        api.post(
          '/api/v1/driver/availability',
          body: {'onlineStatus': 'online'},
        ),
        throwsA(isA<ApiError>()),
      );
      expect(seen.single['X-App-Version'], '1.4.0');
      expect(seen.single['X-App-Platform'], 'android');
      expect(MinAppVersion.required, isTrue);
    },
  );

  test(
    'S-D1: a failed active-trip read is marked failed, a good one not',
    () async {
      var fail = true;
      final trip = LiveActiveTrip(
        api: ApiClient(
          client: MockClient(
            (request) async => fail
                ? http.Response('{"code":"unavailable","message":"x"}', 503)
                : http.Response(jsonEncode({'activeTripId': null}), 200),
          ),
          baseUri: Uri.parse('https://api.movera.invalid'),
          tokens: MemoryTokenStore(),
        ),
      );
      expect(await trip.fetch(), isNull);
      expect(trip.lastReadFailed, isTrue);
      fail = false;
      expect(await trip.fetch(), isNull);
      expect(trip.lastReadFailed, isFalse);
    },
  );

  test('O-2: the accepted list tells whether a booked ride is held', () async {
    MinAppVersion.bookedHeld.value = null;
    final reservations = LiveReservations(
      api: ApiClient(
        client: MockClient(
          (request) async => http.Response(jsonEncode({'items': []}), 200),
        ),
        baseUri: Uri.parse('https://api.movera.invalid'),
        tokens: MemoryTokenStore(),
      ),
    );
    await reservations.load();
    expect(MinAppVersion.bookedHeld.value, isFalse);
  });
}
