import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/live/reservations_refresh.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// L-a driver (owner answers Q1, Q3, Q4, Q6, Q7 in Rules
/// decisions/driver-g15.md; plan/LA-BUILD-PLAN-2026-11-06.md §5): a live
/// build shows only what the server sent.
void main() {
  late DriverRuntimeConfig previous;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ApiClient api(http.Response Function(http.Request) answer) => ApiClient(
    client: MockClient((request) async => answer(request)),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );

  void live() => DriverRuntimeConfig.current = const DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: false,
    skipAccountActivation: true,
    authRequired: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    PickupPayConfig.current = const PickupPayConfig();
  });

  group('Q4 no pickup pay until the server sends it (D7)', () {
    test('live: off before the config, the server rates after', () {
      live();
      PickupPayConfig.reset();
      expect(PickupPayConfig.current.rateFor('Movera').enabled, isFalse);
      expect(PickupPayConfig.current.kinds, isEmpty);
      PickupPayConfig.current = const PickupPayConfig(
        categories: {'Movera': PickupPayRate(krPerKm: 2, krPerMinute: 1)},
      );
      expect(PickupPayConfig.current.rateFor('Movera').krPerKm, 2);
    });

    test('demo keeps the demo rates', () {
      PickupPayConfig.reset();
      expect(PickupPayConfig.current.rateFor('Movera').krPerKm, 2.5);
    });
  });

  group('Q7 Live push for booked rides (D6)', () {
    Map<String, Object?> row(String id) => {
      'tripId': id,
      'version': 1,
      'status': 'open',
      'scheduledAt': DateTime.now()
          .add(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
      'categoryId': 'economy',
      'rideType': 'normal',
      'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
      'dropoff': {'address': 'Bromma', 'lat': 59.35, 'lng': 17.94},
      'stops': 0,
      'distanceMeters': 8000,
      'durationSeconds': 1080,
      'earnings': {'amountMinor': 15000, 'currency': 'SEK'},
      'mustBeOnlineAt': DateTime.now()
          .add(const Duration(hours: 23))
          .toUtc()
          .toIso8601String(),
      'canStartAt': DateTime.now()
          .add(const Duration(hours: 23))
          .toUtc()
          .toIso8601String(),
    };

    testWidgets('demo rides touched before sign-in are gone after it; only '
        'the server rides stay', (tester) async {
      ScheduledRideStore.reset();
      // Touched before sign-in (the demo seed).
      expect(ScheduledRideStore.openRequests.value, greaterThan(0));
      final live = LiveReservations(
        api: api(
          (request) => json(200, {
            'items': [if (request.url.query.contains('open')) row('srv-1')],
            'nextCursor': null,
          }),
        ),
      );
      ScheduledRideStore.clearRides();
      expect(ScheduledRideStore.openRequests.value, 0);
      await tester.runAsync(() => ScheduledRideStore.syncFromServer(live));
      expect(ScheduledRideStore.serverRow('srv-1'), isNotNull);
      expect(ScheduledRideStore.openRequests.value, 1);
      ScheduledRideStore.reset();
    });

    test('driver_reservations_changed and every stream open ask for a '
        're-read', () async {
      var asked = 0;
      final events = StreamController<List<int>>();
      final opened = Completer<void>();
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            if (!opened.isCompleted) opened.complete();
            return http.StreamedResponse(events.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 'token-1',
        cache: MemoryDriverConfigCache(),
        onReservationsChanged: () => asked++,
      );
      await config.watch();
      await opened.future;
      await Future<void>.delayed(Duration.zero);
      expect(asked, 1, reason: 'the stream opened: read once');
      events.add(
        utf8.encode(
          'data: {"eventId":"e1","kind":"driver_reservations_changed",'
          '"tripId":"t1","occurredAt":"x","serverTime":"y"}\n\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(asked, 2);
      config.dispose();
      await events.close();
    });

    test('a stream reconnect asks for a re-read again', () async {
      var asked = 0;
      var connects = 0;
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            connects++;
            // The stream ends at once: the app reconnects.
            return http.StreamedResponse(const Stream.empty(), 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }),
        apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
        accessToken: () async => 'token-1',
        cache: MemoryDriverConfigCache(),
        retryAfter: const Duration(milliseconds: 10),
        onReservationsChanged: () => asked++,
      );
      await config.watch();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      config.dispose();
      expect(connects, greaterThanOrEqualTo(2));
      expect(asked, connects);
    });

    test('at most one read per gap; a burst of 5 is not lost', () async {
      var reads = 0;
      expect(ReservationsRefresh(read: () async {}).gap.inSeconds, 2);
      final refresh = ReservationsRefresh(
        read: () async => reads++,
        gap: const Duration(milliseconds: 200),
      );
      for (var i = 0; i < 5; i++) {
        refresh.request();
      }
      expect(reads, 1, reason: 'the first read runs at once');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(reads, 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(reads, 2, reason: 'one read for the rest of the burst');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(reads, 2, reason: 'nothing more without a new hint');
      refresh.dispose();
    });
  });
}
