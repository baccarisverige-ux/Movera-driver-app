// Safety part 1 (contract v0.7.0 §15, owner decisions 2026-10-27): the
// driver's SOS opens 112 on the phone AND alerts Movera through
// POST /driver/trips/{tripId}/sos with the phone's GPS; it retries with the
// same Idempotency-Key and the toolkit then says only "SOS sent".
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/presentation/driver/safety toolkits/safety_toolkits.dart';

void main() {
  late List<http.Request> sent;
  late List<int> answers;
  String? activeTrip;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      sent.add(request);
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'driverId': 'drv_1', 'activeTripId': activeTrip}),
          200,
        );
      }
      final status = answers.isEmpty ? 200 : answers.removeAt(0);
      return http.Response(
        jsonEncode(
          status == 200
              ? {
                  'incidentId': 'inc_1',
                  'tripId': 'trp_1',
                  'receivedAt': '2026-10-27T10:00:01Z',
                }
              : {
                  'code': status == 409 ? 'invalid_transition' : 'unavailable',
                  'message': 'x',
                  'requestId': 'r',
                  'retryable': status != 409,
                },
        ),
        status,
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore(),
  );
  const fix = <String, Object?>{
    'lat': 59.3331,
    'lng': 18.0651,
    'accuracy': 6.0,
    'measuredAt': '2026-10-27T10:00:00.000Z',
  };

  setUp(() {
    sent = [];
    answers = [];
    activeTrip = 'trp_1';
  });

  List<http.Request> posts() => sent.where((r) => r.method == 'POST').toList();

  test('sends at and the GPS once to the trip the server holds', () async {
    final outcome = await DriverSos(api: api()).send(fix: fix);
    expect(outcome, DriverSosOutcome.sent);
    expect(sent.first.url.path, '/api/v1/driver/profile');
    expect(posts().single.url.path, '/api/v1/driver/trips/trp_1/sos');
    final body = jsonDecode(posts().single.body) as Map<String, dynamic>;
    expect(body['position'], {
      'lat': 59.3331,
      'lng': 18.0651,
      'accuracyM': 6.0,
      'at': '2026-10-27T10:00:00.000Z',
    });
    expect(body['at'], isA<String>());
    expect(posts().single.headers['Idempotency-Key'], startsWith('sos-'));
  });

  test('retries with the same Idempotency-Key and body', () async {
    answers = [503, 503];
    final waits = <Duration>[];
    final outcome = await DriverSos(
      api: api(),
      sleep: (d) async => waits.add(d),
    ).send(tripId: 'trp_1');
    expect(outcome, DriverSosOutcome.sent);
    expect(posts(), hasLength(3));
    expect(
      posts().map((r) => r.headers['Idempotency-Key']).toSet(),
      hasLength(1),
    );
    expect(posts().map((r) => r.body).toSet(), hasLength(1));
    expect(waits, DriverSos.retryDelays.take(2));
    expect(jsonDecode(posts().first.body), isNot(contains('position')));
  });

  test('no trip, a trip that is not live, and giving up', () async {
    activeTrip = null;
    expect(await DriverSos(api: api()).send(), DriverSosOutcome.noTrip);
    expect(posts(), isEmpty);
    answers = [409];
    expect(
      await DriverSos(api: api()).send(tripId: 'trp_1'),
      DriverSosOutcome.noTrip,
    );
    answers = [503, 503, 503, 503];
    sent = [];
    expect(
      await DriverSos(api: api(), sleep: (_) async {}).send(tripId: 'trp_1'),
      DriverSosOutcome.failed,
    );
    expect(posts(), hasLength(4));
    expect(DriverSos.positionOf(null), isNull);
    expect(DriverSos.positionOf(const {'lat': 1}), isNull);
  });

  test('the demo has no server: the SOS reads as sent', () async {
    expect(await DriverSos.fromApp(), DriverSosOutcome.sent);
  });

  Future<void> open(
    WidgetTester tester, {
    required Future<bool> Function() dial,
    required Future<DriverSosOutcome> Function() sos,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyToolKits(
            launchEmergencyDial: dial,
            sendSos: sos,
            web: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-sos')));
    await tester.pumpAndSettle();
    expect(find.text('Send SOS?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-sos-send')));
    await tester.pumpAndSettle();
  }

  testWidgets('SOS button: opens 112 and alerts Movera, then "SOS sent"', (
    tester,
  ) async {
    var dials = 0;
    var alerts = 0;
    await open(
      tester,
      dial: () async {
        dials++;
        return true;
      },
      sos: () async {
        alerts++;
        return DriverSosOutcome.sent;
      },
    );
    expect((dials, alerts), (1, 1));
    expect(find.text('SOS sent'), findsOneWidget);
  });

  testWidgets('no dialer, no trip, not sent: the driver is told to call 112', (
    tester,
  ) async {
    await open(
      tester,
      dial: () async => false,
      sos: () async => DriverSosOutcome.sent,
    );
    expect(
      find.text('SOS sent. Could not open the dialer: dial 112 on your phone.'),
      findsOneWidget,
    );
    await open(
      tester,
      dial: () async => true,
      sos: () async => DriverSosOutcome.noTrip,
    );
    expect(
      find.text('SOS to Movera works during a trip. Call 112.'),
      findsOneWidget,
    );
    await open(
      tester,
      dial: () async => true,
      sos: () async => DriverSosOutcome.failed,
    );
    expect(find.text('SOS could not reach Movera. Call 112.'), findsOneWidget);
  });

  testWidgets('cancel sends nothing', (tester) async {
    var alerts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyToolKits(
            launchEmergencyDial: () async => true,
            sendSos: () async {
              alerts++;
              return DriverSosOutcome.sent;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-sos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(alerts, 0);
    expect(find.text('SOS sent'), findsNothing);
  });
}
