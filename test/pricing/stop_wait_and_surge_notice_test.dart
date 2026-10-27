import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/presentation/driver/notifications/surge_notice_banner.dart';

/// Contract v0.7.1 (owner Pricing decisions 2026-10-27): the driver app
/// reports "Framme vid stoppet" and leaving each middle stop to the server
/// (no free minutes at a stop), and shows Movera's surge notice on Home.
void main() {
  final origin = Uri.parse('https://api.test.movera.se');
  late List<http.Request> requests;
  late List<FutureOr<http.Response> Function(http.Request)> answers;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      if (answers.isEmpty) {
        return json(500, {
          'code': 'internal',
          'message': 'x',
          'requestId': 'r',
          'retryable': false,
        });
      }
      return answers.removeAt(0)(request);
    }),
    baseUri: origin,
    tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
  );

  setUp(() {
    requests = [];
    answers = [];
  });

  group('middle stops', () {
    Map<String, dynamic> trip(int version, [List<Object> visits = const []]) =>
        {
          'tripId': 't1',
          'status': 'in_trip',
          'version': version,
          if (visits.isNotEmpty) 'stopVisits': visits,
        };

    test('arrive and leave go to the stop with the trip version', () async {
      final trips = LiveTripCommands(api: api())..observe(trip(7));
      answers
        ..add(
          (_) => json(
            200,
            trip(8, [
              {'stopIndex': 0, 'arrivedAt': '2026-10-27T10:00:00Z'},
            ]),
          ),
        )
        ..add(
          (_) => json(
            200,
            trip(9, [
              {
                'stopIndex': 0,
                'arrivedAt': '2026-10-27T10:00:00Z',
                'leftAt': '2026-10-27T10:04:00Z',
              },
            ]),
          ),
        );
      expect((await trips.arriveAtStop('t1', 0)).ok, isTrue);
      expect((await trips.leaveStop('t1', 0)).ok, isTrue);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/driver/trips/t1/stops/0/arrive',
        '/api/v1/driver/trips/t1/stops/0/leave',
      ]);
      expect(jsonDecode(requests[0].body), {'expectedVersion': 7});
      expect(jsonDecode(requests[1].body), {'expectedVersion': 8});
      expect(requests[0].headers['Idempotency-Key'], isNotEmpty);
      // Already recorded: nothing is sent again.
      expect((await trips.leaveStop('t1', 0)).ok, isTrue);
      expect(requests, hasLength(2));
    });

    test('a refusal is shown; a stop the server already has is fine', () async {
      final trips = LiveTripCommands(api: api())..observe(trip(3));
      answers
        ..add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'message': 'Tap arrived at this stop first.',
            'requestId': 'r',
            'retryable': false,
            'reason': 'stop_not_arrived',
          }),
        )
        ..add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'message': 'You already arrived at this stop.',
            'requestId': 'r',
            'retryable': false,
            'reason': 'stop_already_arrived',
          }),
        );
      final refused = await trips.leaveStop('t1', 1);
      expect(refused.ok, isFalse);
      expect(refused.message, isNotEmpty);
      expect((await trips.arriveAtStop('t1', 1)).ok, isTrue);
    });
  });

  group('surge notice', () {
    final notices = {
      'items': [
        {
          'notificationId': 'n2',
          'audience': 'driver',
          'kind': 'surge_started',
          'title': 'Högre priser nu',
          'body': 'Prishöjning ×2.0 i ditt område. Fler resor väntar.',
          'at': '2026-10-27T10:00:00Z',
          'read': false,
          'data': {'zoneId': 'Z001', 'multiplier': 2},
        },
        {
          'notificationId': 'n1',
          'audience': 'driver',
          'kind': 'fleet_invitation',
          'title': 'Inbjudan',
          'body': 'x',
          'at': '2026-10-26T10:00:00Z',
          'read': false,
        },
      ],
      'nextCursor': null,
    };

    testWidgets(
      'Home shows the newest unread surge notice until it is closed',
      (tester) async {
        answers
          ..add((_) => json(200, notices))
          ..add(
            (_) => json(200, {
              ...(notices['items'] as List).first as Map,
              'read': true,
            }),
          );
        final session = DriverAccountSession(
          repository: DriverAccountRepository(api()),
        );
        await tester.runAsync(session.refreshUnread);
        expect(session.unreadNotifications.value, 2);
        expect(session.surgeNotice.value?.surgeMultiplier, 2);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SurgeNoticeBanner(
                session: session,
                pollEvery: const Duration(hours: 1),
              ),
            ),
          ),
        );
        expect(find.text('Högre priser nu'), findsOneWidget);
        expect(find.text('×2.0'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey<String>('surge-notice-close')),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('surge-notice-banner')),
          findsNothing,
        );
        expect(requests.last.url.path, '/api/v1/notifications/n2/read');
        expect(session.unreadNotifications.value, 1);
      },
    );
  });
}
