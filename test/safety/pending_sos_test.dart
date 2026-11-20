// Audit 2026-11-20 (app lifecycle) item 1: an SOS Movera did not confirm
// is kept on the phone and sent again, with the same Idempotency-Key and
// growing waits, until Movera has it, also after an app restart.
import 'dart:async';
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

  final t0 = DateTime.utc(2026, 11, 20, 12);
  final at = t0.toIso8601String();

  tearDown(DriverSos.resetForTesting);

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
      PendingSos(key: 'sos-k1', tripId: 'trp_9', body: {'at': at}),
    );
    networkUp = true;
    await DriverSos(
      api: api(),
      now: () => t0,
      sleep: (_) async {},
    ).retryPending();
    expect(posts.single.url.path, '/api/v1/driver/trips/trp_9/sos');
    expect(posts.single.headers['Idempotency-Key'], 'sos-k1');
    expect(await const PendingSosStore().read(), isNull);
  });

  test('a trip that ended first never drops the kept SOS', () async {
    // Ali presses SOS offline; the trip ends before the network is back.
    await const PendingSosStore().save(
      PendingSos(key: 'sos-k2', tripId: 'trp_9', body: {'at': at}),
    );
    networkUp = true;
    status = 409;
    final waits = <Duration>[];
    await expectLater(
      DriverSos(
        api: api(),
        now: () => t0.add(const Duration(minutes: 10)),
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
    await DriverSos.writesDone;
    expect((await const PendingSosStore().read())?.tripId, 'trp_1');
  });

  test('older than 30 min: dropped, never sent to a later trip', () async {
    await const PendingSosStore().save(
      const PendingSos(key: 'sos-k3', body: {'at': '2026-11-20T12:00:00Z'}),
    );
    networkUp = true;
    await DriverSos(
      api: api(),
      now: () => t0.add(const Duration(minutes: 31)),
      sleep: (_) async {},
    ).retryPending();
    expect(posts, isEmpty);
    expect(await const PendingSosStore().read(), isNull);
  });

  test('past the max age the driver is told it was not sent', () async {
    var told = 0;
    DriverSos.onExpired = () => told++;
    addTearDown(() => DriverSos.onExpired = null);
    await const PendingSosStore().save(
      const PendingSos(key: 'sos-k4', body: {'at': '2026-11-20T12:00:00Z'}),
    );
    await DriverSos(
      api: api(),
      now: () => t0.add(const Duration(minutes: 31)),
      sleep: (_) async {},
    ).retryPending();
    expect(told, 1);
  });

  test('the SOS POST never waits for the phone storage', () async {
    networkUp = true;
    final stuck = _StuckStore();
    final outcome = await DriverSos(
      api: api(),
      pending: stuck,
    ).send(tripId: 'trp_1').timeout(const Duration(seconds: 2));
    expect(outcome, DriverSosOutcome.sent);
    expect(posts, hasLength(1));
    stuck.disk.complete();
  });

  test('a confirmed SOS leaves nothing kept', () async {
    networkUp = true;
    expect(await DriverSos(api: api()).send(), DriverSosOutcome.sent);
    await DriverSos.writesDone;
    expect(await const PendingSosStore().read(), isNull);
  });
}

/// Storage that never answers (a slow or stuck disk).
class _StuckStore extends PendingSosStore {
  final Completer<void> disk = Completer<void>();

  @override
  Future<void> save(PendingSos sos) => disk.future;
}
