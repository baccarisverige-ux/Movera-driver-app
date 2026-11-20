// Owner 2026-11-20 "Show 'SOS not sent' (Rec.)" + supervisor findings:
// every kept SOS given up on tells the driver in a dialog that stays until
// OK (and comes back after a restart); another driver never sends it.
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

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'driverId': me, 'activeTripId': 'trp_2'}),
          200,
        );
      }
      posts.add(request);
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
    SharedPreferences.setMockInitialValues({});
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
    me = 'drv_B';
    await sos().retryPending();
    expect(posts, isEmpty);
    expect(told, 1);
    expect(await const PendingSosStore().read(), isNull);
  });

  test('the first profile read records whose SOS it is', () async {
    await const PendingSosStore().save(
      PendingSos(key: 'k3', tripId: 'trp_1', body: {'at': at}),
    );
    status = 503;
    var n = 0;
    await expectLater(
      DriverSos(
        api: api(),
        now: () => t0,
        sleep: (_) async {
          if (++n == 1) throw StateError('stop');
        },
      ).retryPending(),
      throwsStateError,
    );
    expect((await const PendingSosStore().read())?.driverId, 'drv_A');
  });

  test('sign-out drops a kept SOS and tells the driver', () async {
    await const PendingSosStore().save(PendingSos(key: 'k4', body: {'at': at}));
    await DriverSos.signedOut();
    expect(told, 1);
    expect(await const PendingSosStore().read(), isNull);
    await DriverSos.signedOut();
    expect(told, 1, reason: 'nothing kept: nothing to tell');
  });

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
}
