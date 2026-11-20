// Audit 2026-11-20 (app lifecycle) item 1: an SOS Movera did not confirm
// is kept on the phone and sent again, with the same Idempotency-Key and
// growing waits, until Movera has it, also after an app restart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> posts;
  late bool networkUp;
  late int status;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'activeTripId': 'trp_1'}), 200);
      }
      posts.add(request);
      if (!networkUp) throw http.ClientException('offline');
      return http.Response(
        jsonEncode(
          status == 200
              ? {'incidentId': 'inc_1', 'tripId': 'trp_1'}
              : {
                  'code': 'invalid_transition',
                  'message': 'x',
                  'requestId': 'r',
                },
        ),
        status,
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    posts = [];
    networkUp = false;
    status = 200;
  });

  test('a failed SOS is kept and sent again until confirmed', () async {
    final waits = <Duration>[];
    var tries = 0;
    final sos = DriverSos(
      api: api(),
      sleep: (d) async {
        waits.add(d);
        // The network comes back during the background retries.
        if (++tries == 6) networkUp = true;
      },
    );
    expect(await sos.send(), DriverSosOutcome.failed);
    final kept = await const PendingSosStore().read();
    expect(kept, isNotNull);
    expect(kept!.tripId, 'trp_1');
    await sos.retryPending();
    expect(await const PendingSosStore().read(), isNull);
    expect(
      posts.map((r) => r.headers['Idempotency-Key']).toSet(),
      hasLength(1),
    );
    expect(posts.map((r) => r.body).toSet(), hasLength(1));
    expect(
      waits.skip(DriverSos.retryDelays.length).first,
      DriverSos.backgroundDelays.first,
    );
  });

  test('after an app restart the kept SOS is sent', () async {
    await const PendingSosStore().save(
      const PendingSos(key: 'sos-k1', tripId: 'trp_9', body: {'at': 't'}),
    );
    networkUp = true;
    await DriverSos(api: api(), sleep: (_) async {}).retryPending();
    expect(posts.single.url.path, '/api/v1/driver/trips/trp_9/sos');
    expect(posts.single.headers['Idempotency-Key'], 'sos-k1');
    expect(await const PendingSosStore().read(), isNull);
  });

  test('a trip that ended first never drops the kept SOS', () async {
    // Ali presses SOS offline; the trip ends before the network is back.
    await const PendingSosStore().save(
      const PendingSos(key: 'sos-k2', tripId: 'trp_9', body: {'at': 't'}),
    );
    networkUp = true;
    status = 409;
    final waits = <Duration>[];
    await expectLater(
      DriverSos(
        api: api(),
        sleep: (d) async {
          waits.add(d);
          if (waits.length == 3) throw StateError('stop the test loop');
        },
      ).retryPending(),
      throwsStateError,
    );
    expect(posts, hasLength(3));
    expect(waits, everyElement(DriverSos.refusedDelay));
    expect((await const PendingSosStore().read())?.key, 'sos-k2');
  });

  test('a press refused as not live is kept and reads not sent', () async {
    networkUp = true;
    status = 409;
    final outcome = await DriverSos(
      api: api(),
      sleep: (_) async => throw StateError('stop'),
    ).send(tripId: 'trp_1');
    expect(outcome, DriverSosOutcome.failed);
    expect((await const PendingSosStore().read())?.tripId, 'trp_1');
  });

  test('a confirmed SOS leaves nothing kept', () async {
    networkUp = true;
    expect(await DriverSos(api: api()).send(), DriverSosOutcome.sent);
    expect(await const PendingSosStore().read(), isNull);
  });
}
