import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_location_share.dart';
import 'package:movera/presentation/driver/accept%20ride/driver_live_location_card.dart';

/// Contract v0.18.144 (`contract.json#liveLocation`, owner 2026-11-20): the
/// rider's live dot on the driver's map and the driver's own switch.
void main() {
  const pickup = GeoPoint(59.3300, 18.0600);
  ApiClient api(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(
        client: MockClient(handler),
        baseUri: Uri.parse('https://api.example.test'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      );
  http.Response ok() => http.Response(
    jsonEncode({'sharing': false, 'sendEverySeconds': 8}),
    200,
    headers: {'content-type': 'application/json'},
  );
  http.Response off() => http.Response(
    jsonEncode({
      'code': 'conflict',
      'message': 'off',
      'reason': 'live_location_off',
    }),
    409,
    headers: {'content-type': 'application/json'},
  );

  tearDown(LiveLocationHub.clear);

  test(
    'a rider frame sets the dot; sharing false clears it; a trip event is not a frame',
    () {
      final at = DateTime.utc(2026, 11, 20, 10);
      expect(
        LiveLocationHub.offer({
          'tripId': 't1',
          'side': 'rider',
          'sharing': true,
          'lat': 59.3301,
          'lng': 18.0601,
          'at': at.toIso8601String(),
        }, now: at),
        isTrue,
      );
      expect(LiveLocationHub.freshFor('t1', now: at)?.point.latitude, 59.3301);
      expect(
        LiveLocationHub.freshFor(
          't1',
          now: at.add(const Duration(seconds: 30)),
        ),
        isNull,
        reason: 'older than 3 x 8 s',
      );
      expect(LiveLocationHub.freshFor('t2', now: at), isNull);
      expect(
        LiveLocationHub.offer({
          'tripId': 't1',
          'side': 'rider',
          'sharing': false,
          'at': at.toIso8601String(),
        }),
        isTrue,
      );
      expect(LiveLocationHub.riderDot.value, isNull);
      expect(
        LiveLocationHub.offer({
          'eventId': 'e',
          'sequence': 3,
          'tripId': 't1',
          'kind': 'location',
        }),
        isFalse,
      );
    },
  );

  test('sender: PUT with the point; 409 live_location_off stops it', () async {
    final bodies = <Object?>[];
    var refuse = false;
    final client = api((request) async {
      expect(request.url.path, '/api/v1/trips/t1/live-location');
      bodies.add(jsonDecode(request.body));
      return refuse ? off() : ok();
    });
    LiveShareStop? why;
    final sender = LiveLocationSender(
      api: client,
      tripId: 't1',
      position: () => pickup,
      every: const Duration(hours: 1),
      onStopped: (w) => why = w,
    );
    sender.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bodies.single, {
      'sharing': true,
      'lat': pickup.latitude,
      'lng': pickup.longitude,
    });
    refuse = true;
    await sender.tick();
    expect(why, LiveShareStop.zoneOff);
    expect(sender.running, isFalse);
  });

  testWidgets('zone off: the card stays hidden after one probe', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverLiveLocationCard(
            api: api((_) async {
              calls++;
              return off();
            }),
            tripId: 't1',
            riderName: 'Sara Berg',
            pickup: pickup,
            position: () => pickup,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.byKey(const ValueKey<String>('driver-share-location-switch')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a 503 probe does not hide the card: it asks again in 30 s', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverLiveLocationCard(
            api: api((_) async {
              calls++;
              return calls == 1
                  ? http.Response(
                      '{"code":"unavailable","message":"busy"}',
                      503,
                      headers: {'content-type': 'application/json'},
                    )
                  : ok();
            }),
            tripId: 't1',
            riderName: 'Sara Berg',
            pickup: pickup,
            position: () => pickup,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final key = find.byKey(
      const ValueKey<String>('driver-share-location-switch'),
    );
    expect(key, findsNothing);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(calls, 2);
    expect(key, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'zone on: the switch starts OFF (the driver opts in); a sharing rider shows "Sara is sharing … m from pickup"',
    (tester) async {
      final puts = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverLiveLocationCard(
              api: api((request) async {
                puts.add(jsonDecode(request.body));
                return ok();
              }),
              tripId: 't1',
              riderName: 'Sara Berg',
              pickup: pickup,
              position: () => pickup,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final key = find.byKey(
        const ValueKey<String>('driver-share-location-switch'),
      );
      expect(
        tester.widget<Switch>(key).value,
        isFalse,
        reason: 'no auto-share',
      );
      expect(puts, [
        {'sharing': false},
      ], reason: 'only the probe, no point');
      await tester.tap(key);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Switch>(key).value, isTrue);
      expect(puts.last, {
        'sharing': true,
        'lat': pickup.latitude,
        'lng': pickup.longitude,
      });
      expect(find.text('Sara sees you on the map.'), findsOneWidget);
      expect(
        find.text(
          'Your live location is sent only to your rider until pickup and is not saved.',
        ),
        findsOneWidget,
      );
      LiveLocationHub.offer({
        'tripId': 't1',
        'side': 'rider',
        'sharing': true,
        'lat': 59.33011,
        'lng': 18.0600,
        'at': DateTime.now().toIso8601String(),
      });
      await tester.pump();
      expect(
        find.textContaining('Sara is sharing their location ('),
        findsOneWidget,
      );
      expect(find.textContaining('m from pickup)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(
        LiveLocationHub.riderDot.value,
        isNull,
        reason: 'the screen closed: the point is forgotten',
      );
    },
  );

  test('position: only a real fix at most 30 s old; none = nothing', () {
    final now = DateTime.utc(2026, 11, 20, 10);
    expect(freshDriverPoint(null, now: now), isNull);
    expect(
      freshDriverPoint({
        'lat': 59.3,
        'lng': 18.0,
        'measuredAt': now
            .subtract(const Duration(seconds: 45))
            .toIso8601String(),
      }, now: now),
      isNull,
    );
    expect(
      freshDriverPoint({
        'lat': 59.3,
        'lng': 18.0,
        'measuredAt': now
            .subtract(const Duration(seconds: 5))
            .toIso8601String(),
      }, now: now)?.latitude,
      59.3,
    );
  });

  test('sender with no fix sends nothing', () async {
    var puts = 0;
    final sender = LiveLocationSender(
      api: api((_) async {
        puts++;
        return ok();
      }),
      tripId: 't1',
      position: () => null,
      every: const Duration(hours: 1),
    );
    sender.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(puts, 0);
    await sender.stop(tellServer: false);
  });

  testWidgets(
    'app paused: sharing stops and the switch shows off until tapped',
    (tester) async {
      final puts = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverLiveLocationCard(
              api: api((r) async {
                puts.add(jsonDecode(r.body));
                return ok();
              }),
              tripId: 't1',
              riderName: 'Sara',
              pickup: pickup,
              position: () => pickup,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final key = find.byKey(
        const ValueKey<String>('driver-share-location-switch'),
      );
      await tester.tap(key);
      await tester.pump();
      expect(tester.widget<Switch>(key).value, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.widget<Switch>(key).value, isFalse);
      expect(puts.last, {'sharing': false});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester.widget<Switch>(key).value,
        isFalse,
        reason: 'resumes only on a tap',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
