// Owner 2026-11-20 "Show 'SOS not sent' (Rec.)" + supervisor findings:
// every kept SOS given up on tells the driver in a dialog that stays until
// OK (and comes back after a restart); another driver never sends it.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/sos_not_sent_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 12);
  final at = t0.toIso8601String();
  late List<http.Request> posts;
  late int status;
  late String me;
  late int told;
  late int profileStatus;
  late List<String> gets;
  Completer<void>? holdGet;
  Completer<int>? holdPost;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        gets.add(request.url.path);
        await holdGet?.future;
        return http.Response(
          jsonEncode(
            profileStatus == 200
                ? {'driverId': me, 'activeTripId': 'trp_2'}
                : {'code': 'forbidden', 'message': 'x', 'requestId': 'r'},
          ),
          profileStatus,
        );
      }
      posts.add(request);
      final held = holdPost;
      if (held != null) status = await held.future;
      return http.Response(
        jsonEncode(
          status == 200
              ? {'incidentId': 'inc_1'}
              : {'code': 'not_found', 'message': 'x', 'requestId': 'r'},
        ),
        status,
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore(),
  );

  DriverSos sos() => DriverSos(api: api(), now: () => t0, sleep: (_) async {});

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'movera_driver_local_owner': 'drv_A',
    });
    profileStatus = 200;
    gets = [];
    holdGet = null;
    holdPost = null;
    posts = [];
    status = 200;
    me = 'drv_A';
    told = 0;
    DriverSos.onExpired = () => told++;
  });
  tearDown(() async {
    DriverSos.onExpired = null;
    await DriverSos.resetForTesting();
  });

  test('a 404 refusal drops it and tells the driver', () async {
    await const PendingSosStore().save(
      PendingSos(key: 'k1', tripId: 'trp_1', body: {'at': at}),
    );
    status = 404;
    await sos().retryPending();
    expect(told, 1);
    expect(await const PendingSosStore().read(), isNull);
  });

  test('another driver never sends it, also not to his trip', () async {
    await const PendingSosStore().save(
      PendingSos(key: 'k2', driverId: 'drv_A', body: {'at': at}),
    );
    SharedPreferences.setMockInitialValues({
      'movera_driver_local_owner': 'drv_B',
      'pending_sos_v1': jsonEncode(
        PendingSos(key: 'k2', driverId: 'drv_A', body: {'at': at}).toJson(),
      ),
    });
    await sos().retryPending();
    expect(posts, isEmpty);
    expect(told, 1);
    expect(await const PendingSosStore().read(), isNull);
  });

  test('the press keeps the driver signed in at press time', () async {
    status = 503;
    var n = 0;
    final outcome = await DriverSos(
      api: api(),
      now: () => t0,
      sleep: (_) async {
        if (++n > DriverSos.retryDelays.length) throw StateError('stop');
      },
    ).send(tripId: 'trp_1');
    expect(outcome, DriverSosOutcome.failed);
    await DriverSos.writesDone;
    expect((await const PendingSosStore().read())?.driverId, 'drv_A');
  });

  test(
    'an SOS of unknown driver is never tagged or sent to a trip later',
    () async {
      await const PendingSosStore().save(
        PendingSos(key: 'k5', body: {'at': at}),
      );
      var n = 0;
      await expectLater(
        DriverSos(
          api: api(),
          now: () => t0,
          sleep: (_) async {
            if (++n == 2) throw StateError('stop');
          },
        ).retryPending(),
        throwsStateError,
      );
      expect(posts, isEmpty);
      expect(gets, isEmpty);
      final kept = await const PendingSosStore().read();
      expect(kept?.driverId, isNull);
    },
  );

  for (final code in [403, 401, 503]) {
    test('a profile read answered $code keeps the SOS', () async {
      await const PendingSosStore().save(
        PendingSos(key: 'k6', driverId: 'drv_A', body: {'at': at}),
      );
      profileStatus = code;
      var n = 0;
      await expectLater(
        DriverSos(
          api: api(),
          now: () => t0,
          sleep: (_) async {
            if (++n == 2) throw StateError('stop');
          },
        ).retryPending(),
        throwsStateError,
      );
      expect(told, 0);
      expect((await const PendingSosStore().read())?.key, 'k6');
    });
  }

  test('after sign-out the retry never saves it again', () async {
    await const PendingSosStore().save(
      PendingSos(
        key: 'k7',
        tripId: 'trp_1',
        driverId: 'drv_A',
        body: {'at': at},
      ),
    );
    await DriverSos.signedOut();
    await sos().retryPending();
    expect(posts, isEmpty);
    expect(await const PendingSosStore().read(), isNull);
  });

  test('sign-out drops a kept SOS and tells the driver', () async {
    await const PendingSosStore().save(PendingSos(key: 'k4', body: {'at': at}));
    await DriverSos.signedOut();
    expect(told, 1);
    expect(await const PendingSosStore().read(), isNull);
    await DriverSos.signedOut();
    expect(told, 1, reason: 'nothing kept: nothing to tell');
  });

  test('a trip-less press whose profile read is 403 keeps the SOS', () async {
    profileStatus = 403;
    var n = 0;
    final outcome = await DriverSos(
      api: api(),
      now: () => t0,
      sleep: (_) async {
        if (++n > DriverSos.retryDelays.length) throw StateError('stop');
      },
    ).send();
    expect(outcome, DriverSosOutcome.failed);
    await DriverSos.writesDone;
    expect((await const PendingSosStore().read())?.driverId, 'drv_A');
    expect(told, 0);
  });

  test('a press from before sign-out is never saved again or posted', () async {
    holdGet = Completer<void>();
    final press = DriverSos(api: api(), now: () => t0).send();
    await Future<void>.delayed(Duration.zero);
    await DriverSos.signedOut();
    holdGet!.complete();
    expect(await press, DriverSosOutcome.failed);
    await DriverSos.writesDone;
    expect(posts, isEmpty);
    expect(await const PendingSosStore().read(), isNull);
  });

  for (final ok in [true, false]) {
    test(
      'a retry on its way at sign-out: told only if it fails ($ok)',
      () async {
        await const PendingSosStore().save(
          PendingSos(
            key: 'k8',
            tripId: 'trp_1',
            driverId: 'drv_A',
            body: {'at': at},
          ),
        );
        holdPost = Completer<int>();
        final retry = sos().retryPending();
        while (posts.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        await DriverSos.signedOut();
        expect(told, 0);
        holdPost!.complete(ok ? 200 : 503);
        await retry;
        expect(told, ok ? 0 : 1);
        expect(posts, hasLength(1));
        expect(await const PendingSosStore().read(), isNull);
      },
    );
  }

  testWidgets('the notice stays until OK and comes back after a restart', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox()),
    );
    final notice = SosNotSentNotice.instance;
    addTearDown(notice.resetForTesting);
    notice.context = () => key.currentContext;
    // Raised while nothing could show it (locked, no UI yet): kept.
    notice.context = () => null;
    await tester.runAsync(notice.raise);
    expect(await tester.runAsync(notice.pending), isTrue);
    // The next start: shown.
    notice.attach(() => key.currentContext);
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('sos-not-sent-notice'));
    expect(dialog, findsOneWidget);
    expect(find.text('SOS could not reach Movera. Call 112.'), findsOneWidget);
    // A tap outside does not close it.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(await tester.runAsync(notice.pending), isFalse);
  });

  testWidgets('a notice raised while one is up is shown again after OK; '
      'two shows never stack', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const SizedBox()),
    );
    final notice = SosNotSentNotice.instance;
    addTearDown(notice.resetForTesting);
    notice.context = () => key.currentContext;
    unawaited(notice.raise());
    unawaited(notice.showIfPending(force: true));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('sos-not-sent-notice'));
    expect(dialog, findsOneWidget);
    unawaited(notice.raise());
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget, reason: 'the second one');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });
}
